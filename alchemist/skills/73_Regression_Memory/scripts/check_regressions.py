#!/usr/bin/env python3
"""check_regressions.py — Scan a git diff for known regression signatures.

Reads a regression database (JSON) and diffs the current branch against a base
ref. For each regression entry, checks whether the diff touches the affected
files and matches any recorded patterns. Reports findings with confidence
levels and exits non-zero when HIGH or MEDIUM matches are found.

Usage:
  python3 check_regressions.py --db .flutter-pipeline/regressions.json
  python3 check_regressions.py --db reg.json --base origin/develop --json
"""

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path


def load_regressions(db_path: Path) -> dict:
    """Load and validate the regression database."""
    if not db_path.exists():
        print(f"WARNING: Regression database not found at {db_path}")
        return {"version": 1, "entries": []}

    with open(db_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    if "entries" not in data:
        data["entries"] = []
    return data


def get_diff_files(base_ref: str) -> list[str]:
    """Return the list of files changed in the diff from base_ref to HEAD."""
    cmd = ["git", "diff", "--name-only", f"{base_ref}...HEAD"]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"ERROR: git diff failed — {result.stderr.strip()}")
        sys.exit(2)
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def get_diff_for_file(base_ref: str, file_path: str) -> str:
    """Return the full diff hunk text for a single file."""
    cmd = ["git", "diff", f"{base_ref}...HEAD", "--", file_path]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        return ""
    return result.stdout


def check_patterns(diff_text: str, patterns: list[str]) -> list[str]:
    """Return the subset of patterns that match anywhere in the diff text."""
    matched = []
    for pattern in patterns:
        try:
            if re.search(pattern, diff_text):
                matched.append(pattern)
        except re.error:
            print(f"WARNING: Invalid regex pattern skipped — {pattern}")
    return matched


def check_function_overlap(diff_text: str, functions: list[str]) -> list[str]:
    """Return function names whose definitions or calls appear in the diff."""
    matched = []
    for func in functions:
        escaped = re.escape(func)
        if re.search(escaped, diff_text):
            matched.append(func)
    return matched


def analyze_entry(entry: dict, changed_files: set[str], base_ref: str) -> list[dict]:
    """Analyze one regression entry against the current diff.

    Returns a list of finding dicts (one per matched file).
    """
    findings = []
    signature = entry.get("signature", {})
    entry_files = set(signature.get("files", []))
    entry_functions = signature.get("functions", [])
    entry_patterns = signature.get("patterns", [])

    touched_files = entry_files & changed_files
    if not touched_files:
        return findings

    for file_path in sorted(touched_files):
        diff_text = get_diff_for_file(base_ref, file_path)
        if not diff_text:
            continue

        matched_functions = check_function_overlap(diff_text, entry_functions)
        matched_patterns = check_patterns(diff_text, entry_patterns)

        if matched_patterns and matched_functions:
            confidence = "HIGH"
        elif matched_patterns:
            confidence = "MEDIUM"
        else:
            confidence = "LOW"

        finding = {
            "confidence": confidence,
            "bug_id": entry["bug_id"],
            "title": entry["title"],
            "file": file_path,
            "function": matched_functions[0] if matched_functions else None,
            "pattern": matched_patterns[0] if matched_patterns else None,
        }
        findings.append(finding)

    return findings


def format_finding_text(finding: dict) -> str:
    """Format a single finding as a human-readable line."""
    func_part = f" — {finding['file']}: {finding['function']}" if finding["function"] else f" — {finding['file']}"
    pattern_part = f" — pattern: {finding['pattern']}" if finding["pattern"] else ""
    return f"{finding['confidence']}: {finding['bug_id']} — {finding['title']}{func_part}{pattern_part}"


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Scan a git diff for known regression signatures"
    )
    parser.add_argument(
        "--db",
        default=".flutter-pipeline/regressions.json",
        help="Path to the regression database JSON (default: .flutter-pipeline/regressions.json)",
    )
    parser.add_argument(
        "--base",
        default="origin/main",
        help="Base ref to diff against (default: origin/main)",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        dest="json_output",
        help="Output findings as a JSON array",
    )
    args = parser.parse_args()

    db_path = Path(args.db)
    data = load_regressions(db_path)
    entries = data.get("entries", [])

    if not entries:
        print("No regression entries in database — nothing to check.")
        sys.exit(0)

    changed_files = set(get_diff_files(args.base))

    all_findings: list[dict] = []
    for entry in entries:
        findings = analyze_entry(entry, changed_files, args.base)
        all_findings.extend(findings)

    if args.json_output:
        print(json.dumps(all_findings, indent=2))
    else:
        if not all_findings:
            print("No regression signatures matched.")
        for finding in all_findings:
            print(format_finding_text(finding))

    # Exit 1 if any HIGH or MEDIUM confidence match
    has_actionable = any(
        f["confidence"] in ("HIGH", "MEDIUM") for f in all_findings
    )
    sys.exit(1 if has_actionable else 0)


if __name__ == "__main__":
    main()
