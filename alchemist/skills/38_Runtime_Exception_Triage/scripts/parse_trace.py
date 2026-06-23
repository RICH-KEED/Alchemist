#!/usr/bin/env python3
"""parse_trace.py — Parse a Dart/Flutter stack trace for runtime-exception triage.

Reads a stack trace (file arg or stdin), extracts the exception line and each
frame (index, package, file, line, col, symbol), detects whether the trace is
OBFUSCATED (a release build that must be `flutter symbolize`-d first), and
prints the top APP-CODE frames with framework/library frames filtered out — the
deepest frame in your own package is almost always the suspect.

Feeds the #38 Runtime Exception Triage flow: the printed `file:line` is exactly
what the #26 semantic index keys on, so the next step is an index lookup, not a
grep of lib/**.

STDLIB ONLY. Python 3.8+. No third-party deps.

Usage:
  python parse_trace.py [TRACE_FILE]        # or pipe:  cat crash.txt | python parse_trace.py
  python parse_trace.py crash.txt --json    # machine-readable output
  python parse_trace.py crash.txt --package my_app   # force the app package name
  python parse_trace.py crash.txt --top 5   # show N top app-code frames (default 3)

Options:
  TRACE_FILE        path to the trace; omit (or "-") to read stdin
  --json            emit a JSON object instead of the human report
  --package NAME    treat `package:NAME/` as app code (else auto-detected as the
                    most common non-framework package in the trace)
  --top N           how many top app-code frames to print (default 3)
  --all             list every parsed frame, not just app-code ones

Exit codes: 0 ok (frames found) · 3 obfuscated (symbolize first) ·
            4 no frames parsed · 2 bad arguments.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from typing import Dict, List, Optional

# --------------------------------------------------------------------------- #
# Frame patterns                                                              #
# --------------------------------------------------------------------------- #

# Symbolized Dart frame:
#   #0      Foo.bar (package:my_app/x/y.dart:42:18)
#   #12     _rootRun (dart:async/zone.dart:1399:47)
RE_FRAME = re.compile(
    r"^\s*#(?P<idx>\d+)\s+"
    r"(?P<symbol>.+?)\s+"
    r"\((?P<loc>(?:package:|dart:|file:)?[^):]+?)"
    r"(?::(?P<line>\d+))?(?::(?P<col>\d+))?\)\s*$"
)

# Some traces (e.g. assertion dumps) use a bare path without the `#N Symbol (...)`
# wrapper:  package:my_app/x/y.dart 42:18  Foo.bar
RE_FRAME_BARE = re.compile(
    r"^\s*(?P<loc>(?:package:|dart:)[^\s:]+\.dart)\s+(?P<line>\d+)(?::(?P<col>\d+))?"
    r"(?:\s+(?P<symbol>.+))?\s*$"
)

# Markers that a trace is an UNSYMBOLIZED release (obfuscated) crash dump.
RE_OBFUSCATED = [
    re.compile(r"_kDartIsolateSnapshotInstructions"),
    re.compile(r"isolate_dso_base"),
    re.compile(r"\bbuild_id\s*[:=]"),
    re.compile(r"^\s*#\d+\s+abs\s+[0-9a-fA-F]+", re.M),  # `#00 abs 00007.. virt ..`
    re.compile(r"warning:.*Flutter.*obfuscat", re.I),
]

FRAMEWORK_PREFIXES = (
    "dart:",
    "package:flutter/",
    "package:flutter_test/",
    "package:riverpod/",
    "package:flutter_riverpod/",
    "package:hooks_riverpod/",
    "package:dio/",
    "package:go_router/",
    "package:http/",
    "package:async/",
    "package:stack_trace/",
)


def is_obfuscated(text: str) -> bool:
    return any(p.search(text) for p in RE_OBFUSCATED)


def detect_package(frames: List[Dict]) -> Optional[str]:
    """Most common non-framework `package:<name>/` in the trace = the app package."""
    names: Counter = Counter()
    for f in frames:
        loc = f.get("loc") or ""
        if loc.startswith("package:") and not _is_framework_loc(loc):
            names[loc.split("package:", 1)[1].split("/", 1)[0]] += 1
    return names.most_common(1)[0][0] if names else None


def _is_framework_loc(loc: str) -> bool:
    return any(loc.startswith(p) for p in FRAMEWORK_PREFIXES)


def parse_exception(lines: List[str]) -> Optional[str]:
    """Best-effort: the human exception line, usually the first non-frame, non-header line."""
    for ln in lines:
        s = ln.strip()
        if not s:
            continue
        if RE_FRAME.match(ln) or RE_FRAME_BARE.match(ln):
            continue
        if s.startswith(("***", "pid:", "build_id", "isolate_dso_base", "vm_dso_base")):
            continue
        # Strip common framework prefixes for a cleaner signature.
        s = re.sub(r"^(Unhandled exception:|EXCEPTION CAUGHT BY [A-Z ]+|═+)\s*", "", s).strip()
        if s:
            return s
    return None


def parse_frames(lines: List[str]) -> List[Dict]:
    frames: List[Dict] = []
    for ln in lines:
        m = RE_FRAME.match(ln)
        if m:
            d = m.groupdict()
            frames.append(_mk_frame(d.get("idx"), d["symbol"], d["loc"], d.get("line"), d.get("col")))
            continue
        m = RE_FRAME_BARE.match(ln)
        if m:
            d = m.groupdict()
            frames.append(_mk_frame(None, (d.get("symbol") or "").strip() or None,
                                    d["loc"], d.get("line"), d.get("col")))
    return frames


def _mk_frame(idx, symbol, loc, line, col) -> Dict:
    loc = loc.strip()
    package = None
    file = loc
    if loc.startswith("package:"):
        rest = loc.split("package:", 1)[1]
        package = rest.split("/", 1)[0]
        # Re-root to a repo-relative path the #26 index understands: package:app/x → lib/x
        path = rest.split("/", 1)[1] if "/" in rest else rest
        file = "lib/" + path
    elif loc.startswith("dart:"):
        package = loc.split("/", 1)[0]  # e.g. dart:async
    return {
        "index": int(idx) if idx is not None and str(idx).isdigit() else None,
        "symbol": symbol.strip() if symbol else None,
        "loc": loc,
        "package": package,
        "file": file,
        "line": int(line) if line and str(line).isdigit() else None,
        "col": int(col) if col and str(col).isdigit() else None,
    }


def classify(frames: List[Dict], app_package: Optional[str]) -> None:
    """Tag each frame `app` True/False in place."""
    for f in frames:
        loc = f["loc"]
        if _is_framework_loc(loc) or not loc.startswith("package:"):
            f["app"] = False
        elif app_package is not None:
            f["app"] = f["package"] == app_package
        else:
            f["app"] = True  # a non-framework package, no app name given


def analyze(text: str, app_package: Optional[str]) -> Dict:
    lines = text.splitlines()
    obf = is_obfuscated(text)
    frames = parse_frames(lines)
    if app_package is None:
        app_package = detect_package(frames)
    classify(frames, app_package)
    app_frames = [f for f in frames if f.get("app")]
    return {
        "obfuscated": obf,
        "package": app_package,
        "exception": parse_exception(lines),
        "frame_count": len(frames),
        "app_frame_count": len(app_frames),
        "top_app_frames": app_frames,
        "frames": frames,
    }


def signature(result: Dict) -> Optional[str]:
    """Stable grouping key: <exception> @ <top app frame file:line>."""
    exc = (result.get("exception") or "").split("\n")[0].strip()
    exc = re.sub(r"\s+", " ", exc)[:80] if exc else "UnknownException"
    top = result["top_app_frames"][0] if result["top_app_frames"] else None
    if top and top.get("file") and top.get("line"):
        return f"{exc} @ {top['file']}:{top['line']}"
    return exc


# --------------------------------------------------------------------------- #
# Output                                                                      #
# --------------------------------------------------------------------------- #

def _fmt_frame(f: Dict) -> str:
    loc = f["file"] or f["loc"]
    where = f"{loc}:{f['line']}" if f.get("line") else loc
    sym = f["symbol"] or "?"
    idx = f"#{f['index']} " if f["index"] is not None else ""
    return f"  {idx}{sym}\n      -> {where}"


def print_report(result: Dict, top_n: int, show_all: bool) -> None:
    out = sys.stdout
    print("runtime exception triage — trace parse", file=out)
    print(f"  obfuscated : {result['obfuscated']}", file=out)
    print(f"  package    : {result['package'] or '(unknown)'}", file=out)
    print(f"  exception  : {result['exception'] or '(none parsed)'}", file=out)
    print(f"  frames     : {result['frame_count']} "
          f"({result['app_frame_count']} app-code)", file=out)

    if result["obfuscated"]:
        print("\n  ! OBFUSCATED release trace — symbolize before locating:", file=out)
        print("    flutter symbolize -i <trace> -d build/symbols/app.android-arm64.symbols", file=out)
        print("    (use the archived symbol dir for THIS versionCode — see skill 22)", file=out)

    sig = signature(result)
    if sig:
        print(f"\n  signature  : {sig}", file=out)

    if show_all:
        print("\n  all frames:", file=out)
        for f in result["frames"]:
            tag = "app" if f.get("app") else "   "
            print(f"  [{tag}]" + _fmt_frame(f)[2:], file=out)
    else:
        tops = result["top_app_frames"][:top_n]
        if tops:
            print(f"\n  top {len(tops)} app-code frame(s) (suspects — query the #26 index):", file=out)
            for f in tops:
                print(_fmt_frame(f), file=out)
        else:
            print("\n  no app-code frames found — pure framework/plugin trace.", file=out)
            print("  Check the plugin/dependency and guard at your call site (skill 38).", file=out)


def main(argv: Optional[List[str]] = None) -> int:
    ap = argparse.ArgumentParser(description="Parse a Dart/Flutter stack trace for triage.")
    ap.add_argument("trace_file", nargs="?", default="-", help="trace file path, or - for stdin")
    ap.add_argument("--json", action="store_true", help="emit JSON instead of a report")
    ap.add_argument("--package", default=None, help="app package name (else auto-detected)")
    ap.add_argument("--top", type=int, default=3, help="number of top app-code frames (default 3)")
    ap.add_argument("--all", action="store_true", help="list every frame, not just app-code")
    args = ap.parse_args(argv)

    if args.trace_file in ("-", None):
        text = sys.stdin.read()
    else:
        try:
            with open(args.trace_file, "r", encoding="utf-8", errors="replace") as fh:
                text = fh.read()
        except OSError as e:
            print(f"error: cannot read {args.trace_file}: {e}", file=sys.stderr)
            return 2

    if not text.strip():
        print("error: empty trace input", file=sys.stderr)
        return 4

    result = analyze(text, args.package)
    result["signature"] = signature(result)

    if args.json:
        json.dump(result, sys.stdout, indent=2)
        sys.stdout.write("\n")
    else:
        print_report(result, top_n=args.top, show_all=args.all)

    if result["obfuscated"]:
        return 3
    if result["frame_count"] == 0:
        return 4
    return 0


if __name__ == "__main__":
    sys.exit(main())
