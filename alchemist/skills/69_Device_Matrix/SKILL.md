---
name: Device Matrix
description: Run integration and golden tests across a real device matrix via Firebase Test Lab — cover low-end devices, foldables, tablets, and multiple API levels. Use before a release to verify hardware diversity, or when a bug is suspected on a specific device class.
when_to_use: Trigger on "run on device matrix", "test on real devices", "Firebase Test Lab", "test on foldable", "low-end device test", "device compatibility", or before any production release as a hardware diversity gate.
---

# Device Matrix

You run integration tests and golden/image tests across a **real device matrix** on Firebase Test Lab. The goal is to catch issues that only surface on specific hardware — slow CPUs, foldable screens, old API levels, tablets — before users do.

House style: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md). This skill feeds [stage 20 Testing](../20_Testing/SKILL.md) and [stage 22 Deployment](../22_Deployment/SKILL.md).

**Done when:** the matrix run completes with zero failures on all target devices, and a matrix report is produced.

---
## The device matrix tiers

Define a matrix that covers the risk surface. The template at [`templates/device_matrix.yaml`](templates/device_matrix.yaml) provides a ready-to-use config. Three tiers:

### Tier 1 — Core (run on every PR/commit)
- **Pixel 6** (API 33) — reference device, mid-range, current API.
- One **low-end** device (e.g., Moto G Power, 2GB RAM, API 30) — performance floor.
- These run fast (<5 min), catch 80% of device-specific issues.

### Tier 2 — Expanded (run on every release candidate)
Add to Tier 1:
- **Samsung Galaxy** (most popular OEM, API 34) — Samsung-specific behavior (OneUI, edge panels).
- **Pixel Tablet** or **Nexus 9** (large screen, API 33) — layout/tablet issues.
- **Pixel Fold** or emulator foldable config (API 33+) — folded/unfolded state, hinge-aware layout.
- **Low-end 2GB RAM API 29** (min supported API) — absolute floor.

### Tier 3 — Full matrix (run on major releases, e.g. 2.0)
Add to Tier 2:
- **High-end** (e.g., Pixel 8 Pro, API 35) — latest API, edge performance.
- **Samsung Galaxy Tab** (large screen, Samsung OEM).
- **API 30, 31, 32** devices — one per API level still in the support window.
- **RTL locale** device or emulator — Arabic/Hebrew layout issues.

The exact device names are loaded from [`templates/device_matrix.yaml`](templates/device_matrix.yaml). Firebase Test Lab periodically rotates devices — use `gcloud firebase test android models list` to verify availability before running.

---
## Step 1 — Verify prerequisites

1. Firebase project with Test Lab enabled.
2. `gcloud` CLI authenticated (`gcloud auth login`).
3. Integration tests that run on real devices (APK + test APK, or an instrumentation test APK).
4. The app APK is built (`flutter build apk --debug` or `--release`).

If any are missing, stop and tell the user what's needed.

---
## Step 2 — Configure the matrix

Choose the tier based on context:
- **PR / commit:** Tier 1.
- **Release candidate:** Tier 2.
- **Major release:** Tier 3.

Use [`templates/device_matrix.yaml`](templates/device_matrix.yaml) as the device list. The YAML is documentation; the actual command is:

```bash
gcloud firebase test android run \
  --type instrumentation \
  --app build/app/outputs/flutter-apk/app-debug.apk \
  --test build/app/outputs/flutter-apk/app-debug-androidTest.apk \
  --device model=redfin,version=33,locale=en_US,orientation=portrait \
  --device model=redfin,version=33,locale=en_US,orientation=landscape \
  --device model=felis,version=33,locale=en_US,orientation=portrait \
  --timeout 15m \
  --results-bucket gs://<your-bucket>/test-results \
  --results-dir matrix-$(date +%Y%m%d-%H%M%S)
```

Also run golden tests if the project has them: flutter test with golden file comparison is CPU-only; but visual regression tests via `flutter driver` or screenshots on real devices need a different runner.

---
## Step 3 — Run and wait

Execute the `gcloud` command. Test Lab runs the matrix in parallel. Wait for results.

If any device fails:
1. Download the test artifacts (screenshots, logs, video) from the results bucket.
2. For each failure, determine: **device-specific** (passes on other devices, fails on this one) or **universal** (fails everywhere — not a device-matrix issue, fix the test).
3. For device-specific failures, the matrix report template at [`templates/matrix_report.md`](templates/matrix_report.md) guides the diagnosis.

---
## Step 4 — Produce the matrix report

Fill [`templates/matrix_report.md`](templates/matrix_report.md) with:

1. **Run metadata:** date, app version, commit SHA, tier, number of devices.
2. **Results table:** device model, API level, RAM, orientation, result (PASS/FAIL), duration.
3. **Failure analysis:** per failed device: what broke, likely root cause, suggested fix.
4. **Performance observations:** startup time, scroll jank, memory pressure across devices.
5. **Foldable-specific:** does the app handle folded/unfolded transitions? Hinge-aware layout?
6. **Verdict:** `CLEAR` (all pass) or `BLOCKED` (N failures, list blocking devices).

---
## Step 5 — Integrate into CI (optional, recommended)

Add the matrix to the project's CI pipeline (skill 21 CICD):

```yaml
# GitHub Actions fragment
- name: Run device matrix (Tier 1)
  run: |
    gcloud firebase test android run \
      --type instrumentation \
      --app ${{ steps.build.outputs.app-apk }} \
      --test ${{ steps.build.outputs.test-apk }} \
      --device model=redfin,version=33,locale=en_US,orientation=portrait \
      --device model=grunt,version=30,locale=en_US,orientation=portrait \
      --timeout 10m
```

Tier 1 on every PR merge to main; Tier 2 on release branch pushes; Tier 3 on major version tags.

---
## Low-end device strategy

Low-end devices surface real issues that fast CI emulators hide:
- Jank from too much work on the UI thread.
- Out-of-memory crashes from large image caches.
- Slow first-paint because of heavy startup work.
- Large APK extraction delays on low storage.

If Tier 1 includes a 2GB RAM device and it passes, most real-world devices will too.

---
## Foldable strategy

Foldables need explicit testing because:
- **Resize events** — the app must handle `MediaQuery` changes without restarting.
- **Hinge-aware layouts** — content should not be hidden behind the hinge.
- **Folded/unfolded transitions** — the app should not crash or lose state.

Firebase Test Lab supports foldable emulator configs. Use them even if a physical device is unavailable.

---
## Cross-references

- **20 Testing** — produces the integration tests this matrix runs.
- **17 Responsive_UI** — the responsive layouts you validate on tablets/foldables.
- **22 Deployment** — the release gate this matrix feeds.
- **23 Monitoring** — low-end performance issues found here should feed perf monitoring.

See the device matrix template at [`templates/device_matrix.yaml`](templates/device_matrix.yaml) and the report template at [`templates/matrix_report.md`](templates/matrix_report.md).
