# Mobile Screen Wireframe Checklist (Android · Material 3)

Run **every key screen** through this before marking the wireframe done. Lo-fi = structure, hierarchy, reach, and states — not final color/type (that's stage 04). Link back: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md) §4.

## Visual hierarchy & layout
- [ ] The screen's **single primary action** is the most prominent element; secondary actions are visibly subordinate (overflow menu, text buttons).
- [ ] Content is ordered most-important → least, top → bottom; the key content is visible without scrolling.
- [ ] Clear layout regions: top app bar (nav/title/overflow) · scrollable content · fixed bottom (nav bar or primary action). State what's fixed vs. scrolls.
- [ ] No more than **one FAB**; it maps to the screen's main constructive action.

## Thumb reach & ergonomics
- [ ] Primary action sits in the bottom/center **easy-reach zone** (FAB, bottom-sheet confirm) — not a top corner.
- [ ] Destructive or rarely-used actions are kept out of accidental-tap reach.
- [ ] One-handed use works: nothing critical requires reaching the top with the thumb.

## Touch targets & spacing
- [ ] Every interactive element is **≥ 48×48 dp**.
- [ ] Adequate spacing between tappable items so neighbors aren't mis-tapped.
- [ ] Spacing follows a **4/8-dp scale**; consistent margins/gutters (no arbitrary values).

## Navigation
- [ ] The screen's place in the nav map is clear (top-level destination vs. pushed detail vs. modal).
- [ ] **Back** does the obvious thing; modals offer discard/confirm if there's unsaved input.
- [ ] If top-level: appears in the chosen nav component (NavigationBar / drawer); destination count fits Material 3 (2–5 for a bottom bar).

## All four async states (mandatory for data screens)
- [ ] **Loading** — skeleton/shimmer shaped like the content, not a bare centered spinner.
- [ ] **Data** — populated view (the happy path).
- [ ] **Empty** — explains what's missing + offers the primary action ("No items yet — tap + to add").
- [ ] **Error** — human message + **Retry**; no raw exceptions/codes.
- [ ] **Offline** (where relevant) — cached data shown + offline banner.
- [ ] Each state is sketched as its own variant, not assumed.

## Accessibility
- [ ] Every actionable/icon-only control has a text label or `Semantics` description.
- [ ] Layout reflows for larger text sizes (no clipped/truncated critical content); avoid fixed heights on text.
- [ ] Meaning is never conveyed by color/position alone (icon + label, or text).
- [ ] Logical focus/reading order top→bottom, left→right.
- [ ] Target contrast/legibility is achievable (final values confirmed in stage 04).

## Dark mode
- [ ] Layout works in **both light and dark**; nothing depends on a light-only assumption.
- [ ] No hardcoded backgrounds/borders that would vanish or glare in dark (tokens come in stage 04).
- [ ] Elevation/surface separation reads in both themes.

## Sign-off
- [ ] Screen covers its assigned MVP story/stories (cross-check the coverage matrix in `UX.md`).
- [ ] Empty + error variants drawn, not just the data view.
