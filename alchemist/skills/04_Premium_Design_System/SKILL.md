---
name: Premium Design System
description: Build a premium Material 3 design system from a PRD/UX — define design tokens (color, type, spacing, radii, elevation, motion), wire them into ThemeData + a custom AppTokens ThemeExtension for light & dark, and mock the kit in a .pen file. Use when starting visual design, setting up theming, defining tokens, or when a screen "looks generic" and needs a cohesive premium look.
when_to_use: Trigger on "set up the theme", "design system", "design tokens", "make it look premium/polished", "light and dark mode", "ColorScheme", "ThemeData", or stage 04 of the pipeline. This stage owns lib/app/theme/* and the .pen design kit. If you only need a single widget styled, style it against the existing tokens instead of re-running this stage.
---

# Premium Design System

Stage **04** of the [24-stage pipeline](../../references/PIPELINE.md). You turn the PRD and UX map into a **premium, token-driven Material 3 theme**: a single seed-driven palette, semantic colors, a typographic scale, and a spacing/radii/elevation/motion system — encoded as `ThemeData` (light + dark) plus an `AppTokens` `ThemeExtension`. You also mock the kit as a `.pen` file so stakeholders can see it.

House style is law: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md). **Code is the source of truth; the `.pen` kit is the visual reference.**

**Exit gate:** tokens compile (`flutter analyze` clean), light **and** dark are both defined, and component specs (buttons, cards, inputs, app bar) exist.

### 🎨 Picking a visual style

This skill pulls from the **[UI Style Taxonomy](../../references/UI_STYLE_TAXONOMY.md)** — a catalog of 140+ visual design styles grouped by domain and implementation tier. Use it to match the app's vibe:

- If the user names a style ("cyberpunk", "glassmorphism", "bento"), look it up in the taxonomy → translate its key traits into M3 token values.
- If no style is named, infer from app domain: fintech → **Fintech UI** (dark + trust blue), health → **Health & Wellness UI** (calm green + soft radius), SaaS → **SaaS UI** (blue/indigo + sidebar), creative → **Swiss Design** or **Bauhaus**.
- The taxonomy maps every style to concrete token overrides: seed color, radius set, spacing scale, type scale, motion curve. There is no "custom style" — every aesthetic compiles to `ThemeData` + `AppTokens` in the end.
- Tier 3+ styles (Cyberpunk, Neumorphism, Holographic) need `CustomPaint`/`BackdropFilter` → warn the user and offer the nearest T1/T2 approximation as a fast alternative.

When processing app DNA from `/initialize`, the visual direction question feeds directly into this catalog lookup.

---

## What "premium" actually means

Premium is not more decoration — it is **discipline**. Six principles drive every decision here:

1. **Restraint.** One seed color, a tight semantic palette, ≤2 typefaces. No rainbow of ad-hoc hexes. If a color isn't in the scheme or `AppTokens`, it doesn't exist.
2. **Strong hierarchy.** Size, weight, and color carry meaning. A screen should read in one glance: one primary action, clear headings, muted secondary text (`onSurfaceVariant`).
3. **Generous spacing.** Premium UIs breathe. Lean on the upper half of the 4/8 spacing scale; whitespace is a feature, not waste.
4. **Purposeful depth.** Elevation communicates layering, not flashiness. M3 prefers tonal surface tints over heavy shadows — keep elevation low and consistent (0/1/3/6/8/12 dp).
5. **Consistent motion.** Every transition uses the same small set of durations and curves. Motion confirms cause→effect; it never decorates.
6. **Single source of palette.** `ColorScheme.fromSeed` generates a harmonious, accessible palette for light and dark. Tweak deliberately, never randomly.

A premium system is **boring to describe and delightful to use** — its power is consistency.

---

## Token taxonomy

Split tokens by what Material 3 already models vs. what it doesn't:

| Category | Lives in | Notes |
|---|---|---|
| **Color (roles)** | `ColorScheme` (M3) | `primary`, `secondary`, `tertiary`, `surface`, `error`, their `on*` + container variants. Generated from one seed. |
| **Color (semantic)** | `AppTokens` | `success`, `warning`, `info` (+ `on*`) — M3 has no role for these. |
| **Typography** | `TextTheme` (M3) | display / headline / title / body / label — 15 styles from one font scale. |
| **Spacing** | `AppTokens.spacing` | 4/8 scale: `xs 4, sm 8, md 16, lg 24, xl 32, xxl 48`. |
| **Radii** | `AppTokens.radius` | `sm 8, md 12, lg 16, xl 24, pill 999`. |
| **Elevation** | `AppTokens.elevation` | `level0..level5` → `0,1,3,6,8,12`. |
| **Motion** | `AppTokens.motion` | durations (`fast 120ms, medium 240ms, slow 400ms`) + curves (`standard`, `emphasized`). |

Rule of thumb: **if Material 3 has a role for it, use the role.** Only reach into `AppTokens` for things M3 doesn't model.

---

## How the theme is built (code is truth)

The deliverable is `lib/app/theme/`:

```
lib/app/theme/
├── theme.dart            # lightTheme / darkTheme — assembles everything
├── color_schemes.dart    # ColorScheme.fromSeed (light+dark) + semantic colors
├── app_tokens.dart       # ThemeExtension<AppTokens>: spacing/radii/elevation/motion/semantics
└── typography.dart        # Material 3 TextTheme from the chosen font scale
```

Copy the [`templates/`](templates) here and adjust the seed + font. The pieces:

### 1. Seed → ColorScheme (light + dark)

```dart
static const seed = Color(0xFF4F46E5); // indigo — pick from brand/PRD
final lightScheme = ColorScheme.fromSeed(seedColor: seed); // brightness: light by default
final darkScheme  = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);
```

One seed yields a balanced, WCAG-aware palette for both modes. See [`templates/color_schemes.dart`](templates/color_schemes.dart).

### 2. Non-M3 tokens → `AppTokens` ThemeExtension

`AppTokens` carries everything M3 doesn't. It implements `copyWith` + `lerp` (so it animates across theme changes) and ships `light`/`dark` factories. See [`templates/app_tokens.dart`](templates/app_tokens.dart). Access it anywhere:

```dart
final tokens = Theme.of(context).extension<AppTokens>()!;
Padding(padding: EdgeInsets.all(tokens.spacing.md), child: ...);
```

> Add a tiny extension `BuildContext.tokens => Theme.of(this).extension<AppTokens>()!` in your widgets so usage reads `context.tokens.spacing.md`.

### 3. Typography → `TextTheme`

A Material 3 `TextTheme` mapping the 15 roles to one font scale (placeholder: **Inter** via `google_fonts`). See [`templates/typography.dart`](templates/typography.dart).

### 4. Component themes (the specs)

Don't restyle widgets ad-hoc — set defaults once in `ThemeData` so every button/card/field is consistent. The template wires:

- `FilledButtonThemeData` / `ElevatedButtonThemeData` / `OutlinedButtonThemeData` — height ≥48dp, `radius.md`, label = `labelLarge`.
- `CardTheme` — `elevation.level1`, `radius.lg`, surface tint on.
- `InputDecorationTheme` — filled, `radius.md`, consistent content padding, error uses `colorScheme.error`.
- `AppBarTheme` — `elevation.level0`, centered title = `titleLarge`, surface color.

These **are** the component specs the exit gate asks for. Assembled in [`templates/theme.dart`](templates/theme.dart).

---

## The Pencil workflow (visual reference)

A **Pencil MCP** is connected now. Use it to mock the kit so stakeholders see the system — but the `.pen` is downstream of the code tokens, never the reverse.

1. `get_editor_state({ include_schema: true })` — learn the schema before any other Pencil call.
2. `get_guidelines({ category: "style" })` — browse style archetypes; pick one matching the PRD's tone.
3. **Mirror your tokens into `.pen` variables** with `set_variables` — same names as `AppTokens`/scheme roles (`primary`, `surface`, `spacing-md`, `radius-lg`, `success`…). This keeps the kit and code in lockstep.
4. `batch_design` — lay out a **design-kit page**: a color swatch row, a type-scale specimen, and a component sheet (buttons in each state, a card, a text field, an app bar) in both light and dark frames.
5. `get_screenshot` on the kit frame to verify, then `export_nodes` (PNG) into `previews/` for stage 05 sign-off.

**If a Google Stitch MCP is connected**, you may instead prompt Stitch (prompt→UI) to generate screen mockups from the UX, then reconcile its output back to your tokens. Otherwise Pencil is the path. Either way: extract the agreed values, then **hand-write them into the Dart tokens** — generated design output is a reference, not the committed theme.

### Tokens ↔ Flutter mapping

| `.pen` variable | Dart home |
|---|---|
| `primary`, `surface`, `error`, `on*`… | `ColorScheme` role |
| `success` / `warning` / `info` | `AppTokens` semantic color |
| `spacing-*`, `radius-*` | `AppTokens.spacing` / `.radius` |
| `font-display`, `font-body` | `typography.dart` font scale |
| `elevation-*` | `AppTokens.elevation` |

---

## Design review rubric (premium bar)

Before you pass the gate, check every box:

- [ ] **One seed**, one (max two) typeface; zero stray hex literals in widget code.
- [ ] Light **and** dark both look intentional — not an auto-inverted afterthought. Contrast ≥ 4.5:1 for body text in both.
- [ ] Type scale has clear jumps; body is 14–16sp, line height comfortable (~1.4–1.5).
- [ ] Spacing follows the 4/8 scale; primary content has generous margins (≥`spacing.md`, often `lg`).
- [ ] Touch targets ≥ 48dp; one obvious primary action per screen.
- [ ] Elevation is low and consistent; depth reads as layering, not drop-shadow noise.
- [ ] Motion uses only the defined durations/curves.
- [ ] Semantic colors (success/warning/info) are distinguishable in both modes and not relied on by color alone (pair with icon/label for a11y).
- [ ] `flutter analyze` is clean under `very_good_analysis`.

---

## Hand-off

This stage produces the visual contract every later UI stage consumes:

- **05 App_Preview** — renders the widget gallery / mockups from these tokens for sign-off.
- **06 Flutter_Architecture** — wires `lightTheme`/`darkTheme` into `MaterialApp.router`.
- **16 Loading_States** — skeleton/shimmer colors come from `colorScheme.surfaceContainerHighest` + `AppTokens` durations.
- **17 Responsive_UI** — breakpoint spacing scales off `AppTokens.spacing`.

Record the artifact in `.flutter-pipeline/STATE.md`: `04 → lib/app/theme/ + previews/`. Never let a downstream stage hardcode a color or size — send it back here.
