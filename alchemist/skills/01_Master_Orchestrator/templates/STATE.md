# Pipeline State — <APP NAME>

goal: <one-line app goal>
mode: full            # full | range:NN-MM | single:NN
current_stage: 02_Product_Planning
status: not_started   # not_started | in_progress | gate_pending | done
updated: <YYYY-MM-DD>

## Completed
<!-- append as stages pass their gate -->
<!-- - 02 Product_Planning  → docs/PRD.md   ✅ gate passed (YYYY-MM-DD) -->

## Current stage
- stage: 02_Product_Planning
- inputs ready: app idea
- exit gate: MVP scope + success metrics agreed
- notes:

## Open gates / blockers
- (none)

## Skipped (with reason)
- (none)

## Decisions log
<!-- - YYYY-MM-DD: <decision> (ADR-XXXX) -->

## Artifacts index
| stage | artifact path |
|-------|---------------|
| 02 | docs/PRD.md |
| 03 | docs/UX.md |
| 04 | lib/app/theme/ , design/*.pen |
| 05 | previews/ |
| 06 | lib/ (scaffold) |
| 07 | lib/app/router/ |
| 08 | features/*/application/ |
| 11 | core/network/ , features/*/data/ |
| 18 | README.md , docs/adr/ |
| 21 | .github/workflows/ |
| 22 | release/ |
