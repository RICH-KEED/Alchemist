# NNNN. <Short title of the decision>

<!--
  Scaffolded by scripts/new_adr.py. Copy lives at docs/adr/NNNN-kebab-title.md.
  Numbers are immutable. One decision per file. An ADR is a record, not an essay.
  This template extends the base ADR (skill 18_Documentation) with two fields
  the Decision Ledger requires: **Alternatives** and **Provenance**.
-->

- **Status:** Proposed   <!-- Proposed | Accepted | Rejected | Deprecated | Superseded by ADR-NNNN -->
- **Date:** <YYYY-MM-DD>
- **Deciders:** <names / roles>
- **Stage:** <pipeline stage that made the call, e.g. 11_Backend_Integration>

## Context

<What forces make this decision necessary — the technical, product, and team
constraints. State the problem neutrally; do not pre-justify the choice here.
Name the requirement that drove it (see Provenance below).>

## Decision

<The change we are making, in active voice: "We will …". Specific enough to act
on. This is the one settled answer the ledger recalls so it is never re-argued.>

## Alternatives considered

<The options we weighed and rejected — this is what stops the choice being
relitigated. One row per real alternative, each with a one-line reason it lost.>

| Alternative | Why not chosen |
|---|---|
| <Option B> | <one-line reason> |
| <Option C> | <one-line reason> |

## Consequences

<What becomes easier and what becomes harder — the good and the bad. Follow-up
work, new constraints, risks, and any tech debt we are knowingly taking on.>

## Provenance

The trace from requirement → this decision → code. Mirrors the entry in
`.flutter-pipeline/decisions.json`.

- **Requirement:** <PRD story id / UX flow / pipeline gate / issue, e.g. STORY-12>
- **Files:** <lib/** paths this decision produced or changed>
  - `lib/features/<feature>/data/<x>_repository.dart`
- **Supersedes:** <ADR-NNNN, or "none">
- **Superseded by:** <ADR-NNNN, or "none">

## References

<Links: related ADRs, the skill 42 debate that resolved this (if any),
issues/PRs, docs, prior art. House style: ../../references/CONVENTIONS.md.>
