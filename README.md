# Alchemist — turn raw ideas into shipped gold.

A Claude Code plugin bundling **77 composable, Android-first Flutter skills**. Alchemist takes an app from idea → premium Material 3 UI → clean architecture → backend, security, testing → CI/CD, Play Store deployment, monitoring → production sign-off. A **Master Orchestrator** sequences the full pipeline; autonomous agents handle maintenance, CI healing, and crash triage.

## Why

Generic AI coding produces inconsistent apps. Alchemist encodes one **opinionated, coherent house style** and a **repeatable 24-stage delivery pipeline** so every app is architecturally sound, visually premium, and production-ready.

**Stack:** Dart 3 · Material 3 · Riverpod 2.x · go_router · freezed · dio · `very_good_analysis` · golden + integration tests.

**Visual range:** 140+ styles catalogued in the [UI Style Taxonomy](alchemist/references/UI_STYLE_TAXONOMY.md) — Material You, Cyberpunk, Glassmorphism, Bento, Neumorphism, Swiss Design, Fintech, and more. Every style compiles to `ThemeData` + `AppTokens`.

## Quick start

### Install from GitHub

```text
/plugin marketplace add https://github.com/RICH-KEED/Alchemist
/plugin install alchemist@android-skills
```

### Or test locally

```bash
git clone https://github.com/RICH-KEED/Alchemist.git
claude --plugin-dir ./Alchemist/alchemist
```

### Then start building

```text
/initialize
```

Alchemist asks 5-8 questions to extract your app's DNA, then runs the full pipeline with design critique + quality feedback loops. When complete, you get an APK/AAB, CI pipelines, Play Store copy and graphics, and a checklist of the 10 manual steps that require a human (SHA fingerprints, signing keys, etc.).

### Or invoke a single skill

```text
alchemist:04_Premium_Design_System   # build a design system
alchemist:08_Riverpod                # wire state management
alchemist:43_Design_Critic           # critique a screen
alchemist:77_Store_And_Docs_Publisher  # generate Play Store assets
```

## What's inside

| Cluster | Skills |
|---|---|
| Pipeline (01–24) | Master Orchestrator · Product/UX Planning · Premium Design System · App Preview · Architecture · Navigation · Riverpod · Animation · Assets · Backend Integration · API Testing · Security · Network Resilience · Error Handling · Loading States · Responsive UI · Documentation · GitHub Workflow · Testing · CI/CD · Deployment · Monitoring · Production Readiness |
| Token Economy (25–31) | Context Compression · Semantic Index · Diff-Scoped Loader · Skill Router · Budget Governor |
| Autonomy (32–36) | Autonomous Maintenance · Self-Healing CI · Crash-Free Watchdog · Telemetry · Codebase Onboarding |
| Correctness (37–42) | Build Doctor · Exception Triage · Performance Profiler · State Leak Auditor · Analyzer Auto-Fix · Architecture Debate |
| UI Intelligence (43–48) | Design Critic · Visual Regression · Accessibility Auditor · Figma Bridge · Screenshot→Widget · Motion Critic |
| Codegen (49–55) | OpenAPI Generator · i18n Engine · DB Migration · Push Notifications · Background Sync · Feature Flags · Form Engine |
| Enterprise (56–63) | Dependency Health · Package Recommendation · SBOM/Compliance · Privacy/Data Safety · Threat Modeling · Secrets Scanner · White-Label Engine · Decision Ledger |
| Product (64–69) | ASO · Changelog Generator · Analytics Taxonomy · A/B Experiments · Performance Budget · Device Matrix |
| Reliability (70–74) | Test Generation · Mutation Testing · Contract Drift · Regression Memory · Chaos Testing |
| Extras (75–80) | User Onboarding & Coach Marks · Cross-Project Patterns · Store & Docs Publisher · App Icon Generator · Initialize Command |

## Layout

```
.claude-plugin/marketplace.json     # marketplace listing
alchemist/
  .claude-plugin/plugin.json        # plugin manifest
  references/CONVENTIONS.md          # house style
  references/PIPELINE.md             # 24-stage flow + gates
  references/UI_STYLE_TAXONOMY.md    # 140+ visual styles catalog
  skills/NN_Name/SKILL.md            # 77 skills, each with templates/ + scripts/
```

## Validate

```bash
claude plugin validate ./alchemist
```

## License

MIT
