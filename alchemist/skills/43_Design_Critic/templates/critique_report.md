# Design Critique Report — <Screen name>

- **Screen / route:** `<RouteName>` — `lib/features/<feature>/presentation/<screen>_screen.dart`
- **Captured from:** `Pencil .pen mock` | `flutter run` | `golden image`  ·  **Modes:** light + dark  ·  **Sizes:** phone / large-screen
- **Capture artifacts:** `previews/<screen>_light.png`, `previews/<screen>_dark.png`
- **Round:** 1  ·  **Date:** <YYYY-MM-DD>  ·  **Rubric:** `templates/critique_rubric.md`

---

## 1. Scores

| # | Dimension | Score (1–5) | One-line justification |
|---|---|:---:|---|
| 1 | Visual hierarchy |  |  |
| 2 | Spacing rhythm |  |  |
| 3 | Color & contrast (WCAG) |  |  |
| 4 | Alignment & grid |  |  |
| 5 | Density & breathing room |  |  |
| 6 | Typography scale |  |  |
| 7 | Component consistency |  |  |
| 8 | Motion consistency |  |  |
| 9 | Touch targets |  |  |
| 10 | State polish |  |  |

**Lowest dimensions drive the verdict.** Any score < 4 must have a matching issue below.

---

## 2. Prioritized issues

Sort Critical → High → Medium → Low. Every issue cites **evidence** and a **token-referenced fix**.

| # | Severity | Dimension | Evidence (saw / measured) | File : widget | Suggested fix (token-referenced) |
|---|---|---|---|---|---|
| 1 | Critical |  |  | `…_screen.dart : <Widget>` |  |
| 2 | High |  |  |  |  |
| 3 | Medium |  |  |  |  |
| 4 | Low |  |  |  |  |

> Severity: **Critical** = unusable / fails WCAG body contrast / primary action unfindable ·
> **High** = clearly unpolished (mixed radii, off-scale gutters, weak CTA) ·
> **Medium** = noticeable minor (one tight gap, off line-height) · **Low** = nitpick / opportunity.

### Example rows (delete before use)
| # | Severity | Dimension | Evidence | File : widget | Fix |
|---|---|---|---|---|---|
| – | High | Component consistency | Card `radius 16`, chip `radius 8`, dialog `radius 20` — three radius families | `home_screen.dart : _PromoCard` | Use `radius.lg` everywhere; drop ad-hoc `BorderRadius.circular` |
| – | High | Color & contrast | Caption `onSurface.withOpacity(0.4)` ≈ 3.1:1 < 4.5:1 | `profile_screen.dart : _MetaLabel` | Use `onSurfaceVariant` |
| – | Medium | Spacing rhythm | Header pads `20`, cards pad `16` — `20` off the 4/8 scale | `home_screen.dart : _SectionHeader` | Snap to `spacing.lg` (24) or `spacing.md` (16) |

---

## 3. Overall verdict

**Verdict:** ☐ **SHIP** (all dimensions ≥ 4, no open Critical/High, verified light+dark)
          ☐ **REVISE** (one or more below bar — see issues above)

**Headline:** <one sentence: the single most important thing to fix, or why it ships>

---

## 4. Re-check checklist (after fixes → re-capture → re-score)

- [ ] All **Critical** issues resolved and re-captured
- [ ] All **High** issues resolved and re-captured
- [ ] Affected dimensions re-scored to ≥ 4
- [ ] Verified in **light** and **dark**
- [ ] Verified on **phone** and (if applicable) **large screen**
- [ ] No new off-scale spacing / stray hex introduced by the fix
- [ ] `flutter analyze` clean (`very_good_analysis`)
- [ ] Fresh screenshot attached for this round (not judged from memory)

---

### Round log
| Round | Date | Lowest score | Open Critical/High | Verdict |
|---|---|---|---|---|
| 1 |  |  |  |  |
| 2 |  |  |  |  |
