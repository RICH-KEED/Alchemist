---
name: Screenshot To Widget
description: Reconstruct an editable Flutter widget tree from a screenshot of any app — map visual elements to project design tokens and produce compilable, themed Dart widgets. Use when you have a screenshot of a UI you want to reproduce in Flutter, or when asked to "recreate this screen", "copy this design", "widget from screenshot".
when_to_use: Trigger on "recreate this screen from a screenshot", "turn this screenshot into Flutter", "clone this UI", "build this screen I'm showing you", or whenever a screenshot/image of a UI is provided as the primary input. Works from any app screenshot — iOS, Android, web, or a design mock exported as PNG.
---

# Screenshot To Widget

You reconstruct a **compilable Flutter widget tree** from a screenshot of any app. You map every visual element to the project's design tokens — spacing scale, color roles, typography roles, corner radii — so the output is not a hardcoded clone but a **theme-aware, editable, premium** widget that belongs in the project's design system.

House style is law: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md) §4 (widget hygiene). The token contract you build against belongs to [skill 04 Premium_Design_System](../04_Premium_Design_System/SKILL.md) — read it before starting.

---
## When this skill applies

- You have a **screenshot** (PNG/JPEG) of a screen — from any app, any platform.
- The goal is a **reconstruction**, not a pixel-perfect clone. The output uses the *project's* tokens, not the source app's.
- You are producing Flutter Dart code, not a `.pen` design file (that's skill 05).

---
## Step 1 — Load the token contract

Read the project's theme files before analyzing the screenshot:

1. `lib/app/theme/app_tokens.dart` — spacing scale (4/8-based), radii, elevations, durations.
2. `lib/app/theme/color_schemes.dart` — the light + dark color roles.
3. `lib/app/theme/typography.dart` — the TextTheme roles.

If these do not exist, STOP — you cannot produce token-aware widgets without tokens. Route to skill 04 first.

---
## Step 2 — Decompose the screenshot

Analyze the screenshot element by element. Follow [`templates/reconstruction_approach.md`](templates/reconstruction_approach.md) for the systematic method. For each region, answer:

1. **What widget?** — Identify the structural widget (Scaffold, AppBar, ListView, Card, BottomNavigationBar, Chip, FAB, etc.).
2. **What tokens?** — Map every visual property to a token:
   - Size/spacing → `AppTokens.spacing` scale (xs4, sm8, md16, lg24, xl32, xxl48).
   - Color → `ColorScheme` role (primary, surface, onSurface, etc.), not a hex literal.
   - Typography → `TextTheme` role (headlineMedium, titleLarge, bodyMedium, labelSmall, etc.).
   - Radius → `AppTokens.radius` scale (sm8, md12, lg16, xl24, pill).
   - Elevation → `AppTokens.elevation` scale.
   - Duration → `AppTokens.motion` durations.
3. **What's the layout?** — Row, Column, Stack, GridView, Sliver? What are the cross-axis constraints?
4. **State surface:** loading skeleton shape, empty state illustration area, error state placement — note all four per [skill 16 Loading_States](../16_Loading_States/SKILL.md).

---
## Step 3 — Produce the widget tree

Write the Dart code. Rules:

- Every widget gets `const` where possible; keys on list items.
- Colors/sizes/radii from tokens; **zero hardcoded values** (no `Color(0xFF...)`, no `EdgeInsets.all(13)`, no `BorderRadius.circular(9)`).
- Extract reusable pieces into named widget classes — no `_buildX()` methods.
- Include all four async states (loading/data/empty/error) per CONVENTIONS §4.
- Light + dark must both work from the token mapping.
- `flutter analyze` clean under `very_good_analysis` (run skill 41 if needed).

---
## Step 4 — Verify

After writing the widget tree:

1. **Token audit** — grep the output for `Color(`, `EdgeInsets.all(`, `BorderRadius.circular(`, `TextStyle(` — if any appear, fix them to tokens.
2. **Analyze pass** — `flutter analyze` must be zero.
3. **Dark mode check** — mentally verify every color comes from `ColorScheme`, which auto-adapts to dark.
4. **Spacing scale check** — every gap/padding must land on {4,8,12,16,24,32,48}.

---
## Limitations (be honest)

- You cannot see the source app's actual code — you are **reconstructing intent**, not decompiling. Subtle behaviors (scroll physics, gesture disambiguation, custom painters) are guesses unless the screenshot makes them obvious.
- Icons are mapped to the closest Material Icon; if the source uses a custom icon set, note it and use the nearest equivalent.
- Animations and transitions are invisible in a screenshot — document them as [ANIMATION NEEDED] placeholders.
- Complex custom painters (charts, path-based illustrations) get a `CustomPaint` stub with a comment describing the observed shape.

---
## Cross-references

- **04 Premium_Design_System** — token contract you build against. Must exist before this skill.
- **16 Loading_States** — the four-state pattern for every data surface.
- **05 App_Preview** — mock up a screen in .pen (design-first); this skill goes screenshot → widget instead.
- **43 Design_Critic** — after building the widget, run this to verify it looks premium.

See the full reconstruction method in [`templates/reconstruction_approach.md`](templates/reconstruction_approach.md).
