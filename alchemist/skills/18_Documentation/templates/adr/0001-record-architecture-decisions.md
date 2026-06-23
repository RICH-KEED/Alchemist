# 1. Record architecture decisions

- **Status:** Accepted
- **Date:** <YYYY-MM-DD>
- **Deciders:** <names / roles>

## Context

We make architecturally significant decisions throughout the life of this
Flutter app — choosing a backend, a state-management approach, an offline
strategy, dropping a platform, and so on. These decisions are easy to forget
and expensive to relitigate: six months later nobody remembers *why* we picked
Riverpod over Bloc, or why offline sync works the way it does.

We need a lightweight, durable record of these decisions and their reasoning
that lives **with the code**, evolves in version control, and is visible in
pull-request review.

## Decision

We will use **Architecture Decision Records (ADRs)**, as described by Michael
Nygard.

- ADRs live in `docs/adr/` as Markdown files, one decision per file.
- Files are named `NNNN-kebab-title.md` with an immutable, monotonically
  increasing number (this is `0001`).
- Each ADR follows the format **Status · Context · Decision · Consequences**
  (see `ADR_TEMPLATE.md`).
- Status follows the lifecycle `proposed → accepted` (or `rejected`); an ADR may
  later become `deprecated` or `superseded by ADR-NNNN`.
- Accepted ADRs are **append-only**: we never rewrite the decision of an old
  ADR. To change course we write a new ADR and cross-link it as the superseding
  record.
- Significant decisions are also logged in `.flutter-pipeline/STATE.md` with the
  ADR number and date.

## Consequences

- The reasoning behind significant decisions is preserved and discoverable.
- New contributors can read `docs/adr/` to understand how the system got here.
- There is a small, ongoing cost: writing an ADR when a real decision is made.
  This is accepted — it is far cheaper than reconstructing lost context.
- We must judge what is "significant"; trivial or easily-reversed choices do not
  warrant an ADR.

## References

- Michael Nygard, *Documenting Architecture Decisions* (2011).
- House style: `../../references/CONVENTIONS.md`.
