#!/usr/bin/env python3
"""dep_health.py — Dependency Health Monitor collector (skill #56).

Parses a Flutter project's pubspec.yaml (declared deps) or pubspec.lock
(resolved deps, incl. transitive) for package names, then queries the public
pub.dev APIs for each package and optionally the OSV advisory database, and
prints a health table (or JSON).

Data sources (HTTP, JSON, no auth):
  - https://pub.dev/api/packages/<name>            latest version + publish dates
  - https://pub.dev/api/packages/<name>/score      pub points, likes, popularity, tags
  - POST https://api.osv.dev/v1/query              known vulnerabilities (--osv)

Stdlib only (urllib, json). Network failures are handled gracefully: the
affected package is skipped with a note and the run continues.

Usage:
  python dep_health.py pubspec.yaml
  python dep_health.py pubspec.lock --osv
  python dep_health.py pubspec.yaml --json
  python dep_health.py pubspec.lock --include-transitive --osv --json

Flags:
  --osv                 query OSV advisories for each resolved version
  --json                emit JSON instead of a text table
  --include-transitive  also score transitive deps (lock files only)
  --delay <seconds>     polite delay between requests (default 0.3)
  --timeout <seconds>   per-request timeout (default 10)
"""
from __future__ import annotations

import argparse
import datetime as _dt
import json
import re
import sys
import time
import urllib.error
import urllib.request

PUB_BASE = "https://pub.dev/api/packages/"
OSV_URL = "https://api.osv.dev/v1/query"
USER_AGENT = "flutter-android-dep-health/1.0 (skill #56; +https://pub.dev)"

# Dimension weights (must match templates/health_rubric.md).
WEIGHTS = {
    "maintenance": 0.25,
    "popularity": 0.15,
    "pub_points": 0.10,
    "modern_dart": 0.10,
    "vulnerabilities": 0.20,
    "abandonment": 0.10,
    "breaking": 0.10,
}


# --------------------------------------------------------------------------- #
# Manifest parsing (no PyYAML; tolerant line parser for pubspec files)
# --------------------------------------------------------------------------- #
def parse_pubspec_yaml(text: str) -> list[str]:
    """Return direct dependency names from a pubspec.yaml.

    Reads the `dependencies:` and `dev_dependencies:` top-level blocks. Skips
    `flutter`/`flutter_test` SDK pseudo-deps and git/path/sdk-sourced entries
    (no pub.dev record to score).
    """
    names: list[str] = []
    section = None
    skip = {"flutter", "flutter_test", "flutter_localizations", "flutter_web_plugins"}
    lines = text.splitlines()
    for i, raw in enumerate(lines):
        line = raw.rstrip()
        if not line or line.lstrip().startswith("#"):
            continue
        # top-level key (no indentation)
        if re.match(r"^[A-Za-z_]", line):
            key = line.split(":", 1)[0].strip()
            section = key if key in ("dependencies", "dev_dependencies") else None
            continue
        if section is None:
            continue
        m = re.match(r"^\s{2}([A-Za-z0-9_]+)\s*:(.*)$", raw)
        if not m:
            continue
        name = m.group(1)
        rest = m.group(2).strip()
        if name in skip:
            continue
        # nested git/path/sdk source -> next indented lines describe it; skip
        if rest == "" and i + 1 < len(lines):
            nxt = lines[i + 1].strip()
            if nxt.startswith(("git:", "path:", "sdk:", "hosted:")):
                continue
        if rest.startswith(("git", "path", "sdk", "{")):
            continue
        if name not in names:
            names.append(name)
    return names


def parse_pubspec_lock(text: str, include_transitive: bool) -> list[tuple[str, str, str]]:
    """Return [(name, version, dependency_kind)] from a pubspec.lock.

    dependency_kind is one of: 'direct main', 'direct dev', 'transitive'.
    Only 'hosted' (pub.dev) packages are returned.
    """
    out: list[tuple[str, str, str]] = []
    lines = text.splitlines()
    in_packages = False
    cur_name = None
    cur_version = None
    cur_kind = None
    cur_source = None

    def flush():
        if cur_name and cur_source == "hosted":
            kind = cur_kind or "transitive"
            if include_transitive or kind.startswith("direct"):
                out.append((cur_name, cur_version or "?", kind))

    for raw in lines:
        if re.match(r"^packages:\s*$", raw):
            in_packages = True
            continue
        if in_packages and re.match(r"^[A-Za-z_]", raw) and not raw.startswith(" "):
            # left the packages block (e.g. `sdks:`)
            flush()
            in_packages = False
            cur_name = None
            continue
        if not in_packages:
            continue
        # package name: exactly 2-space indent, key ends with ':'
        m = re.match(r"^\s{2}([A-Za-z0-9_]+):\s*$", raw)
        if m:
            flush()
            cur_name = m.group(1)
            cur_version = cur_kind = cur_source = None
            continue
        sm = re.match(r"^\s{4}(\w+):\s*(.+?)\s*$", raw)
        if sm and cur_name:
            key, val = sm.group(1), sm.group(2).strip().strip('"')
            if key == "version":
                cur_version = val
            elif key == "dependency":
                cur_kind = val
            elif key == "source":
                cur_source = val
    flush()
    return out


# --------------------------------------------------------------------------- #
# HTTP helpers (graceful)
# --------------------------------------------------------------------------- #
def _get_json(url: str, timeout: float):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def _post_json(url: str, payload: dict, timeout: float):
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url, data=data,
        headers={"User-Agent": USER_AGENT, "Content-Type": "application/json", "Accept": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def fetch_package(name: str, timeout: float):
    return _get_json(f"{PUB_BASE}{urllib.parse.quote(name)}", timeout)


def fetch_score(name: str, timeout: float):
    return _get_json(f"{PUB_BASE}{urllib.parse.quote(name)}/score", timeout)


def fetch_osv(name: str, version: str, timeout: float):
    payload = {"package": {"ecosystem": "Pub", "name": name}}
    if version and version != "?":
        payload["version"] = version
    return _post_json(OSV_URL, payload, timeout)


# --------------------------------------------------------------------------- #
# Scoring
# --------------------------------------------------------------------------- #
def _parse_iso(ts: str):
    if not ts:
        return None
    ts = ts.replace("Z", "+00:00")
    try:
        return _dt.datetime.fromisoformat(ts)
    except ValueError:
        try:
            return _dt.datetime.strptime(ts[:10], "%Y-%m-%d").replace(tzinfo=_dt.timezone.utc)
        except ValueError:
            return None


def _semver_parts(v: str):
    nums = re.findall(r"\d+", (v or "").split("+")[0])
    nums = [int(x) for x in nums[:3]]
    while len(nums) < 3:
        nums.append(0)
    return tuple(nums)


def maintenance_score(days):
    if days is None:
        return 50
    if days <= 90:
        return 100
    if days <= 180:
        return 85
    if days <= 365:
        return 65
    if days <= 547:
        return 45
    if days <= 730:
        return 25
    return 0


def breaking_score(current, latest):
    c, l = _semver_parts(current), _semver_parts(latest)
    if c == l:
        return 100
    if l[0] > c[0]:
        return 10 if (l[0] - c[0]) >= 2 else 40
    if l[1] > c[1]:
        return 70
    return 90  # patch behind


def evaluate(name, current_version, kind, args):
    """Collect + score one package. Returns a result dict."""
    res = {
        "name": name, "kind": kind, "current": current_version,
        "latest": None, "last_publish": None, "days_since_publish": None,
        "pub_points": None, "max_points": None, "likes": None,
        "popularity": None, "downloads_30d": None,
        "null_safe": None, "dart3": None, "discontinued": False,
        "advisories": [], "score": None, "tier": None,
        "action": "", "note": "", "skipped": False,
    }
    try:
        pkg = fetch_package(name, args.timeout)
    except Exception as e:  # noqa: BLE001 — degrade gracefully
        res["skipped"] = True
        res["note"] = f"pub.dev API failed: {type(e).__name__}"
        return res

    latest = pkg.get("latest", {})
    res["latest"] = latest.get("version")
    res["discontinued"] = bool(pkg.get("isDiscontinued"))
    pub = _parse_iso(latest.get("published", ""))
    if pub:
        now = _dt.datetime.now(_dt.timezone.utc)
        res["last_publish"] = pub.date().isoformat()
        res["days_since_publish"] = (now - pub).days

    time.sleep(args.delay)
    try:
        score = fetch_score(name, args.timeout)
        res["pub_points"] = score.get("grantedPoints")
        res["max_points"] = score.get("maxPoints")
        res["likes"] = score.get("likeCount")
        pop = score.get("popularityScore")
        res["popularity"] = round(pop, 3) if isinstance(pop, (int, float)) else None
        res["downloads_30d"] = score.get("downloadCount30Days")
        tags = score.get("tags") or []
        res["null_safe"] = "is:null-safe" in tags
        res["dart3"] = "is:dart3-compatible" in tags
    except Exception as e:  # noqa: BLE001
        res["note"] = (res["note"] + f"; score API failed: {type(e).__name__}").strip("; ")

    if args.osv:
        time.sleep(args.delay)
        try:
            osv = fetch_osv(name, current_version, args.timeout)
            for v in osv.get("vulns", []) or []:
                res["advisories"].append(v.get("id", "?"))
        except Exception as e:  # noqa: BLE001
            res["note"] = (res["note"] + f"; OSV failed: {type(e).__name__}").strip("; ")

    _score_and_tier(res)
    return res


def _popularity_pct(res):
    """Derive a 0..1 popularity from likes + 30-day downloads.

    pub.dev's old `popularityScore` field is gone from the public score API, so
    we synthesize one from the signals that ARE returned (downloads dominate,
    likes refine). Log-scaled against rough ecosystem reference points so a
    mega-package lands near 1.0 and an obscure one near 0.
    """
    if res["popularity"] is not None:  # honor it if the API ever returns it
        return res["popularity"]
    import math
    dl = res["downloads_30d"] or 0
    likes = res["likes"] or 0
    # ~1M downloads/30d or ~3k likes => "very popular" reference.
    dl_n = math.log10(dl + 1) / 6.0 if dl > 0 else 0.0
    like_n = math.log10(likes + 1) / 3.5 if likes > 0 else 0.0
    return max(0.0, min(1.0, 0.7 * dl_n + 0.3 * like_n))


def _score_and_tier(res):
    dims = {}
    dims["maintenance"] = maintenance_score(res["days_since_publish"])

    pop = _popularity_pct(res)
    res["popularity"] = round(pop, 3)
    pscore = pop * 100
    if (res["likes"] or 0) > 500:
        pscore += 5
    if (res["downloads_30d"] or 0) > 100_000:
        pscore += 5
    dims["popularity"] = min(100, pscore)

    if res["pub_points"] is not None and res["max_points"]:
        dims["pub_points"] = res["pub_points"] / res["max_points"] * 100
    else:
        dims["pub_points"] = 50

    md = 0
    if res["null_safe"]:
        md += 50
    if res["dart3"]:
        md += 50
    dims["modern_dart"] = md

    dims["vulnerabilities"] = 0 if res["advisories"] else 100

    ab = 100
    if (res["days_since_publish"] or 0) > 547:
        ab -= 60
    if pop < 0.3:
        ab -= 40
    if res["discontinued"]:
        ab = 0
    dims["abandonment"] = max(0, ab)

    dims["breaking"] = breaking_score(res["current"], res["latest"]) if res["latest"] else 50

    total = sum(dims[k] * WEIGHTS[k] for k in WEIGHTS)
    res["score"] = round(total)

    # tier + hard overrides
    if res["advisories"] or res["discontinued"]:
        tier = "RISK"
    elif res["score"] >= 75:
        tier = "HEALTHY"
    elif res["score"] >= 50:
        tier = "WARN"
    else:
        tier = "RISK"
    # null-safety cap
    if res["null_safe"] is False and tier == "HEALTHY":
        tier = "WARN"
    res["tier"] = tier
    res["action"] = _action(res)


def _action(res):
    if res["advisories"]:
        return "SECURITY: bump to lowest non-vulnerable version now (#32)"
    if res["discontinued"]:
        return "Discontinued -> replace (#57)"
    if res["tier"] == "RISK":
        return "Replace or urgent review (#57/#32)"
    if res["latest"] and _semver_parts(res["latest"])[0] > _semver_parts(res["current"])[0]:
        return "Reviewed major upgrade: read CHANGELOG (#32)"
    if res["latest"] and _semver_parts(res["latest"]) != _semver_parts(res["current"]):
        return "Safe minor/patch bump in batch (#32)"
    return "OK — keep"


# --------------------------------------------------------------------------- #
# Output
# --------------------------------------------------------------------------- #
TIER_MARK = {"HEALTHY": "OK ", "WARN": "WARN", "RISK": "RISK", None: "?   "}


def print_table(results):
    header = (
        f"{'PACKAGE':24} {'KIND':12} {'CUR':10} {'LATEST':10} "
        f"{'PUBLISHED':11} {'PTS':7} {'POP':5} {'NS/D3':6} {'ADV':4} {'SCORE':5} {'TIER':4}  ACTION"
    )
    print(header)
    print("-" * len(header))
    for r in sorted(results, key=lambda x: (x["tier"] != "RISK", x["tier"] != "WARN", x["name"])):
        if r["skipped"]:
            print(f"{r['name']:24} {r['kind']:12} {'SKIPPED — ' + r['note']}")
            continue
        pts = f"{r['pub_points']}/{r['max_points']}" if r["pub_points"] is not None else "-"
        pop = f"{int(r['popularity']*100)}%" if r["popularity"] is not None else "-"
        ns = "Y" if r["null_safe"] else ("N" if r["null_safe"] is False else "?")
        d3 = "Y" if r["dart3"] else ("N" if r["dart3"] is False else "?")
        adv = str(len(r["advisories"])) if r["advisories"] else "-"
        print(
            f"{r['name']:24} {r['kind']:12} {(r['current'] or '?'):10} {(r['latest'] or '?'):10} "
            f"{(r['last_publish'] or '?'):11} {pts:7} {pop:5} {ns+'/'+d3:6} {adv:4} "
            f"{str(r['score']):5} {TIER_MARK[r['tier']]:4}  {r['action']}"
        )
    _print_summary(results)


def _print_summary(results):
    scored = [r for r in results if not r["skipped"]]
    skipped = [r for r in results if r["skipped"]]
    tiers = {"HEALTHY": 0, "WARN": 0, "RISK": 0}
    advisories = []
    for r in scored:
        tiers[r["tier"]] = tiers.get(r["tier"], 0) + 1
        advisories += r["advisories"]
    print("\nSUMMARY")
    print(f"  scored={len(scored)}  healthy={tiers['HEALTHY']}  warn={tiers['WARN']}  risk={tiers['RISK']}  skipped={len(skipped)}")
    print(f"  open advisories: {len(advisories)} {advisories if advisories else ''}")
    direct_risk = [r for r in scored if r["tier"] == "RISK" and r["kind"].startswith("direct")]
    gate = "PASS" if not advisories and not direct_risk else "FAIL"
    print(f"  release gate (#24): {gate}")
    if skipped:
        print("  skipped (re-run): " + ", ".join(r["name"] for r in skipped))


def main(argv=None):
    ap = argparse.ArgumentParser(description="Dependency Health Monitor collector (skill #56)")
    ap.add_argument("manifest", help="path to pubspec.yaml or pubspec.lock")
    ap.add_argument("--osv", action="store_true", help="query OSV advisories")
    ap.add_argument("--json", action="store_true", help="emit JSON instead of a table")
    ap.add_argument("--include-transitive", action="store_true", help="score transitive deps (lock only)")
    ap.add_argument("--delay", type=float, default=0.3, help="polite delay between requests (s)")
    ap.add_argument("--timeout", type=float, default=10.0, help="per-request timeout (s)")
    args = ap.parse_args(argv)

    try:
        with open(args.manifest, "r", encoding="utf-8") as fh:
            text = fh.read()
    except OSError as e:
        print(f"error: cannot read {args.manifest}: {e}", file=sys.stderr)
        return 2

    is_lock = args.manifest.replace("\\", "/").endswith(".lock") or "packages:" in text[:200]
    if is_lock:
        deps = parse_pubspec_lock(text, args.include_transitive)
    else:
        deps = [(n, "?", "direct main") for n in parse_pubspec_yaml(text)]

    if not deps:
        print("no pub.dev dependencies found in manifest", file=sys.stderr)
        return 1

    if not args.json:
        print(f"Scoring {len(deps)} dependencies from {args.manifest} "
              f"(osv={'on' if args.osv else 'off'})...\n", file=sys.stderr)

    results = []
    for i, (name, version, kind) in enumerate(deps):
        results.append(evaluate(name, version, kind, args))
        if i < len(deps) - 1:
            time.sleep(args.delay)

    if args.json:
        print(json.dumps({
            "manifest": args.manifest,
            "generated": _dt.date.today().isoformat(),
            "weights": WEIGHTS,
            "packages": results,
        }, indent=2))
    else:
        print_table(results)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
