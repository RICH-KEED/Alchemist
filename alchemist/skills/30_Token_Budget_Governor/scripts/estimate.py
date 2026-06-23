#!/usr/bin/env python3
"""Estimate token + dollar cost for a multi-skill plan, before running it.

Reads cost_model.json (per-skill token seeds + heuristics) and pricing.json
(model price-per-1M tokens, PLACEHOLDER values) and a plan, then prints
estimated tokens and a $ range, flagging if over a passed --budget.

Plan input — either way works:
  * CLI: --skill NN_Name --skill NN_Name --files N --templates N --stages N
  * stdin JSON: {"skills":[{"name":"06_Flutter_Architecture","files":4,
                 "templates":2}], "stages":3}

Dollar prices come ONLY from pricing.json and are PLACEHOLDERS — see that file's
_verify note. Token counts are estimates. stdlib only.

Exit code: 0 ok / under budget, 2 over budget, 1 bad input.

Examples:
  python estimate.py --skill 06_Flutter_Architecture --files 5 --templates 2
  python estimate.py --skill 04 --skill 06 --budget 60000 --model claude-opus-4-8
  echo '{"skills":[{"name":"20_Testing","files":8}]}' | python estimate.py --budget 200000
"""
from __future__ import annotations

import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SKILL_DIR = os.environ.get("CLAUDE_SKILL_DIR", os.path.dirname(HERE))
TEMPLATES = os.path.join(SKILL_DIR, "templates")


def _load(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def _resolve_skill_key(name: str, skills: dict) -> str | None:
    """Accept '06', '06_Flutter_Architecture', or a full key. Return the key or None."""
    if name in skills:
        return name
    # match by leading NN_ prefix
    for key in skills:
        if key == name or key.split("_", 1)[0] == name.split("_", 1)[0]:
            if key.startswith(name) or name.startswith(key.split("_", 1)[0]):
                return key
    # last resort: exact numeric prefix
    pref = name.split("_", 1)[0]
    matches = [k for k in skills if k.split("_", 1)[0] == pref]
    return matches[0] if len(matches) == 1 else None


def _telemetry_mean(skill_key: str, cost_model: dict) -> dict | None:
    cfg = cost_model.get("_telemetry", {})
    if not cfg.get("enabled_when_present"):
        return None
    tpath = cfg.get("telemetry_path", "")
    if not tpath or not os.path.exists(tpath):
        return None
    try:
        tel = _load(tpath)
    except (OSError, json.JSONDecodeError):
        return None
    runs = tel.get(skill_key) or tel.get("skills", {}).get(skill_key)
    if not isinstance(runs, list) or len(runs) < cfg.get("min_samples", 3):
        return None
    n = len(runs)
    return {
        "input": round(sum(r.get("input", 0) for r in runs) / n),
        "output": round(sum(r.get("output", 0) for r in runs) / n),
        "_src": f"telemetry(n={n})",
    }


def estimate_skill(item: dict, cost_model: dict) -> dict:
    """item = {name, files, templates, stages}. Returns dict with input/output/source."""
    skills = cost_model.get("skills", {})
    h = cost_model.get("heuristics", {})
    name = item["name"]
    key = _resolve_skill_key(name, skills)

    base_in = base_out = 0
    source = "heuristic"

    if key:
        tel = _telemetry_mean(key, cost_model)
        if tel:
            base_in, base_out, source = tel["input"], tel["output"], tel["_src"]
        else:
            seed = skills[key]
            base_in, base_out, source = seed["input"], seed["output"], "seed"
    else:
        hb = h.get("base", {"input": 8000, "output": 3000})
        base_in, base_out = hb["input"], hb["output"]

    # additive heuristic deltas (always applied on top of seed/telemetry/base)
    pf = h.get("per_file_edited", {"input": 1500, "output": 2500})
    pt = h.get("per_template_generated", {"input": 1200, "output": 4000})
    ps = h.get("per_plan_stage", {"input": 6000, "output": 4000})
    files = int(item.get("files", 0) or 0)
    templates = int(item.get("templates", 0) or 0)
    stages = int(item.get("stages", 0) or 0)

    inp = base_in + pf["input"] * files + pt["input"] * templates + ps["input"] * stages
    out = base_out + pf["output"] * files + pt["output"] * templates + ps["output"] * stages
    out = round(out * h.get("thinking_output_multiplier", 1.0))

    return {
        "name": key or name,
        "resolved": bool(key),
        "source": source,
        "input": inp,
        "output": out,
    }


def dollars(inp: int, out: int, model: str, pricing: dict) -> float | None:
    m = pricing.get("models", {}).get(model)
    if not m:
        return None
    return round(inp / 1_000_000 * m["input"] + out / 1_000_000 * m["output"], 4)


def build_plan(args) -> dict:
    if not sys.stdin.isatty():
        raw = sys.stdin.read().strip()
        if raw:
            data = json.loads(raw)
            data.setdefault("skills", [])
            # promote a top-level stages onto a synthetic first item if needed
            if "stages" in data and data["skills"]:
                data["skills"][0].setdefault("stages", data["stages"])
            return data
    skills = []
    for name in args.skill or []:
        skills.append({
            "name": name,
            "files": args.files,
            "templates": args.templates,
            "stages": args.stages,
        })
    return {"skills": skills}


def main() -> int:
    ap = argparse.ArgumentParser(description="Estimate plan token/$ cost before running it.")
    ap.add_argument("--skill", action="append", help="Skill name or NN (repeatable).")
    ap.add_argument("--files", type=int, default=0, help="Files edited (applied to each --skill).")
    ap.add_argument("--templates", type=int, default=0, help="Templates generated (per --skill).")
    ap.add_argument("--stages", type=int, default=0, help="Plan stages (per --skill).")
    ap.add_argument("--model", default=None, help="Model id for pricing (default: session model from pricing.json).")
    ap.add_argument("--budget", type=int, default=None, help="Token ceiling (in+out). Flag if exceeded.")
    ap.add_argument("--cost-model", default=os.path.join(TEMPLATES, "cost_model.json"))
    ap.add_argument("--pricing", default=os.path.join(TEMPLATES, "pricing.json"))
    ap.add_argument("--json", action="store_true", help="Emit machine-readable JSON instead of a report.")
    args = ap.parse_args()

    try:
        cost_model = _load(args.cost_model)
        pricing = _load(args.pricing)
    except (OSError, json.JSONDecodeError) as exc:
        print(f"error: cannot load config: {exc}", file=sys.stderr)
        return 1

    try:
        plan = build_plan(args)
    except json.JSONDecodeError as exc:
        print(f"error: bad plan JSON on stdin: {exc}", file=sys.stderr)
        return 1

    if not plan.get("skills"):
        print("error: no skills in plan (use --skill or pipe plan JSON on stdin).", file=sys.stderr)
        return 1

    model = args.model or pricing.get("_session_model", "claude-opus-4-8").split(" ")[0]

    rows = [estimate_skill(it, cost_model) for it in plan["skills"]]
    tot_in = sum(r["input"] for r in rows)
    tot_out = sum(r["output"] for r in rows)
    tot = tot_in + tot_out

    # $ range: low = batch-discounted, high = full price
    full = dollars(tot_in, tot_out, model, pricing)
    mconf = pricing.get("models", {}).get(model, {})
    disc = mconf.get("batch_discount")
    low = round(full * disc, 4) if (full is not None and disc) else full
    over = args.budget is not None and tot > args.budget

    if args.json:
        print(json.dumps({
            "model": model,
            "skills": rows,
            "total_input": tot_in,
            "total_output": tot_out,
            "total_tokens": tot,
            "usd_low": low,
            "usd_high": full,
            "budget": args.budget,
            "over_budget": over,
            "prices_are_placeholder": True,
        }, indent=2))
        return 2 if over else 0

    print("Token & cost estimate (PRE-RUN)")
    print(f"  model: {model}")
    print("  per skill (input / output  source):")
    for r in rows:
        flag = "" if r["resolved"] else "  [no seed — heuristic]"
        print(f"    - {r['name']:<32} {r['input']:>8} / {r['output']:>8}  {r['source']}{flag}")
    print(f"  TOTAL tokens: {tot:,}  (in {tot_in:,} + out {tot_out:,})")
    if full is not None:
        if low != full:
            print(f"  est. cost:    ${low} (batched) – ${full} (standard)  *placeholder prices*")
        else:
            print(f"  est. cost:    ${full}  *placeholder prices*")
    else:
        print(f"  est. cost:    n/a (model '{model}' not in pricing.json)")
    print("  NOTE: $ uses pricing.json PLACEHOLDER values — verify before quoting (see pricing.json _verify).")

    if args.budget is not None:
        pct = round(tot / args.budget * 100)
        if over:
            print(f"  >> OVER BUDGET: {tot:,} > {args.budget:,} tokens ({pct}%). "
                  f"Degrade (compress #25 -> scope -> sample -> defer -> ask) per budget_policy.md.")
        elif pct >= 80:
            print(f"  >> WARN: {pct}% of {args.budget:,}-token budget. Proceeding; surface estimate to user.")
        else:
            print(f"  >> under budget ({pct}% of {args.budget:,}).")

    return 2 if over else 0


if __name__ == "__main__":
    sys.exit(main())
