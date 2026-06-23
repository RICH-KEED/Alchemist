# The 24-Stage Flutter Delivery Pipeline

Owned by skill `01_Master_Orchestrator`. Defines the order, the **artifacts** each stage hands off, and the **exit gate** that must pass before advancing. The orchestrator tracks progress in a per-project `.flutter-pipeline/STATE.md`.

Stages are grouped into five phases. Within a phase, some stages can run together; across phases, advance only when the prior gate is green.

---

## Phase A — Plan & Design (02–05)

| # | Stage | Inputs | Output artifacts | Exit gate |
|---|---|---|---|---|
| 02 | Product_Planning | app idea | `docs/PRD.md` (problem, personas, stories, MVP scope, metrics) | MVP scope + success metrics agreed |
| 03 | UI_UX_Planning | PRD | `docs/UX.md` (IA, user flows, screen inventory, nav map) | every MVP story maps to a screen + flow |
| 04 | Premium_Design_System | PRD, UX | `.pen` design kit + `lib/app/theme/*` (tokens, color schemes, typography) | tokens compile; light+dark defined; component specs exist |
| 05 | App_Preview | UX, design system | `.pen`/Stitch mockups + widget gallery + screenshots | stakeholder sign-off on look & feel |

## Phase B — Foundation (06–08)

| # | Stage | Inputs | Output artifacts | Exit gate |
|---|---|---|---|---|
| 06 | Flutter_Architecture | UX, design system | scaffolded app (`lib/` layout, `analysis_options.yaml`, `main.dart`, feature skeleton) | `flutter analyze` clean; app boots |
| 07 | Navigation | screen inventory | `lib/app/router/*` (go_router, guards, deep links) | all screens reachable; deep links resolve |
| 08 | Riverpod | architecture | provider/notifier scaffolds per feature | state wired; provider override tests pass |

## Phase C — Build the experience (09–17)

| # | Stage | Output artifacts | Exit gate |
|---|---|---|---|
| 09 | Animation | transitions, micro-interactions | motion runs 60fps; no jank in profile |
| 10 | Asset_Management | assets pipeline (`flutter_gen`), icons, splash | assets typed; adaptive icon + splash render |
| 11 | Backend_Integration | dio client, repositories, DTO↔domain mappers | endpoints return mapped domain via `Result` |
| 12 | API_Testing | contract/mocked API tests | green against mock server; contracts pinned |
| 13 | Security | secure storage, pinning, obfuscation, biometrics | secrets never in plaintext; MASVS L1 checks pass |
| 14 | Network_Resilience | retry/timeout/offline/connectivity | app degrades gracefully offline; retries bounded |
| 15 | Error_Handling | `Failure`/`Result`, global boundary, error UX | no uncaught errors; every error has UX + log |
| 16 | Loading_States | AsyncValue→UI, skeleton/shimmer, empty/error | all four async states on every data surface |
| 17 | Responsive_UI | adaptive layouts, breakpoints | phone/tablet/foldable + both orientations OK |

## Phase D — Quality & collaboration (18–20)

| # | Stage | Output artifacts | Exit gate |
|---|---|---|---|
| 18 | Documentation | README, ADRs, dartdoc | public APIs documented; ADRs for key decisions |
| 19 | GitHub_Workflow | `.github/` templates, branching, commits | repo hygiene set; PR/issue templates live |
| 20 | Testing | unit/widget/golden/integration + coverage | coverage gate met; CI test job green |

## Phase E — Ship & operate (21–24)

| # | Stage | Output artifacts | Exit gate |
|---|---|---|---|
| 21 | CICD | Actions/Codemagic/Fastlane pipelines | build+test+sign automated on push/tag |
| 22 | Deployment | signed app bundle, store metadata, tracks | internal track release succeeds |
| 23 | Monitoring | crash + analytics + perf + logging wired | events/crashes visible in dashboard |
| 24 | Production_Readiness | launch checklist sign-off | all gates 02–23 green; store compliance + privacy done |

---

## STATE.md (per project)

The orchestrator maintains `.flutter-pipeline/STATE.md` at the target app's root:

```markdown
# Pipeline State — <app name>
current_stage: 06_Flutter_Architecture
status: in_progress        # not_started | in_progress | gate_pending | done

## Completed
- 02 Product_Planning  → docs/PRD.md            ✅ gate passed
- 03 UI_UX_Planning    → docs/UX.md             ✅ gate passed
- 04 Premium_Design... → lib/app/theme/         ✅ gate passed
- 05 App_Preview       → previews/              ✅ gate passed

## Open gates / blockers
- (none)

## Decisions log
- 2026-06-23: chose Supabase backend (ADR-0003)
```

Commands the orchestrator understands: **start**, **status**, **continue/next**, **jump to <NN>**, **skip <NN> (with reason)**, **resume** (re-read STATE.md). A stage is never marked done until its **exit gate** passes.
