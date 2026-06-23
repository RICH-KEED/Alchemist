// core/error/app_error_boundary.dart
//
// Two complementary safety nets for *build-phase* errors:
//
//  1. [AppErrorBoundary] — wrap any subtree to catch errors thrown while its
//     descendants build, and render a friendly fallback instead of a red box.
//  2. [installReleaseErrorWidget] — replaces Flutter's default red error box
//     (which is fine in debug) with a calm fallback in release builds.
//
// These handle the *widget tree*. App-wide uncaught errors (async, platform,
// zone) are caught in main.dart via FlutterError.onError /
// PlatformDispatcher.onError / runZonedGuarded — wired in skill 06, and routed
// to the crash reporter in skill 23. See SKILL.md "The global boundary".

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Catches errors thrown by [child]'s descendants during build/layout/paint
/// and shows [fallbackBuilder] instead. Use it around a screen body or a risky
/// section so one broken widget can't take down the whole app.
///
/// Note: like all Flutter error boundaries this catches *synchronous build*
/// errors surfaced through [FlutterError.onError]; it is not a substitute for
/// the typed [Result] flow that handles expected, recoverable failures.
class AppErrorBoundary extends StatefulWidget {
  const AppErrorBoundary({
    required this.child,
    this.fallbackBuilder,
    this.onError,
    super.key,
  });

  final Widget child;

  /// Builds the fallback shown after an error. Receives the captured details
  /// and a [retry] callback that clears the error and rebuilds [child].
  final Widget Function(
    BuildContext context,
    FlutterErrorDetails details,
    VoidCallback retry,
  )? fallbackBuilder;

  /// Optional hook (e.g. forward to the crash reporter from skill 23).
  final void Function(FlutterErrorDetails details)? onError;

  @override
  State<AppErrorBoundary> createState() => _AppErrorBoundaryState();
}

class _AppErrorBoundaryState extends State<AppErrorBoundary> {
  FlutterErrorDetails? _details;
  FlutterExceptionHandler? _previousOnError;

  @override
  void initState() {
    super.initState();
    // Scope a handler so build errors below us are captured here. We still
    // forward to the previously-installed handler (global boundary / crash
    // reporting) so nothing is swallowed.
    _previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      _previousOnError?.call(details);
      widget.onError?.call(details);
      if (mounted) setState(() => _details = details);
    };
  }

  @override
  void dispose() {
    FlutterError.onError = _previousOnError;
    super.dispose();
  }

  void _retry() => setState(() => _details = null);

  @override
  Widget build(BuildContext context) {
    final details = _details;
    if (details == null) return widget.child;
    return widget.fallbackBuilder?.call(context, details, _retry) ??
        _DefaultBoundaryFallback(details: details, onRetry: _retry);
  }
}

class _DefaultBoundaryFallback extends StatelessWidget {
  const _DefaultBoundaryFallback({required this.details, required this.onRetry});

  final FlutterErrorDetails details;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: scheme.error),
              const SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This part of the app ran into a problem.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 12),
                Text(
                  details.exceptionAsString(),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      ),
    );
  }
}

/// Replace Flutter's default red error box with a calm fallback in RELEASE
/// builds. In debug the loud red box is kept — you *want* to see it.
///
/// Call once during bootstrap (main.dart, skill 06):
/// ```dart
/// installReleaseErrorWidget();
/// ```
void installReleaseErrorWidget() {
  if (kReleaseMode) {
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return _ReleaseErrorWidget(details: details);
    };
  }
}

/// Minimal, theme-agnostic fallback used when an [ErrorWidget] is built outside
/// of (or before) a [Material] ancestor. Kept dependency-free on purpose.
class _ReleaseErrorWidget extends StatelessWidget {
  const _ReleaseErrorWidget({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: Color(0xFF1C1B1F),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Something went wrong.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFE6E1E5), fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}
