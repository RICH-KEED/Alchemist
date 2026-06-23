#!/usr/bin/env python3
"""build_index.py — Build/maintain a persistent semantic index of a Flutter app.

Walks `lib/**/*.dart`, regex-extracts the entities that the flutter-android
skill pipeline cares about, and writes `.flutter-pipeline/index.json`. Other
skills then QUERY the index instead of re-reading the source tree — turning
context cost from O(app) into O(change).

Entities extracted (see CONVENTIONS.md):
  - feature     a directory under lib/features/<name>/
  - screen      class extends ConsumerWidget / StatelessWidget / StatefulWidget /
                ConsumerStatefulWidget / HookConsumerWidget / HookWidget
  - provider    `@riverpod` annotated class/function  OR  `final xProvider = ...`
  - route       go_router `GoRoute(path:, name:)`  +  `RouteDef x = (name:, path:)`
  - repository  abstract repo interface  +  its `... implements XRepository` impl
  - model       `@freezed` class  (the house-style immutable model)

Plus a file-level `dependsOn` edge list built from project-internal imports.

STDLIB ONLY. Python 3.8+. No third-party deps, no Dart parser — pragmatic
regex tuned to the flutter-android house style.

Usage:
  python build_index.py [PROJECT_ROOT] [--incremental] [--out PATH] [--quiet]

  PROJECT_ROOT   app root containing lib/ (default: cwd)
  --incremental  only re-scan Dart files newer than the existing index, reuse
                 the rest. Falls back to a full scan if no index exists.
  --out PATH     output path (default: <root>/.flutter-pipeline/index.json)
  --quiet        suppress the human summary (still writes the file)

Exit codes: 0 ok · 1 no lib/ dir found · 2 bad arguments.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from pathlib import Path
from typing import Dict, List, Optional, Tuple

SCHEMA_VERSION = 1

# --------------------------------------------------------------------------- #
# Regex patterns (house style — CONVENTIONS.md §2/§3/§5/§6, go_router routes). #
# --------------------------------------------------------------------------- #

# Screens: any class whose superclass is a known widget base. Captures the name.
WIDGET_BASES = (
    "ConsumerStatefulWidget",
    "ConsumerWidget",
    "HookConsumerWidget",
    "HookWidget",
    "StatefulWidget",
    "StatelessWidget",
)
RE_WIDGET = re.compile(
    r"^\s*(?:final\s+|sealed\s+|abstract\s+)?class\s+(\w+)"
    r"(?:<[^>]*>)?\s+extends\s+(" + "|".join(WIDGET_BASES) + r")\b"
)

# Riverpod codegen: annotated function  ->  `final <name>Provider` is generated.
#   @riverpod
#   TodoRepository todoRepository(Ref ref) => ...
#   @riverpod
#   Future<List<X>> things(ThingsRef ref) async => ...
RE_RIVERPOD_ANNOTATION = re.compile(r"^\s*@(riverpod|Riverpod)\b")
RE_RIVERPOD_FUNC = re.compile(
    r"^\s*(?:Future<.*?>|Stream<.*?>|[\w<>,\s\?]+?)\s+(\w+)\s*\([^)]*\bRef\b"
)
RE_RIVERPOD_CLASS = re.compile(
    r"^\s*(?:final\s+)?class\s+(\w+)\s+extends\s+_\$\1\b"
)

# Manual providers:  final xProvider = Provider<...>((ref) => ...);
RE_MANUAL_PROVIDER = re.compile(
    r"^\s*final\s+(\w*Provider)\s*=\s*"
    r"(\w*Provider(?:\.\w+)?|StateNotifierProvider(?:\.\w+)?|"
    r"NotifierProvider(?:\.\w+)?|AsyncNotifierProvider(?:\.\w+)?)\b"
)

# go_router: GoRoute(path: '...', name: '...')  — path/name may be on either of
# the next lines, and may be a literal OR an `AppRoute.x.path` reference.
RE_GOROUTE = re.compile(r"\bGoRoute\s*\(")
RE_PATH_LITERAL = re.compile(r"\bpath\s*:\s*(['\"])(.*?)\1")
RE_PATH_REF = re.compile(r"\bpath\s*:\s*([\w.]+)")
RE_NAME_LITERAL = re.compile(r"\bname\s*:\s*(['\"])(.*?)\1")
RE_NAME_REF = re.compile(r"\bname\s*:\s*([\w.]+)")

# RouteDef table (routes.dart): the literal source of truth for paths/names.
#   static const RouteDef login = (name: 'login', path: '/login');
RE_ROUTEDEF = re.compile(
    r"\bRouteDef\s+(\w+)\s*=\s*\(\s*"
    r"name\s*:\s*(['\"])(.*?)\2\s*,\s*"
    r"path\s*:\s*(['\"])(.*?)\4\s*\)"
)

# Repositories.
RE_REPO_INTERFACE = re.compile(
    r"^\s*abstract\s+(?:interface\s+)?class\s+(\w*Repository)\b"
)
RE_REPO_IMPL = re.compile(
    r"^\s*(?:final\s+|sealed\s+)?class\s+(\w*Repository\w*)\s+"
    r"(?:implements|extends)\s+(\w*Repository)\b"
)

# Freezed models:  @freezed  (next line) class X with _$X
RE_FREEZED = re.compile(r"^\s*@freezed\b")
RE_CLASS_NAME = re.compile(r"^\s*(?:final\s+|abstract\s+|sealed\s+)?class\s+(\w+)\b")

# Project-internal imports for the dependency edge list.
#   import 'package:<app>/features/x/y.dart';
#   import '../domain/z.dart';
RE_IMPORT_PKG = re.compile(r"""^\s*import\s+['"]package:([\w_]+)/(.+?\.dart)['"]""")
RE_IMPORT_REL = re.compile(r"""^\s*import\s+['"]((?:\.|\w).+?\.dart)['"]""")


# --------------------------------------------------------------------------- #
# Helpers                                                                      #
# --------------------------------------------------------------------------- #

def detect_package_name(root: Path) -> Optional[str]:
    """Read the package name from pubspec.yaml so `package:` imports resolve."""
    pub = root / "pubspec.yaml"
    if not pub.exists():
        return None
    try:
        for line in pub.read_text(encoding="utf-8", errors="ignore").splitlines():
            m = re.match(r"^name\s*:\s*([\w_]+)\s*$", line)
            if m:
                return m.group(1)
    except OSError:
        pass
    return None


def rel(root: Path, p: Path) -> str:
    """POSIX-style path relative to the project root (stable across OSes)."""
    return p.relative_to(root).as_posix()


def feature_of(relpath: str) -> Optional[str]:
    """Return the feature name for a lib/features/<feature>/... path, else None."""
    m = re.match(r"lib/features/([^/]+)/", relpath)
    return m.group(1) if m else None


def strip_comment(line: str) -> str:
    """Drop a trailing `// ...` line comment (good enough for our patterns)."""
    idx = line.find("//")
    return line[:idx] if idx != -1 else line


# --------------------------------------------------------------------------- #
# Per-file extraction                                                          #
# --------------------------------------------------------------------------- #

def scan_file(root: Path, path: Path, pkg: Optional[str]) -> Dict:
    """Extract every entity + import edge from one Dart file.

    Returns a dict: {relpath, mtime, entities[], imports[]}.
    """
    relpath = rel(root, path)
    try:
        raw = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return {"relpath": relpath, "mtime": 0.0, "entities": [], "imports": []}

    lines = raw.splitlines()
    feature = feature_of(relpath)
    entities: List[Dict] = []
    imports: List[str] = []

    pending_riverpod = False  # saw @riverpod on a previous line
    pending_freezed = False   # saw @freezed on a previous line
    goroute_open = False      # inside a GoRoute(...) header awaiting path/name
    goroute_line = 0
    goroute_path: Optional[str] = None
    goroute_name: Optional[str] = None

    def add(kind: str, name: str, lineno: int, extra: Optional[Dict] = None):
        ent = {
            "id": f"{kind}:{relpath}#{name}",
            "kind": kind,
            "name": name,
            "file": relpath,
            "line": lineno,
        }
        if feature:
            ent["feature"] = feature
        if extra:
            ent.update(extra)
        entities.append(ent)

    for i, raw_line in enumerate(lines, start=1):
        line = strip_comment(raw_line)
        if not line.strip():
            continue

        # ---- imports (dependency edges) ----
        m = RE_IMPORT_PKG.match(line)
        if m:
            imp_pkg, imp_path = m.group(1), m.group(2)
            if pkg and imp_pkg == pkg:
                imports.append("lib/" + imp_path)
            continue
        m = RE_IMPORT_REL.match(line)
        if m and "package:" not in line:
            resolved = (path.parent / m.group(1)).resolve()
            try:
                imports.append(rel(root, resolved))
            except ValueError:
                pass  # outside the project tree; ignore
            continue

        # ---- RouteDef literal table (routes.dart) ----
        for rm in RE_ROUTEDEF.finditer(line):
            varname, _q1, rname, _q2, rpath = rm.groups()
            add("route", rname, i, {"path": rpath, "routeVar": varname})

        # ---- go_router GoRoute(...) blocks ----
        if RE_GOROUTE.search(line):
            goroute_open = True
            goroute_line = i
            goroute_path = None
            goroute_name = None
        if goroute_open:
            if goroute_path is None:
                pm = RE_PATH_LITERAL.search(line)
                if pm:
                    goroute_path = pm.group(2)
                else:
                    pr = RE_PATH_REF.search(line)
                    if pr and "." in pr.group(1):
                        goroute_path = "{" + pr.group(1) + "}"  # ref, resolved later
            if goroute_name is None:
                nm = RE_NAME_LITERAL.search(line)
                if nm:
                    goroute_name = nm.group(2)
                else:
                    nr = RE_NAME_REF.search(line)
                    if nr and "." in nr.group(1):
                        goroute_name = "{" + nr.group(1) + "}"
            # Close the block on builder/) once we have at least a path.
            if ("builder" in line or "redirect" in line) and goroute_path is not None:
                nm = goroute_name or goroute_path
                # Only emit literal-path GoRoutes; ref-path ones are already
                # covered by the RouteDef table (avoids duplicates).
                if not goroute_path.startswith("{"):
                    label = nm if not nm.startswith("{") else goroute_path
                    add("route", label, goroute_line,
                        {"path": goroute_path, "source": "GoRoute"})
                goroute_open = False

        # ---- @riverpod annotation latch ----
        if RE_RIVERPOD_ANNOTATION.match(line):
            pending_riverpod = True
            continue

        # ---- @freezed annotation latch ----
        if RE_FREEZED.match(line):
            pending_freezed = True
            continue

        # ---- providers (codegen) ----
        if pending_riverpod:
            cm = RE_RIVERPOD_CLASS.match(line)
            if cm:
                cls = cm.group(1)
                pname = cls[0].lower() + cls[1:] + "Provider"
                add("provider", pname, i, {"style": "codegen-class", "notifier": cls})
                pending_riverpod = False
                # A codegen Notifier class is also the screen/feature controller,
                # not a widget, so we do NOT also classify it as a screen.
                continue
            fm = RE_RIVERPOD_FUNC.match(line)
            if fm:
                fn = fm.group(1)
                add("provider", fn + "Provider", i,
                    {"style": "codegen-fn", "function": fn})
                pending_riverpod = False
                continue
            # @riverpod sat above something we didn't recognize; drop the latch
            # after one non-blank line so it can't leak.
            if line.strip():
                pending_riverpod = False

        # ---- manual providers ----
        mp = RE_MANUAL_PROVIDER.match(line)
        if mp:
            add("provider", mp.group(1), i,
                {"style": "manual", "providerType": mp.group(2)})
            # fallthrough: a provider line won't also be a class line.

        # ---- freezed models ----
        if pending_freezed:
            cm = RE_CLASS_NAME.match(line)
            if cm:
                add("model", cm.group(1), i, {"style": "freezed"})
                pending_freezed = False
                continue
            if line.strip().startswith("enum"):
                # @freezed never precedes an enum; release the latch.
                pending_freezed = False

        # ---- repositories ----
        ri = RE_REPO_INTERFACE.match(line)
        if ri:
            add("repository", ri.group(1), i, {"role": "interface"})
            continue
        rimpl = RE_REPO_IMPL.match(line)
        if rimpl:
            add("repository", rimpl.group(1), i,
                {"role": "impl", "implements": rimpl.group(2)})
            continue

        # ---- screens / widgets ----
        wm = RE_WIDGET.match(line)
        if wm:
            add("screen", wm.group(1), i, {"base": wm.group(2)})
            continue

    # De-dupe imports while preserving order.
    seen = set()
    uniq_imports = []
    for imp in imports:
        if imp not in seen:
            seen.add(imp)
            uniq_imports.append(imp)

    try:
        mtime = path.stat().st_mtime
    except OSError:
        mtime = 0.0

    return {
        "relpath": relpath,
        "mtime": mtime,
        "entities": entities,
        "imports": uniq_imports,
    }


# --------------------------------------------------------------------------- #
# Index assembly                                                              #
# --------------------------------------------------------------------------- #

def list_dart_files(lib: Path) -> List[Path]:
    out = []
    for p in lib.rglob("*.dart"):
        name = p.name
        # Skip generated files — they add noise and no new symbols.
        if name.endswith((".g.dart", ".freezed.dart", ".gr.dart", ".config.dart")):
            continue
        out.append(p)
    return sorted(out)


def resolve_route_refs(entities: List[Dict]) -> None:
    """Resolve `{AppRoute.x.path}` placeholders left by GoRoute parsing using the
    RouteDef literal table. In practice RouteDef routes already cover these, so
    any unresolved placeholder is simply normalized to a readable form."""
    # Build a lookup of routeVar -> {path,name} from RouteDef entities.
    by_var: Dict[str, Dict] = {}
    for e in entities:
        if e["kind"] == "route" and "routeVar" in e:
            by_var[e["routeVar"]] = e
    for e in entities:
        if e["kind"] != "route":
            continue
        p = e.get("path", "")
        if isinstance(p, str) and p.startswith("{") and p.endswith("}"):
            inner = p[1:-1]                     # e.g. AppRoute.login.path
            var = inner.split(".")[1] if "." in inner else inner
            ref = by_var.get(var)
            e["path"] = ref["path"] if ref else inner


def build(root: Path, out: Path, incremental: bool) -> Dict:
    lib = root / "lib"
    pkg = detect_package_name(root)
    files = list_dart_files(lib)

    prev: Optional[Dict] = None
    prev_by_file: Dict[str, Dict] = {}
    prev_index_mtime = 0.0
    if incremental and out.exists():
        try:
            prev = json.loads(out.read_text(encoding="utf-8"))
            # Reconstruct per-file records from the previous index so unchanged
            # files can be reused verbatim. Entities are grouped back by file.
            ent_by_file: Dict[str, List[Dict]] = {}
            for e in prev.get("entities", []):
                if e.get("kind") == "feature":
                    continue  # synthesized, not file-owned
                ent_by_file.setdefault(e["file"], []).append(e)
            for f in prev.get("files", []):
                prev_by_file[f["file"]] = {
                    "file": f["file"],
                    "mtime": f.get("mtime", 0.0),
                    "imports": f.get("dependsOn", []),
                    "entities": ent_by_file.get(f["file"], []),
                }
            prev_index_mtime = out.stat().st_mtime
        except (OSError, ValueError, KeyError):
            prev = None  # corrupt index → full rebuild

    scanned = 0
    reused = 0
    file_records: List[Dict] = []

    for path in files:
        relpath = rel(root, path)
        try:
            fmtime = path.stat().st_mtime
        except OSError:
            fmtime = 0.0

        if (
            incremental
            and prev is not None
            and relpath in prev_by_file
            and fmtime <= prev_index_mtime
        ):
            file_records.append(prev_by_file[relpath])
            reused += 1
            continue

        rec = scan_file(root, path, pkg)
        file_records.append({
            "file": rec["relpath"],
            "mtime": rec["mtime"],
            "entities": rec["entities"],
            "imports": rec["imports"],
        })
        scanned += 1

    # Flatten entities and attach dependsOn (file-level edges) to each.
    all_entities: List[Dict] = []
    files_summary: List[Dict] = []
    features = set()

    for fr in file_records:
        deps = fr["imports"]
        for e in fr["entities"]:
            e = dict(e)
            e["dependsOn"] = deps
            all_entities.append(e)
            if "feature" in e:
                features.add(e["feature"])
        files_summary.append({
            "file": fr["file"],
            "mtime": fr.get("mtime", 0.0),
            "dependsOn": deps,
        })

    resolve_route_refs(all_entities)

    # Feature entities (one per discovered feature dir).
    feature_entities = []
    for feat in sorted(features):
        feature_entities.append({
            "id": f"feature:{feat}",
            "kind": "feature",
            "name": feat,
            "file": f"lib/features/{feat}/",
            "line": 1,
            "dependsOn": [],
        })
    all_entities = feature_entities + all_entities

    counts: Dict[str, int] = {}
    for e in all_entities:
        counts[e["kind"]] = counts.get(e["kind"], 0) + 1

    index = {
        "schemaVersion": SCHEMA_VERSION,
        "generatedAt": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "root": ".",
        "package": pkg,
        "counts": counts,
        "entities": all_entities,
        "files": files_summary,
        "_meta": {
            "scanned": scanned,
            "reused": reused,
            "totalFiles": len(file_records),
            "incremental": bool(incremental and prev is not None),
        },
    }
    return index


# --------------------------------------------------------------------------- #
# CLI                                                                          #
# --------------------------------------------------------------------------- #

def main(argv: List[str]) -> int:
    ap = argparse.ArgumentParser(description="Build a Flutter semantic index.")
    ap.add_argument("root", nargs="?", default=".", help="project root (has lib/)")
    ap.add_argument("--incremental", action="store_true",
                    help="reuse the existing index for unchanged files")
    ap.add_argument("--out", default=None, help="output JSON path")
    ap.add_argument("--quiet", action="store_true", help="no summary output")
    args = ap.parse_args(argv)

    root = Path(args.root).resolve()
    lib = root / "lib"
    if not lib.is_dir():
        sys.stderr.write(f"error: no lib/ directory under {root}\n")
        return 1

    out = Path(args.out).resolve() if args.out else root / ".flutter-pipeline" / "index.json"
    out.parent.mkdir(parents=True, exist_ok=True)

    index = build(root, out, args.incremental)
    out.write_text(json.dumps(index, indent=2) + "\n", encoding="utf-8")

    if not args.quiet:
        meta = index["_meta"]
        counts = index["counts"]
        mode = "incremental" if meta["incremental"] else "full"
        try:
            out_disp = rel(root, out)
        except ValueError:
            out_disp = str(out)
        print(f"semantic index -> {out_disp}")
        print(f"  mode: {mode}  -  package: {index['package'] or '(unknown)'}")
        print(f"  files: {meta['totalFiles']} "
              f"(scanned {meta['scanned']}, reused {meta['reused']})")
        order = ["feature", "screen", "provider", "route", "repository", "model"]
        parts = [f"{counts.get(k, 0)} {k}{'s' if counts.get(k, 0) != 1 else ''}"
                 for k in order]
        print("  entities: " + ", ".join(parts))

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except KeyboardInterrupt:
        sys.exit(130)
