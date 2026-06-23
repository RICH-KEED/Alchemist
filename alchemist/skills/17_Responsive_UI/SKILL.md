---
name: Responsive UI
description: Make every screen adapt across phone, tablet, and foldable in both orientations — Material 3 window size classes + a breakpoint set, LayoutBuilder/MediaQuery, an adaptive navigation switch (NavigationBar ↔ NavigationRail ↔ extended rail/Drawer), and a list/detail (master-detail) layout. Use when the app must look right on large screens, when "make it responsive/adaptive", "tablet/foldable support", or "landscape layout" comes up, or when the orchestrator enters stage 17.
when_to_use: Trigger on "make it responsive", "support tablets / foldables", "large-screen layout", "two-pane / master-detail", "adaptive navigation", "handle landscape", or "the keyboard covers my field". Run after the build stages have screens to adapt and after stage 07 (Navigation) so this can host the nav shell. For the design tokens themselves go to stage 04; for golden tests across sizes, stage 20.
---

# Responsive UI (Stage 17)

You make the app **adapt** — not just shrink — across phones, tablets, and foldables in portrait and landscape. You add window size classes and breakpoints, swap the navigation affordance by size, promote single-pane flows to list/detail on big screens, and respect text scaling, safe areas, and the keyboard. Stay aligned with [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md) (§4: no hardcoded sizes — spacing comes from `AppTokens`).

**Output artifact:** `lib/core/responsive/*` (breakpoints, adaptive scaffold, list/detail) + adapted feature screens.
**Exit gate:** *phone / tablet / foldable + both orientations verified.*
**Consumes:** stage 04's `AppTokens` (spacing/radii), stage 07's `StatefulShellRoute` shell (this skill provides its chrome), stage 16's loading/empty/error states (rendered inside each pane).

---

## The process

1. **Adopt window size classes** — classify width into compact / medium / expanded ([`templates/breakpoints.dart`](templates/breakpoints.dart)). Branch on the class, never on raw pixels.
2. **Swap navigation by size** — drop in the [`AdaptiveScaffold`](templates/adaptive_scaffold.dart) to host the stage-07 shell: bottom bar → rail → extended rail.
3. **Promote flows to list/detail** — single-pane navigation on compact, side-by-side on expanded ([`templates/list_detail.dart`](templates/list_detail.dart)).
4. **Honor the system** — text scaling, `SafeArea`, display features (folds/cutouts), and keyboard insets.
5. **Verify the gate** — run the matrix in §8 across phone/tablet/foldable × portrait/landscape.

---

## 1. Window size classes & breakpoints

Material 3 defines **width** size classes; almost every adaptive decision keys off them. Use the official thresholds and put them in **one** place ([`templates/breakpoints.dart`](templates/breakpoints.dart)):

| Class | Width (logical px) | Typical device | Navigation |
|---|---|---|---|
| **compact** | `< 600` | phone portrait | bottom `NavigationBar` |
| **medium** | `600 – 839` | phone landscape, small tablet, foldable unfolded | collapsed `NavigationRail` |
| **expanded** | `>= 840` | tablet, foldable open landscape, desktop | extended rail / `NavigationDrawer`, list/detail |

```dart
WindowSize sizeForWidth(double w) => w < 600
    ? WindowSize.compact
    : w < 840
        ? WindowSize.medium
        : WindowSize.expanded;
```

Branch on `context.windowSize`, **never** `if (width < 375)`-style magic numbers in feature code. A breakpoint change must be a single edit in `Breakpoints`.

---

## 2. `LayoutBuilder` vs `MediaQuery` — pick the right tool

They answer different questions:

- **`MediaQuery`** describes the **whole window** — size, orientation, `textScaler`, `padding`/`viewPadding` (status bar, notches, gesture areas), and `viewInsets` (the keyboard). Use it for **app-level** decisions: which nav affordance the scaffold shows.
- **`LayoutBuilder`** gives the **constraints of the box your widget actually got**. Use it for a widget that must adapt to its slot — a card in a grid, a pane inside a split. Inside the detail pane, `MediaQuery.sizeOf(context).width` is the *window*, not your pane; only `LayoutBuilder` knows the pane is narrow.

Rule of thumb: **window-level → `MediaQuery` (`context.windowSize`); component-level → `LayoutBuilder` (`ResponsiveBuilder`).** The templates do exactly this — `AdaptiveScaffold` reads `context.windowSize`; `ListDetailLayout` and `ResponsiveBuilder` read incoming constraints.

Use the granular `MediaQuery.sizeOf` / `MediaQuery.orientationOf` accessors (not `MediaQuery.of(context)`) so a widget only rebuilds when the property it reads changes.

---

## 3. Responsive vs adaptive

- **Responsive** = the *same* layout fluidly reflows (a grid goes 1→2→3 columns, paddings grow). Use `responsiveValue(context, compact: 1, medium: 2, expanded: 3)` or `Wrap`/`Flexible`/`FractionallySizedBox`.
- **Adaptive** = a *different* layout/affordance per class (bottom bar vs rail; single-pane vs two-pane; `CupertinoSwitch` vs `Switch` per platform). Use `ResponsiveBuilder` or `switch (context.windowSize)`.

Most premium screens use **both**: adaptive chrome (nav + panes) wrapping responsive content (reflowing grids, growing gutters). Don't fork into two unmaintained widget trees when a value swap would do.

---

## 4. The canonical adaptive navigation switch

One `AdaptiveScaffold` ([`templates/adaptive_scaffold.dart`](templates/adaptive_scaffold.dart)) renders the right chrome for the size, hosting the **stage-07** `StatefulShellRoute.indexedStack` as its `body`:

| Window size | Affordance |
|---|---|
| compact | bottom `NavigationBar` |
| medium | collapsed `NavigationRail` (icons + short labels) |
| expanded | **extended** `NavigationRail` (labelled) or `NavigationDrawer` for many destinations |

Wire it to the shell — same destinations, same body, only the chrome changes:

```dart
StatefulShellRoute.indexedStack(
  builder: (context, state, shell) => AdaptiveScaffold(
    destinations: kDestinations,
    selectedIndex: shell.currentIndex,
    onDestinationSelected: shell.goBranch, // preserves per-tab state (stage 07)
    body: shell,
  ),
  branches: [/* Home, Items, Profile ... */],
);
```

This replaces stage 07's `ScaffoldWithNavBar` — it *is* the large-screen version of it. On rail layouts, hoist the FAB into the rail's leading slot (M3 convention); the template does this. For 5+ destinations on expanded, prefer a `NavigationDrawer` over a crowded rail.

---

## 5. List/detail (master-detail)

The signature large-screen win: a list that *navigates* on phones becomes a list that *populates a detail pane* on tablets. [`ListDetailLayout`](templates/list_detail.dart) keeps one selection state and branches presentation off the **pane's** width:

- **compact** → list fills the screen; a tap calls `onNavigateToDetail` → `context.goNamed(itemDetail, …)` (a real route, so back works and deep links land).
- **expanded** → list (fixed ~360px column) + detail side-by-side; a tap calls `onSelect` to update in-place selection.

```dart
ListDetailLayout(
  selectedId: state.selectedId,
  onSelect: controller.select,                       // two-pane
  onNavigateToDetail: (id) =>                          // single-pane
      context.goNamed(AppRoute.itemDetail.name, pathParameters: {'id': id}),
  list: (context, onTap) => ItemList(onTap: onTap),
  detail: (context, id) => id == null
      ? const SelectSomethingPlaceholder()
      : ItemDetail(id: id),
);
```

Each pane still renders all four async states (loading/data/empty/error) from **stage 16** — a half-loaded detail pane is not done.

---

## 6. Foldables, dual-screen, safe areas

- **Wrap content in `SafeArea`** so status bars, notches, and gesture insets never clip it. The templates wrap their bodies in `SafeArea`.
- **Display features.** Foldables and dual-screens expose hinges/cutouts via `MediaQuery.displayFeaturesOf(context)`. For a true hinge-aware split, place panes either side of the fold bounds (the `dual_screen`/`TwoPane` package wraps this); at minimum, don't paint critical UI under a hinge.
- **Posture.** Unfolded inner displays read as **medium/expanded** by width, so the size-class switch already promotes nav + panes correctly when a device unfolds — no extra branching for the common case.

---

## 7. Honor text scaling & never hardcode sizes

- **Respect `textScaler`.** Users set system font size up to ~2x. Don't pass a fixed `fontSize` that ignores it, and don't cap it without a real reason. Test at large scale: text must wrap, not clip. Let rows grow vertically (`Wrap`, `IntrinsicHeight`, or scrollable bodies) instead of overflowing.
- **Spacing/radii from `AppTokens`** (stage 04): `context.tokens.spacing.md`, never `EdgeInsets.all(16)`. The templates note where to swap inline literals for tokens.
- **Keyboard insets.** When the soft keyboard opens, `MediaQuery.viewInsetsOf(context).bottom` is its height. Keep `Scaffold.resizeToAvoidBottomInset: true` (default) and wrap forms in a `SingleChildScrollView` so fields scroll above the keyboard. For a button pinned above the keyboard, pad by `viewInsets.bottom`.
- **Min 48dp touch targets** (§4) at every size; rails and bars already satisfy this — keep it for custom controls.

---

## 8. Testing across sizes (exit gate)

Make "looks right everywhere" mechanical — don't eyeball one emulator:

- **In-widget:** pump under a forced size with `tester.view.physicalSize` / `devicePixelRatio` (or wrap in a sized `MediaQuery`) and assert the right affordance renders — `NavigationBar` at 400px width, `NavigationRail` at 700px, extended rail + two panes at 1000px.
- **Orientation:** repeat at a landscape aspect; assert no overflow (no `RenderFlex overflowed` in the test log).
- **Text scale:** wrap in `MediaQuery(textScaler: TextScaler.linear(2.0))` and assert no overflow / key text still finds by `find.text`.
- **Goldens across sizes** belong to **stage 20** — generate a golden per device class so regressions are visible. `device_preview` is handy for manual sweeps during dev.

Walk the matrix before claiming the gate: **phone-portrait, phone-landscape, tablet-portrait, tablet-landscape, foldable-unfolded** — each renders correct nav, no clipping, no overflow, keyboard-safe forms.

---

## Anti-patterns

- **Fixed widths/heights** (`width: 400`) that break on small phones and waste space on tablets — use `Expanded`/`Flexible`/`FractionallySizedBox` and token spacing.
- **Assuming phone** — bottom bar only, single column forever; tablets get a stretched phone UI.
- **Ignoring keyboard insets** — fields hidden behind the keyboard because the form isn't scrollable and `resizeToAvoidBottomInset` was turned off.
- **Not handling landscape** — content overflows or wastes the width; verticality assumed.
- **Branching on `MediaQuery` width inside a pane** — reports the window, not the pane; use `LayoutBuilder` there.
- **Suppressing `textScaler`** to "keep the design" — clips accessible text; design for growth instead.
- **Two divergent trees** for phone vs tablet that drift out of sync — share content, swap only chrome/panes.

---

## Exit gate (must pass before stage 18)

- [ ] Window size classes + breakpoints live in `lib/core/responsive/breakpoints.dart`; no magic-number width checks in features.
- [ ] Navigation adapts: bottom `NavigationBar` (compact) → `NavigationRail` (medium) → extended rail/`NavigationDrawer` (expanded), hosting the stage-07 shell with preserved tab state.
- [ ] At least one list/detail flow is single-pane on compact (real route) and two-pane on expanded.
- [ ] `SafeArea` applied; foldable/cutout insets don't clip content.
- [ ] No hardcoded sizes — spacing/radii from `AppTokens`; layouts survive `textScaler` up to 2x with no overflow.
- [ ] Forms stay usable with the keyboard open (scrollable, `resizeToAvoidBottomInset`).
- [ ] Verified across **phone / tablet / foldable + both orientations** (size + orientation + text-scale tests pass; goldens deferred to stage 20).

When green, record `lib/core/responsive/*` in `.flutter-pipeline/STATE.md` and advance to **stage 18 (Documentation)**.
