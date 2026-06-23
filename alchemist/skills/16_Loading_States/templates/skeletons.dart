// core/widgets/skeletons.dart
//
// Lightweight skeleton placeholders + a dependency-free Shimmer effect.
// Owned by skill 16 (Loading_States). Skeletons mirror the FINAL layout so the
// page does not shift (layout jank) when real data arrives.
//
// Colors come from the M3 surface roles; the pulse duration comes from
// AppTokens.motion (skill 04). No external shimmer package — a ShaderMask
// sweep driven by an AnimatedBuilder.

import 'package:flutter/material.dart';

// Skill 04 design tokens. `context.tokens` resolves AppTokens from the theme.
//   import 'package:app/app/theme/app_tokens.dart';

/// A dependency-free shimmer. Sweeps a soft highlight across [child] (which is
/// usually a tree of [SkeletonBox]es). Driven by a [ShaderMask] so it shimmers
/// the actual skeleton shapes, not a rectangle over them.
///
/// ```dart
/// Shimmer(child: const ListTileSkeleton());
/// ```
class Shimmer extends StatefulWidget {
  const Shimmer({required this.child, this.enabled = true, super.key});

  final Widget child;

  /// Set false to freeze the sweep (e.g. when reduce-motion is on — see
  /// [Shimmer.maybeReduceMotion]).
  final bool enabled;

  /// Honors the platform "reduce motion" a11y setting: returns a still
  /// skeleton (no animated sweep) when the user has disabled animations.
  static bool maybeReduceMotion(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    // Pull the cadence from motion tokens; ~1.2s reads as "alive" not "frantic".
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _controller.repeat();
  }

  @override
  void didUpdateWidget(Shimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.enabled && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Base = the skeleton fill; highlight = the moving glint. Both derive from
    // surface roles so the effect is subtle in light AND dark.
    final base = scheme.surfaceContainerHighest;
    final highlight = Color.alphaBlend(
      scheme.onSurface.withValues(alpha: 0.08),
      base,
    );

    if (!widget.enabled || Shimmer.maybeReduceMotion(context)) {
      // Still skeleton — no animation, no jank, respects reduce-motion.
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value; // 0..1
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1 - 2 * t, 0),
              end: Alignment(1 - 2 * t, 0),
              colors: [base, highlight, base],
              stops: const [0.35, 0.5, 0.65],
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

/// A single rounded skeleton shape. Compose these to mirror a real widget's
/// box model. Defaults read from the M3 surface roles + a token radius.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    this.width,
    this.height = 16,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    super.key,
  });

  /// A circle (e.g. an avatar) of the given diameter.
  const SkeletonBox.circle(double diameter, {Key? key})
      : width = diameter,
        height = diameter,
        borderRadius = null,
        shape = BoxShape.circle,
        super(key: key);

  final double? width;
  final double height;
  final BorderRadius? borderRadius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 12 is AppTokens.radius.md; replace with `context.tokens.radius.md` once
    // the design tokens are present in the host app.
    final radius = borderRadius ?? BorderRadius.circular(12);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        shape: shape,
        borderRadius: shape == BoxShape.circle ? null : radius,
      ),
    );
  }
}

/// Skeleton mirroring a leading-avatar + two-line [ListTile]. Wrap a column of
/// these in a [Shimmer] for a list placeholder.
class ListTileSkeleton extends StatelessWidget {
  const ListTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    // 16 == spacing.md, 8 == spacing.sm (AppTokens). Use context.tokens in app.
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox.circle(48),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 160, height: 14),
                SizedBox(height: 8),
                SkeletonBox(width: 240, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A whole list placeholder: [count] tile skeletons under one shimmer sweep.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({this.count = 6, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.builder(
        itemCount: count,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (_, __) => const ListTileSkeleton(),
      ),
    );
  }
}

/// Skeleton mirroring a media card: image banner, title, subtitle.
class CardSkeleton extends StatelessWidget {
  const CardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    // 16 == radius.lg / spacing.md (AppTokens).
    return Shimmer(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(
              height: 160,
              borderRadius: BorderRadius.circular(16),
            ),
            const SizedBox(height: 16),
            const SkeletonBox(width: 200, height: 16),
            const SizedBox(height: 8),
            const SkeletonBox(width: double.infinity, height: 12),
            const SizedBox(height: 6),
            const SkeletonBox(width: 140, height: 12),
          ],
        ),
      ),
    );
  }
}

/// Footer shown at the end of a paginated list while the next page loads.
/// Keeps the loaded items visible — never replace the list with a spinner.
class PaginationFooter extends StatelessWidget {
  const PaginationFooter({this.error, this.onRetry, super.key});

  /// When non-null, the next-page load failed — show a compact retry row
  /// instead of a spinner.
  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Failed to load more — retry'),
          ),
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
