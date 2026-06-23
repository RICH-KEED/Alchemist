#!/usr/bin/env python3
"""Skill Router & Minimal-Load Planner.

Given a free-text request, pick the SMALLEST set of skills to load instead of
pulling all ~70 skill descriptions, expand that set to its dependsOn closure,
order it, and print a plan with a confidence signal.

Reads templates/skill_catalog.json (id -> triggers[] + dependsOn[]). stdlib only.

Scoring (per skill): each trigger phrase found as a substring of the lowercased
request scores points. Longer / multi-word phrases score more (they are more
specific). The matched set is the skills scoring above --threshold. The closure
adds every dependsOn ancestor (marked role=dependency). Ordering is by phase
(A..E, then X) and skill number, so upstream contracts come before consumers.

Full-pipeline guard: if the top match is 01 (fullPipeline) or several phase-A
planning skills match strongly, the router recommends deferring to the
orchestrator (#01) instead of an ad-hoc plan.

Usage:
  python route.py "add a login form"
  python route.py --json "why is my build red"
  echo "make the app responsive on tablets" | python route.py
  python route.py --threshold 2 --catalog /path/to/skill_catalog.json "add retries"

Exit code: 0 plan produced, 1 bad input / empty match.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SKILL_DIR = os.environ.get("CLAUDE_SKILL_DIR", os.path.dirname(HERE))
DEFAULT_CATALOG = os.path.join(SKILL_DIR, "templates", "skill_catalog.json")

PHASE_ORDER = {"A": 0, "B": 1, "C": 2, "D": 3, "E": 4, "X": 5}

# For an AD-HOC ask, these are assumed already done (the app exists). They are
# NOT loaded as plan steps — they are surfaced as preconditions to verify.
# Phase-A planning/design + the 06 scaffold are the project's foundation.
PRECONDITION_PHASES = {"A"}
PRECONDITION_SKILLS = {"06_Flutter_Architecture"}


def is_precondition(sid: str, catalog: dict) -> bool:
    if sid in PRECONDITION_SKILLS:
        return True
    return catalog.get(sid, {}).get("phase") in PRECONDITION_PHASES


def load_catalog(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
    # drop the _meta block; it is documentation, not a skill
    return {k: v for k, v in data.items() if not k.startswith("_")}


def skill_num(skill_id: str) -> int:
    m = re.match(r"(\d+)", skill_id)
    return int(m.group(1)) if m else 999


def phrase_weight(phrase: str) -> int:
    """Longer, multi-word triggers are more specific -> worth more."""
    words = len(phrase.split())
    if words >= 3:
        return 3
    if words == 2:
        return 2
    return 1


def score_request(request: str, catalog: dict) -> dict:
    """Return {skill_id: {"score": int, "hits": [phrase, ...]}} for matches."""
    req = " " + request.lower().strip() + " "
    scored: dict = {}
    for sid, entry in catalog.items():
        hits = []
        total = 0
        for phrase in entry.get("triggers", []):
            p = phrase.lower()
            if p in req:
                hits.append(phrase)
                total += phrase_weight(p)
        if total:
            scored[sid] = {"score": total, "hits": hits}
    return scored


def expand_closure(seeds: list, catalog: dict) -> dict:
    """Walk dependsOn from each seed. Return {skill_id: role}."""
    roles: dict = {s: "match" for s in seeds}
    stack = list(seeds)
    while stack:
        cur = stack.pop()
        for dep in catalog.get(cur, {}).get("dependsOn", []):
            if dep not in catalog:
                continue  # unknown id in catalog, skip defensively
            if dep not in roles:
                roles[dep] = "dependency"
                stack.append(dep)
            elif roles[dep] == "dependency":
                pass  # already pulled in as a dependency
    return roles


def order_plan(roles: dict, catalog: dict) -> list:
    def sort_key(sid: str):
        phase = catalog.get(sid, {}).get("phase", "X")
        return (PHASE_ORDER.get(phase, 5), skill_num(sid))

    return sorted(roles.keys(), key=sort_key)


def confidence(scored: dict, matched: list) -> str:
    if not matched:
        return "none"
    top = max(scored[s]["score"] for s in matched)
    if top >= 3 and len(matched) <= 4:
        return "high"
    if top >= 2:
        return "medium"
    return "low"


def detect_full_pipeline(scored: dict, catalog: dict) -> bool:
    """Should we defer to the orchestrator instead of an ad-hoc plan?"""
    for sid in scored:
        if catalog.get(sid, {}).get("fullPipeline"):
            return True
    # 3+ Phase-A planning skills matching strongly => looks like a whole build
    a_hits = [s for s in scored if catalog.get(s, {}).get("phase") == "A"]
    return len(a_hits) >= 3


def build_plan(request: str, catalog: dict, threshold: int) -> dict:
    scored = score_request(request, catalog)
    matched = [s for s, v in scored.items() if v["score"] >= threshold]
    full = detect_full_pipeline(scored, catalog)

    if full:
        return {
            "request": request,
            "mode": "orchestrator",
            "recommend": "01_Master_Orchestrator",
            "reason": "Request spans multiple phases / a full build -- defer to the orchestrator (#01) to run the 24-stage pipeline rather than loading skills ad-hoc.",
            "matched": sorted(matched, key=skill_num),
            "confidence": "high",
        }

    if not matched:
        return {
            "request": request,
            "mode": "ad-hoc",
            "plan": [],
            "matched": [],
            "confidence": "none",
            "reason": "No trigger matched above threshold. Broaden the request, lower --threshold, or load the orchestrator (#01) to scope it.",
        }

    roles = expand_closure(matched, catalog)
    ordered = order_plan(roles, catalog)

    preconditions = sorted(
        [s for s in ordered if is_precondition(s, catalog)], key=skill_num
    )
    plan_steps = [s for s in ordered if not is_precondition(s, catalog)]

    plan = []
    for sid in plan_steps:
        plan.append({
            "skill": sid,
            "role": roles[sid],
            "phase": catalog.get(sid, {}).get("phase", "X"),
            "score": scored.get(sid, {}).get("score", 0),
            "hits": scored.get(sid, {}).get("hits", []),
        })

    return {
        "request": request,
        "mode": "ad-hoc",
        "plan": plan,
        "preconditions": preconditions,
        "matched": sorted(matched, key=skill_num),
        "loaded": len(plan),
        "catalog_size": len(catalog),
        "confidence": confidence(scored, matched),
    }


def render_text(result: dict, catalog: dict) -> str:
    lines = []
    req = result.get("request", "")
    lines.append(f'Request: "{req}"')

    if result.get("mode") == "orchestrator":
        lines.append("Mode: ORCHESTRATOR (full pipeline)")
        lines.append(f"  -> {result['recommend']}")
        lines.append(f"  {result['reason']}")
        if result.get("matched"):
            lines.append("  Strong matches: " + ", ".join(result["matched"]))
        return "\n".join(lines)

    plan = result.get("plan", [])
    if not plan:
        lines.append("Mode: ad-hoc -- NO MATCH")
        lines.append("  " + result.get("reason", ""))
        return "\n".join(lines)

    lines.append(
        f"Mode: ad-hoc  |  confidence: {result['confidence']}  |  "
        f"loaded {result['loaded']} of {result['catalog_size']} skills"
    )
    precond = result.get("preconditions", [])
    if precond:
        lines.append("Preconditions (assumed present -- verify before loading deps):")
        for s in precond:
            lines.append(f"  [{catalog.get(s, {}).get('phase','?')}] {s}")
    lines.append("Ordered plan (upstream contracts first):")
    for i, step in enumerate(plan, 1):
        tag = "match     " if step["role"] == "match" else "dependency"
        why = (" <- " + ", ".join(step["hits"])) if step["hits"] else ""
        lines.append(f"  {i:>2}. [{tag}] {step['skill']}  (phase {step['phase']}){why}")
    return "\n".join(lines)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Route a request to the minimal skill set.")
    ap.add_argument("request", nargs="*", help="free-text request (or pipe via stdin)")
    ap.add_argument("--catalog", default=DEFAULT_CATALOG, help="path to skill_catalog.json")
    ap.add_argument("--threshold", type=int, default=1, help="min match score to include a skill (default 1)")
    ap.add_argument("--json", action="store_true", help="emit JSON instead of text")
    args = ap.parse_args(argv)

    request = " ".join(args.request).strip()
    if not request and not sys.stdin.isatty():
        request = sys.stdin.read().strip()
    if not request:
        ap.error("no request given (pass as args or pipe via stdin)")

    if not os.path.exists(args.catalog):
        print(f"catalog not found: {args.catalog}", file=sys.stderr)
        return 1

    catalog = load_catalog(args.catalog)
    result = build_plan(request, catalog, args.threshold)

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(render_text(result, catalog))

    return 0 if (result.get("plan") or result.get("mode") == "orchestrator") else 1


if __name__ == "__main__":
    raise SystemExit(main())
