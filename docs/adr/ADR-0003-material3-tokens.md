# ADR-0003: Material 3 + ThemeExtension Tokens for Design

## Status
Accepted (2026-06-21)

## Context
We needed a design-system foundation that is:

- Premium-looking (skill 04)
- Themeable with light + dark as first-class
- Tokenized so colors, spacing, and typography are centrally controlled
- Compatible with Figma exports (skill 46) and visual regression (skill 44)

Options:
1. **Material 3 + ThemeExtension** — native Flutter theming, `ColorScheme.fromSeed`,
   custom `ThemeExtension<T>` classes for brand tokens.
2. **Raw InheritedWidgets** — hand-rolled, maximum control, no framework dependency.
3. **Third-party design systems** — external package dependency.

## Decision
We chose **Material 3 + ThemeExtension tokens** because:

- `ColorScheme.fromSeed` generates a harmonious color ramp from a single brand color.
- `ThemeExtension<T>` lets us add custom design tokens (spacing scale, radii,
  durations, brand-specific colors) that participate in `Theme.of(context)`.
- Light + dark themes are automatically handled with `ThemeData` overrides.
- Accessibility (high contrast, text scaling) is built into M3 and requires
  zero extra work.
- Works with Figma dev-mode exports (skill 46 bridge).
- Golden-image tests (skill 44) can compare Widget trees against theme snapshots.

## Consequences

- Skill 04 (Premium Design System) codifies the `AppTokens` ThemeExtension class.
- Skill 43 (Design Critic) audits widget trees for hardcoded colors/sizes.
- All scaffolded widgets reference `Theme.of(context).colorScheme` and
  `AppTokens.of(context)` — never raw values.
- The spacing scale is 4/8-based; minimum touch target is 48dp.
