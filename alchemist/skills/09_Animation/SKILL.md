---
name: Animation
description: Add tasteful, performant motion to a Flutter app — implicit vs explicit animations, page/shared-axis/container transitions, Hero continuity, staggered lists, and micro-interactions. Use when a screen needs transitions, a widget should animate state changes, lists should animate in, or the app needs polished micro-interactions. Stage 09 of the pipeline.
when_to_use: Trigger on "animate this", "add a transition", "make it feel smooth/premium", "animate the list", "Hero from list to detail", "button press feedback", "the screen change is abrupt", or "fix the jank". For one-off theming pick stage 04; for page routing wiring pick stage 07. This stage owns motion — how things move, not what they look like or where they route.
---

# Animation

Motion makes a UI feel alive — but only when it is **consistent, fast, and honest**.
Every duration and curve in the app comes from one place: `AppMotion` in `AppTokens`
(stage 04). Never hardcode a `Duration(milliseconds: 300)` in a feature widget —
read `context.tokens.motion.medium`. That is what makes the whole app feel like one
system instead of a pile of independently-timed widgets.

House style: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).
Related stages: **04** (motion tokens), **07** (page transitions / go_router), **17** (responsive layout).

**Exit gate:** *animations run 60fps; no jank in profile mode.*

---

## The motion tokens (from stage 04)

All timing is sourced from `AppTokens.motion` (`AppMotion`). Reference by import:
`Theme.of(context).extension<AppTokens>()!.motion` or `context.tokens.motion`.

| Token | Value | Use for |
|---|---|---|
| `motion.fast` | 120ms | taps, toggles, small state flips |
| `motion.medium` | 240ms | most transitions, switchers, list items |
| `motion.slow` | 400ms | page/hero/emphasis moments |
| `motion.standard` | `easeInOutCubicEmphasized` | default for UI changes |
| `motion.emphasized` | `easeOutCubic` | high-emphasis enter/exit |

Picking timing from tokens is the single most important rule in this stage.

---

## Decision: implicit vs explicit

**Reach for implicit animations first.** They are the simplest correct thing and
they cannot leak: Flutter owns the controller. Use explicit only when implicit
can't express what you need.

### Implicit — animate *toward a target value*, no controller

Use when a property changes and you just want it to glide to the new value.

- `AnimatedContainer` / `AnimatedPadding` / `AnimatedAlign` / `AnimatedOpacity` /
  `AnimatedPositioned` — animate layout/visual props when they change.
- `AnimatedSwitcher` — cross-fade/scale between two *different child widgets*
  (give the children distinct `Key`s or the switch won't fire).
- `TweenAnimationBuilder` — one-shot drive from begin→end on build (e.g. count-up,
  entrance scale) without owning a controller.

```dart
// Implicit: glides whenever `_expanded` flips. No controller, nothing to dispose.
AnimatedContainer(
  duration: context.tokens.motion.medium,
  curve: context.tokens.motion.standard,
  height: _expanded ? 200 : 80,
)
```

### Explicit — you need to *drive, repeat, reverse, sequence, or fling*

Use when you need to: replay/reverse on demand, loop, chain intervals (stagger),
drive multiple tweens from one timeline, or respond to gestures/physics.

- `AnimationController` (the clock) + `Tween`/`CurvedAnimation` + `AnimatedBuilder`
  (rebuilds only the animated subtree) or a `*Transition` widget
  (`FadeTransition`, `SlideTransition`, `ScaleTransition`, `RotationTransition`).
- Prefer a `*Transition` widget over `AnimatedBuilder` when one exists — it's
  cheaper and clearer.

```dart
class Pulse extends StatefulWidget {
  const Pulse({required this.child, super.key});
  final Widget child;
  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    // vsync ties the controller to the screen's frame ticker.
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _scale = Tween(begin: 0.97, end: 1.03)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose(); // ALWAYS. A leaked controller ticks forever.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}
```

### Controller lifecycle — the rules that prevent leaks

1. Create the controller in `initState`, not `build`.
2. Mix in `SingleTickerProviderStateMixin` (one controller) or
   `TickerProviderStateMixin` (several) and pass `vsync: this`.
3. **`dispose()` every controller** in `State.dispose`. This is the #1 source of
   "ticker was active when disposed" errors and silent battery drain.
4. Duration comes from a token; read it from `context.tokens.motion` (in
   `didChangeDependencies` if you need it at controller-construction time, since
   `Theme.of` isn't available in `initState`).

---

## Page & shared-axis transitions (with go_router)

Material's `animations` package (`package:animations`) provides the four canonical
M3 transition patterns. Wire them into go_router via `CustomTransitionPage`:

| Pattern | When |
|---|---|
| **Shared axis (X)** | forward/back between peer screens (wizard, tabs you push) |
| **Shared axis (Y)** | up/down hierarchy (e.g. expand a section into a page) |
| **Shared axis (Z)** | drill in/out of a hierarchy (parent → child) |
| **Fade through** | switching between unrelated top-level destinations |
| **Container transform** | a tappable element grows into the screen it opens |

Use the ready-made builders in [`templates/transitions.dart`](templates/transitions.dart).
In a `GoRoute`, return a `pageBuilder` instead of `builder`:

```dart
GoRoute(
  path: AppRoute.itemDetail.path,
  name: AppRoute.itemDetail.name,
  pageBuilder: (context, state) => buildSharedAxisPage(
    context: context,
    state: state,
    type: SharedAxisTransitionType.horizontal,
    child: ItemDetailScreen(id: state.pathParameters['id']!),
  ),
)
```

The builders read durations/curves from `AppTokens` and collapse to a plain page
when reduce-motion is on. For **container-transform** (list card → detail), prefer
`OpenContainer` from the `animations` package at the call site, or a `Hero` if you
only need a single element to fly.

---

## Hero — visual continuity across a route change

When the *same element* exists on both screens (a thumbnail, an avatar, a title),
wrap it in `Hero` with a matching `tag` on each screen. Flutter flies it between
positions during the route transition. This pairs beautifully with shared-axis Z.

```dart
// On the list tile AND the detail screen:
Hero(tag: 'item-${item.id}', child: ItemThumbnail(item));
```

Rules: tags must be **unique per screen** and **match** across the two screens; in
lists, make the tag include the id. Keep the two children visually similar (size,
shape) so the flight reads as one object. Don't Hero text whose font size changes
wildly — it stretches; cross-fade instead. Reduce-motion: the route transition
already degrades, so the Hero simply cuts.

---

## Staggered / entrance animations for lists

Animate list items **in sequence** so a screen assembles instead of popping. Use
the helper in [`templates/staggered_list.dart`](templates/staggered_list.dart),
which fades + slides each child with a per-index delay capped so long lists don't
crawl.

Principles:
- Stagger only the **first paint** of items that are on-screen — don't re-stagger
  on every scroll/rebuild (that's jank and nausea).
- Cap the delay (e.g. 8 items × `fast` then stop) so a 500-item list doesn't take
  a minute to appear.
- Each item still gets a stable `Key` (CONVENTIONS §4).
- Honor reduce-motion: render items at rest, no delay.

---

## Micro-interactions

Small, fast feedback that confirms a touch did something. They use tokens so they
feel uniform. See [`templates/micro_interactions.dart`](templates/micro_interactions.dart):

- **`PressableScale`** — scales a widget down ~3% on press (an explicit controller,
  `motion.fast`). Wrap any tappable card/button-like element.
- **Like / favorite toggle** — animated heart that scales+colors on toggle
  (implicit `AnimatedSwitcher` + a small pop).
- **Success checkmark** — a one-shot `TweenAnimationBuilder` draw-on, for confirming
  a completed action.

Keep micro-interactions at `fast`/`medium`; anything slower feels laggy on a tap.

---

## Performance — earning the 60/120fps gate

Animation jank is almost always *too much work per frame*, not the animation itself.

- **`const` everywhere** the subtree doesn't change — const widgets are skipped on
  rebuild (CONVENTIONS §4).
- **`RepaintBoundary`** around an animating subtree isolates its repaints from the
  rest of the screen (and vice-versa). Wrap the moving thing, and wrap expensive
  static neighbors.
- **Animate transforms/opacity, not layout.** Prefer `SlideTransition`/`Transform`
  over animating `width`/`height`/`padding`, which re-runs layout every frame.
- **Rebuild the smallest subtree.** Put the animated bit behind `AnimatedBuilder`'s
  `child:` (passed-through, built once) or a `*Transition` widget — don't rebuild
  the whole screen each tick.
- **Keep work off the build thread.** No I/O, JSON, or heavy compute in `build` or
  in an animation callback; precompute, or use `compute`/isolates.
- **Profile honestly.** Run in **profile mode**, enable the performance overlay
  (`MaterialApp(showPerformanceOverlay: true)` or DevTools), and watch the raster +
  UI bars. A spike = a dropped frame. The gate is met only when both bars stay under
  the 16ms (60fps) / 8ms (120fps) line during the animation.

---

## Accessibility — honor reduce-motion (mandatory)

The OS "reduce motion" setting surfaces as `MediaQuery.of(context).disableAnimations`
(true when the user has asked for less motion). When it's true:

- Skip non-essential motion: no parallax, no big slides, no looping pulses.
- Keep *essential* state changes but make them instant or a gentle cross-fade.
- All templates here check it via a tiny helper:
  `final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;`

Never gate functionality on an animation completing — a reduce-motion user must
reach the same end state immediately.

---

## Anti-patterns (don't ship these)

- **Animating in `build` without a controller** — e.g. starting a `Future.delayed`
  loop that calls `setState`. Use an implicit widget or a disposed controller.
- **Not disposing controllers** — leaks the ticker, drains battery, throws on unmount.
- **Hardcoded durations/curves** — breaks system consistency. Use `context.tokens.motion`.
- **Over-animating** — everything bouncing/sliding is noise; motion should direct
  attention, not compete for it. If two things animate at once, ask which one matters.
- **Long-duration motion** (>~400ms for routine UI) — feels sluggish; reserve `slow`
  for genuine emphasis.
- **Re-staggering lists on every rebuild/scroll** — animate entrance once.
- **Animating layout properties** when a transform would do — needless per-frame layout.
- **Ignoring reduce-motion** — fails accessibility and the stage's a11y bar.

---

## Definition of done for this stage

- Page transitions wired through go_router using token-driven builders.
- Key state changes animate via implicit widgets or properly-disposed controllers.
- Lists animate in (staggered, capped, once) where it adds clarity.
- Micro-interactions present on primary tappables, all reading tokens.
- `MediaQuery.disableAnimations` honored everywhere.
- Verified in **profile mode** with the performance overlay: no dropped frames during
  any animation. **Then the exit gate passes.**
