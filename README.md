# Alchemist — turn raw ideas into shipped gold.

A Claude Code plugin bundling **75+ composable, Android-first Flutter skills**. Alchemist takes an app from idea → premium Material 3 UI → clean architecture → backend, security, testing → CI/CD, Play Store deployment, monitoring → production sign-off. A **Master Orchestrator** sequences the full pipeline; autonomous agents handle maintenance, CI healing, and crash triage.

## Why

Generic AI coding produces inconsistent apps. Alchemist encodes one **opinionated, coherent house style** (see `alchemist/references/CONVENTIONS.md`) and a **repeatable 24-stage delivery pipeline** (`alchemist/references/PIPELINE.md`) so every app is architecturally sound, visually premium, and production-ready.

**Stack:** Dart 3 · Material 3 · Riverpod 2.x · go_router · freezed · dio · `very_good_analysis` · golden + integration tests.

## The ecosystem

| Cluster | Skills |
|---|---|
| Pipeline (01–24) | Master Orchestrator · Product/UX Planning · Premium Design System · App Preview · Architecture · Navigation · Riverpod · Animation · Assets · Backend Integration · API Testing · Security · Network Resilience · Error Handling · Loading States · Responsive UI · Documentation · GitHub Workflow · Testing · CI/CD · Deployment · Monitoring · Production Readiness |
| Token Economy (25–31) | Context Compression · Semantic Index · Diff-Scoped Loader · Skill Router · Template Cache · Budget Governor · Handoff Compressor |
| Autonomy (32–36) | Autonomous Maintenance · Self-Healing CI · Crash-Free Watchdog · Telemetry · Codebase Onboarding |
| Correctness (37–42) | Build Doctor · Exception Triage · Performance Profiler · State Leak Auditor · Analyzer Auto-Fix · Architecture Debate |
| UI Intelligence (43–48) | Design Critic · Visual Regression · Accessibility Auditor · Figma Bridge · Screenshot→Widget · Motion Critic |
| Codegen (49–55) | OpenAPI Generator · i18n Engine · DB Migration · Push Notifications · Background Sync · Feature Flags · Form Engine |
| Enterprise (56–63) | Dependency Health · Package Recommendation · SBOM/Compliance · Privacy/Data Safety · Threat Modeling · Secrets Scanner · White-Label Engine · Decision Ledger |
| Product (64–69) | ASO · Changelog Generator · Analytics Taxonomy · A/B Experiments · Performance Budget · Device Matrix |
| Reliability (70–74) | Test Generation · Mutation Testing · Contract Drift · Regression Memory · Chaos Testing |
| Extras (75–80) | User Onboarding & Coach Marks · Cross-Project Patterns · Store & Docs Publisher · App Icon Generator |

## Quick start

```bash
# This session only
claude --plugin-dir "D:/ANDROID SKILLS/alchemist"

# Persistent install
/plugin marketplace add "D:/ANDROID SKILLS"
/plugin install alchemist@android-skills

# Trigger the interactive build loop
/initialize
```

## Validate

```bash
claude plugin validate "D:/ANDROID SKILLS/alchemist"
```

## Layout

```
.claude-plugin/marketplace.json     # marketplace listing
alchemist/
  .claude-plugin/plugin.json        # plugin manifest
  references/CONVENTIONS.md          # house style
  references/PIPELINE.md             # 24-stage flow + gates
  skills/NN_Name/SKILL.md            # 80 skills, one per folder
  skills/NN_Name/templates/          # compilable Dart/config templates
  skills/NN_Name/scripts/            # runnable Python/bash tooling
```

## Status

v1.0.0 — 80 skills authored, validated, smoke-tested through stage 08.
