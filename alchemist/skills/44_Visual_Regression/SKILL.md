---
name: Visual Regression
description: Pixel-diff agent — capture golden screenshots of every key screen across theme (light/dark) × size and diff them on every change to catch UNINTENDED visual deltas unit tests miss. Use for "visual regression", "golden screenshots", "pixel diff", "my UI changed and I didn't mean it to", or wiring golden diffs into PR review and CI.
when_to_use: Trigger on "set up visual regression", "golden screenshot diffs", "pixel diff on PRs", "catch unintended UI changes", "screenshot tests across light/dark and sizes", or "why did this widget shift". Runs after stage 20 (Testing) has the golden basics and stage 17 (Responsive_UI) defines the sizes. For the broader test pyramid/coverage go to stage 20 — this skill is the dedicated visual-diff harness on top of it. Distinguishing intended drift from regression hands off to skill 72.
---

# Visual Regression (Pixel-Diff Agent)

You run the app's **visual safety net**. Unit and widget tests assert *behavior* — a finder is present, a tap fires a callback — but they never see that a padding doubled, a color drifted, or a card shifted 8px. Goldens do: each key screen is rendered to a reference PNG, and every change re-renders and **diffs pixel-for-pixel**. A nonzero diff is a flag for a human: *did you mean to change this?*

This sits on top of stage 20's golden basics. Stage 20 teaches *what a golden is*; you scale it into a **matrix** (screen × theme × size), make rendering **deterministic** enough to diff across machines, wire the **review workflow** so intended changes are blessed and unintended ones are caught, and put it in **CI** so a regression can't merge unseen.

House style is law — [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md) (§4 widget hygiene, §7 Definition of Done). When this skill and that file disagree, that file wins.

**Output artifact:** `test/golden/` (harness + per-screen golden tests + committed `*.png`), `test/flutter_test_config.dart` (global font loading), `.github/workflows/visual_regression.yaml`.
**Exit gate:** every key screen has a golden per theme × size; the suite diffs green on an unchanged tree; CI runs goldens on PRs and uploads failure images as artifacts.

Stack: built-in `matchesGoldenFile` + the [`pumpGolden`](templates/golden_harness.dart) harness. Helpers worth adopting: **`golden_toolkit`** (`loadAppFonts`, multi-device `multiScreenGolden`) or **`alchemist`** (disables platform-specific rendering for stable cross-machine CI — strongly recommended if your goldens flake between local and CI).

---

## 1. The matrix — what to capture

A golden is `screen × theme × size`. Be deliberate about each axis so the set is *complete* but not bloated.

- **Screen** — the **key** screens and stable components: the screens a user lives in (home, list, detail, profile, the empty/error states of each). Not every transient dialog; not screens dominated by live data.
- **Theme** — **light and dark**, always both (CONVENTIONS §4: both are first-class). A regression that only shows in dark is the classic one humans miss.
- **Size** — the device classes from stage 17: at minimum **phone** (`compact`, ~390×844) and **tablet** (`expanded`, ~840×1180). Add a landscape entry where layout genuinely changes.

| Axis | Values | Source |
|---|---|---|
| theme | light, dark | stage 04 `lightTheme` / `darkTheme` |
| size | phone (390×844), tablet (840×1180) | stage 17 breakpoints |
| screen | home, list, detail, empty, error, … | the screens that matter |

For 5 screens that is 5 × 2 × 2 = **20 goldens**. The [`pumpGolden`](templates/golden_harness.dart) helper produces one per call; loop the theme × size axes (see the helper's `goldenMatrix`). Name files `<screen>_<theme>_<size>.png` so a failing artifact is self-describing.

---

## 2. Deterministic rendering (the whole game)

A golden that drifts on a different machine is **worse than none** — it cries wolf until everyone disables it. Determinism is non-negotiable:

1. **Load real fonts.** The default test font is `Ahem` (everything is boxes). Load your app fonts **once** for the whole suite in [`test/flutter_test_config.dart`](templates/flutter_test_config.dart) so every golden renders real glyphs. Use `loadAppFonts()` (golden_toolkit/alchemist) or roll your own `FontLoader` over bundled `.ttf` files.
2. **Pin the size.** Set `tester.view.physicalSize` + `devicePixelRatio` (the harness does this via `setSurfaceSize`); never let the host window decide.
3. **Kill animations & time.** Pump to a settled, fixed frame: `pumpAndSettle()` and avoid mid-animation captures. Disable implicit animations where possible, and **inject a fixed clock** — never let a rendered `DateTime.now()`, a relative timestamp ("2m ago"), or a `Random()` reach a golden.
4. **Freeze data.** No real network — override providers with fakes that return fixed payloads (CONVENTIONS §6). The same input must always paint the same pixels.
5. **Pin the runner.** Anti-aliasing differs across OS/GPU. Generate and verify goldens on **one** environment (one CI runner image). `alchemist` can disable platform-specific text rendering so local-vs-CI matches; otherwise treat the CI runner's PNGs as canonical and never commit goldens generated on a developer's machine.

The `pumpGolden` harness folds 1–4 into one call: ProviderScope + theme + pinned size + settle.

---

## 3. Organizing goldens by screen × theme × size

```
test/
├── flutter_test_config.dart          # loads fonts for the WHOLE suite (deterministic)
└── golden/
    ├── golden_harness.dart           # pumpGolden + goldenMatrix helpers
    ├── home_golden_test.dart         # loops light/dark × phone/tablet
    ├── profile_golden_test.dart
    └── goldens/                       # committed reference PNGs (the baseline)
        ├── home_light_phone.png
        ├── home_dark_phone.png
        ├── home_light_tablet.png
        ├── home_dark_tablet.png
        └── …
```

- Goldens live in a `goldens/` subfolder **next to the test** that produces them; `matchesGoldenFile` paths are relative to the test file.
- **Commit the PNGs** — they are the baseline the diff runs against. Treat them as code: they go through review.
- One file per screen keeps a failure scoped to one screen; the theme × size loop lives inside it (see [`golden_harness.dart`](templates/golden_harness.dart)).

---

## 4. The review workflow — intent is the gate

`--update-goldens` makes a golden pass **by definition** — it overwrites the baseline with whatever the widget renders now. That is exactly why an unreviewed update **hides the regression goldens exist to catch**. The discipline:

1. **Default: read-only.** Developers run `flutter test test/golden/` and the suite diffs against committed PNGs. A failure means *the pixels changed*.
2. **Update only with intent.** When a change is **intended** (you restyled the card on purpose), regenerate:
   ```bash
   flutter test --update-goldens test/golden/profile_golden_test.dart
   ```
   …then **commit the new PNGs in the same PR as the code change**, so the diff is visible.
3. **The PR shows the image diff.** Because PNGs are committed, the PR's file view renders **before/after image diffs** for every changed golden. Reviewers eyeball them: *is this the change the PR claims?* A golden PNG changing in a PR that didn't mean to touch UI is the regression — block it.
4. **Never `--update-goldens` blind across the whole suite** to "make it green." That blesses real regressions wholesale. Update only the goldens whose change you can explain, and explain it in the PR.

Decision rule: **intended visual change → update goldens, point at the diff in the PR description. Unexpected diff → it's a regression, fix the code, don't touch the golden.**

---

## 5. CI integration

Goldens run on **every PR** so a regression can't merge unseen. The job ([`templates/visual_regression.yaml`](templates/visual_regression.yaml)):

- **Runs on `pull_request`** (and pushes to main to keep the baseline honest), on a **pinned runner image** so anti-aliasing is stable.
- Loads fonts via `flutter_test_config.dart` automatically (it runs for the whole suite).
- Runs the golden tests; on a pixel mismatch the test **fails** and Flutter writes the actual/expected/diff PNGs under `test/**/failures/`.
- **`if: failure()` uploads `**/failures/**` as a build artifact** so a reviewer downloads the exact diff images without reproducing locally — this is what makes a CI golden failure actionable instead of opaque.
- Does **not** auto-update goldens. CI never runs `--update-goldens`; updating is a human, intent-driven act (§4).

If goldens flake between local and CI despite a pinned runner, switch the harness to `alchemist`'s `goldenTest` (it disables platform-specific rendering) rather than loosening thresholds — a fuzzy diff stops catching the small regressions that matter.

---

## 6. Intended change vs regression (hands off to #72)

Every nonzero diff is one of two things; your job is to make telling them apart **fast**:

- **Intended** — the PR set out to change this UI. Update the affected goldens, commit them, and the PR diff documents the change. ✅
- **Regression** — the PR meant to touch logic/another screen, yet a golden moved. Something leaked: a shared token changed, a default shifted, a parent relaid out. **Do not update the golden** — find and fix the cause. ❌

When the cause is a **shared design-token or shared-component drift** that ripples across many goldens at once (e.g. one spacing token changes and 30 screens shift), that's the province of **skill 72 (Contract & Golden Drift)** — it correlates a token/component change to its fan-out of golden diffs and decides whether the whole sweep is intended. Hand a mass-diff there; keep per-screen, scoped diffs here.

---

## 7. Flakiness avoidance

A flaky golden gets disabled, and a disabled golden catches nothing. Kill flake at the source:

- **Fonts not loaded** → boxes/metrics differ → load fonts in `flutter_test_config.dart` (§2).
- **Unpinned size** → host window leaks in → always pump through `pumpGolden` (it pins size).
- **Live time/random** → frame differs each run → inject a fixed clock, seed/avoid `Random`, no relative timestamps.
- **Mid-animation capture** → race on which frame → `pumpAndSettle()`; disable implicit animations; never golden a perpetual spinner (use a fixed placeholder).
- **Network/async data** → nondeterministic content → override providers with fixed fakes (CONVENTIONS §6).
- **Cross-platform anti-aliasing** → local PNG ≠ CI PNG → one canonical runner image (§5), or `alchemist` to disable platform rendering.
- **Images decoding async** → blank/late image → precache or use a deterministic placeholder asset; `await tester.runAsync` only when you must, then settle.

A golden you can't make deterministic shouldn't be a golden — cover that surface with a widget test instead and golden the stable parts.

---

## Anti-patterns

- **Blind `--update-goldens`** on the whole suite to go green — blesses every regression at once.
- **Goldens with `Ahem`** — boxes, not text; the diff is meaningless. Load fonts.
- **Live clock/random/network in a captured frame** — flaky; freeze all three.
- **Committing goldens generated on a laptop** — anti-aliasing won't match CI; regenerate on the canonical runner.
- **Pumping the host window size** — non-reproducible; always pin via `pumpGolden`.
- **Goldening a whole live screen with real data** — drifts constantly; golden stable components and fixed-data screens.
- **No diff artifact in CI** — a red check with no image is unactionable; always upload `failures/`.
- **Loosening the diff threshold to stop flake** — hides the small regressions goldens exist for; fix determinism instead.

---

## Exit gate (visual regression is "done" when)

- [ ] `test/flutter_test_config.dart` loads real fonts for the whole suite.
- [ ] Every **key screen** has a golden per **theme (light+dark) × size (phone+tablet)**, produced via [`pumpGolden`](templates/golden_harness.dart), with PNGs committed under `goldens/`.
- [ ] The suite diffs **green on an unchanged tree** and is deterministic (re-running yields identical pixels) — no flaky goldens.
- [ ] The review workflow is documented: read-only by default, `--update-goldens` only with intent, PR shows image diffs.
- [ ] `.github/workflows/visual_regression.yaml` runs goldens on PRs on a pinned runner and **uploads failure/diff images as artifacts** on failure.
- [ ] Mass token/component-driven drift is routed to **skill 72**; per-screen diffs handled here.

When green, record `test/golden/` + `flutter_test_config.dart` + the workflow in `.flutter-pipeline/STATE.md`.
