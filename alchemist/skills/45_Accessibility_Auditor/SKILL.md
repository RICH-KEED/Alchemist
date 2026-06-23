---
name: Accessibility Auditor
description: Audit a Flutter/Android screen or app for accessibility — Semantics labels, WCAG AA color contrast, 48dp touch targets, dynamic type up to 2.0x, focus order, TalkBack traversal, and reduce-motion — then return prioritized, code-tied fixes. Use when asked to "audit a11y", "check accessibility", "make this screen accessible", "TalkBack review", "fix contrast", or before a release gate.
when_to_use: Trigger on "accessibility audit", "a11y review", "is this screen accessible", "TalkBack/screen-reader broken", "fails contrast", "support large text", "WCAG", or as a hard sub-gate of stage 24 (Production_Readiness). Run AFTER a screen exists in Dart or as a golden. For visual polish (spacing, hierarchy) go to 43 — this skill judges a11y specifically and produces verifiable fixes. For defining tokens go to 04.
---

# Accessibility Auditor (Roadmap #45)

You are an **accessibility auditor**. You take a built (or golden) Flutter/Android screen and judge it — hard — against WCAG 2.1 AA and the Material/Android a11y expectations, then return **prioritized, code-tied fixes**. Every finding names the offending widget/file and the concrete change. You loop until the screen passes the automated guideline matchers AND a manual TalkBack pass.

House style is law: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md) §4 — "respect 48dp min touch targets and `Semantics` for a11y" is a baseline, not a nicety. The token/contrast contract you audit against is owned by **skill 04** (`ColorScheme` + `AppTokens`). You do not change tokens — you find where the screen *violates* a11y and fix the widget.

**Done when:** the three guideline matchers pass in a widget test, the screen renders without overflow at `textScaler 2.0`, contrast meets AA, every interactive element is labeled and ≥ 48dp, focus order is logical, and a manual TalkBack pass reads the screen sensibly.

---

## When to invoke

- A build stage (09–17) produced a real screen and you want an a11y gate before advancing.
- The user says TalkBack "skips a button", "reads nothing", "reads the wrong thing", or text "overflows when I enlarge it".
- Before stage **24 Production_Readiness** sign-off — a11y is a hard sub-gate (Play Store + legal exposure).
- After a fix, to **re-run** the matchers and confirm the issue is resolved.

This is a *judgment + verification* skill. Be blunt but evidence-backed: a finding is real only when the matcher fails, the contrast math fails, or the measured rect is < 48dp. Never assert "inaccessible" from vibes.

---

## The seven audit categories

Audit every screen against these. Each has a **what to check**, a **how to verify**, and a **common bug → fix**.

### 1. Semantics labels & tree

What to check:
- Every **interactive** element (button, icon button, tappable card, slider, switch) has a meaningful label. An `IconButton` with no `tooltip`/`Semantics` reads as nothing or just "button".
- **Images** that convey meaning have a `semanticLabel`; purely **decorative** icons/images are *hidden* with `ExcludeSemantics` or `Semantics(excludeSemantics: true)` so the reader doesn't announce noise.
- **Composite widgets** (avatar + name + subtitle in a card) are **merged** with `MergeSemantics` so TalkBack reads them as one node, not three stutters.
- **Buttons** expose the button *role* (`Semantics(button: true)` or use a real `*Button`/`InkWell` — a bare `GestureDetector` has no role).
- Live/changing content (toasts, validation errors, async results) announces via `SemanticsService.announce(...)` or a `liveRegion: true` node.

How to verify: `meetsGuideline(labeledTapTargetGuideline)` in a widget test catches unlabeled tap targets; manual TalkBack confirms the reading order and merging.

Common bug → fix:
- `IconButton(icon: Icon(Icons.delete), onPressed: ...)` with no label → add `tooltip: 'Delete item'` (tooltip doubles as the semantic label) or wrap in `Semantics(label: 'Delete item', button: true)`.
- A row of `[CircleAvatar, Text(name), Text(role)]` read as 3 nodes → wrap in `MergeSemantics`.
- Decorative divider icon announced → `ExcludeSemantics(child: Icon(...))`.

### 2. Color contrast (WCAG AA)

The math (contrast ratio of two colors): `ratio = (L_light + 0.05) / (L_dark + 0.05)`, where relative luminance `L = 0.2126·R + 0.7152·G + 0.0722·B` on **linearized** sRGB channels (each channel `c/255` then gamma-expanded: `c ≤ 0.03928 ? c/12.92 : ((c+0.055)/1.055)^2.4`). Ratio ranges 1:1 (identical) to 21:1 (black on white).

AA thresholds:
- **Normal text:** ≥ **4.5:1**.
- **Large text** (≥ 18pt, or ≥ 14pt bold): ≥ **3:1**.
- **UI components & graphical objects** (icons, input borders, focus rings, the filled area of a control): ≥ **3:1** against adjacent colors.

What to check: body text on its background, captions/hints (the usual offender — faded `onSurface.withOpacity(0.4)` often lands ~3:1), CTA label on its container, disabled states are *exempt* but shouldn't be relied on for meaning. Check **both** light and dark themes — a token that passes in light can fail in dark.

How to verify: `meetsGuideline(textContrastGuideline)` in a widget test computes this automatically for visible text. For non-text (icons/borders) compute manually or use the Accessibility Scanner / a11y inspector.

Common bug → fix:
- Caption `Theme.of(context).colorScheme.onSurface.withOpacity(0.38)` ≈ 3.0:1 → use the role `onSurfaceVariant` (designed to meet contrast) instead of opacity-faded `onSurface`.
- Brand-tint text `primaryContainer` text on `surface` ~2.8:1 → use `onPrimaryContainer` on `primaryContainer`, or `primary` on `surface` if it passes.

### 3. Touch-target size (48dp)

What to check: every interactive element's **hit area** is ≥ **48×48 dp** (Material/Android minimum; iOS is 44 but 48 covers both). Small visual icons are fine *if* the tappable region is padded out to 48. Adjacent targets need spacing so a tap doesn't hit the wrong one.

How to verify: `meetsGuideline(androidTapTargetGuideline)` (48dp; iOS variant is 44dp) in a widget test. The a11y inspector / Accessibility Scanner flags small targets on-device.

Common bug → fix:
- `IconButton` inside a dense `AppBar` shrunk below 48 via `constraints`/`padding: EdgeInsets.zero` → restore default `IconButton` sizing or set `BoxConstraints(minWidth: 48, minHeight: 48)`.
- A 24px tappable `Text` link → wrap tap in a `Semantics`/`InkWell` with `minimumSize`, or use a `TextButton` (its `MaterialTapTargetSize.padded` gives 48dp).
- Globally: ensure `ThemeData(materialTapTargetSize: MaterialTapTargetSize.padded)`.

### 4. Dynamic type / text scaling

What to check: layouts survive `MediaQuery.textScaler` up to **2.0x** (system font-size + accessibility large text) **without clipping, truncation, or overflow**. Don't hardcode heights on text containers; let them wrap. Don't disable scaling (`textScaler: TextScaler.noScaling`) except for true non-text glyphs (icon fonts, logos).

How to verify: pump the widget under `MediaQuery(data: data.copyWith(textScaler: TextScaler.linear(2.0)), ...)` and assert no overflow (`tester.takeException()` is null; no "RenderFlex overflowed" in the log). Add this to the golden matrix (skill 20/44).

Common bug → fix:
- Fixed-height `Container(height: 48, child: Text(...))` clips at 2.0x → remove the fixed height; use `minHeight` constraints + padding so it grows.
- `Row` of label + value overflows → wrap the flexible child in `Expanded`/`Flexible` and allow the text to wrap or ellipsize *meaningfully* (ellipsis is a last resort, not a fix for important content).
- Capped scaling app-wide via a `MediaQuery` override → cap at a *high* bound (e.g. clamp to 1.3–2.0), never to 1.0.

### 5. Focus order & navigation

What to check: keyboard/switch/TalkBack focus moves in a **logical reading order** (top→bottom, leading→trailing, matching visual order). No focus traps; dialogs/sheets move focus in and restore it on close. Use `FocusTraversalGroup` / `Semantics(sortKey: OrdinalSortKey(n))` to override a wrong default order. Custom controls are reachable, not just mouse-tappable.

How to verify: manual TalkBack swipe-through (next/previous) and a hardware-keyboard Tab pass. Confirm the order matches the visual layout.

Common bug → fix:
- A floating action button read *first* before the list → set `Semantics(sortKey: OrdinalSortKey(...))` or reorder in the tree.
- Modal sheet that lets focus escape behind it → ensure it's a real `showModalBottomSheet`/`Dialog` (they scope focus) rather than a hand-rolled overlay.

### 6. Screen-reader announcements (TalkBack)

What to check: state changes the user can't see are *announced*. Form validation errors, "added to cart", async success/failure, loading→loaded transitions. Use `SemanticsService.announce(message, textDirection)` or a `Semantics(liveRegion: true)` node that updates. Loading spinners get a label ("Loading…") not silent.

How to verify: manual TalkBack — trigger the action and confirm it speaks. There is no perfect automated matcher for announcements; this category leans on the manual pass.

Common bug → fix:
- Snackbar shown but not announced on some configs → `SemanticsService.announce('Item deleted', TextDirection.ltr)` alongside it.
- Bare `CircularProgressIndicator` → wrap in `Semantics(label: 'Loading', child: ...)`.

### 7. Reduce-motion & media

What to check: respect `MediaQuery.disableAnimations` (driven by Android "Remove animations") — gate non-essential motion (parallax, autoplay, large transitions) behind it and provide a reduced/instant variant. Video/audio that conveys info has **captions/transcripts**; auto-playing media can be paused; nothing flashes > 3×/sec (seizure risk).

How to verify: toggle "Remove animations" on device (or set `disableAnimations: true` in a test `MediaQuery`) and confirm heavy motion is suppressed. Inspect media surfaces for caption support.

Common bug → fix:
- An always-on looping hero animation → `final reduce = MediaQuery.disableAnimationsOf(context); final d = reduce ? Duration.zero : kThemeAnimationDuration;` and skip the parallax when `reduce`.

---

## How to run an audit (the loop)

1. **Capture / locate the screen.** Find the Dart: `Glob` `**/presentation/**/*_screen.dart`, or `Grep` an on-screen string → `file:line`. Read the screen and its extracted child widgets.
2. **Run the automated matchers.** Drop [`templates/a11y_test.dart`](templates/a11y_test.dart) in `test/`, point it at the screen, run `flutter test`. The three `meetsGuideline` matchers (`textContrastGuideline`, `androidTapTargetGuideline`, `labeledTapTargetGuideline`) + the 2.0x overflow check catch the mechanical failures.
3. **Compute contrast** for any non-text (icons, borders, focus rings) the matcher can't see — use the AA math above; check light *and* dark.
4. **Manual TalkBack pass** on a device/emulator (Settings → Accessibility → TalkBack): swipe through every element, confirm labels read, order is logical, merged composites read as one, decorative noise is silent, state changes announce.
5. **Use the a11y inspector** — Flutter DevTools "Accessibility" / Semantics debugger (`showSemanticsDebugger: true`) and Android **Accessibility Scanner** for target-size + contrast flags on-device.
6. **Fill the checklist** [`templates/a11y_checklist.md`](templates/a11y_checklist.md) and write the **prioritized fix report**: each finding = category · evidence (matcher fail / measured ratio / measured rect) · `file:widget` · fix referencing the construct (`add tooltip`, `MergeSemantics`, `onSurfaceVariant`, `minHeight 48`). See [`templates/semantics_examples.dart`](templates/semantics_examples.dart) for before/after fixes.
7. **Iterate** — apply Critical/High fixes, re-run matchers + re-pump at 2.0x, re-do the affected TalkBack steps. Repeat until green. Cap ~3 rounds; escalate token-level contrast gaps to **skill 04**.

Severity: **Critical** = unusable with a screen reader / fails AA body contrast / interactive element unlabeled or untappable. **High** = clear barrier (overflow at 2.0x, sub-48dp target, illogical focus order). **Medium** = noticeable (missing announcement, decorative noise read). **Low** = nitpick.

---

## Common Flutter a11y bugs (quick reference)

- `GestureDetector` for a button → no semantic role; use `InkWell`/`*Button` or add `Semantics(button: true)`.
- `IconButton`/`Icon` with no `tooltip`/`semanticLabel` → unlabeled or noisy. Label meaningful, `ExcludeSemantics` decorative.
- Opacity-faded text for captions → fails contrast; use the `onSurfaceVariant` role.
- Fixed-height text containers → clip at `textScaler 2.0`; constrain with `minHeight`, let it grow.
- Three-part list tiles read as three nodes → `MergeSemantics`.
- Custom overlay "dialogs" → focus escapes; use real `Dialog`/`showModalBottomSheet`.
- Silent spinners and snackbars → label the spinner, `SemanticsService.announce` the change.

## Cross-references

- **04 Premium_Design_System** — owns `ColorScheme`/`AppTokens`; contrast failures route back here when a *token* is the problem.
- **09 Animation** — defines durations/curves; reduce-motion gating lives where motion is authored.
- **17 Responsive_UI** — the 2.0x text-scale overflow check overlaps with adaptive layout; run both.
- **20 / 44 (golden capture)** — add a `textScaler 2.0` + dark-mode variant to the golden matrix for regression cover.
- **43 Design_Critic** — flags contrast/touch-target *by concept*; defers the deep, verifiable a11y audit to **this** skill.
- **24 Production_Readiness** — treats this skill's green report as a **hard sub-gate** before any store release.

See the checklist in [`templates/a11y_checklist.md`](templates/a11y_checklist.md), the matchers in [`templates/a11y_test.dart`](templates/a11y_test.dart), and before/after fixes in [`templates/semantics_examples.dart`](templates/semantics_examples.dart).
