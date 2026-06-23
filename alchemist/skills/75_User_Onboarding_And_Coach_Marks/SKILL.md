---
name: User Onboarding & Coach Marks
description: Add first-run onboarding and in-context feature coaching to a Flutter app — an intro/welcome flow plus ShowcaseView/FeatureDiscovery coach marks that spotlight key actions, shown only on first launch, with persisted completion state and replay from Settings. Use when the user says "add onboarding", "coach marks", "feature tour", "showcase", "walkthrough", "highlight the FAB", "first-run experience", or "tutorial overlay".
when_to_use: Trigger when introducing a new or complex feature that needs explaining, when a screen's primary action isn't discoverable, after shipping a feature that users miss, or when building the first-run experience. Pairs with stage 03 (UX flows), 04 (tokens), 07 (navigation), 08 (state), 10 (assets/illustrations). Not for marketing splash screens — this is functional product onboarding.
---

# User Onboarding & Coach Marks

Make features discoverable. This skill produces two complementary layers, both governed by **persisted completion state** so they appear **only on first launch** and can be **replayed from Settings**:

1. **Onboarding flow** — a short, skippable intro (value props / permissions priming / sign-in) shown once before the user reaches the app.
2. **Coach marks** — in-context spotlights (ShowcaseView / Feature Discovery) that highlight the real UI: the FAB, a gesture, a new tab — anchored to live widgets, not screenshots.

Stay aligned with the house style in [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md): Riverpod for state, `AppTokens` for spacing/typography/motion, persistence via `shared_preferences`, no business logic in widgets.

**Output artifacts:** `lib/features/onboarding/` (flow) + `lib/core/coach_marks/` (showcase infra) + a Settings tile to replay.

---

## Responsibilities (what this skill guarantees)

| # | Responsibility | How it's delivered |
|---|---|---|
| 1 | **Detect important features** | Derive coach targets from `docs/UX.md` primary actions + new-in-version features (see *Detecting features*). |
| 2 | **Auto-generate onboarding flow** | Scaffold a token-styled `PageView` intro from a page spec ([`onboarding_carousel.dart`](templates/onboarding_carousel.dart)). |
| 3 | **ShowcaseView / FeatureDiscovery impl** | Reusable showcase wrapper + global keys registry ([`showcase_setup.dart`](templates/showcase_setup.dart)). |
| 4 | **Track completion state** | Versioned, per-flow + per-tour flags persisted via Riverpod ([`onboarding_state.dart`](templates/onboarding_state.dart)). |
| 5 | **Show only on first launch** | Gate every flow/tour behind `isCompleted(...)`; auto-start once, never again. |
| 6 | **Allow replay from Settings** | A "Show app tour again" tile that clears flags and restarts ([`onboarding_settings_tile.dart`](templates/onboarding_settings_tile.dart)). |

---

## Package choice

- **Coach marks (default): [`showcaseview`](https://pub.dev/packages/showcaseview)** — mature, supports multi-step tours, tooltip positioning, scroll-into-view, custom widgets. Templates target it.
- **Alternative: `feature_discovery`** — Material "tap target" reveal animation; swap-in notes are in `showcase_setup.dart`.
- **Onboarding intro:** hand-rolled `PageView` (no dep, fully tokenized) — preferred over `introduction_screen` so it inherits the design system. The package is noted as a heavier option.

Add to `pubspec.yaml`: `showcaseview: ^4.0.0` and (already in house stack) `shared_preferences`, `flutter_riverpod`, `riverpod_annotation`.

---

## Detecting "important" features (Responsibility 1)

Don't guess — derive coach targets deterministically, in priority order:

1. **Primary actions from `docs/UX.md`** — every screen's "Key components" / primary CTA and each FAB is a candidate spotlight.
2. **Non-obvious gestures** — swipe-to-dismiss, long-press, pull-to-refresh: things with no visible affordance.
3. **New features by version** — diff this release's features vs the last onboarded version (the state is versioned); only spotlight what's *new* to a returning user.
4. **Analytics-informed (optional)** — if stage 23 analytics show a key action with low engagement, propose a coach mark for it.

Cap a single tour at **3–5 steps** (more is ignored). Order by importance, follow natural reading/tap flow, and never block the user from skipping.

---

## How completion state works (Responsibilities 4–6)

State is a small, **versioned** registry persisted in `shared_preferences`:

- Keys are namespaced: `onboarding.intro.v1`, `coach.home.v2`, `coach.checkout.v1`.
- `OnboardingController` exposes `isCompleted(id)`, `complete(id)`, `reset(id)`, `resetAll()`.
- **First launch** = no key present → auto-start the flow/tour once, then `complete()`.
- **Versioning** = bump the suffix (`home.v2`) when a screen changes enough to re-coach; returning users see only the new version, not the whole tour again.
- **Replay** = Settings tile calls `reset(...)` (one tour) or `resetAll()` then re-triggers on next visit.

This avoids the two classic bugs: re-showing a tour every launch, and *never* re-showing it after a redesign.

---

## Implementation steps

1. **Persist state** — drop [`onboarding_state.dart`](templates/onboarding_state.dart) into `lib/core/coach_marks/`; it wires a `sharedPreferencesProvider` + `OnboardingController` notifier.
2. **Wrap the app/screen** — put `ShowCaseWidget` above the subtree to be coached (see [`showcase_setup.dart`](templates/showcase_setup.dart)); register a `GlobalKey` per target in the keys registry.
3. **Author tours** — define a `CoachTour` (ordered list of step keys + tooltip copy) and start it via the controller, gated on `isCompleted`.
4. **Build onboarding intro** — scaffold pages with [`onboarding_carousel.dart`](templates/onboarding_carousel.dart); route to it from app start only when `!isCompleted('onboarding.intro.vN')` (wire in stage 07's redirect).
5. **Add replay** — drop [`onboarding_settings_tile.dart`](templates/onboarding_settings_tile.dart) into the Settings screen.
6. **Gate first-run auto-start** — start a screen's tour in `initState`/post-frame *only if* not completed; mark complete on finish.

---

## Wiring auto-start safely

Coach marks must start **after first frame** (targets must be laid out) and **only once**:

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final controller = ref.read(onboardingControllerProvider.notifier);
    if (!controller.isCompleted(HomeTour.id)) {
      ShowCaseWidget.of(context).startShowCase(HomeTour.keys);
    }
  });
}
```

Mark complete in `ShowCaseWidget(onFinish: ...)` → `controller.complete(HomeTour.id)`.

---

## Quality bar (Definition of Done)

- Tour/intro appears **exactly once** per version on a fresh install; never on subsequent launches.
- Every step is **skippable**; skipping marks the tour complete (no nagging).
- Replay from Settings works and re-shows from step 1.
- Tooltips use `AppTokens` (spacing, radius, motion) and theme colors — light **and** dark.
- Targets are real widgets (keys), scroll into view if off-screen, and respect `MediaQuery.disableAnimations` (reduce-motion).
- Coach copy is concise (≤ ~12 words/step), action-oriented, localized via stage 50 if i18n is present.
- State is versioned so a redesign can re-coach without replaying everything.

## Anti-patterns

- Showing the tour every launch (missing/incorrect persistence) — the #1 onboarding bug.
- Coaching everything → tour fatigue. Spotlight only the 3–5 that matter.
- Anchoring to a widget that may be absent/off-screen without a fallback.
- Starting the showcase before layout (null/zero-size target) — always post-frame.
- Blocking dismissal or hijacking back navigation.
- Hardcoding copy/colors instead of tokens + localization.

See templates in [`templates/`](templates/). Pairs with stages 03 (flows), 04 (tokens), 07 (first-run redirect), 08 (state), 23 (analytics-informed targeting).
