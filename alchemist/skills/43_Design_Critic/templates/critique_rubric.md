# Premium Design Critique Rubric

Score each dimension **1–5** against the anchors below. A screen *ships* only when every
dimension is **≥ 4** and no **Critical/High** issue is open. "Premium" = disciplined
consistency, not decoration (see skill 04). Token references: spacing `xs4 sm8 md16 lg24
xl32 xxl48`, radii `sm8 md12 lg16 xl24 pill`, elevation `0/1/3/6/8/12`, M3 `TextTheme`
roles, `ColorScheme` color roles.

Scoring anchors (apply to every dimension): **1** broken/unusable · **2** clearly
amateur · **3** functional but generic · **4** polished, minor nits · **5** premium,
intentional, nothing to remove.

---

## 1. Visual hierarchy
- **Premium looks like:** one obvious primary action; eye lands on the heading first, then
  scans body, then secondary actions. Importance encoded by size + weight + color, not just position.
- **Common failure signs:** two equal-weight CTAs competing; heading same size as body;
  everything `onSurface` full-opacity (no muted secondary text); no focal point.
- **Anchors:** 5 = instant one-glance read, single clear CTA · 3 = readable but flat, no
  strong focal point · 1 = can't tell what to do or where to look.

## 2. Spacing rhythm (vs the token scale)
- **Premium looks like:** every gap/padding lands on the 4/8 scale; one consistent gutter
  across the screen; sections separated by `lg`/`xl`; outer margins ≥ `md`, often `lg`.
- **Common failure signs:** off-scale values (`13`, `7`, `20`); gutters that vary card-to-card;
  cramped edges (content touching the screen border).
- **Anchors:** 5 = perfect 4/8 rhythm, generous margins · 3 = mostly on-scale, a few strays ·
  1 = arbitrary spacing everywhere, no rhythm.

## 3. Color & contrast (WCAG)
- **Premium looks like:** body text ≥ **4.5:1**; large text / UI components / icons ≥ **3:1**;
  CTA visually dominant; only `ColorScheme` + `AppTokens` semantic colors — zero stray hex.
- **Common failure signs:** grey-on-grey captions (`onSurface.withOpacity(0.4)` ≈ 3:1);
  low-contrast `primaryContainer` CTA; hardcoded `Color(0x…)` in widgets; success/warning
  conveyed by color alone (no icon/label — a11y, defer depth to skill 45).
- **Anchors:** 5 = all text passes AA, CTA pops, palette pure · 3 = passes mostly, one weak spot ·
  1 = body text fails contrast / illegible.

## 4. Alignment & grid
- **Premium looks like:** elements share a left edge and a consistent column grid; labels and
  values align; icons optically centered.
- **Common failure signs:** 1–3px drift between rows; text not aligned with its icon;
  inconsistent leading edge between header and list.
- **Anchors:** 5 = pixel-true shared grid · 3 = mostly aligned, minor drift · 1 = ragged, no grid.

## 5. Density & breathing room
- **Premium looks like:** content breathes; whitespace is deliberate; comfortable list-row
  height; nothing wall-to-wall.
- **Common failure signs:** cramped rows, text butting against edges, too many items per
  viewport, no separation between groups.
- **Anchors:** 5 = balanced, airy, nothing cramped · 3 = usable but tight/busy · 1 = claustrophobic
  or, conversely, vast empty void with no structure.

## 6. Typography scale usage
- **Premium looks like:** every text style maps to an M3 `TextTheme` role; clear size jumps
  between levels; body 14–16sp, line-height ~1.4–1.5; ≤ 2 typefaces.
- **Common failure signs:** ad-hoc `TextStyle(fontSize: 15)`; heading and body nearly the same
  size; too many weights; cramped line height.
- **Anchors:** 5 = clean role-based scale, clear jumps · 3 = readable but inconsistent sizes ·
  1 = random font sizes, no scale.

## 7. Component consistency
- **Premium looks like:** all buttons/cards/fields inherit the component themes (skill 04);
  one radius family; one elevation language; consistent button shapes.
- **Common failure signs:** mixed corner radii (card 16, chip 8, dialog 20); one screen mixes
  `ElevatedButton` + `FilledButton` for the same intent; bespoke card styling.
- **Anchors:** 5 = every component matches the system · 3 = mostly consistent, one outlier ·
  1 = each component styled ad-hoc.

## 8. Motion consistency
- **Premium looks like:** transitions use only the defined durations (`fast/medium/slow`) and
  curves (skill 09); motion confirms cause→effect; nothing decorative or janky.
- **Common failure signs:** mixed/arbitrary durations; abrupt screen changes; over-animated
  bouncing; jank in profile.
- **Anchors:** 5 = cohesive, purposeful motion · 3 = present but inconsistent timing · 1 = none,
  or chaotic/janky. (Score from build behavior; mark N/A for a static mock.)

## 9. Touch targets
- **Premium looks like:** every interactive element ≥ **48dp**; adequate spacing so taps don't
  collide; full-row tappable where expected.
- **Common failure signs:** 32dp icon buttons; tightly packed adjacent tap targets; tiny text links.
- **Anchors:** 5 = all ≥48dp, well-spaced · 3 = one or two under 48dp · 1 = multiple sub-target hit areas.

## 10. Empty / error / loading polish
- **Premium looks like:** loading = skeleton/shimmer mirroring the layout; empty = illustration
  + cause + a primary action; error = friendly copy + retry (skill 16). All four states designed.
- **Common failure signs:** bare `CircularProgressIndicator`; blank empty screen; raw exception text;
  layout shift between states.
- **Anchors:** 5 = all states designed and premium · 3 = states exist but plain · 1 = missing
  states / raw spinner / blank.

---

## Scoring summary

| Dimension | Score (1–5) |
|---|---|
| 1. Visual hierarchy |  |
| 2. Spacing rhythm |  |
| 3. Color & contrast (WCAG) |  |
| 4. Alignment & grid |  |
| 5. Density & breathing room |  |
| 6. Typography scale |  |
| 7. Component consistency |  |
| 8. Motion consistency |  |
| 9. Touch targets |  |
| 10. State polish |  |

**Pass bar:** all ≥ 4 **and** zero open Critical/High issues, verified in light **and** dark.
