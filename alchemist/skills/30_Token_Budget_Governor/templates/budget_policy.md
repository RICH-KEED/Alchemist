# Budget Policy — token & cost ceilings and the degradation ladder

Copy this into a project's `.flutter-pipeline/` and edit the numbers to taste. The Token Budget Governor reads it (or its defaults) before running a big operation.

> Dollar figures are derived from `pricing.json`, whose values are **PLACEHOLDER** until verified against current Anthropic pricing (see that file's `_verify` note). Treat token ceilings as the hard control; treat `$` ceilings as advisory until prices are confirmed.

---

## Default ceilings per task class

A "task class" is how big the requested operation is. Pick the row that matches; these are *per invocation*, not per session.

| Task class | Example | Token ceiling (in+out) | Advisory $ ceiling (Opus 4.8 seed) | Behavior at ceiling |
|---|---|---|---|---|
| `single_stage` | run one pipeline skill (e.g. just #04) | 60,000 | ~$0.80 | warn, then ask |
| `phase` | a full pipeline phase (e.g. Phase C build) | 350,000 | ~$5.00 | degrade automatically, then ask |
| `full_pipeline` | idea → production, all 24 stages | 2,500,000 | ~$35.00 | checkpoint at each phase; degrade + ask |
| `ad_hoc` | one-off edit / question | 25,000 | ~$0.30 | warn only |

Rules:
- **Hard ceiling** = the token number. The governor must not *start* an operation whose estimate exceeds it without first degrading or asking.
- **Soft warn** at 80% of the ceiling: surface the estimate to the user but proceed.
- The `$` column is advisory because prices are placeholders; never block solely on `$` until `pricing.json` is verified.

---

## Graceful-degradation ladder

When an estimate exceeds a ceiling, climb this ladder **in order**, re-estimating after each rung. Stop as soon as the estimate fits. Only reach the last rung if nothing else brought it under budget.

1. **Compress** — invoke **#25 Context_Compression_Engine** to shrink the input context (summaries, dropped stale tool output, semantic index from #26 instead of raw files). Biggest lever when input tokens dominate. Re-estimate.
2. **Scope down** — narrow the work: fewer features this pass, fewer files touched, defer optional stages, lower the reasoning effort. Re-estimate.
3. **Sample** — instead of processing everything, do a representative subset (e.g. wire 2 of 8 screens, generate 1 golden test as a pattern) and report what was sampled. Re-estimate.
4. **Defer** — split the operation; do the part that fits now, record the remainder in `.flutter-pipeline/STATE.md` as deferred work with its own estimate. Re-estimate the *now* part.
5. **Ask** — present the user the estimate, the ceiling, what each cheaper option would sacrifice, and let them choose: raise the ceiling, accept a degraded run, or cancel.

Never silently truncate inputs or silently drop a stage — deferral and sampling must be recorded and reported.

---

## When to ask the user (vs. proceed autonomously)

Ask when **any** of these holds:
- The estimate exceeds the task-class ceiling **and** the ladder (rungs 1–4) cannot bring it under.
- Degrading would drop something the user explicitly asked for (a named feature, a named stage).
- A single operation's advisory `$` estimate exceeds the `full_pipeline` $ ceiling, regardless of token fit (cost shock guard) — but flag that prices are unverified.
- Prices in `pricing.json` are still placeholders **and** the user has asked for a dollar commitment.

Proceed autonomously (just log the estimate) when the estimate is under the soft-warn threshold, or when rungs 1–4 brought it under the ceiling without sacrificing a named requirement.

---

## Live spend reporting

After an operation, report actuals so the next estimate calibrates:
- tokens in / out (from response `usage`), and cache read/write split if available;
- advisory `$` using `pricing.json` (label it "estimated, unverified prices");
- estimate vs. actual delta — feed this back to **#35 Skill Telemetry** so seed values in `cost_model.json` get replaced by real means over time.
