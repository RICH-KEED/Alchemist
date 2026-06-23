// lib/app/router/transitions.dart
//
// Reusable go_router page builders for the canonical Material 3 motion patterns,
// backed by the `animations` package. Drop these into a `GoRoute.pageBuilder`.
//
// Every builder reads its duration/curve from AppTokens.motion (stage 04) so the
// whole app's navigation feels like one system — never hardcode timing here.
//   import '../theme/app_tokens.dart'; // for AppTokens / context.tokens
//
// Reduce-motion: when MediaQuery.disableAnimations is set, every builder collapses
// to a plain, instant page (no slide/fade). Functionality is unchanged.
//
// House style: ../../references/CONVENTIONS.md (routing = go_router; tokens for motion).
//
// pubspec: animations: ^2.0.0, go_router: ^14.0.0
//
// PLACEHOLDER: a minimal `AppTokens`/`AppMotion`/`context.tokens` shim lives at the
// bottom so this file compiles in isolation. In a real app, DELETE the shim and
// import the real tokens from stage 04 (lib/app/theme/app_tokens.dart).

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// True when the user has asked the OS for reduced motion.
bool _reduceMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// A page with no transition — used as the reduce-motion fallback and for cases
/// where an instant cut is correct.
CustomTransitionPage<T> _instantPage<T>(GoRouterState state, Widget child) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    transitionsBuilder: (_, __, ___, child) => child,
  );
}

/// Shared-axis transition (Material 3). Use for movement between peer screens:
///   * [SharedAxisTransitionType.horizontal] — forward/back in a flow (wizard).
///   * [SharedAxisTransitionType.vertical]   — up/down a hierarchy.
///   * [SharedAxisTransitionType.scaled]     — drill in/out of a hierarchy (Z).
///
/// ```dart
/// GoRoute(
///   path: AppRoute.itemDetail.path,
///   pageBuilder: (context, state) => buildSharedAxisPage(
///     context: context,
///     state: state,
///     type: SharedAxisTransitionType.horizontal,
///     child: ItemDetailScreen(id: state.pathParameters['id']!),
///   ),
/// );
/// ```
CustomTransitionPage<T> buildSharedAxisPage<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
  SharedAxisTransitionType type = SharedAxisTransitionType.horizontal,
}) {
  if (_reduceMotion(context)) return _instantPage<T>(state, child);

  final motion = context.tokens.motion;
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: motion.slow,
    reverseTransitionDuration: motion.slow,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        transitionType: type,
        // Let the route's container surface paint behind the transition.
        fillColor: Theme.of(context).colorScheme.surface,
        child: child,
      );
    },
  );
}

/// Fade-through transition (Material 3). Use when switching between *unrelated*
/// top-level destinations (e.g. swapping a body via the router) — the outgoing
/// screen fades + scales out, the incoming fades + scales in.
CustomTransitionPage<T> buildFadeThroughPage<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  if (_reduceMotion(context)) return _instantPage<T>(state, child);

  final motion = context.tokens.motion;
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: motion.medium,
    reverseTransitionDuration: motion.medium,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeThroughTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        fillColor: Theme.of(context).colorScheme.surface,
        child: child,
      );
    },
  );
}

/// Convenience wrappers so call sites stay terse and intent-revealing.
extension SharedAxisPages on GoRouterState {
  // Intentionally empty placeholder for future per-route helpers; kept so call
  // sites can grow without touching the builders above.
}

// =============================================================================
// PLACEHOLDER tokens — DELETE in a real app; import from stage 04 instead.
// Mirrors AppMotion from skills/04_Premium_Design_System/templates/app_tokens.dart.
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
