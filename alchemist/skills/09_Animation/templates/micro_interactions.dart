// lib/core/widgets/micro_interactions.dart
//
// Small, reusable feedback animations. They confirm a touch did something and
// keep the app feeling responsive. All timing comes from AppTokens.motion
// (stage 04) so micro-interactions feel uniform across the app.
//   import '../../app/theme/app_tokens.dart'; // for AppTokens / context.tokens
//
// Reduce-motion: each widget checks MediaQuery.disableAnimations and degrades to
// an instant state change — the action still works, it just doesn't animate.
//
// House style: ../../references/CONVENTIONS.md (tokens for motion, const, a11y).
//
// PLACEHOLDER: a minimal AppTokens/AppMotion shim is at the bottom so this file
// compiles standalone. DELETE it in a real app and import from stage 04.

import 'package:flutter/material.dart';

bool _reduceMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// Scales its [child] down slightly while pressed, springing back on release —
/// the standard "this is tappable and you touched it" feedback.
///
/// Explicit animation (we need to drive forward on press-down and reverse on
/// release), so it owns a controller and disposes it. Wrap any card/tile/button
/// surface:
///
/// ```dart
/// PressableScale(
///   onTap: () => context.go(AppRoute.itemDetailLocation(item.id)),
///   child: ItemCard(item),
/// );
/// ```
class PressableScale extends StatefulWidget {
  const PressableScale({
    required this.child,
    this.onTap,
    this.pressedScale = 0.97,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// How far to scale down while held (1.0 = no scale).
  final double pressedScale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    // Duration is set in didChangeDependencies, where Theme/tokens are available.
    _controller = AnimationController(vsync: this);
    _scale = AlwaysStoppedAnimation(1);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = context.tokens.motion;
    _controller.duration = motion.fast;
    _scale = Tween<double>(begin: 1, end: widget.pressedScale)
        .animate(CurvedAnimation(parent: _controller, curve: motion.emphasized));
  }

  @override
  void dispose() {
    _controller.dispose(); // never leak the ticker
    super.dispose();
  }

  void _down(_) {
    if (_reduceMotion(context)) return;
    _controller.forward();
  }

  void _up([_]) {
    if (_controller.value > 0) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _down,
      onTapUp: _up,
      onTapCancel: _up,
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      // ScaleTransition is cheaper than AnimatedBuilder and only repaints the
      // child subtree (which is passed through, not rebuilt each frame).
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

/// An animated like / favorite toggle. The icon swaps (outline ↔ filled) with a
/// small pop and a color change. Uses implicit animation (`AnimatedSwitcher`) —
/// no controller to manage — which is the right tool for "cross-fade between two
/// child widgets when a value flips".
///
/// ```dart
/// LikeButton(
///   liked: state.isLiked,
///   onChanged: (v) => ref.read(itemController.notifier).setLiked(v),
/// );
/// ```
class LikeButton extends StatelessWidget {
  const LikeButton({
    required this.liked,
    required this.onChanged,
    this.size = 28,
    super.key,
  });

  final bool liked;
  final ValueChanged<bool> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final motion = context.tokens.motion;
    final reduce = _reduceMotion(context);
    final color =
        liked ? Theme.of(context).colorScheme.error : Theme.of(context).iconTheme.color;

    return Semantics(
      button: true,
      label: liked ? 'Unlike' : 'Like',
      child: IconButton(
        // 48dp min touch target (CONVENTIONS §4) — IconButton enforces this.
        onPressed: () => onChanged(!liked),
        icon: AnimatedSwitcher(
          duration: reduce ? Duration.zero : motion.fast,
          switchInCurve: motion.emphasized,
          // Pop the new icon in by scaling from 0.7 → 1.0 as it fades.
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: Tween<double>(begin: 0.7, end: 1).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: Icon(
            liked ? Icons.favorite : Icons.favorite_border,
            // distinct key per state so AnimatedSwitcher actually transitions
            key: ValueKey<bool>(liked),
            color: color,
            size: size,
          ),
        ),
      ),
    );
  }
}

/// A one-shot success checkmark that draws/pops on first build. Use to confirm a
/// completed action (e.g. inside a success snackbar/sheet). `TweenAnimationBuilder`
/// drives 0→1 on mount without a controller.
class SuccessCheck extends StatelessWidget {
  const SuccessCheck({this.size = 48, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final motion = context.tokens.motion;
    final color = Theme.of(context).colorScheme.primary;
    final reduce = _reduceMotion(context);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: reduce ? 1 : 0, end: 1),
      duration: reduce ? Duration.zero : motion.medium,
      curve: motion.emphasized,
      builder: (context, t, _) {
        return Transform.scale(
          scale: t,
          child: Icon(Icons.check_circle, size: size, color: color),
        );
      },
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
