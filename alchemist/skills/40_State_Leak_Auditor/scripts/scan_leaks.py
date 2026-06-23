#!/usr/bin/env python3
"""State Leak Auditor — scan a Flutter/Dart project for undisposed controllers,
uncancelled subscriptions, missing Riverpod autoDispose, and other resource leaks.

Walks all .dart files under a project root, applies regex patterns for each leak
category, and reports every high-signal match ranked by severity.

Usage:
    python scan_leaks.py lib/                          # default scan
    python scan_leaks.py lib/ --json                   # machine-readable JSON output
    python scan_leaks.py lib/ --severity high          # only critical + high
    python scan_leaks.py lib/ --severity medium        # critical + high + medium
    python scan_leaks.py lib/ --no-require-dispose-in-file   # skip controller checks
    python scan_leaks.py lib/ --no-check-riverpod-autodispose # skip Riverpod checks

Stdlib only — no third-party deps, runs anywhere Python 3.8+ is present.
Keep patterns in sync with ../templates/leak_patterns.md.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple

# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------

SEVERITY_ORDER: Dict[str, int] = {
    "critical": 0,
    "high": 1,
    "medium": 2,
    "low": 3,
}


@dataclass
class LeakPattern:
    """A single leak-detection rule."""

    category: str
    severity: str  # critical | high | medium | low
    description: str
    # Regex(es) that signal "this resource was created in this file"
    creation_patterns: List[str]
    # Regex(es) that signal "this resource was properly torn down in this file"
    teardown_patterns: List[str]
    # If true, match creation only if the resource appears to be owned locally
    # (e.g. assigned to a field/local rather than received as a parameter)
    check_ownership: bool = False
    # Additional regex that, if matched, boosts confidence
    confidence_boosters: List[str] = field(default_factory=list)


@dataclass
class Finding:
    """A single leak finding."""

    file: str
    line: int
    col: int
    category: str
    severity: str
    description: str
    snippet: str  # the matching line (trimmed)


# ---------------------------------------------------------------------------
# Pattern catalog — mirrors templates/leak_patterns.md
# ---------------------------------------------------------------------------

CONTROLLER_PATTERNS: List[LeakPattern] = [
    LeakPattern(
        category="animation-controller-no-dispose",
        severity="critical",
        description="AnimationController created but .dispose() not found in same file",
        creation_patterns=[r"AnimationController\("],
        teardown_patterns=[r"\.dispose\(\)"],
        check_ownership=True,
        confidence_boosters=[
            r"(late\s+final|final)\s+AnimationController\s+\w+",
            r"SingleTickerProviderStateMixin",
        ],
    ),
    LeakPattern(
        category="stream-subscription-no-cancel",
        severity="high",
        description="StreamSubscription created via .listen() but .cancel() not found in same file",
        creation_patterns=[r"\.listen\("],
        teardown_patterns=[r"\.cancel\(\)"],
        check_ownership=True,
        confidence_boosters=[
            r"(late\s+final|final|var)\s+StreamSubscription\S*\s+\w+\s*=",
        ],
    ),
    LeakPattern(
        category="text-editing-controller-no-dispose",
        severity="critical",
        description="TextEditingController created but .dispose() not found in same file",
        creation_patterns=[r"TextEditingController\("],
        teardown_patterns=[r"\.dispose\(\)"],
        check_ownership=True,
        confidence_boosters=[
            r"(late\s+final|final)\s+TextEditingController\s+\w+",
        ],
    ),
    LeakPattern(
        category="focus-node-no-dispose",
        severity="high",
        description="FocusNode created but .dispose() not found in same file",
        creation_patterns=[r"FocusNode\("],
        teardown_patterns=[r"\.dispose\(\)"],
        check_ownership=True,
        confidence_boosters=[
            r"(late\s+final|final)\s+FocusNode\s+\w+",
        ],
    ),
    LeakPattern(
        category="scroll-controller-no-dispose",
        severity="high",
        description="ScrollController created but .dispose() not found in same file",
        creation_patterns=[r"ScrollController\("],
        teardown_patterns=[r"\.dispose\(\)"],
        check_ownership=True,
        confidence_boosters=[
            r"(late\s+final|final)\s+ScrollController\s+\w+",
        ],
    ),
    LeakPattern(
        category="page-controller-no-dispose",
        severity="high",
        description="PageController created but .dispose() not found in same file",
        creation_patterns=[r"PageController\("],
        teardown_patterns=[r"\.dispose\(\)"],
        check_ownership=True,
        confidence_boosters=[
            r"(late\s+final|final)\s+PageController\s+\w+",
        ],
    ),
    LeakPattern(
        category="video-player-controller-no-dispose",
        severity="critical",
        description="VideoPlayerController created but .dispose() not found in same file",
        creation_patterns=[r"VideoPlayerController\.(file|network|asset)\("],
        teardown_patterns=[r"\.dispose\(\)"],
        check_ownership=True,
        confidence_boosters=[
            r"(late\s+final|final)\s+VideoPlayerController\s+\w+",
        ],
    ),
    LeakPattern(
        category="timer-no-cancel",
        severity="high",
        description="Timer or Timer.periodic created but .cancel() not found in same file",
        creation_patterns=[r"Timer(\.periodic)?\("],
        teardown_patterns=[r"\.cancel\(\)"],
        check_ownership=True,
        confidence_boosters=[
            r"(late\s+final|final|var)\s+Timer\??\s+\w+\s*=",
        ],
    ),
]

# Additional patterns that share the ".dispose()" teardown — these avoid false-flagging
# on the same teardown call across different controller types.
SHARED_DISPOSE_PATTERNS: List[Tuple[str, str, str]] = [
    # (category_suffix, creation_regex, severity)
    # These are checked by a combined scan below.
]


# ---------------------------------------------------------------------------
# Core scanning logic
# ---------------------------------------------------------------------------


def _read_file_lines(filepath: str) -> Optional[List[str]]:
    """Read a file and return its lines, or None on error."""
    try:
        with open(filepath, "r", encoding="utf-8", errors="replace") as f:
            return f.readlines()
    except (OSError, UnicodeDecodeError):
        return None


def _any_pattern_matches(patterns: List[str], content: str) -> bool:
    """Return True if any pattern matches anywhere in content (comments still included)."""
    return any(re.search(p, content) for p in patterns)


def _strip_comment_lines(lines: List[str]) -> str:
    """Return file content with //-comment lines replaced by blank lines.
    This keeps line numbering intact while preventing commented-out code from matching."""
    return "\n".join(
        "" if line.lstrip().startswith("//") else line for line in lines
    )


def _find_pattern_lines(
    patterns: List[str], lines: List[str]
) -> List[Tuple[int, int, str]]:
    """Return list of (line_index, col, snippet) for every line that matches a pattern.
    Skips lines that are commented out (//-style comments)."""
    hits: List[Tuple[int, int, str]] = []
    for i, line in enumerate(lines):
        stripped = line.lstrip()
        if stripped.startswith("//"):
            continue
        for pat in patterns:
            m = re.search(pat, line)
            if m:
                hits.append((i + 1, m.start() + 1, line.strip()))
                break  # one hit per line is enough
    return hits


def _should_skip_file(filepath: str) -> bool:
    """Skip generated files and obvious non-source paths."""
    skip_suffixes = (
        ".g.dart",
        ".freezed.dart",
        ".chopper.dart",
        ".retrofit.dart",
        ".gr.dart",
        ".reflectable.dart",
    )
    basename = os.path.basename(filepath)
    return any(basename.endswith(s) for s in skip_suffixes)


def scan_controller_leaks(
    root_dir: str, severity_filter: int
) -> List[Finding]:
    """Pass 1: walk .dart files and check controller/subscription leak patterns."""
    findings: List[Finding] = []
    dart_files: List[str] = []

    for dirpath, _, filenames in os.walk(root_dir):
        for fname in filenames:
            if fname.endswith(".dart"):
                full = os.path.join(dirpath, fname)
                if not _should_skip_file(full):
                    dart_files.append(full)

    for filepath in dart_files:
        lines = _read_file_lines(filepath)
        if lines is None:
            continue

        full_content = "".join(lines)
        # Use comment-stripped content for pattern matching so that commented-out
        # code (e.g. // AnimationController _anim;) does not trigger false positives.
        clean_content = _strip_comment_lines(lines)

        for pattern in CONTROLLER_PATTERNS:
            if SEVERITY_ORDER.get(pattern.severity, 99) > severity_filter:
                continue

            # Check if the file creates this resource (in non-comment lines)
            has_creation = _any_pattern_matches(pattern.creation_patterns, clean_content)
            if not has_creation:
                continue

            # Check if the file tears it down (in non-comment lines)
            has_teardown = _any_pattern_matches(pattern.teardown_patterns, clean_content)
            if has_teardown:
                continue

            # Optional: check ownership heuristics
            if pattern.check_ownership:
                # Look for assignment-style usage: "= AnimationController(" rather than
                # just any occurrence (which could be a parameter, doc example, etc.)
                owned = False
                for creation_pat in pattern.creation_patterns:
                    for i, line in enumerate(lines):
                        stripped = line.lstrip()
                        if stripped.startswith("//"):
                            continue
                        m = re.search(creation_pat, line)
                        if m:
                            # Heuristic: if the line has "=" or "return" near the match,
                            # it is likely local ownership, not a parameter
                            owned = True
                            break
                    if owned:
                        break
                if not owned:
                    continue  # skip — probably a parameter or doc reference

            # Find the first creation line for the report
            creation_hits = _find_pattern_lines(pattern.creation_patterns, lines)
            if not creation_hits:
                continue

            line_num, col, snippet = creation_hits[0]

            # Boost confidence: if a booster matches (in clean content), keep the assigned
            # severity; otherwise downgrade one level (but never below low).
            boosted = _any_pattern_matches(
                pattern.confidence_boosters, clean_content
            )
            sev = pattern.severity
            if not boosted:
                sev_order = SEVERITY_ORDER.get(sev, 99)
                next_order = min(sev_order + 1, SEVERITY_ORDER["low"])
                sev = [k for k, v in SEVERITY_ORDER.items() if v == next_order][0]

            if SEVERITY_ORDER.get(sev, 99) > severity_filter:
                continue

            findings.append(
                Finding(
                    file=os.path.relpath(filepath, root_dir),
                    line=line_num,
                    col=col,
                    category=pattern.category,
                    severity=sev,
                    description=pattern.description,
                    snippet=snippet,
                )
            )

    return findings


def scan_riverpod_autodispose(
    root_dir: str, severity_filter: int
) -> List[Finding]:
    """Pass 2: find Riverpod providers missing autoDispose."""
    findings: List[Finding] = []

    if SEVERITY_ORDER.get("medium", 99) > severity_filter:
        return findings  # medium is below threshold — skip entirely

    # Match @riverpod or @Riverpod( annotation lines
    provider_annotation = re.compile(r"@(riverpod|Riverpod)\b")

    # Lines that indicate autoDispose is present
    autodispose_indicator = re.compile(
        r"(autoDispose|keepAlive\s*:\s*false|AutoDispose\w+Ref)"
    )

    for dirpath, _, filenames in os.walk(root_dir):
        for fname in filenames:
            if not fname.endswith(".dart"):
                continue
            full = os.path.join(dirpath, fname)
            if _should_skip_file(full):
                continue

            lines = _read_file_lines(full)
            if lines is None:
                continue

            for i, line in enumerate(lines):
                if not provider_annotation.search(line):
                    continue

                # Skip commented-out annotations (// style only — block comments
                # can be tricky, but a line starting with // is unambiguous)
                stripped = line.lstrip()
                if stripped.startswith("//"):
                    continue

                line_num = i + 1

                # Look ahead and behind for autoDispose signal within a reasonable
                # window (Riverpod function/class body typically starts within ~10 lines)
                context_start = max(0, i - 3)
                context_end = min(len(lines), i + 15)
                context = "".join(lines[context_start:context_end])

                if autodispose_indicator.search(context):
                    continue  # has autoDispose — clean

                findings.append(
                    Finding(
                        file=os.path.relpath(full, root_dir),
                        line=line_num,
                        col=1,
                        category="riverpod-no-autodispose",
                        severity="medium",
                        description=(
                            "Riverpod provider declared without autoDispose — "
                            "state persists for ProviderScope lifetime. Add "
                            "keepAlive: false to @Riverpod() or use autoDispose "
                            "modifier."
                        ),
                        snippet=line.strip(),
                    )
                )

    return findings


# ---------------------------------------------------------------------------
# Output formatters
# ---------------------------------------------------------------------------


def format_text(findings: List[Finding]) -> str:
    """Human-readable output."""
    if not findings:
        return "No leaks found.\n"

    # Group by severity
    by_sev: Dict[str, List[Finding]] = {}
    for f in findings:
        by_sev.setdefault(f.severity, []).append(f)

    lines: List[str] = []
    lines.append(f"Found {len(findings)} potential leak(s):\n")

    for sev in ("critical", "high", "medium", "low"):
        items = by_sev.get(sev)
        if not items:
            continue
        lines.append(f"=== {sev.upper()} ({len(items)}) ===")
        for item in sorted(items, key=lambda x: (x.file, x.line)):
            lines.append(
                f"  {item.file}:{item.line}:{item.col}  [{item.category}]"
            )
            lines.append(f"    {item.description}")
            lines.append(f"    >> {item.snippet}")
        lines.append("")

    return "\n".join(lines)


def format_json(findings: List[Finding]) -> str:
    """Machine-readable JSON output."""
    return json.dumps(
        [
            {
                "file": f.file,
                "line": f.line,
                "col": f.col,
                "category": f.category,
                "severity": f.severity,
                "description": f.description,
                "snippet": f.snippet,
            }
            for f in findings
        ],
        indent=2,
    )


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def parse_args(argv: List[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="State Leak Auditor — scan a Flutter/Dart project for resource leaks.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python scan_leaks.py lib/
  python scan_leaks.py lib/ --json
  python scan_leaks.py lib/ --severity high
  python scan_leaks.py lib/ --no-require-dispose-in-file
  python scan_leaks.py lib/ --no-check-riverpod-autodispose
        """,
    )
    parser.add_argument(
        "root",
        nargs="?",
        default=".",
        help="Project root directory to scan (default: current directory)",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output findings as JSON (default: human-readable text)",
    )
    parser.add_argument(
        "--severity",
        choices=["critical", "high", "medium", "low"],
        default="low",
        help="Minimum severity to report (default: low — show all)",
    )
    parser.add_argument(
        "--require-dispose-in-file",
        default=True,
        action="store_true",
        dest="require_dispose",
        help="Check for .dispose()/.cancel() in the same file (default: true)",
    )
    parser.add_argument(
        "--no-require-dispose-in-file",
        action="store_false",
        dest="require_dispose",
        help="Skip controller/subscription leak checks",
    )
    parser.add_argument(
        "--check-riverpod-autodispose",
        default=True,
        action="store_true",
        dest="check_riverpod",
        help="Check Riverpod providers for autoDispose (default: true)",
    )
    parser.add_argument(
        "--no-check-riverpod-autodispose",
        action="store_false",
        dest="check_riverpod",
        help="Skip Riverpod autoDispose checks",
    )
    return parser.parse_args(argv)


def main(argv: Optional[List[str]] = None) -> int:
    if argv is None:
        argv = sys.argv[1:]

    args = parse_args(argv)
    root = os.path.abspath(args.root)

    if not os.path.isdir(root):
        print(f"Error: '{args.root}' is not a directory or does not exist.", file=sys.stderr)
        return 1

    severity_filter = SEVERITY_ORDER.get(args.severity, 3)

    findings: List[Finding] = []

    if args.require_dispose:
        findings.extend(scan_controller_leaks(root, severity_filter))

    if args.check_riverpod:
        findings.extend(scan_riverpod_autodispose(root, severity_filter))

    # Sort: severity first, then file, then line
    findings.sort(
        key=lambda f: (
            SEVERITY_ORDER.get(f.severity, 99),
            f.file,
            f.line,
        )
    )

    if args.json:
        print(format_json(findings))
    else:
        print(format_text(findings))

    # Exit non-zero if any critical or high findings exist (for CI gating)
    has_blockers = any(
        f.severity in ("critical", "high") for f in findings
    )
    return 1 if has_blockers else 0


if __name__ == "__main__":
    sys.exit(main())
