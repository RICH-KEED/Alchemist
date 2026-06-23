# User Story — US-<NN>: <short title>

> Stage 02 artifact (one per story; summarized in `PRD.md` §5/§6).
> Good stories are vertical, independent, small, and persona-anchored. State the **goal**, not a UI control.

## Story

**As a** <persona from personas.md>,
**I want** <goal — the outcome, not "a dropdown">,
**so that** <value / why it matters>.

- **MoSCoW:** `Must | Should | Could | Won't (now)`
- **Persona:** <name>
- **Maps to (stage 03):** <screen / flow — fill in during UX planning>

## Acceptance criteria (Given / When / Then)

These become widget/integration tests in stage 20 — make them observable and specific.

1. **Given** <starting context>
   **When** <the user action>
   **Then** <the observable result, with concrete numbers/timings where possible>.

2. **Given** <empty / first-run context>
   **When** <action>
   **Then** <the empty-state behavior>.

3. **Given** <offline or error context>
   **When** <action>
   **Then** <graceful degradation — cached data, retry, clear error message>.

> Cover the happy path **and** the empty + error/offline edges — these map to the four async states the UI must render (`CONVENTIONS.md` §4).

## Out of scope (for this story)

- <explicitly what this story does NOT include — prevents the "and" creep>

## Definition of Done

This story is done only when it meets the per-feature DoD in [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md) §7:
- [ ] Compiles with zero analyzer warnings (`very_good_analysis`).
- [ ] All four async states implemented (loading · data · empty · error).
- [ ] Light + dark verified.
- [ ] Colors/sizes/strings tokenized (theme + `AppTokens`).
- [ ] Repository/service calls return `Result<T>` (no raw exceptions across layers).
- [ ] Unit + widget tests cover the acceptance criteria above.
- [ ] Public APIs have doc comments; no unlinked `TODO`.

## Notes / dependencies

- Depends on: <other US-NN, backend endpoint, permission, …>
- Open questions: <…>
