# Compression checklist — turn an artifact into a context card

Follow this when compressing a pipeline artifact into a card. You (Claude) are the compressor;
this is the procedure that keeps the result lossless-enough. Output goes to
`.flutter-pipeline/cards/<NAME>.card.md` using the schema in [`card_format.md`](card_format.md).

Inputs you need: the **source artifact**, its **path**, its **byte hash**, a **target token budget**
(default: ≤ 30% of the source, but never at the cost of a must-keep item).

---

## Step 0 — Cache check (skip if fresh)
1. Compute the source file's byte hash.
2. If a card for this source already exists with the **same** `hash` in its front-matter → it's fresh.
   **Stop. Reuse the existing card.** Do not recompress.
3. Otherwise continue.

## Step 1 — Segment
Split the source by its top-level headings into logical units (e.g. PRD → Overview, Personas, Stories,
Scope, Decisions, Acceptance Criteria, Metrics, Open Questions).

## Step 2 — Classify each unit
- **must-keep** → goes in verbatim/near-verbatim, exempt from trimming:
  acceptance criteria, MVP scope, exit-gate text + evidence, API contracts / interfaces (signatures,
  endpoints, DTO↔domain, `Result`/`Failure` variants, route & provider names), decisions + ADR ids,
  hard constraints (minSdk, platform, security/MASVS, perf 60fps, token/budget limits), open items/blockers.
- **compressible** → prose that wraps a fact; reduce to one dense line (subject + decision + constraint).
- **droppable** → pure rationale, motivation, restated background, illustrative examples that don't gate
  any downstream decision.

> If unsure whether something is must-keep, treat it as must-keep. Correctness beats compression.

## Step 3 — Extract must-keep (no paraphrase)
Copy must-keep units faithfully into the matching card sections (mostly **Interfaces / Contracts**,
**Decisions**, **Open items**). Do not reword acceptance criteria or contracts — a single changed word
can change behavior.

## Step 4 — Compress the rest
Turn compressible units into **Key facts** bullets: one fact per line, strip adjectives, transitions,
and motivation. Drop droppable units entirely. Prefer nouns and numbers over sentences.

## Step 5 — For large source files
If the source is code or very long: card the **interfaces and decisions** (public signatures, exported
types, contracts) and in the body point at `path:line-range` rather than inlining the code. Let #26
Codebase Semantic Index supply the symbol→range map.

## Step 6 — Expand-pointer
Fill the **Expand-pointer** section: `source: <path>` and, per body section, the source heading or line
range it came from, so a reader can recover full text in one Read.

## Step 7 — Budget check
Estimate `tokens_card` (≈ words × 1.3 or chars ÷ 4). If over the target budget:
- Group related Key facts up one level and re-summarize.
- **Never** trim must-keep sections. If must-keep alone exceeds the budget, go over and note it in **Purpose**.

## Step 8 — Write front-matter & save
Set `source`, `hash` (the byte hash from Step 0), `stage`, `tokens_full`, `tokens_card`,
`compressed_at` (today), `schema: 1`. Save to `.flutter-pipeline/cards/<NAME>.card.md`.

## Step 9 — Reindex
Run `python "${CLAUDE_SKILL_DIR}/scripts/card_index.py" --root .flutter-pipeline` to refresh
`cards/index.json` and confirm the card is not flagged stale.

---

## Self-check before you finish
- [ ] Every acceptance criterion present and unparaphrased.
- [ ] Every exit-gate's text + evidence present so a reader can re-verify the gate.
- [ ] Every API contract / interface present and exact.
- [ ] Every locked decision + ADR id present.
- [ ] Every hard constraint present (minSdk, targets, security, perf, budgets).
- [ ] Every open item / blocker present.
- [ ] Expand-pointer lets a reader recover any dropped detail in one hop.
- [ ] `tokens_card` < `tokens_full` and within budget (or over-budget noted in Purpose with reason).
