---
name: Figma Bridge
description: Import Figma frames, variables, text styles, and auto-layout metadata — map them onto the project's design tokens (ColorScheme + AppTokens from skill 04), then emit a token mapping document and optional Flutter widget stubs. Use when connecting a Figma file to a Flutter codebase, translating Figma variables to ThemeExtension properties, generating a token map from a Figma export, or onboarding new screen designs from Figma into the pipeline.
when_to_use: Trigger on "import Figma design", "map Figma tokens to Flutter", "connect Figma to the design system", "generate widgets from Figma", "Figma to code", "convert Figma variables to AppTokens", "bridge Figma and Flutter", or when stage 04 (Premium Design System) tokens exist and new Figma frames need to land as Dart widgets without raw hex values. Defer to #04 directly if no token system exists yet — this skill assumes AppTokens is already wired.
---

# Figma Bridge (Roadmap #46)

Bridge Figma design data into a Flutter codebase by mapping every Figma variable,
style, and layout primitive onto the project's **existing** design tokens — the
`ColorScheme` and `AppTokens` ThemeExtension owned by
[#04 Premium Design System](../04_Premium_Design_System/SKILL.md). This skill never
emits raw hex, never skips dark mode, and never creates ad-hoc styling.

House style: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).

---

## 1. Two input modes

| Mode | Source | Fidelity | Use when |
|---|---|---|---|
| **Figma MCP** (ideal) | Connected Figma MCP server — direct variable/style/component queries | Full: variable bindings, component hierarchy, auto-layout values | Figma MCP is configured and authorized |
| **JSON export** (fallback) | Figma file exported via plugin or REST API (`/v1/files/...` or `/v1/variables/...`) | Reduced: raw values, style names, node tree — no live bindings | No MCP connected; working from an export snapshot |

Both modes feed the same mapping pipeline. The MCP path is richer because it
preserves variable references and component semantics; the JSON path treats every
value as a literal and depends on naming conventions for mapping.

---

## 2. Mapping pipeline

```
Figma source          Token resolution        Flutter output
───────────────       ─────────────────       ──────────────
Variable / style  ──► AppTokens property  ──► ThemeExtension value
Color fill        ──► ColorScheme role     ──► Theme.of(context).colorScheme.X
Text style        ──► TextTheme role       ──► Theme.of(context).textTheme.X
Auto-layout gap   ──► AppTokens.spacing    ──► context.tokens.spacing.X
Auto-layout pad   ──► AppTokens.spacing    ──► EdgeInsets.all(tokens.spacing.X)
Corner radius     ──► AppTokens.radius     ──► tokens.radius.X
Effect (shadow)   ──► AppTokens.elevation  ──► tokens.elevation.levelN
Component         ──► Flutter widget       ──► FilledButton / Card / ...
```

Every mapping resolves to a **symbolic token reference**, never a hardcoded value.
A Figma color `#4F46E5` never appears in Dart — it resolves to `colorScheme.primary`
or a matching `AppTokens` semantic color, or it is flagged as unmatched.

---

## 3. Color mapping

Match Figma color style / variable names against the token catalogue. The naming
convention follows skill 04's taxonomy:

| Figma variable / style name | Maps to | Example Dart usage |
|---|---|---|
| `color/surface/primary` | `ColorScheme.primary` | `colorScheme.primary` |
| `color/surface/on-primary` | `ColorScheme.onPrimary` | `colorScheme.onPrimary` |
| `color/surface/primary-container` | `ColorScheme.primaryContainer` | `colorScheme.primaryContainer` |
| `color/surface/secondary` | `ColorScheme.secondary` | `colorScheme.secondary` |
| `color/surface/tertiary` | `ColorScheme.tertiary` | `colorScheme.tertiary` |
| `color/surface/error` | `ColorScheme.error` | `colorScheme.error` |
| `color/surface/surface` | `ColorScheme.surface` | `colorScheme.surface` |
| `color/surface/on-surface` | `ColorScheme.onSurface` | `colorScheme.onSurface` |
| `color/surface/surface-variant` | `ColorScheme.surfaceVariant` | `colorScheme.surfaceVariant` |
| `color/surface/outline` | `ColorScheme.outline` | `colorScheme.outline` |
| `color/semantic/success` | `AppTokens.semantic.success` | `context.tokens.semantic.success` |
| `color/semantic/warning` | `AppTokens.semantic.warning` | `context.tokens.semantic.warning` |
| `color/semantic/info` | `AppTokens.semantic.info` | `context.tokens.semantic.info` |
| `color/background/scrim` | `ColorScheme.scrim` | `colorScheme.scrim` |
| `color/background/shadow` | `ColorScheme.shadow` | `colorScheme.shadow` |

**Fuzzy matching** (try in order): strip separators + lowercase match → substring containment → hex delta ≤2%. If still unmatched, **flag it** as a gap.

**Rule**: no token match is a blocker — do not guess or pick the "closest" hex. Add a token via skill 04 or ask the designer to re-bind.

---

## 4. Typography mapping

Figma text styles map to Material 3 `TextTheme` roles. The naming convention:

| Figma text style name | TextTheme role | Typical usage |
|---|---|---|
| `display/large` | `displayLarge` | Hero / splash |
| `display/medium` | `displayMedium` | — |
| `display/small` | `displaySmall` | — |
| `headline/large` | `headlineLarge` | Screen title |
| `headline/medium` | `headlineMedium` | Section header |
| `headline/small` | `headlineSmall` | Card title |
| `title/large` | `titleLarge` | AppBar, dialog title |
| `title/medium` | `titleMedium` | List tile title |
| `title/small` | `titleSmall` | Subhead |
| `body/large` | `bodyLarge` | Primary body |
| `body/medium` | `bodyMedium` | Secondary body |
| `body/small` | `bodySmall` | Caption body |
| `label/large` | `labelLarge` | Button text |
| `label/medium` | `labelMedium` | Tab label |
| `label/small` | `labelSmall` | Overline / chip |

Extract `fontSize`, `fontWeight`, `letterSpacing`, `lineHeight` from the Figma
style and compare against the Dart `TextTheme` definitions. Flag any deviation
exceeding 1sp or 50 weight units — it may indicate a missing custom style.

---

## 5. Spacing & layout mapping

Figma auto-layout values (gap, horizontal padding, vertical padding) map to the
4/8-based `AppTokens.spacing` scale:

| Figma value (dp) | Nearest token | Dart usage |
|---|---|---|
| 4 | `spacing.xs` | `tokens.spacing.xs` |
| 8 | `spacing.sm` | `tokens.spacing.sm` |
| 12 | N/A — flag | Split into 8+4 or add `semiMd` token |
| 16 | `spacing.md` | `tokens.spacing.md` |
| 24 | `spacing.lg` | `tokens.spacing.lg` |
| 32 | `spacing.xl` | `tokens.spacing.xl` |
| 48 | `spacing.xxl` | `tokens.spacing.xxl` |

**Tolerance**: round to the nearest token if within 1dp. Values that fall outside
the scale by more than 1dp are flagged for designer review — the spacing scale is
intentional, and ad-hoc values erode consistency.

Corner radii follow the same pattern against `AppTokens.radius` (sm/md/lg/xl/pill).

---

## 6. Effect → elevation mapping

Figma shadow/ blur effects map to `AppTokens.elevation`:

| Figma effect | Likely elevation | Notes |
|---|---|---|
| No shadow, flat | `level0` (0) | Default surface |
| Subtle drop shadow (blur ≤4) | `level1` (1) | Cards, raised surfaces |
| Light shadow (blur 6–10) | `level2` (3) | Elevated button, FAB rest |
| Medium shadow (blur 12–20) | `level3` (6) | Dialogs, bottom sheets |
| Heavy shadow (blur 24–40) | `level4` (8) | Drawer / nav rail |
| Very heavy (blur 48+) | `level5` (12) | Modals, full-screen overlays |

M3 prefers tonal surface tints over heavy shadows — if Figma uses aggressive drop
shadows, prefer `level1` or `level2` and use surface tint instead.

---

## 7. Component mapping (Figma → Flutter)

When a Figma frame or component has a recognizable counterpart, emit a widget
stub using token bindings:

| Figma component | Flutter widget | Key token bindings |
|---|---|---|
| Button / primary | `FilledButton` | `colorScheme.primary`, `tokens.radius.md`, `tokens.spacing.sm` (inner pad) |
| Button / secondary | `OutlinedButton` | `colorScheme.outline`, `tokens.radius.md` |
| Button / tertiary | `TextButton` | `colorScheme.primary` |
| Card | `Card` | `tokens.elevation.level1`, `tokens.radius.lg` |
| Text field | `TextField` / `TextFormField` | `InputDecorationTheme` defaults from theme.dart |
| App bar | `AppBar` | `tokens.elevation.level0`, `textTheme.titleLarge` |
| List / table | `ListView` / `DataTable` | `tokens.spacing.md` padding |
| Chip | `Chip` / `FilterChip` | `colorScheme.secondaryContainer` |
| Bottom nav | `NavigationBar` | `colorScheme.surface`, `tokens.elevation.level2` |

The widget stub includes the token references but **not** business logic or state
wiring — those belong to later pipeline stages (08 Riverpod, 09 Animation, etc.).

---

## 8. Outputs

After mapping, produce these artifacts:

| Artifact | Format | Required | Contents |
|---|---|---|---|
| **Token map document** | Markdown | Always | Every Figma variable/style → token resolution, with match confidence and unmatched gaps (see `templates/figma_to_token_map.md`) |
| **ThemeExtension update** | Dart diff | If new tokens found | Add any new semantic colors or spacing/radius values discovered in Figma but missing from `AppTokens` |
| **Widget stubs** | `.dart` files (optional) | On request | One widget class per Figma frame/component, with token bindings, no logic |

---

## 9. Guardrails

These are non-negotiable — the same discipline that skill 04 enforces:

- **Never emit raw hex.** Every color resolves to a `ColorScheme` role or
  `AppTokens` semantic color. Unmatched colors are blocked, not guessed.
- **Never skip dark mode.** For every token mapping, confirm the dark-variant
  equivalent exists. If Figma only has light frames, derive dark tokens from
  `ColorScheme.fromSeed(brightness: Brightness.dark)`.
- **Flag, don't silently ignore.** Unmatched tokens appear in the map document
  with a `GAP` marker and a suggested resolution.
- **Spacing is the 4/8 scale.** Values off the scale are flagged. The scale is
  intentional — ad-hoc spacing erodes the design system.
- **Use context tokens, not direct hex.** Every emitted widget stub must access
  colors via `Theme.of(context).colorScheme` and spacing via
  `Theme.of(context).extension<AppTokens>()`.
- **One source of truth.** The Dart tokens in `lib/app/theme/` are authoritative.
  If Figma disagrees, the token map flags the discrepancy — do not silently
  override code from design.

---

## 10. Procedure

**Figma MCP path** (ideal — variable bindings preserved):
1. **Connect** — confirm Figma MCP is available; list variable collections, text styles, components.
2. **Extract** — pull variable definitions (names, values, modes) and style definitions.
3. **Select** — identify target frames; walk the node tree for fill/stroke/text/auto-layout properties.
4. **Map** — resolve every property against the token catalogue (§3–§6); populate the token map document.
5. **Generate** — optionally emit widget stubs (§7).
6. **Validate** — check all guardrails (§9); confirm light + dark coverage.

**JSON export path** (fallback — naming conventions carry the mapping):
1. **Export** — Figma plugin (Design Tokens, Variables Export) or REST API → variables + node JSON.
2. **Parse** — walk `children`; extract `fills`, `strokes`, `effects`, `style`, `layoutMode`, `itemSpacing`, `padding*`, `cornerRadius`.
3. **Resolve** — map style IDs to definitions; use `variableCollections`/`variableModes` for variables.
4. **Map / Generate / Validate** — same as MCP steps 4–6 above.

---

## 11. Pairing with other skills

| Skill | Relationship |
|---|---|
| **#04 Premium Design System** | Owns the token catalogue. This skill flags gaps; #04 fills them. |
| **#05 App Preview** | Consumes widget stubs for visual sign-off. |
| **#10 Asset Management** | Routes exported image/SVG assets for `flutter_gen` integration. |
| **#17 Responsive UI** | Auto-layout wrapping informs breakpoint logic for #17. |

---

## 12. Token map document

The delivery is [`templates/figma_to_token_map.md`](templates/figma_to_token_map.md) —
tables for color, typography, spacing, radius, effect, and component maps, plus
a gap register and conflict-resolution rules.

---

House style: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).
Token catalogue: [`../04_Premium_Design_System/templates/app_tokens.dart`](../04_Premium_Design_System/templates/app_tokens.dart).
