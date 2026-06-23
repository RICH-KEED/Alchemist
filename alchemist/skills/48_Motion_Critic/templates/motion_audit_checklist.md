# Motion Audit Checklist

## 1. Inventory — grep patterns

Run these greps to find every animation in the codebase:

```bash
# Duration literals (the main enemy)
grep -rn "Duration(" lib/ --include="*.dart"

# Curve usage
grep -rn "Curves\." lib/ --include="*.dart"

# Animated* widgets
grep -rn "AnimatedContainer\|AnimatedOpacity\|AnimatedPadding\|AnimatedAlign\|AnimatedDefaultTextStyle\|AnimatedSwitcher\|AnimatedList\|AnimatedCrossFade\|AnimatedSize\|AnimatedBuilder" lib/ --include="*.dart"

# Transition widgets
grep -rn "SlideTransition\|ScaleTransition\|FadeTransition\|RotationTransition\|SizeTransition\|DecoratedBoxTransition\|AlignTransition\|PositionedTransition\|RelativePositionedTransition" lib/ --include="*.dart"

# Animation controllers / tweens
grep -rn "AnimationController\|TweenAnimationBuilder\|Tween(" lib/ --include="*.dart"

# Hero
grep -rn "\bHero\b" lib/ --include="*.dart"

# Page transitions
grep -rn "PageRoute\|MaterialPageRoute\|CupertinoPageRoute\|CustomTransitionPage\|pageBuilder\|transitionsBuilder" lib/ --include="*.dart"

# Implicit animations
grep -rn "implicitlyAnimatedRebuild\|setState" lib/ --include="*.dart"

# Opacity (potential perf issue)
grep -rn "\bOpacity\b" lib/ --include="*.dart"
```

## 2. Per-instance audit questions

For each hit, ask:

- [ ] **Token check:** Does it use `AppTokens.motion.durations.*` and `AppTokens.motion.curves.*`?
- [ ] **Context match:** Is the duration/curve appropriate for this animation's purpose?
  - Page transition → `pageTransition` (long + emphasized)
  - Micro-interaction (icon, toggle) → `micro` (short + decelerate)
  - List item → `listItem` (medium + standard)
  - Loading → `shimmer` (extended + easeInOut loop)
  - Overlay/dialog → `overlay` (medium + emphasized)
- [ ] **Curve present:** If no curve, flag — linear is never correct for UI motion.
- [ ] **Performance:** Opacity on large subtrees? Layout animations? Many simultaneous controllers?

## 3. Missing motion scan

For each screen/route, check:

- [ ] Route transitions are animated (no abrupt screen swaps).
- [ ] Bottom sheets / dialogs animate in/out.
- [ ] FAB morphs between related actions (speed dial pattern).
- [ ] Chips/tags fade+slide on dismiss.
- [ ] List items animate on insert/remove/reorder.
- [ ] Toggle states (switch, checkbox, radio) have the default M3 animation.
- [ ] Pull-to-refresh has the standard indicator animation.
- [ ] Tab transitions (if using TabBar) use a crossfade or slide.

## 4. Dark mode pass

- [ ] Animated colors use `ColorScheme` roles — they auto-adapt to dark mode.
- [ ] No hardcoded `Color(0xFF...)` in `Tween<Color?>` or `AnimatedContainer` `color:`.
- [ ] Shimmer/loading shimmer colors adapt to dark mode.

## 5. Accessibility

- [ ] `AnimatedContainer`/`AnimatedSwitcher` preserves `Semantics` during transition.
- [ ] Reduced-motion preference is respected (check `MediaQuery.of(context).disableAnimations` if the app supports it).
- [ ] No seizure-risk animations: no rapid flashing (>3 flashes/second), no parallax that triggers vestibular discomfort.

## 6. Verdict

- [ ] **PASS** — 100% tokenized, no HIGH issues, no missing motion gaps.
- [ ] **PASS with notes** — 100% tokenized, only LOW findings, no missing gaps.
- [ ] **REVISE** — HIGH issues or missing motion gaps remain. List them.
