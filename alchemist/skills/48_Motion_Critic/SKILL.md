---
name: Motion Critic
description: Audit all animations against AppTokens.motion — flag ad-hoc duration/curve literals, jarring transitions, missing motion, and 60fps violations. Use after animation work, before a design sign-off, or when motion "feels off".
when_to_use: Trigger on "audit animations", "check motion", "review transitions", "motion QA", "are animations consistent", "animation review", or after skill 09 Animation produces transitions. Also run before any store release or design sign-off as a motion gate.
---

# Motion Critic

You audit every animation, transition, and implicit motion in the app against the project's **motion token contract** (`AppTokens.motion`). You flag ad-hoc literals, inconsistent durations/curves, missing motion where it belongs, and performance hazards. Your output is a prioritized fix list.

House style: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md) §4. The motion tokens you audit against belong to [skill 04 Premium_Design_System](../04_Premium_Design_System/SKILL.md) and [skill 09 Animation](../09_Animation/SKILL.md). This skill does not define tokens — it enforces them.

**Done when:** every animation draws from `AppTokens.motion`, no ad-hoc literals remain, transitions feel intentional, and the app runs 60fps in profile mode.

---
## Step 1 — Read the motion token contract

Read `lib/app/theme/app_tokens.dart` and extract the `MotionTokens` class. It should define:

- **Durations:** `short` (~150ms), `medium` (~300ms), `long` (~500ms), `extended` (~800ms). Exact values vary by project.
- **Curves:** `standard` (easeInOutCubic-ish), `decelerate`, `accelerate`, `emphasized` (the M3 emphasized curve).
- **Presets:** combined duration+curve for common patterns: `pageTransition`, `fabMorph`, `listItem`, `snackbar`…

If `MotionTokens` does not exist, STOP — route to skill 04 to define it, then skill 09 to apply it, then return here.

---
## Step 2 — Inventory every animation in the app

Grep the codebase for animation triggers. Run the checklist from [`templates/motion_audit_checklist.md`](templates/motion_audit_checklist.md). Capture every instance of:

```
AnimatedContainer, AnimatedOpacity, AnimatedPadding, AnimatedAlign,
AnimatedDefaultTextStyle, AnimatedSwitcher, AnimatedList, AnimatedCrossFade,
TweenAnimationBuilder, SlideTransition, ScaleTransition, FadeTransition,
RotationTransition, SizeTransition, Hero, PageRoute, Navigator.push,
AnimationController, Tween, CurveTween, Curves., Duration(
```

For each instance, record: **file:line**, **widget**, **duration** (if hardcoded), **curve** (if hardcoded), and **purpose** (page transition, micro-interaction, loading shimmer, etc.).

---
## Step 3 — Audit each instance

For each animation found, answer four questions:

### Q1 — Does it use AppTokens.motion?
- YES: `AppTokens.motion.durations.short` / `AppTokens.motion.curves.standard` — pass.
- NO: hardcoded `Duration(milliseconds: 350)` / `Curves.easeInOut` — **flag as AD-HOC LITERAL**.

### Q2 — Is the duration/curve appropriate for the context?
- Page transitions should use `motion.pageTransition` (typically `long` + `emphasized`).
- Micro-interactions (icon press, toggle, chip dismiss) should use `short` + `standard` / `decelerate`.
- List item insert/remove should use `medium` + `standard`.
- Loading shimmer should use `extended` + `easeInOut`-style looping.
- If an animation uses the wrong preset for its context — **flag as WRONG PRESET**.

### Q3 — Is the transition intentional?
- No curve / linear default — **flag as MISSING CURVE** (linear motion looks robotic).
- Same duration for everything — **flag as UNIFORM DURATION** (motion should have hierarchy).
- Abrupt appearance with no transition where one belongs (e.g., a dialog pops in, a chip appears) — **flag as MISSING MOTION**.

### Q4 — Performance hazard?
- `Opacity` on large subtrees (use `FadeTransition` instead — it skips rasterization of fully-transparent children).
- `AnimatedContainer` rebuilding layout on every frame (prefer `AnimatedPadding` + `AnimatedAlign` for non-layout changes).
- Many simultaneous `AnimationController`s (>5 on one screen is suspect).
- Non-`const` widgets inside `AnimatedBuilder` (they rebuild every frame; extract to const).
- Opacity `0.0` instead of `Visibility` / `Offstage` for hidden elements (still in the hit-test tree).

---
## Step 4 — Produce the audit report

Output a markdown report with:

1. **Inventory count:** total animations found, by category (page transitions, micro-interactions, list animations, loading, hero/shared-axis, other).
2. **Tokenized vs ad-hoc:** count + percentage that use `AppTokens.motion`.
3. **Violations table** (sorted by severity):

| Severity | File:Line | Widget | Issue | Fix |
|---|---|---|---|---|
| HIGH | `router.dart:42` | `MaterialPageRoute` | Hardcoded `Duration(400)` | Use `AppTokens.motion.pageTransition.duration` |
| HIGH | `chat_screen.dart:88` | `AnimatedList` | `Curves.linear` — no curve | Use `AppTokens.motion.curves.standard` |
| MEDIUM | `product_card.dart:15` | `AnimatedContainer` | Builds layout every frame | Split to `AnimatedPadding` + `AnimatedAlign` |
| LOW | `settings_screen.dart:30` | `AnimatedOpacity` | Opacity 0 with subtree still in tree | Add `Offstage` when opacity=0 |

4. **Missing motion report:** places where an abrupt appearance/dismissal should be animated (dialogs, bottom sheets, chips, FAB morph).
5. **Performance flags** (the Q4 hazards).
6. **Verdict:** `PASS` (zero HIGH, no missing-motion gaps) or `REVISE` (list what must be fixed).

---
## Step 5 — Fix and re-audit

Apply fixes for all HIGH violations. If many are ad-hoc literals, do a global find-and-replace:
- `Duration(milliseconds: N)` → nearest `AppTokens.motion.durations.*`
- `Curves.easeInOut` → `AppTokens.motion.curves.standard`
- `Curves.easeOut` → `AppTokens.motion.curves.decelerate`
- `Curves.easeIn` → `AppTokens.motion.curves.accelerate`

Keep `flutter analyze` clean (skill 41). Re-run the inventory and verify the tokenized percentage increased.

---
## Cross-references

- **04 Premium_Design_System** — owns `AppTokens.motion`; if tokens are missing, go here first.
- **09 Animation** — builds the animations; if animations were never built, go here first.
- **41 Analyzer_AutoFix** — keep the analyzer clean while applying fixes.
- **43 Design_Critic** — visual/static critique; this skill adds the motion dimension.

See the full audit checklist in [`templates/motion_audit_checklist.md`](templates/motion_audit_checklist.md).
