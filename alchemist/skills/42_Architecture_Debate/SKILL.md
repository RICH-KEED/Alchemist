---
name: Architecture Debate
description: Spawn N advocate agents + a judge for hard architecture decisions — state lib, offline strategy, modularization, backend choice — and produce a scored recommendation plus an ADR. Use when the answer is multi-sided and the cost of a wrong choice is high.
when_to_use: Trigger on "should we use X or Y", "which state management", "Bloc vs Riverpod", "offline-first vs API-first", "monorepo vs multi-package", "SQLite vs NoSQL", "which backend", "help me decide between", or whenever a pipeline stage encounters a structructural choice with defensible arguments on both sides. For simple, single-answer questions use skill 57 Package_Recommendation instead.
---

# Architecture Debate

You are a **structured debate orchestrator**. When the team faces a hard architecture decision — one where reasonable engineers could disagree, where the wrong call costs months, and where the answer is not dictated by [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md) — you run a multi-agent debate: N advocates, one judge, one scored recommendation.

This skill is the **decision-quality multiplier** for the pipeline. It consumes the house style and feeds the [Decision Ledger (skill 63)](../63_Decision_Ledger/SKILL.md), which records the verdict as an ADR so it is never re-litigated.

---
## When to debate (not when to just decide)

| Situation | Use |
|---|---|
| CONVENTIONS already mandates the answer | Cite CONVENTIONS; no debate needed |
| One option is clearly inferior (unsupported, unmaintained, incompatible) | Use skill 57 Package_Recommendation |
| Both/all options are viable, trade-offs are real, and the cost of being wrong is ≥ a week of rework | **Run this skill** |
| A settled ADR already exists in `decisions.json` | Recall it (skill 63); skip |

---
## Step 1 — Frame the question

Before spawning anything, write down:

1. **The decision:** one sentence. "Should we use Drift (SQLite) or Isar for local persistence?"
2. **Constraints:** what is fixed (minSdk, offline requirement, team Dart skill, existing stack decisions).
3. **Criteria with weights** (sum = 1.0): what matters. Examples: correctness/safety (0.25), dev ergonomics (0.20), ecosystem maturity (0.15), bundle size (0.10), team familiarity (0.10), migration cost (0.10), perf on low-end devices (0.10). Pick realistic weights; never make all equal unless they truly are.
4. **Candidates:** 2–4 options. Name them.

Show the framing to the user. If they disagree with criteria or weights, adjust. Proceed only after confirmation.

---
## Step 2 — Spawn advocates (parallel)

For each candidate, spawn **one advocate agent** with a clear brief: argue *for* that candidate against the criteria, using evidence (docs, GitHub stars/issues, pub scores, community size, real benchmarks, migration stories). Each advocate must:

- Score their candidate on every criterion (1–5).
- Cite evidence (link, version, date).
- Propose a **mitigation** for their candidate's weakest criterion.
- Be adversarial about the alternatives — point out real gaps, not strawmen.

Send all advocates in parallel. Each gets the same framing (decision, constraints, criteria, candidates).

---
## Step 3 — Spawn the judge

After all advocates return, spawn a **judge agent** that receives:

- The original framing.
- All advocate briefs (unedited, full text).
- The debate format from [`templates/debate_format.md`](templates/debate_format.md).

The judge must:

1. **Normalize scores** — advocates inflate; the judge calibrates.
2. **Cross-examine** — for each candidate, identify the advocate's weakest claim and stress-test it.
3. **Weigh evidence quality** — a pub.dev score is weaker than a production case study; a 3-year-old benchmark is stale.
4. Produce a **decision matrix**: candidates x criteria, judge-adjusted scores, weighted totals.
5. Write a **recommendation** that names the winner, states the margin, lists the top risk of the winner, and names the closest runner-up (the "plan B" if the winner fails in practice).

---
## Step 4 — Deliver the verdict

Present to the user:

- **Winner** + weighted score + margin over runner-up.
- **Decision matrix** (the table).
- **Top risk** of the winner + the advocate's proposed mitigation.
- **Runner-up** (plan B) — what would make us switch later?
- **ADR draft** — ready for skill 63 to scaffold.

If the margin is < 0.1 (very close), flag it explicitly: "This is a near-tie. The recommendation is X but Y is a real alternative. Consider a spike/prototype before committing."

---
## Step 5 — Feed the ledger

Hand the verdict to [skill 63 Decision_Ledger](../63_Decision_Ledger/SKILL.md) so it is captured as an ADR. The judge's decision matrix becomes the ADR's **Alternatives** section; the winner becomes **Decision**; the top risk + mitigation become **Consequences**.

---
## Cross-references

- **63 Decision_Ledger** — consumes the verdict; prevents re-litigation.
- **57 Package_Recommendation** — for single-answer library picks where CONVENTIONS or pub scores settle it.
- **06 Flutter_Architecture** — the scaffold this decision will live in.
- **CONVENTIONS §1** — the stack defaults; only debate if you are diverging from them.

See [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md) for the stack defaults that pre-resolve many debates, and [`../../references/PIPELINE.md`](../../references/PIPELINE.md) for where this skill fits in the pipeline cycle.
