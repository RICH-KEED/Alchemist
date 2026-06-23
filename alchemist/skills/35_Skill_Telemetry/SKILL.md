---
name: Skill Telemetry & Self-Tuning
description: Records every skill run's outcome, token cost, and duration to a local telemetry log, then rolls up per-skill means that feed the Cost Predictor (#30) and Skill Router (#28) so the system measurably improves. Use after any skill invocation to append a record, and whenever you want a per-skill rollup or a refreshed cost_model fragment. Trigger — a skill just finished and you have its usage; or the orchestrator asks "how is each skill performing".
when_to_use: Trigger after a skill/stage finishes and you have its token usage and outcome (append one record), or when #30/#28 need fresh per-skill aggregates, or when the user asks which skills are slow, expensive, or churning. Skip for a trivial read-only lookup that ran no skill.
---

# Skill Telemetry & Self-Tuning

You are the pipeline's **memory of how it actually performs**. Every time a skill runs, you append one record — what it produced, what it cost, how long it took, whether it had to be reworked — to a local log. Periodically you roll those records up into per-skill means and percentiles, and you hand those numbers to the two skills that consume them: the **Cost Predictor (#30)**, which swaps its hand-estimated seeds for your measured means, and the **Skill Router (#28)**, which uses your success/rework rates as routing priors. The more the pipeline runs, the more accurate its forecasts and routing get. This is the feedback loop that makes the system **self-tuning** rather than statically guessed.

Stay consistent with the house style in [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md). This skill is roadmap item **#35**, a MEMORY system. Its data is written by every stage skill (via the orchestrator) and read by **#30 Token_Budget_Governor** and **#28 Skill_Router**.

> **Privacy & locality (non-negotiable).** Telemetry is a **local file only** — `.flutter-pipeline/telemetry.json` at the target app's root, never uploaded anywhere. Records carry **no PII and no source code**: store IDs, counts, durations, and outcome enums — never prompts, file contents, user text, secrets, or paths into the user's home. `notes` is a short free-text field; keep it to mechanical detail ("retried analyzer once"), never user data. The file is the project's own performance ledger and nothing else.

---

## What to log, and when

**When:** append exactly **one record per skill invocation**, written **after** the skill finishes (success or failure), once you know its `usage` and outcome. The orchestrator already captures `usage` at the end of each stage (see #30's "live spend reporting") — that same hook forwards the numbers here. A single skill that had to be re-run counts as **one record** with `rework_count` incremented, not two records, so the run count stays honest.

**What:** the fields in [`templates/telemetry_schema.json`](templates/telemetry_schema.json). The record schema:

| Field | Type | Meaning |
|---|---|---|
| `skill_id` | string | Full pipeline key, e.g. `06_Flutter_Architecture` (matches #30's `cost_model.json` keys). |
| `ts` | string | ISO-8601 UTC timestamp of when the run finished. |
| `outcome` | enum | `success` · `fail` · `rework` — see the outcome rules below. |
| `tokens_in` | int | Input tokens from the response `usage` (include cache reads if you have them). |
| `tokens_out` | int | Output tokens from `usage` (thinking tokens bill as output — count them). |
| `duration_ms` | int | Wall-clock milliseconds the skill took end to end. |
| `rework_count` | int | How many times this run had to be redone before it passed (0 for a clean first pass). |
| `notes` | string | Short, mechanical, optional — e.g. `"gate failed once on analyzer"`. **No PII / no code.** |

**Compatibility aliases.** #30's `estimate.py` reads each record's `input`/`output` keys directly. So every record **also** carries `input` (= `tokens_in`) and `output` (= `tokens_out`) — the canonical schema fields are `tokens_in`/`tokens_out`, with `input`/`output` written as mirrors so #30 consumes the log **without modification**. The rollup script does the same on its way out.

### Outcome rules

- `success` — the skill's exit gate (from `PIPELINE.md`) passed on the **first** real attempt; `rework_count` is 0.
- `rework` — it eventually passed, but only after one or more redo loops; set `rework_count` to the number of redos. This is the signal the self-tuning loop hunts for.
- `fail` — it did **not** pass and the stage was abandoned/blocked. Still logged: a failure is data.

---

## File structure

`telemetry.json` is a single JSON object with a small header and records grouped by skill, so #30 can read `obj["skills"][skill_id]` as a list:

```json
{
  "_note": "Local performance ledger. No PII, no source. Written by #35, read by #30/#28.",
  "version": 1,
  "skills": {
    "06_Flutter_Architecture": [ { "skill_id": "06_Flutter_Architecture", "ts": "…", "outcome": "success", "tokens_in": 23110, "tokens_out": 19840, "input": 23110, "output": 19840, "duration_ms": 41200, "rework_count": 0, "notes": "" } ]
  }
}
```

A **flat array** of records at the top level is also accepted by the rollup (`rollup.py` normalizes both shapes). The grouped shape is preferred because it matches #30's `tel["skills"][key]` access path. Appending is a read-modify-write: load, push the record onto `skills[skill_id]` (creating the list if new), write back.

---

## Rollups — the per-skill aggregates

Run the rollup to turn raw records into the numbers #30 and #28 want:

```bash
# human-readable per-skill table
python "${CLAUDE_SKILL_DIR}/scripts/rollup.py" --telemetry .flutter-pipeline/telemetry.json

# machine-readable, for a consumer to parse
python "${CLAUDE_SKILL_DIR}/scripts/rollup.py" --json

# emit a #30-compatible cost_model fragment (means become the new seeds)
python "${CLAUDE_SKILL_DIR}/scripts/rollup.py" --emit-cost-model
```

Per skill the rollup computes: **runs**, **success rate**, **rework rate**, **mean tokens in / out**, and **p50 / p90 duration_ms**. Defaults to `.flutter-pipeline/telemetry.json`; override with `--telemetry`. The script is Python 3 stdlib only (see [`scripts/rollup.py`](scripts/rollup.py)).

---

## How the rollups feed #30 (Cost Predictor)

#30's `cost_model.json` ships **hand-estimated seeds** — coarse priors. Its `estimate.py` already prefers telemetry: when `telemetry.json` exists and a skill has `>= min_samples` (default **3**) records, it uses the **measured mean** input/output instead of the seed. So you do not need to touch #30 for the override to kick in — just keep the log growing. The override is automatic the moment a skill crosses `min_samples`.

`--emit-cost-model` is for the **periodic re-seed**: it prints a `skills` fragment (mean in/out per skill, only for skills past `min_samples`) in `cost_model.json` shape, so a maintainer can paste measured means back into #30's seed table and record the source in `_source`. This is the slow loop; the per-run override above is the fast one.

## How the rollups feed #28 (Skill Router)

#28 routes a request to the right skill(s). Your **success rate** and **rework rate** per skill are its **routing priors**: a skill that succeeds cleanly is a safe route; one that churns (high rework) is a route to approach with more scaffolding or a confirmation step. #28 reads the same rollup (`rollup.py --json`) and folds the per-skill `success_rate` / `rework_rate` into its scoring. Telemetry turns routing from a static guess into a record of what has actually worked.

## The self-tuning loop

This is the point of the whole skill — the data is supposed to **change behavior**:

1. **Measure** — every run appends a record.
2. **Roll up** — periodically (end of a phase, or on demand) compute per-skill aggregates.
3. **Flag** — any skill whose **rework rate** crosses a threshold (default **0.3** — i.e. ≥30% of its runs needed a redo) is flagged for **prompt improvement**: its SKILL.md instructions are likely ambiguous or missing a gate detail. `rollup.py` marks these in its report (`flagged_for_improvement: true`).
4. **Re-seed** — feed measured means back into #30 (`--emit-cost-model`) and success/rework priors into #28.
5. **Repeat** — the next runs are cheaper to forecast and better routed.

A flagged skill is a to-do, not an automatic edit — surface it to the user/maintainer ("#12 API_Testing reworked on 4 of 9 runs — review its gate wording") so a human improves the prompt. The measurement is automatic; the prompt fix is human-reviewed.

---

## Worked example

Stage 06 just finished. Its gate (`flutter analyze` clean) failed once on a stray warning, then passed — so it's a `rework`. The orchestrator hands you `usage` (in 23,110 / out 19,840) and a wall-clock of 41.2s. You append:

```json
{ "skill_id": "06_Flutter_Architecture", "ts": "2026-06-23T18:04:11Z",
  "outcome": "rework", "tokens_in": 23110, "tokens_out": 19840,
  "input": 23110, "output": 19840, "duration_ms": 41200,
  "rework_count": 1, "notes": "gate failed once on analyzer warning" }
```

After a few more runs accrue, `rollup.py --emit-cost-model` shows 06's measured mean is ~21k/18k (vs. its 22k/20k seed) — closer, and #30 already uses it automatically once 06 has ≥3 records. If 06's rework rate later climbs past 0.3, the rollup flags it so its SKILL.md gets a clarity pass.

---

Template: [`templates/telemetry_schema.json`](templates/telemetry_schema.json). Script: [`scripts/rollup.py`](scripts/rollup.py). Consumers: [`../30_Token_Budget_Governor/SKILL.md`](../30_Token_Budget_Governor/SKILL.md) (`cost_model.json`), `../28_Skill_Router/SKILL.md` (routing priors). House style: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).
