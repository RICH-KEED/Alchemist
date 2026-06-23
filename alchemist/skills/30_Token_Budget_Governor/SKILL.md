---
name: Token Budget Governor & Cost Predictor
description: Predict the token and dollar cost of a task BEFORE running it, enforce a ceiling, and degrade gracefully when a budget would be exceeded. Use before any big multi-skill operation, when the user sets a budget or asks "how much will this cost", or when the orchestrator is about to run a phase. Reports live spend after.
when_to_use: Trigger before a large or multi-stage operation (a pipeline phase, the full 24-stage run, a heavy single skill like Testing or Backend_Integration), when the user mentions a budget/cost cap or asks for an estimate, or when an operation looks like it might blow up context. For a tiny one-off edit, skip it.
---

# Token Budget Governor & Cost Predictor

You make autonomous operation **forecastable**: before a task runs, you predict its token and dollar cost, check it against a ceiling, and if it would blow the budget you degrade gracefully (compress, scope down, sample, defer, or ask) instead of charging ahead. After it runs, you report what was actually spent. This is the answer to the top enterprise objection to AI agents — "I can't predict what it will cost."

Stay consistent with the house style in [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md). This skill is roadmap item **#30** and is called by **#01 Master_Orchestrator** before big operations.

> **Pricing honesty (non-negotiable).** Never state a dollar price as fact. Token *counts* you may estimate. Price-per-token comes **only** from the editable [`templates/pricing.json`](templates/pricing.json), whose values are clearly-labeled PLACEHOLDERS. Verify them against current Anthropic pricing via the `claude-api` skill (load it → `shared/models.md`, `shared/live-sources.md` → Pricing) or platform.claude.com before quoting dollars or enforcing a `$` ceiling. The session model is **Opus 4.8** (`claude-opus-4-8`).

---

## The cost model

Two inputs, one script.

1. **Per-skill token seeds** — [`templates/cost_model.json`](templates/cost_model.json) holds an `input`/`output` token estimate for each pipeline skill, for one typical run on a small/medium project. These are **seeds**, not measurements.
2. **Telemetry override (#35)** — if **Skill Telemetry #35** has written `.flutter-pipeline/telemetry.json` with at least `min_samples` (default 3) real runs for a skill, the script uses that skill's measured mean instead of the seed. Seeds are training wheels; telemetry replaces them as data accrues.
3. **Heuristic fallback** — for a skill with no seed and no telemetry, or to add work on top of the base, the model scales by plan shape:

   ```
   estimate = base + per_file_edited·files + per_template_generated·templates + per_plan_stage·stages
   ```

   Tunable in `cost_model.json → heuristics`. This is what lets you estimate a skill the seed table has never seen (file count and plan size are the levers).

Prices come from `pricing.json` (model → price-per-1M tokens) and are applied only at the end, to turn a token estimate into a `$` range.

## Estimating a multi-skill plan

A plan is a list of skills, each with how many files it will edit, templates it will generate, and plan stages it spans. Sum the per-skill estimates → total input + output tokens → `$` range via `pricing.json`. The script does all of this:

```bash
# one skill, with file/template counts
python "${CLAUDE_SKILL_DIR}/scripts/estimate.py" \
  --skill 06_Flutter_Architecture --files 5 --templates 2 --budget 60000

# a multi-skill plan via stdin JSON (per-skill file/template counts)
echo '{"skills":[{"name":"20_Testing","files":8},{"name":"04","templates":3}]}' \
  | python "${CLAUDE_SKILL_DIR}/scripts/estimate.py" --budget 350000

# machine-readable, for the orchestrator to branch on
python "${CLAUDE_SKILL_DIR}/scripts/estimate.py" --skill 25 --skill 06 --json
```

Skills resolve by `NN` prefix (`06`) or full name (`06_Flutter_Architecture`). The script prints per-skill input/output, the total, a `$` range (batched–standard), and — if `--budget` is passed — whether the plan is **under**, in the **80% warn** band, or **over**. Exit code: `0` ok, `2` over budget, `1` bad input. `--model` overrides the model (defaults to the session model in `pricing.json`).

## Budget enforcement

- **Hard ceiling** = the token number for the task class (see [`templates/budget_policy.md`](templates/budget_policy.md): `single_stage` / `phase` / `full_pipeline` / `ad_hoc`). Do not *start* an operation whose estimate exceeds it without first degrading or asking.
- **Soft warn** at 80%: surface the estimate, proceed.
- **As a hook:** the orchestrator runs `estimate.py --budget <ceiling> --json` before a big operation and reads the exit code. `2` → run the degradation ladder before proceeding. `0` → log the estimate and go. Because the script is exit-code-driven, it drops cleanly into a pre-operation gate.
- The `$` ceiling is **advisory** until `pricing.json` is verified — gate on tokens, not dollars.

## Graceful-degradation ladder

When the estimate is over the ceiling, climb this ladder **in order**, re-running the estimate after each rung, and stop as soon as it fits. (Full rationale + "when to ask" in `templates/budget_policy.md`.)

1. **Compress** — call **#25 Context_Compression_Engine** to shrink input context (summaries, drop stale tool output, use the **#26 Codebase_Semantic_Index** instead of raw files). Biggest lever when input dominates.
2. **Scope down** — fewer features this pass, fewer files, defer optional stages, lower reasoning effort.
3. **Sample** — do a representative subset (wire 2 of 8 screens, generate 1 golden test as a pattern) and report what was sampled.
4. **Defer** — split the work; do the part that fits now, record the remainder in `.flutter-pipeline/STATE.md` with its own estimate.
5. **Ask** — show the estimate, the ceiling, what each cheaper option sacrifices, and let the user raise the ceiling, accept a degraded run, or cancel.

Never silently truncate inputs or silently drop a stage — deferral and sampling are **recorded and reported**.

## Live spend reporting (after the run)

Once the operation completes, report actuals so estimates calibrate:
- tokens in / out from the response `usage` (plus cache read/write split if available);
- advisory `$` via `pricing.json`, labeled "estimated, unverified prices";
- **estimate vs. actual delta** — hand this to **#35 Skill Telemetry** so the seeds in `cost_model.json` get replaced by real per-skill means over time. The system gets more accurate the more it runs.

## How the orchestrator calls this

In the orchestrator's per-stage / per-phase loop (see [`../01_Master_Orchestrator/SKILL.md`](../01_Master_Orchestrator/SKILL.md)), before invoking the actual work:

1. Build the plan (which skills, rough file/template counts from the stage's artifacts).
2. Run `estimate.py --budget <task-class ceiling> --json`.
3. **Exit 0** → record the estimate in STATE.md, proceed.
4. **Exit 2** → climb the degradation ladder, re-estimate after each rung; if still over after rung 4, **ask** the user.
5. After the work, capture `usage`, report live spend, and forward the delta to #35.

This keeps a full-pipeline run forecastable phase by phase rather than an open-ended spend.

---

## Worked example

The orchestrator is about to run **Phase B foundation**: stage 06 (architecture, ~6 files edited, 1 template) + stage 08 (Riverpod, ~4 files). Task class `phase`, ceiling **350,000** tokens.

Estimate:

```bash
echo '{"skills":[{"name":"06_Flutter_Architecture","files":6,"templates":1},
                 {"name":"08_Riverpod","files":4}]}' \
  | python "${CLAUDE_SKILL_DIR}/scripts/estimate.py" --budget 350000 --model claude-opus-4-8
```

Walk-through (seeds from `cost_model.json`, heuristics `per_file_edited` 1500/2500 in/out, `per_template` 1200/4000):

- **06**: seed 22000/20000 + 6·(1500/2500) + 1·(1200/4000) = **32200 in / 39000 out**
- **08**: seed 16000/14000 + 4·(1500/2500) = **22000 in / 24000 out**
- **Total**: 54,200 in + 63,000 out = **117,200 tokens** → ~$0.92 batched / ~$1.85 standard *(placeholder prices)*
- vs. 350,000 ceiling → **33% — under budget.** Exit 0. Record estimate, run the phase, then report actual `usage` and feed the delta to #35.

Had it come back at, say, 410,000 (exit 2), the orchestrator would compress context via #25 (cutting input tokens), re-estimate, and only ask the user if it were still over after scoping and sampling.

---

Templates: [`cost_model.json`](templates/cost_model.json) · [`pricing.json`](templates/pricing.json) · [`budget_policy.md`](templates/budget_policy.md). Script: [`scripts/estimate.py`](scripts/estimate.py). House style: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).
