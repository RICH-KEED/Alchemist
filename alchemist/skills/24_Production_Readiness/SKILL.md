---
name: Production Readiness
description: Run the final go/no-go launch audit for a Flutter/Android app — walk every pipeline gate (02–23) and audit the cross-cutting concerns (performance, stability, security, accessibility, store compliance, privacy, observability, release hygiene, docs), then produce a GO / NO-GO / CONDITIONAL report. Use before shipping to a public store track, when asked "are we ready to launch", "do a release readiness review", or "production sign-off".
when_to_use: Trigger on "are we ready to ship", "production readiness", "launch gate", "go/no-go", "release sign-off", "final audit before store release", or stage 24 of the pipeline. This is the hard gate before any public release. For a single concern (just security, just monitoring), invoke that stage's skill instead.
allowed-tools: Read Grep Glob
---

# Production Readiness — The Launch Gate (Stage 24)

The **last gate before release**. You audit the whole app against the bar set by every prior
stage and the house style in [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).
Your output is a **go/no-go report**: per-area pass/fail, a blockers list, risks, and a single
recommendation. You do not ship; you tell the human whether it is safe to.

> **Read-only / advisory.** This skill uses only `Read`, `Grep`, `Glob`. You inspect artifacts,
> config, and `.flutter-pipeline/STATE.md` — you never modify code, bump versions, or push a
> release. A failing gate is a finding to report, not a thing to fix here. **The human makes the
> launch call.** When something is broken, name the owning stage and send the user back to it.

## What "ready" means

The exit gate for this stage: **all gates 02–23 are green, AND store compliance + privacy are
done.** If any upstream gate is red or any cross-cutting area below has a blocker, the
recommendation is **NO-GO** (or **CONDITIONAL** if the blocker is minor and time-boxed).

## How to run the review

1. **Read the pipeline state.** Open `.flutter-pipeline/STATE.md` at the project root (owned by
   skill 01). It is your starting ledger of which stages claim to be done.
2. **Re-verify each gate 02–23 against [`PIPELINE.md`](../../references/PIPELINE.md)** — do not
   trust the checkmark; confirm the artifact actually exists and the gate is objectively met
   (file present, config set, tests reference it). Walking the gates is half the audit.
3. **Audit the cross-cutting concerns below** — these span many stages and are where launch risk
   hides.
4. **Fill the checklist** at [`templates/production_readiness_checklist.md`](templates/production_readiness_checklist.md),
   ticking only what you verified and noting the owning stage for each gap.
5. **Write the report** from [`templates/go_no_go_report.md`](templates/go_no_go_report.md): per-area
   status table, blockers, risks, and a GO / NO-GO / CONDITIONAL recommendation with sign-off.
6. **Hand back to the human** — present blockers first, route each to its owning stage, and let
   them make the call.

## Walk the pipeline gates (02–23)

Confirm every gate from PIPELINE.md is genuinely green. Spot-check the artifact, not the tick.

| Phase | Stages | Verify the artifact + gate |
|---|---|---|
| A Plan/Design | 02–05 | `docs/PRD.md`, `docs/UX.md`, theme tokens compile (light+dark), preview signed off |
| B Foundation | 06–08 | `flutter analyze` clean, all screens reachable + deep links, provider tests pass |
| C Experience | 09–17 | 60fps motion, typed assets + adaptive icon/splash, mapped `Result` endpoints, pinned API contracts, **MASVS-L1 (13)**, graceful offline, no uncaught errors + error UX (15), all four async states (16), responsive on phone/tablet/foldable |
| D Quality | 18–20 | public APIs documented + ADRs, repo hygiene, **coverage gate met + CI green (20)** |
| E Ship/Operate | 21–23 | build+test+sign automated, internal track release succeeded, **crashes+analytics+perf visible in dashboard (23)** |

Any red gate here is an automatic blocker — send it back to that stage's skill.

## Audit the cross-cutting concerns

### 1. Performance — *stages 06, 09, 10*
- App **startup time** measured in **release/profile mode** (cold start budget agreed, e.g. < 2s).
- **Jank**: frame build + raster times under 16ms (60fps) / 8ms (120fps); profiled with the
  performance overlay or DevTools timeline, not debug mode.
- **App size**: release AAB inspected (`--analyze-size`); no surprise bloat from assets/deps.
- **Memory**: no leaks on navigation churn; images cached/sized; large lists virtualized.
- Profiling done in **release mode** — debug numbers are meaningless here.

### 2. Stability — *stages 15, 16*
- **Crash-free rate target** defined (e.g. ≥ 99.5% sessions) and dashboard shows headroom.
- **No uncaught errors**: `runZonedGuarded` + `FlutterError.onError` wired (skill 15); a forced
  test crash surfaced in the crash tool.
- **Error UX everywhere**: every async surface renders loading · data · empty · error (skill 16);
  no white-screen-of-death, retries reachable.

### 3. Security — *stage 13*
- **MASVS-L1** checklist from skill 13 passes.
- **No secrets** in the repo or the binary — `grep` the source and inspect strings; keys come from
  CI injection (skill 21), not source.
- **TLS** enforced (no cleartext traffic; pinning where required).
- **Obfuscation + minification** on for release, and the **mapping/symbols are uploaded** so crash
  reports deobfuscate.

### 4. Accessibility — *stages 04, 16, 17*
- **Semantics** labels on interactive + image elements; meaningful reading order.
- **Contrast** meets WCAG AA in light *and* dark.
- **Text scaling** to ~200% doesn't clip or break layouts.
- **Touch targets** ≥ 48dp.
- **Screen-reader pass** done (TalkBack) on the core flows.

### 5. Store compliance — *stage 22*
- **Target API level** meets the current Play requirement.
- **Permissions** each justified; no unused/dangerous permissions in the manifest.
- **Data safety form** completed and matches what the app actually collects.
- **Content rating** questionnaire submitted.
- **Privacy policy URL** live and reachable.

### 6. Privacy — *stage 23*
- **Consent** captured before any non-essential data collection.
- **Data minimization**: only what the feature needs; documented in the data-safety form.
- **Analytics opt-out** honored end-to-end; opting out actually stops events.

### 7. Observability — *stage 23*
- **Crash reporting live** in production config (not just dev) and verified with a test event.
- **Analytics live**: key funnel events fire and appear in the dashboard.
- Perf monitoring + structured logging wired; alerting owner identified.

### 8. Release hygiene — *stage 22*
- **Versioning** correct: `versionName` + monotonically increasing `versionCode` / build number.
- **Staged rollout** planned (e.g. 5% → 20% → 50% → 100%) rather than 100% day one.
- **Rollback plan** written: how to halt the rollout and what the previous-good build is.

### 9. Docs — *stage 18*
- README runnable from clean checkout; ADRs cover key decisions; release notes drafted.
- Runbook exists: who is on call, where dashboards/alerts live, how to triage a crash spike.

## Producing the go/no-go report

Score **every area** as **PASS / FAIL / N/A** with evidence (the artifact or config you checked).
Then choose one recommendation:

- **GO** — all gates 02–23 green; every cross-cutting area PASS; store compliance + privacy done.
- **CONDITIONAL** — no hard blockers, but ≥1 area has a minor, **time-boxed** gap with a named
  owner and date (e.g. "staged rollout config pending — owner X, before 100%").
- **NO-GO** — any red gate, any security/privacy/store-compliance failure, or missing crash
  reporting. List each blocker with its owning stage so the user knows exactly where to go.

Lead the hand-off with **blockers first**, then risks, then the recommendation. Make clear this is
**advisory** — you are recommending, the human signs off and ships.

## Definition of done (this stage)

The checklist is filled from verified evidence (not assumed), the go/no-go report is written with a
clear recommendation and per-area table, and every blocker is routed to its owning stage. When the
recommendation is GO and the human signs off, the pipeline is complete.

See the full stage→artifact→gate map in [`../../references/PIPELINE.md`](../../references/PIPELINE.md)
and the house style in [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).
