---
name: 68_Performance_Budget
description: Enforce CI gates on AAB/APK size — cold-start ms — frame budgets. Fail PRs that regress >5% vs committed baseline. Trigger — performance regression — size budget — cold start — jank — frame budget — CI gate failure — size increase on PR.
when_to_use: When a PR changes dependencies — assets — or any code that could affect app size — startup time — or frame rendering. Also when setting up CI for a new project — adding a dependency — or investigating a size/performance regression.
---

# 68 — Performance Budget

Exit gate: **AAB size, cold-start time, and frame budget all within thresholds; CI gate blocks regressions.**

> Feeds stage 21 (CICD) and stage 24 (Production_Readiness).
> Conventions: see `../../references/CONVENTIONS.md`.

---

## 1. Budget Categories

| Category | Metric | Rationale |
|---|---|---|
| APK/AAB size | Total download size (MB) — per-ABI split | User install friction — cellular data cost |
| Cold start | Time-to-initial-display (TTID) in ms | First impression — Play Store vitals |
| Frame rendering | 90th percentile frame build time (ms) | Scroll jank — animation smoothness |
| Jank count | Frames exceeding 16ms per 1000 frames | User-perceived stutter |

---

## 2. Threshold Definitions

Reasonable defaults (tune per project — these are a starting point):

| Metric | Max (hard fail) | Warn |
|---|---|---|
| AAB total size | 50 MB | 40 MB |
| APK per-ABI (arm64-v8a) | 35 MB | 28 MB |
| APK per-ABI (armeabi-v7a) | 30 MB | 24 MB |
| Cold start (TTID) | 500 ms | 400 ms |
| Frame build p90 | 16 ms | 12 ms |
| Jank frames / 1000 | 5 | 2 |
| Method count (D8) | 80 000 | 65 000 |

**Reference device for cold-start measurements:** Pixel 6a (mid-range Android). All cold-start numbers assume a release build on the reference device, average of 5 runs, first two discarded (warm-up).

---

## 3. Measurement Tools

### 3.1 AAB Size
```bash
flutter build appbundle --analyze-size
```
Produces a JSON size report. Parse `build/app/intermediates/merged_native_libs/release/out/lib/` per-ABI.

Alternative (Android Studio): **Build > Analyze APK** for detailed breakdown.

### 3.2 Cold Start
```bash
flutter run --profile --trace-startup
```
This emits a trace file. Open in **Dart DevTools > Timeline** and look for the TTID marker (time from `runApp` start to first frame rasterized). Subtract framework init overhead if measuring from `main()`.

For automated CI measurement, use the `--machine` flag and parse the JSON output.

### 3.3 Frame Budget
```bash
flutter run --profile --trace-skia
```
**Dart DevTools > Timeline** shows per-frame build times. Filter to the 90th percentile across a 30-second scroll session. Use the **Frame rendering** tab to identify jank frames (frames exceeding the 16 ms budget).

For CI, instrument via `SchedulerBinding.instance.addTimingsCallback` in a profile build and log frame times to a file.

### 3.4 Method Count
```bash
dexdump build/app/outputs/flutter-apk/app-release.apk | grep 'method_idx' | wc -l
```
Or use `apkanalyzer` from the Android SDK: `apkanalyzer dex references app-release.apk`.

---

## 4. CI Gate Implementation

### 4.1 Trigger
The performance gate job runs on:
- **Every PR targeting `main`** — compares against baseline, posts delta comment
- **Push to `main`** — updates baseline if metrics improved (lower is better)

### 4.2 Gate Logic

```
┌─────────────────┐
│ Build AAB/APK   │
│ (profile mode)  │
└────────┬────────┘
         ▼
┌─────────────────┐     ┌──────────────────┐
│ Parse metrics    │────▶│ Compare vs       │
│ from build       │     │ .flutter-pipeline│
│ artifacts        │     │ /perf-baseline   │
└────────┬────────┘     │ .json            │
         │              └────────┬─────────┘
         ▼                       ▼
┌─────────────────┐     ┌──────────────────┐
│ Cold-start trace│     │ Delta > 5% worse?│
│ on emulator     │     │ → FAIL PR        │
└────────┬────────┘     └──────────────────┘
         ▼
┌─────────────────┐
│ Post PR comment │
│ with delta table│
└─────────────────┘
```

### 4.3 Rules
- **PR gate:** any metric regresses > 5% from baseline → **hard fail** (block merge).
- **Warning zone:** any metric exceeds its `warn` threshold but stays within 5% of baseline → comment on PR, do not block.
- **New baseline:** if a metric improves (lower is better) and the change is merged to `main`, update the baseline file automatically.
- **Intentional regressions:** if the team deliberately increases a budget (e.g., adding a large new feature), the PR must also update the baseline. The gate job detects this (both baseline and measurement increase together) and does not fail.

---

## 5. Baseline Storage

The canonical baseline lives at `.flutter-pipeline/perf-baseline.json` in the repo root.

### Schema
```json
{
  "version": 1,
  "updated": "ISO-8601 timestamp",
  "updated_by": "CI commit SHA",
  "budgets": { ... }
}
```

### Update Policy
- **Automatic:** on push to `main`, if measured value < baseline value for any metric, update that metric.
- **Manual:** a PR may include a baseline change in its diff. The gate validates that the new baseline values are >= the measured values in that PR.
- **Never delete:** baseline values only move in the direction of improvement (lower), unless explicitly bumped by a manual PR.

---

## 6. Per-Device-Tier Budgets

Different device tiers impose different frame-budget and cold-start targets.

| Tier | Example device | Cold start max | Frame p90 max |
|---|---|---|---|
| Low-end | Android Go (1 GB RAM) | 1500 ms | 33 ms (30 fps target) |
| Mid-range | Pixel 6a (6 GB RAM) | 500 ms | 16 ms (60 fps target) |
| Flagship | Pixel 8 Pro (12 GB RAM) | 300 ms | 8 ms (120 fps target) |

The CI gate runs on the **mid-range** tier by default (Pixel 6a emulator). If low-end or flagship budgets are required, add a matrix strategy in the GitHub Actions workflow.

---

## 7. Pipeline Integration

| Stage | Relationship |
|---|---|
| Stage 21 — CICD | This skill's `perf_budget.yaml` template is a drop-in job for the CI pipeline. It runs as a required status check on `main`. |
| Stage 24 — Production_Readiness | The gate is part of the production readiness checklist. A green performance gate is required before any release. |
| Stage 01 — Master Orchestrator | The orchestrator dispatches the performance gate job and collects results. |

---

## 8. Tuning Guidance

1. **Start with defaults.** Run the gate in `warn-only` mode for 2 weeks to collect real data.
2. **Set baseline from real data.** After 2 weeks, take the p50 of all measurements and set that as the baseline.
3. **Tighten over time.** Every quarter, review the baseline. If the team has consistently been under budget, reduce thresholds by 10%.
4. **Per-module budgets.** For large apps, decompose the budget into per-module caps and sum them.

---

## 9. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| CI gate flaky (passes/fails intermittently) | Emulator variance in cold-start | Increase run count to 7, discard first 3 |
| AAB size spike without code changes | Asset bundling issue — new fonts — new locale data | Check `pubspec.yaml` assets and localization config |
| Frame budget exceeded on CI but not locally | CI emulator runs without GPU acceleration | Use `-gpu swiftshader_indirect` flag |
| Method count creeping up | Dependency adding transitive D8 references | Run `apkanalyzer dex packages` to find culprits |
