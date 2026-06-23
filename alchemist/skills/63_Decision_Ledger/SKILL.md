---
name: Decision Ledger & Provenance
description: Capture every significant decision (stack, library, architecture, trade-off) as a numbered, linked ADR with a requirement → decision → code trace — so institutional memory persists and settled choices are never re-litigated. Use when a pipeline stage makes a call worth remembering, or before re-deciding something to check whether it was already decided.
when_to_use: Trigger on "record this decision", "why did we choose X", "is this already decided", "add to the decision ledger", "what's the provenance of this", or automatically whenever stage 04/06/08/11/42 commits to a non-trivial choice. For the broad documentation set (README, ARCHITECTURE, dartdoc) use skill 18_Documentation; for actively arguing a choice use skill 42_Architecture_Debate.
---

# Decision Ledger & Provenance

You are the **institutional memory** of a Flutter app. Every significant decision — the *why*, the alternatives weighed, and the trace from requirement → decision → code — is captured once as a numbered ADR and indexed so it can be **recalled instead of re-decided**. Re-litigating a settled choice is a token waste and a coherence risk; this skill exists to make that impossible.

This skill **owns the running ledger** (`.flutter-pipeline/decisions.json`) and the **capture hook**. It builds on the ADR practice defined by [skill 18_Documentation](../../skills/18_Documentation/SKILL.md) (which owns the ADR *format*) and consumes the output of [skill 42_Architecture_Debate](../../skills/42_Architecture_Debate/SKILL.md) (which produces the *reasoning*). It feeds [skill 73_Regression_Memory](../../skills/73_Regression_Memory/SKILL.md) the same way: durable memory that prevents repeated mistakes.

House style: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md). Pipeline map: [`../../references/PIPELINE.md`](../../references/PIPELINE.md).

---

## What counts as a "significant decision"

Record an ADR when a choice is **hard to reverse** and **shapes the system**. Four buckets:

| Bucket | Examples |
|---|---|
| **Stack** | backend (Supabase vs custom REST), database (drift vs isar), auth provider, push transport |
| **Library** | a dependency added to fill a real need (e.g. `dio` interceptor stack, a chart lib, a date picker) where alternatives existed |
| **Architecture** | layer boundaries, offline/sync strategy, navigation shell, multi-module split, a feature-flag gating model |
| **Trade-off** | dropping a platform, accepting tech debt with a payback plan, perf-vs-readability calls, a deliberate convention deviation |

**Do NOT** write an ADR for: a lint rule, a variable name, a one-line refactor, anything trivially reversible, or anything CONVENTIONS already mandates (link it instead — CONVENTIONS wins per §0). When unsure, ask: *"would a new contributor in six months waste time relitigating this?"* If yes, record it.

---

## The capture hook (when stages make a call, write an ADR)

The ledger is fed **automatically** at the moment a decision is made — not in a doc-writing phase after the fact, where the *why* has already evaporated. Hook these stages:

| Stage | Decisions it commits | Example ADR |
|---|---|---|
| **04 Premium_Design_System** | design-token model, theming approach, component-library strategy | "Use `ThemeExtension` tokens over a global constants file" |
| **06 Flutter_Architecture** | layer layout, state-management choice, error/Result contract adoption | "Adopt feature-first + light Clean (CONVENTIONS §2)" |
| **08 Riverpod** | notifier vs codegen style, scoping/override strategy | "Use `@riverpod` codegen classes, not manual providers" |
| **11 Backend_Integration** | backend, DTO↔domain mapping policy, caching layer | "Choose Supabase over a custom Node backend" |
| **42 Architecture_Debate** | the *resolved* position of any structured debate | the debate's verdict, with both sides in Alternatives |

When such a stage commits to a choice, **run `scripts/new_adr.py`** to scaffold the ADR file and register it in the ledger, then fill the body from the template. The orchestrator logs the same line in `.flutter-pipeline/STATE.md` (e.g. `2026-06-23: chose Supabase backend (ADR-0007)`), so STATE.md and the ledger agree.

---

## ADR linkage + the provenance trace

The point of difference from plain ADRs (skill 18) is the **trace**: a decision is only useful if you can walk from *what was asked* to *what was built*.

```
requirement id  →  ADR-NNNN  →  files[]
  (PRD story /                   (the lib/** paths the
   UX flow / gate)               decision produced or changed)
```

- **requirement** — the upstream driver: a PRD story id (`STORY-12`), a UX flow, a pipeline gate, or an issue/ticket. Answers *"why did this decision exist?"*
- **ADR** — the decision record (`docs/adr/NNNN-*.md`) with Context / Decision / **Alternatives** / Consequences / **Provenance**.
- **files[]** — the code the decision touched: the repository it introduced, the theme tokens it defined, the router shell it created. Answers *"where does this decision live now?"*

Every ledger entry carries all three, so any one can be queried from any other:
- *requirement → decisions*: "what did STORY-12 cause us to decide?"
- *file → decision*: "this `auth_repository.dart` exists because of which ADR?"
- *decision → requirement*: "ADR-0007 — what was it serving?"

`scripts/new_adr.py` writes the entry; the ADR's **Provenance** section (template field) mirrors it in human-readable form so the trace survives even if the JSON is lost.

---

## Status lifecycle

ADRs are **append-only history** (skill 18 §3). The ledger tracks the status; the ADR file's Status line is the source of truth.

```
proposed ──► accepted ──► superseded by ADR-NNNN
   │                  └──► deprecated
   └──► rejected
```

- A decision is never **edited** to reverse it. To change course, write a **new** ADR, set the new one's `supersedes` to the old number, and flip the old one's status to `superseded`. Both link each other.
- `deprecated` = no longer relevant but not replaced (the feature was removed).
- `rejected` = considered and declined (still valuable: it stops the choice being re-proposed).
- The record of a wrong-in-hindsight choice is **kept**, not deleted — that's the whole point.

---

## Recall: how the ledger prevents re-deciding

This is the payoff. **Before** any stage or router re-opens a choice, it consults the ledger first:

1. **The orchestrator** (skill 01), at the start of a stage that would make a stack/architecture call, reads `.flutter-pipeline/decisions.json`. If an `accepted` ADR already covers the choice, it **does not re-debate** — it cites `ADR-NNNN` and proceeds. Only a *new force* (a new requirement, a failed gate, a superseding need) justifies a new ADR.
2. **The skill router** (skill 28) checks the ledger before routing a "should we use X?" request into a debate (skill 42). A settled, `accepted` decision short-circuits to "already decided in ADR-NNNN" instead of spending tokens re-arguing.
3. **A debate (skill 42)** must read the ledger as input: if its question is already answered, it produces a *recall* note, not a fresh argument — unless the asker explicitly supplies a new force, which then becomes the Context of a superseding ADR.

The rule: **consult the ledger, then decide; never decide, then discover it was already decided.** A `rejected` entry is just as load-bearing as an `accepted` one — it stops a dead idea from being reborn.

---

## How to use this skill

1. **A stage made a call** → run the scaffolder:
   ```bash
   python3 "${CLAUDE_SKILL_DIR}/scripts/new_adr.py" \
     --title "Choose Supabase over custom backend" \
     --requirement STORY-12 \
     --files lib/features/auth/data/auth_repository.dart \
     --root .
   ```
   This finds the next free number under `docs/adr/`, scaffolds the ADR from the template, and appends an entry to `.flutter-pipeline/decisions.json`. See `scripts/new_adr.py --help`.
2. **Fill the ADR body** from [`templates/decision_record.md`](templates/decision_record.md): Context, Decision, **Alternatives** (what you rejected + the one-line why), Consequences, and **Provenance** (requirement + files).
3. **Flip status to `accepted`** when the decision is committed (the scaffolder writes `proposed`). Update the ledger entry's `status` to match.
4. **Superseding** → scaffold a new ADR with `--supersedes NNNN`; the script links both and flips the old entry to `superseded`.
5. **Before re-deciding** → grep the ledger: `python3 -c "import json;print(*[d['title'] for d in json.load(open('.flutter-pipeline/decisions.json'))['decisions']],sep='\n')"` — or just read the file. If it's there and `accepted`, cite it.

---

## Files this skill owns

| Path | What |
|---|---|
| `docs/adr/NNNN-*.md` | the ADR files (format per skill 18; this skill scaffolds them) |
| `.flutter-pipeline/decisions.json` | the machine-readable ledger / trace index ([schema](templates/trace_index.schema.json)) |
| [`templates/decision_record.md`](templates/decision_record.md) | the ADR template (Context / Decision / Alternatives / Consequences / Provenance) |
| [`templates/trace_index.schema.json`](templates/trace_index.schema.json) | JSON Schema for the ledger |
| [`scripts/new_adr.py`](scripts/new_adr.py) | scaffolder — next number, new ADR file, ledger append |

---

## Definition of done

- Every significant decision (stack / library / architecture / trade-off) has an ADR in `docs/adr/` and an entry in `.flutter-pipeline/decisions.json`.
- Every ledger entry traces **requirement → ADR → files[]**; the ADR's Provenance section mirrors it.
- Statuses are accurate; superseded decisions link both ways and are never deleted.
- STATE.md's decisions log and the ledger agree (same ADR numbers + dates).
- The orchestrator and router **consult the ledger before re-opening** any settled choice.

See the house style in [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md) and the ADR practice in [skill 18_Documentation](../../skills/18_Documentation/SKILL.md).
