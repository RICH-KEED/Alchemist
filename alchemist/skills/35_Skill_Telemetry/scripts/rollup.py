#!/usr/bin/env python3
"""Roll up per-skill telemetry from .flutter-pipeline/telemetry.json.

Reads raw run records (array of records per skill_id), computes per-skill
aggregates — runs, success rate, rework rate, mean tokens in/out, p50/p90
duration — and prints a report or exports to consumers.

Output modes:
  default     — human-readable table
  --json      — machine-readable JSON (for #28 Skill Router)
  --emit-cost-model — #30-compatible cost_model fragment (means become seeds)

The rollup normalizes two file shapes found in the wild:
  (a) {"skills": {"06_...": [records]}}  — preferred, matches #30 reader path
  (b) [record, record, ...]              — flat array tolerated

Exit: 0 ok, 1 bad input/missing file.

Consumed by: #30 Token_Budget_Governor (cost_model), #28 Skill_Router (routing priors).
Written by:  #35 Skill Telemetry.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys

DEFAULT_PATH = ".flutter-pipeline/telemetry.json"
REWORK_FLAG_THRESHOLD = 0.3  # skills with rework rate >= this are flagged


def _load(path: str) -> dict | list:
    if not os.path.exists(path):
        print(f"error: telemetry file not found at '{path}'", file=sys.stderr)
        sys.exit(1)
    try:
        with open(path, "r", encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, json.JSONDecodeError) as exc:
        print(f"error: cannot parse '{path}': {exc}", file=sys.stderr)
        sys.exit(1)


def _normalize(raw: dict | list) -> dict[str, list[dict]]:
    """Return {skill_id: [records]} regardless of input shape."""
    if isinstance(raw, list):
        # flat array — group by skill_id
        grouped: dict[str, list[dict]] = {}
        for r in raw:
            sid = r.get("skill_id", "")
            if sid:
                grouped.setdefault(sid, []).append(r)
        return grouped
    if isinstance(raw, dict):
        # grouped shape preferred
        if "skills" in raw and isinstance(raw["skills"], dict):
            return raw["skills"]
    # fallback: treat dict keys as skill_ids if they map to lists
    result: dict[str, list[dict]] = {}
    for k, v in raw.items() if isinstance(raw, dict) else []:
        if isinstance(v, list) and k not in ("_note", "version"):
            result[k] = v
    return result


def _tokens_in(r: dict) -> int:
    """Read tokens_in, falling back to input alias."""
    return int(r.get("tokens_in", r.get("input", 0)) or 0)


def _tokens_out(r: dict) -> int:
    """Read tokens_out, falling back to output alias."""
    return int(r.get("tokens_out", r.get("output", 0)) or 0)


def _pct_ratio(numer: int, denom: int) -> float:
    if denom == 0:
        return 0.0
    return round(numer / denom, 4)


def _percentile(values: list[float | int], p: float) -> float | int:
    """Percentile by nearest-rank. Returns int if all inputs int."""
    if not values:
        return 0
    s = sorted(values)
    idx = max(0, min(len(s) - 1, int(math.ceil(p / 100.0 * len(s))) - 1))
    return s[idx]


def compute_rollup(skills: dict[str, list[dict]]) -> dict[str, dict]:
    """Return per-skill aggregate dict keyed by skill_id."""
    result: dict[str, dict] = {}
    for sid, records in sorted(skills.items()):
        if not records:
            continue
        n = len(records)
        successes = sum(1 for r in records if r.get("outcome") == "success")
        reworked = sum(1 for r in records if r.get("outcome") in ("rework", "fail"))
        # rework_rate: what fraction of runs needed at least one redo or failed
        rework_rate = _pct_ratio(reworked, n)
        success_rate = _pct_ratio(successes, n)

        mean_in = round(sum(_tokens_in(r) for r in records) / n)
        mean_out = round(sum(_tokens_out(r) for r in records) / n)

        durations = [int(r.get("duration_ms", 0) or 0) for r in records]
        p50 = _percentile(durations, 50)
        p90 = _percentile(durations, 90)

        flagged = rework_rate >= REWORK_FLAG_THRESHOLD

        result[sid] = {
            "runs": n,
            "successes": successes,
            "reworked_or_failed": reworked,
            "success_rate": success_rate,
            "rework_rate": rework_rate,
            "mean_tokens_in": mean_in,
            "mean_tokens_out": mean_out,
            "duration_p50_ms": p50,
            "duration_p90_ms": p90,
            "flagged_for_improvement": flagged,
        }
    return result


def emit_human(rollup: dict[str, dict]) -> None:
    if not rollup:
        print("No records found.")
        return
    hdr = (
        f"{'Skill':<34} {'Runs':>5} {'OK%':>6} {'Rwk%':>6} "
        f"{'In/Out':>18} {'p50':>7} {'p90':>7}  Flag"
    )
    print(hdr)
    print("-" * len(hdr))
    for sid, a in rollup.items():
        flag = "  ** REVIEW" if a["flagged_for_improvement"] else ""
        in_out = f"{a['mean_tokens_in']:,}/{a['mean_tokens_out']:,}"
        print(
            f"{sid:<34} {a['runs']:>5} {a['success_rate']:>5.0%} {a['rework_rate']:>5.0%} "
            f"{in_out:>18} {a['duration_p50_ms']:>6,} {a['duration_p90_ms']:>6,}{flag}"
        )
    flagged = [sid for sid, a in rollup.items() if a["flagged_for_improvement"]]
    if flagged:
        print(f"\n[!] {len(flagged)} skill(s) flagged for prompt improvement "
              f"(rework rate >= {REWORK_FLAG_THRESHOLD:0.0%}):")
        for sid in flagged:
            a = rollup[sid]
            print(f"     {sid} - {a['reworked_or_failed']}/{a['runs']} runs had rework "
                  f"({a['rework_rate']:0.0%}). Review its gate wording in SKILL.md.")


def emit_json(rollup: dict[str, dict]) -> None:
    print(json.dumps(rollup, indent=2))


def emit_cost_model_fragment(rollup: dict[str, dict]) -> None:
    """Print a #30 cost_model.json `skills` key fragment.

    Each entry uses the same shape #30 expects: {"input": N, "output": N, "_note": ...}.
    Only skills with >=3 runs are emitted, matching #30's min_samples gate.
    """
    skills_out: dict[str, dict] = {}
    for sid, a in sorted(rollup.items()):
        if a["runs"] < 3:
            continue
        skills_out[sid] = {
            "input": a["mean_tokens_in"],
            "output": a["mean_tokens_out"],
            "_note": f"telemetry mean, n={a['runs']}, "
                     f"success_rate={a['success_rate']:.0%}, "
                     f"rework_rate={a['rework_rate']:.0%}",
        }
    # also emit a header so the fragment is self-documenting
    print(json.dumps({
        "_note": (
            "MEASURED per-skill token means from telemetry (#35). "
            "Only skills with >=3 runs are included. Replace the corresponding "
            "entries in cost_model.json 'skills' with these values, then update "
            "_source to note the telemetry origin."
        ),
        "_source": "generated by #35 rollup.py --emit-cost-model",
        "_unit": "tokens (input + output) — measured means",
        "skills": skills_out,
    }, indent=2))


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Roll up per-skill telemetry from .flutter-pipeline/telemetry.json"
    )
    ap.add_argument(
        "--telemetry",
        default=DEFAULT_PATH,
        help=f"Path to telemetry.json (default: {DEFAULT_PATH})",
    )
    ap.add_argument(
        "--json",
        action="store_true",
        help="Emit machine-readable JSON rollup.",
    )
    ap.add_argument(
        "--emit-cost-model",
        action="store_true",
        help="Emit #30-compatible cost_model skills fragment (only skills with >=3 runs).",
    )
    args = ap.parse_args()

    raw = _load(args.telemetry)
    skills = _normalize(raw)
    rollup = compute_rollup(skills)

    if args.emit_cost_model:
        emit_cost_model_fragment(rollup)
    elif args.json:
        emit_json(rollup)
    else:
        telemetry_path = os.path.abspath(args.telemetry)
        print(f"Telemetry rollup  source: {telemetry_path}")
        print(f"Records: {sum(a['runs'] for a in rollup.values())}  "
              f"Skills: {len(rollup)}\n")
        emit_human(rollup)
    return 0


if __name__ == "__main__":
    sys.exit(main())
