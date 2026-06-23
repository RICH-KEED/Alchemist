# Context Card schema

A context card is a single Markdown file at `.flutter-pipeline/cards/<NAME>.card.md`.
It has YAML front-matter (machine-readable, indexed by `scripts/card_index.py`) and a fixed
set of body sections. Keep the whole card dense — one fact per line, no prose.

See the engine method in [`../SKILL.md`](../SKILL.md) and the house style in
[`../../../references/CONVENTIONS.md`](../../../references/CONVENTIONS.md).

---

## Front-matter (required)

```yaml
---
card: PRD                      # short id; usually the source basename without extension
source: docs/PRD.md            # path to the source artifact, relative to project root
hash: sha256:3f9a...c1         # hash of the SOURCE file's bytes at compression time (cache key)
stage: 02_Product_Planning     # pipeline stage that owns the source (from PIPELINE.md), or "n/a"
tokens_full: 3200              # approx token count of the FULL source (your estimate)
tokens_card: 900               # approx token count of THIS card
compressed_at: 2026-06-23      # date the card was built (today's date)
schema: 1                      # card schema version
---
```

- `hash` is the **cache key**: reuse the card when the source hash is unchanged; recompress when it differs.
- `tokens_full` / `tokens_card` let the index report savings (`1 - tokens_card/tokens_full`).
- Token counts are estimates (≈ words × 1.3, or chars ÷ 4) — they only need to be consistent, not exact.

## Body sections (in this order)

### Purpose
One or two lines: what this artifact is and why a downstream stage reads it.

### Key facts
Dense bullets — the constraints, scope, numbers, names a reader must know. One fact per line.
Strip rationale and adjectives. Keep hard constraints (minSdk, targets, limits) verbatim.

### Decisions
Choices already made (and locked). Include ADR ids and dated entries where they exist.
A downstream stage must not relitigate these. Copy faithfully.

### Interfaces / Contracts
**Must-keep, near-verbatim.** Public signatures, endpoint shapes, route/provider names,
DTO↔domain mappings, `Result`/`Failure` variants, acceptance criteria, exit-gate text + evidence.
This section is exempt from budget trimming.

### Open items
Unresolved questions, blockers, TODOs-with-owner, gates not yet green. A reader must respect these.

### Expand-pointer
`source: <path>` plus, per body section, the source heading or line range it was derived from,
so a reader can Read just that range to recover full text. Always present.

---

## Authoring rules

- Cards are **read to make decisions**, never edited to change the source. Edit the source, then rebuild the card.
- Never paraphrase items in **Interfaces / Contracts** or acceptance criteria — copy them.
- If keeping must-keep items pushes you over the token budget, **go over budget** and note it in Purpose.
- Keep total length far below the source; if a section is empty, write `- (none)` rather than deleting the heading
  (the section set is fixed so cards are predictable to load).
