# Look & Feel Sign-Off — <app name>

Stage 05 (App_Preview) exit gate. Fill this in with the stakeholder, attach the
preview artifacts, and get an approval before any feature code (stage 06+) is
written. The gate is green only when **every box is checked** and the approver
has signed and dated below.

- **Date:** <yyyy-mm-dd>
- **Reviewed previews:** ☐ `.pen` mockups (`previews/pen/`)  ☐ widget gallery (run)  ☐ device screenshots (`previews/shots/` · `previews/golden/`)
- **Design system version:** stage 04 — `lib/app/theme/*` @ <commit/date>

---

## 1. Brand
- [ ] Seed/primary color and accents match the agreed brand.
- [ ] Typography (families, weights, scale) matches the design system.
- [ ] Logo, app name, iconography, and tone feel on-brand.
- [ ] Imagery/illustration style is consistent across screens.

## 2. Visual hierarchy
- [ ] The most important element on each screen reads first.
- [ ] Headings, body, and captions use the type scale consistently (no ad-hoc sizes).
- [ ] Primary vs. secondary vs. tertiary actions are visually distinct.
- [ ] Color is used for meaning (primary/secondary/error roles), not decoration.

## 3. Spacing & rhythm
- [ ] Spacing follows the token scale (4/8-based) — no eyeballed gaps.
- [ ] Consistent padding/margins across comparable screens.
- [ ] Alignment and grid feel intentional; nothing looks cramped or adrift.
- [ ] Touch targets are >= 48dp.

## 4. Dark mode (first-class)
- [ ] Every key screen reviewed in **both** light and dark.
- [ ] No invisible text, muddy surfaces, or wrong-elevation tints in dark.
- [ ] Brand still reads correctly in dark (not just inverted).
- [ ] Images/illustrations adapt or remain legible in dark.

## 5. Key screens (from `docs/UX.md`)
List each MVP screen; check when its look & feel is approved.
- [ ] <Screen 1>
- [ ] <Screen 2>
- [ ] <Screen 3>
- [ ] <Screen 4>
- [ ] Every MVP-flow screen in the UX inventory is represented (none missing).

## 6. State coverage (per data screen)
- [ ] Loading state previewed (skeleton/shimmer) and looks right.
- [ ] Empty state previewed and is helpful, not blank.
- [ ] Error state previewed and is calm/actionable.
- [ ] Populated/data state previewed.

## 7. Motion feel
- [ ] Intended transitions/micro-interactions described or prototyped.
- [ ] Motion direction & duration feel on-brand (not jarring or sluggish).
- [ ] No motion that would cause discomfort; reduced-motion path considered.

## 8. Accessibility & contrast
- [ ] Text/background contrast meets WCAG AA (4.5:1 body, 3:1 large/UI) — light & dark.
- [ ] Information is not conveyed by color alone.
- [ ] Hit areas, focus order, and labels considered for screen readers (`Semantics`).
- [ ] Layout holds at larger text scale (no clipping/overflow).

---

## Decision
- ☐ **Approved** — proceed to stage 06.
- ☐ **Approved with notes** — proceed; address notes below during build.
- ☐ **Changes requested** — iterate previews; do not advance the gate.

**Notes / follow-ups:**
- <...>

**Approver:** <name / role>  **Signature:** ______________  **Date:** <yyyy-mm-dd>

> When Approved (or Approved with notes), the orchestrator records stage 05 as
> done in `.flutter-pipeline/STATE.md` with the artifact path `previews/` and
> the approver + date.
