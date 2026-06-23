// lib/core/widgets/staggered_list.dart
//
// Entrance-animation helper: fades + slides children in, staggered by index, so a
// list assembles instead of popping. Timing comes from AppTokens.motion (stage 04).
//   import '../../app/theme/app_tokens.dart'; // for AppTokens / context.tokens
//
// Design rules baked in:
//   * Each item animates in ONCE (on first build), not on every scroll/rebuild —
//     re-staggering on rebuild is jank and makes users queasy.
//   * The per-index delay is CAPPED (maxStaggered) so a 500-item list still
//     finishes promptly; items past the cap appear at rest.
//   * Reduce-motion (MediaQuery.disableAnimations) => items render at rest, no delay.
//   * Animates transform + opacity only (no layout), wrapped so repaints stay local.
//
// House style: ../../references/CONVENTIONS.md (const, keys on list items, a11y).
//
// PLACEHOLDER: AppTokens/AppMotion shim at the bottom — DELETE and import stage 04.

import 'package:flutter/material.dart';

bool _reduceMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// Wraps a single child in a fade + upward-slide entrance, delayed by [index]
/// steps. Self-contained: owns and disposes its controller, starts on mount.
///
/// Prefer the [StaggeredColumn]/[buildStaggeredListItem] helpers below; use this
/// directly only for bespoke layouts.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    required this.index,
    required this.child,
    this.maxStaggered = 8,
    this.slideOffset = 24,
    super.key,
  });

  /// Position in the list. Items beyond [maxStaggered] use the same final delay
  /// so long lists don't crawl.
  final int index;
  final Widget child;

  /// Cap on how many items get an increasing delay.
  final int maxStaggered;

  /// How far (logical px) the child slides up while fading in.
  final double slideOffset;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _opacity = const AlwaysStoppedAnimation(1);
    _slide = const AlwaysStoppedAnimation(Offset.zero);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return; // configure + start exactly once
    _started = true;

    final reduce = _reduceMotion(context);
    if (reduce) {
      _controller.value = 1; // render at rest, no motion
      return;
    }

    final motion = context.tokens.motion;
    _controller.duration = motion.medium;
    _opacity = CurvedAnimation(parent: _controller, curve: motion.standard);
    _slide = Tween<Offset>(
      begin: Offset(0, widget.slideOffset / 100),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: motion.emphasized));

    // Stagger: each item starts `fast` later than the previous, capped.
    final step = (widget.index.clamp(0, widget.maxStaggered)) * motion.fast.inMilliseconds;
    Future<void>.delayed(Duration(milliseconds: step), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary keeps each item's entrance repaint from invalidating siblings.
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(position: _slide, child: widget.child),
      ),
    );
  }
}

/// Convenience for `ListView.builder`/`SliverList`: wrap your item widget so it
/// animates in. Pass a stable [key] from the item's id.
///
/// ```dart
/// ListView.builder(
///   itemCount: items.length,
///   itemBuilder: (context, i) => buildStaggeredListItem(
///     index: i,
///     key: ValueKey(items[i].id),
///     child: ItemCard(items[i]),
///   ),
/// );
/// ```
Widget buildStaggeredListItem({
  required int index,
  required Widget child,
  Key? key,
  int maxStaggered = 8,
}) {
  return StaggeredEntrance(
    key: key,
    index: index,
    maxStaggered: maxStaggered,
    child: child,
  );
}

/// A Column whose children animate in, staggered. For short, non-scrolling
/// groups (a card's rows, a small menu). For long/scrolling lists use
/// [buildStaggeredListItem] inside a `ListView.builder` instead.
class StaggeredColumn extends StatelessWidget {
  const StaggeredColumn({
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.maxStaggered = 8,
    super.key,
  });

  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final int maxStaggered;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++)
          StaggeredEntrance(
            index: i,
            maxStaggered: maxStaggered,
            child: children[i],
          ),
      ],
    );
  }
}

// =============================================================================
// PLACEHOLDER tokens — DELETE in a real app; import from stage 04 instead.
// =============================================================================

class AppMotion {
  const AppMotion();
  final Duration fast = const Duration(milliseconds: 120);
  final Duration medium = const Duration(milliseconds: 240);
  final Duration slow = const Duration(milliseconds: 400);
  final Curve standard = Curves.easeInOutCubicEmphasized;
  final Curve emphasized = Curves.easeOutCubic;
}

class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({this.motion = const AppMotion()});
  final AppMotion motion;
  @override
  AppTokens copyWith({AppMotion? motion}) =>
      AppTokens(motion: motion ?? this.motion);
  @override
  AppTokens lerp(covariant ThemeExtension<AppTokens>? other, double t) => this;
}

extension BuildContextTokens on BuildContext {
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ?? const AppTokens();
}
