// core/error/failure_x.dart
//
// The data → UI translation layer for errors. Maps each typed [Failure] to
// user-facing copy + an optional recovery action. The presentation layer reads
// THIS, never `Failure.message` (which is developer-facing).
//
// Every failure MUST yield a recovery action where one is meaningful — see the
// anti-pattern list in SKILL.md ("Something went wrong" with no way out).
//
// See ../../references/CONVENTIONS.md §5.

import 'failure.dart';

/// User-facing presentation of a [Failure].
class FailureUx {
  const FailureUx({
    required this.title,
    required this.message,
    this.actionLabel,
  });

  /// Short headline, e.g. "No connection".
  final String title;

  /// One or two sentences the user can act on.
  final String message;

  /// Label for the recovery affordance (e.g. "Retry", "Sign in"), or `null`
  /// when there is no sensible recovery beyond dismissing.
  final String? actionLabel;
}

/// Maps a [Failure] to its user-facing presentation. Exhaustive over the
/// sealed hierarchy, so adding a new [Failure] is a compile error here until
/// you give it copy — by design.
extension FailureX on Failure {
  FailureUx get ux => switch (this) {
        NetworkFailure() => const FailureUx(
            title: 'No connection',
            message:
                "We couldn't reach the server. Check your internet and try "
                'again.',
            actionLabel: 'Retry',
          ),
        TimeoutFailure() => const FailureUx(
            title: 'This is taking too long',
            message: 'The request timed out. Please try again.',
            actionLabel: 'Retry',
          ),
        UnauthorizedFailure() => const FailureUx(
            title: 'Session expired',
            message: 'Please sign in again to continue.',
            actionLabel: 'Sign in',
          ),
        NotFoundFailure() => const FailureUx(
            title: 'Not found',
            message: "We couldn't find what you were looking for.",
            actionLabel: 'Go back',
          ),
        final ValidationFailure f => FailureUx(
            title: 'Check your details',
            message: f.fieldErrors.isNotEmpty
                ? f.fieldErrors.values.first
                : 'Some of the information looks incorrect. Please review and '
                    'try again.',
            actionLabel: null, // inline field errors handle recovery
          ),
        CacheFailure() => const FailureUx(
            title: "Couldn't load saved data",
            message: 'Something went wrong reading your saved data. '
                'Pull to refresh to reload.',
            actionLabel: 'Reload',
          ),
        UnknownFailure() => const FailureUx(
            title: 'Something went wrong',
            message: 'An unexpected error occurred. Please try again — if it '
                'keeps happening, contact support.',
            actionLabel: 'Retry',
          ),
      };

  /// Convenience accessors for call sites that only need one field.
  String get uxTitle => ux.title;
  String get uxMessage => ux.message;
  String? get uxActionLabel => ux.actionLabel;
}
