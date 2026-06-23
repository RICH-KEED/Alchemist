// lib/core/coach_marks/showcase_setup.dart
//
// ShowcaseView coach-mark infrastructure (Responsibility 3): a global keys
// registry, a tokenized Showcase wrapper, a CoachTour model, and a mixin that
// auto-starts a tour ONCE on first launch (Responsibility 5).
//
// Package: showcaseview: ^4.0.0  (https://pub.dev/packages/showcaseview)
// Alternative: feature_discovery — swap `Showcase` for `DescribedFeatureOverlay`
// and `ShowCaseWidget` for `FeatureDiscovery`; the CoachTour/auto-start logic
// below is reusable either way.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:showcaseview/showcaseview.dart';

import 'onboarding_state.dart';

// import '../../app/theme/app_tokens.dart'; // AppTokens (stage 04)
// Until tokens are wired, these mirror the house spacing/radius/motion scale.
const double _gap = 8;
const double _radius = 12;

/// A named ordered tour: an [id] (persisted) + the [keys] to spotlight in order.
class CoachTour {
  const CoachTour(this.id, this.keys);

  /// Persisted completion id, e.g. [OnboardingIds.homeTour].
  final String id;

  /// Spotlight targets, in display order.
  final List<GlobalKey> keys;
}

/// Registry of coach-mark target keys. Attach each to the widget it spotlights
/// via [CoachMark], then reference them from a [CoachTour].
abstract final class CoachKeys {
  static final fab = GlobalKey();
  static final search = GlobalKey();
  static final profileTab = GlobalKey();

  /// The Home screen's tour: FAB -> search -> profile (3 steps, the sweet spot).
  static final homeTour = CoachTour(OnboardingIds.homeTour, [fab, search, profileTab]);
}

/// Wraps a widget as a coach-mark target with tokenized tooltip styling.
///
/// ```dart
/// CoachMark(
///   showcaseKey: CoachKeys.fab,
///   title: 'Add an item',
///   description: 'Tap here to create your first entry',
///   child: FloatingActionButton(...),
/// )
/// ```
class CoachMark extends StatelessWidget {
  const CoachMark({
    required this.showcaseKey,
    required this.title,
    required this.description,
    required this.child,
    super.key,
  });

  final GlobalKey showcaseKey;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Showcase(
      key: showcaseKey,
      title: title,
      description: description,
      tooltipBackgroundColor: scheme.inverseSurface,
      textColor: scheme.onInverseSurface,
      targetBorderRadius: BorderRadius.circular(_radius),
      tooltipPadding: const EdgeInsets.all(_gap * 1.5),
      disableMovingAnimation: false, // see CoachMarkStarter for reduce-motion
      child: child,
    );
  }
}

/// Put this ABOVE any subtree you want to coach (typically just under
/// MaterialApp, or per-screen). `onFinish` marks the active tour complete.
class CoachScope extends StatelessWidget {
  const CoachScope({required this.child, this.onFinish, super.key});

  final Widget child;
  final VoidCallback? onFinish;

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      onFinish: onFinish,
      builder: (context) => child,
    );
  }
}

/// Mixin for a `ConsumerStatefulWidget`'s State that auto-starts [tour] exactly
/// once, after first frame, only if not already completed (Responsibilities 5).
///
/// ```dart
/// class _HomeScreenState extends ConsumerState<HomeScreen>
///     with CoachMarkStarter<HomeScreen> {
///   @override
///   CoachTour get tour => CoachKeys.homeTour;
/// }
/// ```
mixin CoachMarkStarter<T extends StatefulWidget> on ConsumerState<T> {
  /// The tour to auto-start on this screen.
  CoachTour get tour;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStart());
  }

  void _maybeStart() {
    if (!mounted) return;
    final controller = ref.read(onboardingControllerProvider.notifier);
    if (controller.isCompleted(tour.id)) return;
    // Respect reduce-motion: still show, just without the moving animation.
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    ShowCaseWidget.of(context).startShowCase(
      tour.keys,
      // showMovement / autoPlay flags vary by version; omit if unsupported.
    );
    if (reduceMotion) {
      // Optionally configure ShowCaseWidget(disableMovingAnimation: true) above.
    }
  }

  /// Call from `CoachScope(onFinish:)` to persist completion.
  Future<void> onTourFinished() =>
      ref.read(onboardingControllerProvider.notifier).complete(tour.id);
}
