# Pre-Release Accessibility Checklist (skill 45)

Run this per screen before sign-off. A box is checked only when **verified**
(matcher passed / contrast computed / rect measured / TalkBack confirmed), never
from memory. Anything unchecked is a release blocker until triaged.

> Verify methods used below: **[AUTO]** `meetsGuideline(...)` widget test ·
> **[CALC]** WCAG contrast math · **[TB]** manual TalkBack pass ·
> **[SCAN]** Accessibility Scanner / DevTools a11y inspector ·
> **[DEV]** on-device toggle (large text / remove animations).

Screen: `__________________`  ·  Theme(s) tested: ☐ light ☐ dark  ·  Date: `____`

---

## 1. Semantics & labels
- [ ] Every interactive element (button, icon button, tappable card, switch, slider) has a meaningful label. **[AUTO labeledTapTargetGuideline / TB]**
- [ ] `IconButton`s have a `tooltip` (or `Semantics(label:)`). **[TB]**
- [ ] Meaningful images/icons have a `semanticLabel`. **[TB]**
- [ ] Decorative icons/images are hidden via `ExcludeSemantics`. **[TB]**
- [ ] Composite tiles (avatar + name + subtitle) are wrapped in `MergeSemantics`. **[TB]**
- [ ] Custom tappables expose a button role (`Semantics(button: true)` or a real `*Button`/`InkWell`, not bare `GestureDetector`). **[TB/SCAN]**

## 2. Color contrast (WCAG AA)
- [ ] Body text ≥ **4.5:1** against its background. **[AUTO textContrastGuideline / CALC]**
- [ ] Large text (≥18pt or ≥14pt bold) ≥ **3:1**. **[CALC]**
- [ ] UI components & icons & input borders & focus rings ≥ **3:1**. **[CALC/SCAN]**
- [ ] Captions/hints don't rely on opacity-faded `onSurface` — use `onSurfaceVariant`. **[CALC]**
- [ ] Contrast verified in **both** light and dark themes. **[CALC]**
- [ ] Meaning is never conveyed by color alone (also use text/icon/shape). **[TB]**

## 3. Touch targets
- [ ] Every interactive hit area ≥ **48×48 dp**. **[AUTO androidTapTargetGuideline / SCAN]**
- [ ] No tap targets shrunk via `padding: EdgeInsets.zero` / tight `constraints`. **[SCAN]**
- [ ] Adjacent targets have enough spacing to avoid mis-taps. **[SCAN]**
- [ ] Theme sets `materialTapTargetSize: MaterialTapTargetSize.padded`. **[AUTO]**

## 4. Dynamic type / text scaling
- [ ] No clipping/truncation/overflow at `textScaler 2.0`. **[AUTO / DEV]**
- [ ] No fixed-height containers around text (use `minHeight` + padding). **[AUTO]**
- [ ] Text scaling is **not** disabled app-wide (cap high, e.g. ≤2.0, never to 1.0). **[DEV]**
- [ ] Long strings wrap or ellipsize meaningfully — important content isn't lost. **[DEV]**

## 5. Focus order & navigation
- [ ] TalkBack swipe order matches visual reading order (top→bottom, lead→trail). **[TB]**
- [ ] Hardware-keyboard Tab order is logical; no focus traps. **[DEV]**
- [ ] Wrong default order corrected via `OrdinalSortKey` / `FocusTraversalGroup`. **[TB]**
- [ ] Dialogs/sheets scope focus and restore it on close (real `Dialog`/`showModalBottomSheet`). **[TB]**
- [ ] All controls are reachable by screen reader, not just mouse/touch. **[TB]**

## 6. Reduce-motion & motion safety
- [ ] Non-essential motion is gated behind `MediaQuery.disableAnimations`. **[DEV]**
- [ ] A reduced/instant variant exists when animations are off. **[DEV]**
- [ ] Nothing flashes more than 3×/second (seizure safety). **[DEV]**

## 7. Media captions & announcements
- [ ] Informative video/audio has captions or a transcript. **[manual]**
- [ ] Auto-playing media can be paused/stopped. **[manual]**
- [ ] State changes (validation errors, success, cart updates) announce via `SemanticsService.announce` or `liveRegion`. **[TB]**
- [ ] Loading spinners are labeled ("Loading…"), not silent. **[TB]**

---

## Android specifics
- [ ] **Accessibility Scanner** run on the screen — no target-size/contrast/label warnings. **[SCAN]**
- [ ] Works with **TalkBack** on a real device/emulator (not just the simulator). **[TB]**
- [ ] Honors system **Font size** and **Display size** (Settings → Accessibility). **[DEV]**
- [ ] Honors **Remove animations**. **[DEV]**
- [ ] Honors **High contrast text** / **Color correction** without breaking layout. **[DEV]**
- [ ] `minSdk 23` behaviors verified (per CONVENTIONS) — a11y APIs degrade gracefully on older OS. **[DEV]**
- [ ] Touch targets validated against Material's 48dp (Android), not just iOS 44dp. **[AUTO/SCAN]**

---

## Sign-off
- [ ] All three guideline matchers pass in `test/` (`a11y_test.dart`). **[AUTO]**
- [ ] Manual TalkBack pass completed end-to-end on the screen. **[TB]**
- [ ] All **Critical** and **High** findings resolved (Medium/Low triaged with owner + issue link).
- [ ] Re-captured/re-ran after fixes — no regressions.

Verdict: ☐ **Pass** (a11y sub-gate green for stage 24) · ☐ **Revise**

See `../SKILL.md` for the audit method, the AA math, and severity guidance.
Ties to **43** (visual critique) and **24** (Production_Readiness release gate).
Links: [`../../../references/CONVENTIONS.md`](../../../references/CONVENTIONS.md) §4.
