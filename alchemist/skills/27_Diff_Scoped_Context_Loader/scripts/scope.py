#!/usr/bin/env python3
"""scope.py — Diff-scoped context loader for a Flutter app.

Given a set of CHANGED files and the semantic index produced by skill #26
(.flutter-pipeline/index.json), compute the *minimal* context an edit task
needs:

  1. the changed files themselves,
  2. their reverse-dependency closure (files that import them, transitively,
     capped at --depth N), and
  3. the entities living in that file set + the tests that likely exercise
     them.

This bounds context to O(change) instead of O(feature-tree). It does NOT walk
the source tree — it reads only the JSON index, so it is cheap and offline.

Changed files come from any of:
  - positional args           scope.py a.dart b.dart
  - --files "a.dart b.dart"   (space/newline/comma separated)
  - stdin (a pipe)            git diff --name-only | scope.py
  - --git                     shell out to `git diff --name-only` in --root

Usage:
  python scope.py [CHANGED ...] [options]

Options:
  --index PATH     path to index.json (default: <root>/.flutter-pipeline/index.json)
  --root DIR       project root (default: cwd); also used to resolve --git
  --files STR      changed files as one string (sep: space/newline/comma)
  --git            derive changed files from `git diff --name-only`
  --depth N        reverse-dependency depth cap (default: 1; 0 = changed only)
  --json           emit a machine-readable JSON report instead of text
  --quiet          suppress the human header line

Exit codes: 0 ok · 1 index not found / unreadable · 2 no changed files · 3 bad args.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional, Set


# --------------------------------------------------------------------------- #
# Loading & normalizing input                                                 #
# --------------------------------------------------------------------------- #

def load_index(path: Path) -> Dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        sys.stderr.write(f"error: cannot read index at {path}: {exc}\n")
        raise SystemExit(1)


def split_files(blob: str) -> List[str]:
    """Split a free-form list on commas, newlines, and whitespace."""
    out: List[str] = []
    for chunk in blob.replace(",", " ").split():
        out.append(chunk.strip())
    return [c for c in out if c]


def git_changed(root: Path) -> List[str]:
    """Best-effort `git diff --name-only` (staged + unstaged) under root."""
    files: List[str] = []
    for args in (["git", "diff", "--name-only"],
                 ["git", "diff", "--name-only", "--cached"]):
        try:
            res = subprocess.run(
                args, cwd=str(root), capture_output=True, text=True, timeout=15,
            )
        except (OSError, subprocess.SubprocessError):
            continue
        if res.returncode == 0:
            files.extend(split_files(res.stdout))
    # de-dup, preserve order
    seen: Set[str] = set()
    uniq = []
    for f in files:
        if f not in seen:
            seen.add(f)
            uniq.append(f)
    return uniq


def to_lib_relative(root: Path, raw: str) -> str:
    """Normalize a changed path to the index's lib/-relative POSIX form.

    git reports paths relative to the repo root; the index keys on
    lib/-relative paths. We strip any leading directory up to and including a
    `lib/` segment and re-prefix with `lib/`. Already-normalized paths pass
    through unchanged. Backslashes (Windows) are converted to forward slashes.
    """
    p = raw.strip().replace("\\", "/")
    if not p:
        return p
    # Drop an absolute root prefix if present.
    try:
        root_posix = root.as_posix().rstrip("/") + "/"
        if p.startswith(root_posix):
            p = p[len(root_posix):]
    except ValueError:
        pass
    if p.startswith("lib/"):
        return p
    idx = p.find("/lib/")
    if idx != -1:
        return p[idx + 1:]  # keep from 'lib/...'
    return p  # leave non-lib paths (pubspec, etc.) as-is for reporting


# --------------------------------------------------------------------------- #
# Reverse-dependency closure                                                   #
# --------------------------------------------------------------------------- #

def build_reverse_edges(index: Dict) -> Dict[str, Set[str]]:
    """importee -> {importers}. Built from files[].dependsOn (forward edges)."""
    rev: Dict[str, Set[str]] = {}
    for f in index.get("files", []):
        importer = f.get("file")
        for dep in f.get("dependsOn", []) or []:
            rev.setdefault(dep, set()).add(importer)
    return rev


def reverse_closure(seeds: Set[str], rev: Dict[str, Set[str]],
                    depth: int) -> Dict[str, int]:
    """BFS over reverse edges from `seeds`, capped at `depth` hops.

    Returns {file: hop_distance}; seeds are hop 0. depth=0 returns seeds only.
    """
    dist: Dict[str, int] = {s: 0 for s in seeds}
    frontier = set(seeds)
    hop = 0
    while frontier and hop < depth:
        hop += 1
        nxt: Set[str] = set()
        for f in frontier:
            for importer in rev.get(f, ()):  # who imports f
                if importer not in dist:
                    dist[importer] = hop
                    nxt.add(importer)
        frontier = nxt
    return dist


# --------------------------------------------------------------------------- #
# Entities + tests                                                            #
# --------------------------------------------------------------------------- #

def entities_in(index: Dict, files: Set[str]) -> List[Dict]:
    out = []
    for e in index.get("entities", []):
        if e.get("kind") == "feature":
            continue  # synthesized, not a concrete file
        if e.get("file") in files:
            out.append(e)
    return out


def likely_tests(index: Dict, files: Set[str]) -> List[str]:
    """Map source files to their mirrored test paths (house style §3:
    'Test files mirror source path under test/ and end in _test.dart').

    A test is *real* (exists in the index's file list / on disk) or
    *suggested* (the conventional path to create). We return conventional
    paths and flag which already exist via the index's known file set so the
    caller knows what to run vs. write.
    """
    known = {f.get("file") for f in index.get("files", [])}
    out: List[Dict] = []
    for src in sorted(files):
        if not src.startswith("lib/") or not src.endswith(".dart"):
            continue
        test_path = "test/" + src[len("lib/"):]
        test_path = test_path[:-len(".dart")] + "_test.dart"
        out.append({"test": test_path, "exists": test_path in known, "covers": src})
    return out


def feature_set(entities: List[Dict]) -> List[str]:
    feats = {e["feature"] for e in entities if e.get("feature")}
    return sorted(feats)


# --------------------------------------------------------------------------- #
# Report assembly                                                             #
# --------------------------------------------------------------------------- #

def assemble(index: Dict, changed: List[str], depth: int) -> Dict:
    rev = build_reverse_edges(index)
    known = {f.get("file") for f in index.get("files", [])}

    seeds = set(changed)
    # Seeds that aren't in the index (new/untracked or non-lib) still seed the
    # closure but produce no reverse edges; we surface them as 'unindexed'.
    unindexed = sorted(s for s in seeds if s not in known)

    dist = reverse_closure(seeds, rev, depth)
    load_files = sorted(dist)

    ents = entities_in(index, set(load_files))
    tests = likely_tests(index, set(load_files))

    # Risk notes — cheap heuristics over the loaded set.
    risks: List[str] = []
    impacted_count = len([f for f, d in dist.items() if d > 0])
    if impacted_count == 0 and depth > 0:
        risks.append("No reverse dependents found — change is leaf-local (low blast radius).")
    if impacted_count > 20:
        risks.append(
            f"Wide blast radius — {impacted_count} dependent file(s). "
            "Consider raising test coverage before merging.")
    # Touching a repository interface ripples to every impl + caller.
    if any(e["kind"] == "repository" and e.get("role") == "interface" for e in ents):
        risks.append(
            "A repository INTERFACE is in scope — re-check all impls and "
            "callers; contract changes propagate via Result/Failure.")
    # Touching a core/ file is cross-feature by definition.
    if any(f.startswith("lib/core/") for f in changed):
        risks.append(
            "A lib/core/ file changed — impact is cross-feature; "
            "verify dependents in multiple features.")
    if any(e["kind"] == "route" for e in ents):
        risks.append("Route definitions in scope — re-check deep links and navigation guards.")
    if unindexed:
        risks.append(
            f"{len(unindexed)} changed path(s) not in the index (new/untracked "
            "or non-lib) — rebuild the index (#26 --incremental) for full accuracy.")

    return {
        "depth": depth,
        "changedFiles": sorted(seeds),
        "unindexed": unindexed,
        "impactedFiles": [f for f in load_files if dist[f] > 0],
        "filesToLoad": load_files,
        "fileDepth": dist,
        "impactedEntities": [
            {"id": e["id"], "kind": e["kind"], "name": e["name"],
             "file": e["file"], "line": e.get("line"),
             "feature": e.get("feature")}
            for e in ents
        ],
        "impactedFeatures": feature_set(ents),
        "testsToRun": tests,
        "riskNotes": risks,
        "counts": {
            "changed": len(seeds),
            "impacted": impacted_count,
            "filesToLoad": len(load_files),
            "entities": len(ents),
            "testsExisting": sum(1 for t in tests if t["exists"]),
        },
    }


def render_text(report: Dict, package: Optional[str], quiet: bool) -> str:
    L: List[str] = []
    c = report["counts"]
    if not quiet:
        L.append(f"diff-scoped context  (package: {package or '(unknown)'}, "
                 f"depth: {report['depth']})")
        L.append(f"  {c['changed']} changed -> {c['filesToLoad']} files to load, "
                 f"{c['impacted']} dependents, {c['entities']} entities")
        L.append("")

    L.append("CHANGED FILES")
    for f in report["changedFiles"]:
        tag = "  (unindexed)" if f in report["unindexed"] else ""
        L.append(f"  - {f}{tag}")

    L.append("")
    L.append("FILES TO LOAD  (changed + reverse deps)")
    for f in report["filesToLoad"]:
        d = report["fileDepth"][f]
        marker = "*" if d == 0 else f"+{d}"
        L.append(f"  [{marker}] {f}")

    L.append("")
    L.append("IMPACTED ENTITIES")
    if report["impactedEntities"]:
        for e in report["impactedEntities"]:
            feat = f"  ({e['feature']})" if e.get("feature") else ""
            L.append(f"  - {e['kind']:<10} {e['name']}  "
                     f"{e['file']}:{e['line']}{feat}")
    else:
        L.append("  (none in index for this file set)")

    if report["impactedFeatures"]:
        L.append("")
        L.append("FEATURES TOUCHED: " + ", ".join(report["impactedFeatures"]))

    L.append("")
    L.append("TESTS TO RUN")
    if report["testsToRun"]:
        for t in report["testsToRun"]:
            state = "run " if t["exists"] else "write"
            L.append(f"  [{state}] {t['test']}")
    else:
        L.append("  (no lib/ sources in scope)")

    if report["riskNotes"]:
        L.append("")
        L.append("RISK NOTES")
        for r in report["riskNotes"]:
            L.append(f"  ! {r}")

    return "\n".join(L) + "\n"


# --------------------------------------------------------------------------- #
# CLI                                                                          #
# --------------------------------------------------------------------------- #

def gather_changed(args, root: Path) -> List[str]:
    raw: List[str] = []
    raw.extend(args.changed or [])
    if args.files:
        raw.extend(split_files(args.files))
    if args.git:
        raw.extend(git_changed(root))
    # stdin only if piped (not a tty) and nothing else supplied this round
    if not sys.stdin.isatty() and not raw:
        data = sys.stdin.read()
        raw.extend(split_files(data))
    # normalize + de-dup
    seen: Set[str] = set()
    out: List[str] = []
    for f in raw:
        norm = to_lib_relative(root, f)
        if norm and norm not in seen:
            seen.add(norm)
            out.append(norm)
    return out


def main(argv: List[str]) -> int:
    ap = argparse.ArgumentParser(description="Diff-scoped context loader.")
    ap.add_argument("changed", nargs="*", help="changed file paths")
    ap.add_argument("--index", default=None, help="path to index.json")
    ap.add_argument("--root", default=".", help="project root (for --git, defaults)")
    ap.add_argument("--files", default=None, help="changed files as one string")
    ap.add_argument("--git", action="store_true", help="use `git diff --name-only`")
    ap.add_argument("--depth", type=int, default=1, help="reverse-dep depth cap (default 1)")
    ap.add_argument("--json", action="store_true", help="emit JSON report")
    ap.add_argument("--quiet", action="store_true", help="suppress header line")
    args = ap.parse_args(argv)

    if args.depth < 0:
        sys.stderr.write("error: --depth must be >= 0\n")
        return 3

    root = Path(args.root).resolve()
    index_path = (Path(args.index).resolve() if args.index
                  else root / ".flutter-pipeline" / "index.json")
    if not index_path.exists():
        sys.stderr.write(
            f"error: no index at {index_path}\n"
            "       build it first: skill #26 build_index.py\n")
        return 1

    index = load_index(index_path)

    changed = gather_changed(args, root)
    if not changed:
        sys.stderr.write(
            "error: no changed files. Pass paths, --files, --git, or pipe "
            "`git diff --name-only`.\n")
        return 2

    report = assemble(index, changed, args.depth)

    if args.json:
        sys.stdout.write(json.dumps(report, indent=2) + "\n")
    else:
        sys.stdout.write(render_text(report, index.get("package"), args.quiet))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except KeyboardInterrupt:
        sys.exit(130)
