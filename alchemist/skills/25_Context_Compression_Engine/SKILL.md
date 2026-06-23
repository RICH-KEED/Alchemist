---
name: Context Compression Engine
description: Compress large pipeline artifacts (PRD, UX, STATE, source files) into dense, lossless-enough "context cards" that downstream skills load instead of full docs — cutting per-stage tokens 40-70% as the project grows. Use when the orchestrator or a stage skill is about to re-read a big artifact, when context is tight, or when the user asks to compress/summarize the project context. Content-hash cached, expand-on-demand.
when_to_use: Trigger when a stage skill needs an upstream artifact (PRD, UX, STATE, ADRs, large source files) and the raw doc is big; when the orchestrator hands artifacts to a stage; when `.flutter-pipeline/STATE.md` shows many completed stages (context is accumulating); or on "compress the context", "shrink the docs", "make context cards", "we're running out of context". Do NOT use to compress acceptance criteria, gate evidence, or API contracts away — those are preserved verbatim.
---

# Context Compression Engine

House style: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md) · Pipeline & artifacts: [`../../references/PIPELINE.md`](../../references/PIPELINE.md)

## The problem

The 24-stage pipeline produces hand-off artifacts — `docs/PRD.md`, `docs/UX.md`, `.flutter-pipeline/STATE.md`, ADRs, and large source files. Every downstream stage re-reads its upstream inputs (PIPELINE.md's "Inputs" column). By Phase C–E a single stage may need the PRD, UX, design tokens, error contract, and STATE all at once. Those docs only grow. **Re-reading full prose across 24 stages is unbounded context** — it crowds out the actual work, slows runs, and risks the model losing the thread mid-stage.

Most of that prose is *explanatory*: rationale, examples, transitions, restated background. The **decisions, constraints, and interfaces** a downstream stage actually needs are a small fraction of it.

## The "context card" concept

A **context card** is a compact, structured Markdown file that preserves what a downstream stage needs to act — decisions, constraints, interfaces, acceptance criteria, open items — while dropping prose, rationale, and repetition. It is *lossless-enough*: nothing that changes a downstream decision is lost, and the card always **links back to its source** so any reader can expand on demand.

- One card per artifact: `docs/PRD.md` → `.flutter-pipeline/cards/PRD.card.md`.
- Cards live in `.flutter-pipeline/cards/`; an index lives at `.flutter-pipeline/cards/index.json`.
- Cards are **produced by Claude** (this is LLM-driven compression — there is no magic compressor binary). This skill gives you the *method*, the *format*, the *caching rule*, and a deterministic *index helper*.

> Schema → [`templates/card_format.md`](templates/card_format.md) · worked example → [`templates/PRD.card.example.md`](templates/PRD.card.example.md) · the compression checklist you follow → [`templates/compression_prompt.md`](templates/compression_prompt.md).

## WHEN to compress vs. load raw

| Situation | Action |
|---|---|
| Downstream stage needs an upstream artifact and a fresh card exists | **Load the card** |
| Artifact > ~400 tokens and is re-read by ≥2 stages (PRD, UX, STATE, contracts) | **Compress → card**, then load card |
| Artifact is small (< ~400 tokens) or read exactly once | **Load raw** — compression won't pay off |
| You need exact wording (a quoted API signature, a regex, a gate's literal text) | **Load raw, or expand the card's pointer** for that one section |
| Card is stale (source changed since card built) | **Recompress**, then load |
| You are *editing* the artifact (e.g. updating STATE) | **Load raw** — never edit through a card |

Rule of thumb: cards are for **reading to make decisions**, not for editing and not for verbatim extraction. When in doubt about exact text, follow the expand-pointer.

## The hierarchical summarization method

Compress in passes, smallest-loss first. Follow [`templates/compression_prompt.md`](templates/compression_prompt.md) for the full checklist; the shape is:

1. **Segment** the source by its headings into logical units (Problem, Personas, Stories, Scope, Metrics…).
2. **Classify each unit** as `must-keep` (see below), `compressible` (prose around a fact), or `droppable` (pure rationale/restatement/examples that don't gate a decision).
3. **Extract** `must-keep` units **verbatim or near-verbatim** into the card's structured sections — never paraphrase acceptance criteria, gate evidence, or contracts.
4. **Compress** the rest to one dense line per fact: subject + decision + constraint. Strip adjectives, transitions, motivation.
5. **Record an expand-pointer**: `source path` + the heading/anchor each card section came from, so a reader can jump back.
6. **Budget check**: if still over the target token budget, summarize *one more level up* (group related facts), but `must-keep` sections are immune — they are never sacrificed to hit a budget.

For very large sources (e.g. a 2000-line file), card the **interfaces and decisions** (public signatures, exported types, contracts) and point the body at the file path + line ranges rather than inlining code.

## What must NEVER be dropped

These are copied into the card faithfully and are exempt from any budget trimming:

- **Acceptance criteria / MVP scope** (PRD) — they define "done".
- **Exit-gate evidence and gate text** (per PIPELINE.md) — a gate is only green when objectively met; the card must let a reader re-check it.
- **API contracts / interfaces** — public signatures, endpoint shapes, DTO↔domain mappings, `Result`/`Failure` variants, route names, provider names.
- **Decisions** — including ADR references and dated entries from STATE's decisions log.
- **Hard constraints** — `minSdk`, platform targets, security requirements (MASVS), performance targets (60fps), token/budget limits.
- **Open items / blockers** — anything unresolved a downstream stage must respect.

If you cannot fit these *and* stay under budget, **exceed the budget** and note it — correctness beats compression.

## Content-hash caching (recompress only on change)

A card is valid only while its source is unchanged. Each card's front-matter stores `hash` (a hash of the source file's bytes) and the source path.

- Before compressing, compute the source hash. If a card exists with the **same** hash → it's fresh, **reuse it, skip recompression**.
- If the hash differs (or no card) → recompress and update the card + index.
- Run `scripts/card_index.py` to (re)build `index.json`; it records source path, stored hash, token counts, and **staleness** by comparing card vs. source mtime. Cards flagged `stale: true` should be recompressed before they're trusted.

```bash
python "${CLAUDE_SKILL_DIR}/scripts/card_index.py" --root .flutter-pipeline
# prints a table + writes .flutter-pipeline/cards/index.json
python "${CLAUDE_SKILL_DIR}/scripts/card_index.py" --root .flutter-pipeline --stale-only   # list only stale cards
```

The helper is deterministic and stdlib-only — it does **not** compress (that's your job); it indexes and detects staleness. Hashing for the cache lives in the card front-matter you write; the script reports whatever hash you stored and the file-mtime staleness signal.

## Expand-on-demand

Every card ends with an **Expand-pointer** section listing `source: <path>` and, per card section, the heading/line-range it came from. When a reader needs the full text of one section, they Read that range from the source — they never need to re-read the whole document. This keeps the card the *default* load while the source stays one hop away.

## Integration

**With the orchestrator (01):** when handing artifacts to a stage, prefer the card. Load `.flutter-pipeline/cards/PRD.card.md` instead of `docs/PRD.md`; load `STATE.card.md` for a progress snapshot. The orchestrator should call this skill to (re)build cards at phase boundaries (end of A/B/C/D/E), when each artifact is freshly produced, and report cards in STATE alongside their sources. Editing STATE still happens on the raw `STATE.md`; its card is rebuilt after.

**With #26 Codebase Semantic Index:** #26 maps *where* things are (symbols → files); this skill compresses *what they say*. Card large source files by pointing at the index's symbol ranges, and let #26 reference card IDs so a query can return a card instead of a raw file. They share the `.flutter-pipeline/` workspace; cards and the index complement, not duplicate.

## Token-savings math (worked example)

Assume a project mid-Phase-C. Approx token sizes:

| Artifact | Full tokens | Card tokens | Reads downstream |
|---|---|---|---|
| `docs/PRD.md` | 3,200 | 900 | 8 stages read it |
| `docs/UX.md` | 2,600 | 750 | 6 stages |
| `STATE.md` | 1,400 | 400 | every stage (24) |

Without cards, just these three re-reads cost roughly:
`3200·8 + 2600·6 + 1400·24 = 25,600 + 15,600 + 33,600 = 74,800` tokens of repeated input.

With cards (paying the one-time compression read once each, then loading cards):
- One-time compression input ≈ `3200 + 2600 + 1400 = 7,200`.
- Repeated loads: `900·8 + 750·6 + 400·24 = 7,200 + 4,500 + 9,600 = 21,300`.
- Total ≈ `7,200 + 21,300 = 28,500` vs `74,800`.

**Savings ≈ 46,300 tokens (~62%)**, and it widens as more stages and larger docs accumulate — the compression cost is paid once per change, the savings recur on every read. Per-read savings are 65–72% (e.g. STATE 1,400→400). This is the 40–70% per-stage reduction the engine targets.

## Output

- `.flutter-pipeline/cards/<NAME>.card.md` — one per compressed artifact (schema in `templates/card_format.md`).
- `.flutter-pipeline/cards/index.json` — built by `scripts/card_index.py`.

Never write outside `.flutter-pipeline/`. Never compress away a `must-keep` item to hit a budget.
