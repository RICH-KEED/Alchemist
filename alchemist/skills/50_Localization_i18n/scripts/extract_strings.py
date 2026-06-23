#!/usr/bin/env python3
"""extract_strings.py — find user-facing string literals in a Flutter app.

Scans lib/**/*.dart for hardcoded UI strings (the kind that should live in an
ARB file) and emits candidate ARB key -> value pairs. It is a FINDER, not an
editor: a human names the keys, drops false positives, and replaces the literals
with AppLocalizations.of(context).<key>.

What it treats as user-facing:
  - Text('...')                       widget body text
  - common UI string args: label, hintText, labelText, helperText, title,
    subtitle, tooltip, semanticLabel, message, content, errorText
  - SnackBar / AppBar / Dialog title text passed as the above

What it SKIPS (heuristics — not perfect):
  - import/export/part directives
  - Key('...') / ValueKey('...') / GlobalKey
  - logging & debug: print, debugPrint, logger.*, log(...), assert(...)
  - URLs / asset paths / package: imports / pure identifiers & snake_case keys
  - strings with no letters, or that look like a code token (no spaces and
    contains '/', '.', '_', '$', or is camelCase-ish without a space)

Usage:
  python3 extract_strings.py <dir> [<dir> ...]        human-readable report
  python3 extract_strings.py lib --json               ARB-ready JSON to stdout
  python3 extract_strings.py lib --json > new.json    merge into app_en.arb

Stdlib only. Heuristic by design — expect (and skip) false positives.
House style: ../../references/CONVENTIONS.md (§4 never hardcode strings).
"""

import argparse
import json
import os
import re
import sys

# Argument names whose string value is shown to the user.
UI_ARG_KEYS = (
    "label", "labelText", "hintText", "helperText", "errorText",
    "title", "subtitle", "tooltip", "semanticLabel", "message",
    "content", "header", "placeholder",
)

# Lines we never mine for strings.
SKIP_LINE_RE = re.compile(
    r"^\s*(import|export|part|library)\b"
)

# Constructs whose string args are NOT user-facing.
SKIP_CALL_RE = re.compile(
    r"\b("
    r"Key|ValueKey|GlobalKey|ObjectKey|UniqueKey|"
    r"print|debugPrint|log|logger|Logger|"
    r"Uri|Image\.asset|AssetImage|rootBundle|"
    r"Intl\.message|Locale|FontFeature|TextStyle"
    r")\b"
)

# Text('...') or Text("...")  — captures the literal.
TEXT_WIDGET_RE = re.compile(r"""\bText\s*\(\s*(['"])(?P<val>(?:\\.|(?!\1).)*)\1""")

# someUiArg: '...'  — captures key + literal.
ARG_RE = re.compile(
    r"""\b(?P<arg>%s)\s*:\s*(?P<q>['"])(?P<val>(?:\\.|(?!(?P=q)).)*)(?P=q)"""
    % "|".join(UI_ARG_KEYS)
)

# A bare string literal on a line (fallback, used loosely) — not used for
# emission directly; we rely on the two targeted matchers above to stay precise.

WORD_RE = re.compile(r"[A-Za-z]")
CODE_TOKEN_RE = re.compile(r"^[\w.$/\\:-]+$")  # no spaces, looks like a token/path


def looks_user_facing(value):
    """Heuristic: does this literal read like UI copy rather than a code token?"""
    v = value.strip()
    if len(v) < 2:
        return False
    if not WORD_RE.search(v):
        return False  # no letters → not copy
    if v.startswith("http://") or v.startswith("https://"):
        return False
    if v.startswith("assets/") or v.startswith("package:") or v.endswith(".dart"):
        return False
    if CODE_TOKEN_RE.match(v) and " " not in v:
        # single token w/o spaces (e.g. an enum name, route, snake_case key)
        # allow if it's a capitalized real word; reject obvious identifiers.
        if "_" in v or "/" in v or "." in v or "$" in v:
            return False
        if v[:1].islower() and any(c.isupper() for c in v[1:]):
            return False  # camelCase identifier
    return True


def camel_key(value, used):
    """Propose a lowerCamelCase ARB key from the English text; ensure unique."""
    words = re.findall(r"[A-Za-z0-9]+", value.lower())
    words = [w for w in words if w][:5]  # cap length
    if not words:
        words = ["string"]
    key = words[0] + "".join(w.capitalize() for w in words[1:])
    if key[:1].isdigit():
        key = "k" + key
    base, n = key, 2
    while key in used:
        key = "%s%d" % (base, n)
        n += 1
    used.add(key)
    return key


def scan_file(path):
    """Yield (lineno, value) for candidate user-facing literals in one file."""
    try:
        with open(path, "r", encoding="utf-8") as fh:
            lines = fh.readlines()
    except (OSError, UnicodeDecodeError):
        return
    for i, line in enumerate(lines, start=1):
        if SKIP_LINE_RE.search(line):
            continue
        if SKIP_CALL_RE.search(line):
            # Still possible to have a good Text() on the same line, but the
            # safe choice for a finder is to skip ambiguous lines.
            continue
        for m in TEXT_WIDGET_RE.finditer(line):
            val = m.group("val")
            if looks_user_facing(val):
                yield i, val
        for m in ARG_RE.finditer(line):
            val = m.group("val")
            if looks_user_facing(val):
                yield i, val


def walk_dart(roots):
    for root in roots:
        if os.path.isfile(root) and root.endswith(".dart"):
            yield root
            continue
        for dirpath, dirnames, filenames in os.walk(root):
            # skip generated & build noise
            dirnames[:] = [
                d for d in dirnames
                if d not in (".dart_tool", "build", ".git", "l10n")
            ]
            for fn in filenames:
                if fn.endswith(".dart") and not fn.endswith(".g.dart") \
                        and not fn.endswith(".freezed.dart"):
                    yield os.path.join(dirpath, fn)


def main(argv=None):
    ap = argparse.ArgumentParser(description="Find hardcoded UI strings in a Flutter app.")
    ap.add_argument("paths", nargs="+", help="dirs/files to scan (e.g. lib)")
    ap.add_argument("--json", action="store_true",
                    help="emit an ARB-ready {key: value, @key: {...}} map to stdout")
    args = ap.parse_args(argv)

    used_keys = set()
    seen_values = {}   # value -> key  (dedupe identical copy to one key)
    findings = []      # (file, lineno, value, key)

    for path in walk_dart(args.paths):
        for lineno, value in scan_file(path):
            if value in seen_values:
                key = seen_values[value]
            else:
                key = camel_key(value, used_keys)
                seen_values[value] = key
            findings.append((path, lineno, value, key))

    if args.json:
        arb = {}
        for value, key in seen_values.items():
            arb[key] = value
            arb["@" + key] = {"description": "TODO: describe. Source: hardcoded literal."}
        json.dump(arb, sys.stdout, ensure_ascii=False, indent=2)
        sys.stdout.write("\n")
    else:
        if not findings:
            print("No candidate user-facing strings found.")
            return 0
        print("# Candidate ARB keys (review, rename by intent, drop false positives)\n")
        for path, lineno, value, key in findings:
            print("%-28s  =>  %r" % (key, value))
            print("    %s:%d" % (path, lineno))
        uniq = len(seen_values)
        print("\n%d occurrence(s), %d unique string(s)." % (len(findings), uniq))
        print("Re-run with --json to emit an app_en.arb-ready map.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
