// core/widgets/error_state.dart
//
// A reusable, friendly error surface with a retry action. Owned by skill 16
// (Loading_States), but the *copy* it shows comes from skill 15's Failure UX.
//
// Contract: a Failure (skill 15) is never shown to the user via its raw
// `.message` (that's developer-facing). Instead skill 15 ships a `failure_x.dart`
// extension that maps each Failure to user-facing copy:
//
//   import 'package:app/core/error/failure.dart';
//   import 'package:app/core/error/failure_x.dart'; // FailureUx on Failure
//
//   extension FailureUx on Failure {
//     String get title;          // e.g. "You're offline"
//     String get description;    // e.g. "Check your connection and try again."
//     IconData get icon;         // e.g. Icons.wifi_off
//     bool get isRetryable;      // e.g. false for UnauthorizedFailure
//   }
//
// When a real Failure is available we use that mapping; otherwise we fall back
// to a generic friendly message. NEVER a dead-end: always offer retry (or, for
// non-retryable failures like Unauthorized, a relevant action the caller wires).

import 'package:flutter/material.dart';

// import 'package:app/core/error/failure.dart';
// import 'package:app/core/error/failure_x.dart';

/// A friendly full-surface error with an icon, title, message and a retry
/// button. Construct it from a [Failure] (preferred — uses skill 15's UX
/// mapping) or from raw title/message for non-Failure errors.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    required this.title,
    required this.message,
    this.icon = Icons.error_outline,
    this.onRetry,
    this.retryLabel = 'Try again',
    super.key,
  });

  /// Build from any thrown error. If it is a [Failure], delegate to its
  /// `failure_x` UX mapping; otherwise show a generic friendly message.
  ///
  /// Wire this from [AsyncValueView]'s default error branch:
  /// ```dart
  /// ErrorStateView.fromError(err, stackTrace: st, onRetry: onRetry);
  /// ```
  factory ErrorStateView.fromError(
    Object error, {
    StackTrace? stackTrace,
    VoidCallback? onRetry,
  }) {
    // When skill 15 is present, replace this block with:
    //   if (error is Failure) {
    //     return ErrorStateView(
    //       icon: error.icon,
    //       title: error.title,
    //       message: error.description,
    //       onRetry: error.isRetryable ? onRetry : null,
    //     );
    //   }
    return ErrorStateView(
      icon: Icons.error_outline,
      title: 'Something went wrong',
      message: "We couldn't complete that. Please try again.",
      onRetry: onRetry,
    );
  }

  final String title;
  final String message;
  final IconData icon;

  /// Retry callback — typically `() => ref.invalidate(theProvider)`. When null
  /// the button is hidden (e.g. a non-retryable failure); the caller should
  /// then provide an alternative path (re-auth, go home).
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Spacing mirrors AppTokens (sm 8, md 16, lg 24). Use context.tokens in app.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: scheme.error),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact inline error for partial surfaces (a failed widget inside an
/// otherwise-fine screen, or a banner). Keeps surrounding content intact.
class InlineErrorBanner extends StatelessWidget {
  const InlineErrorBanner({
    required this.message,
    this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }
}
