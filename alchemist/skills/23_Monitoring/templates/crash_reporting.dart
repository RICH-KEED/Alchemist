// lib/core/monitoring/crash_reporting.dart
//
// Stage 23 (Monitoring). Completes the three global error hooks that skill 15
// defined and skill 06's main.dart left as `// TODO(skill-23)`.
//
// Default backend: Sentry (`sentry_flutter`). A Crashlytics swap-in is noted at
// each forwarding point. Whichever backend you pick, the *shape* is the same:
//   1. init the SDK (DSN / Firebase) before runApp,
//   2. forward FlutterError.onError, PlatformDispatcher.onError, and zone errors,
//   3. run the whole app inside a guarded zone so async errors are caught.
//
// pubspec (Sentry):    sentry_flutter: ^8.0.0
// pubspec (Crashlytics): firebase_core, firebase_crashlytics
//
// Privacy: only enabled in release with a real DSN, and (per skill 24) only after
// consent for any non-essential / PII-bearing data. No request bodies, no tokens.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app_logger.dart';

/// Set at build time, e.g. `--dart-define=SENTRY_DSN=https://...`.
/// Empty in debug → reporting is disabled (we keep the red error box instead).
const String _sentryDsn = String.fromEnvironment('SENTRY_DSN');

/// App version/build, used as the Sentry `release`/`dist`. Must match the value
/// the stage-22 CI job keys the uploaded debug-info to, or symbolication fails.
const String _release = String.fromEnvironment('APP_RELEASE');

/// True when crash reporting should actually send events.
/// Debug never reports (it would pollute the dashboard — see SKILL §"Release vs debug").
bool get _reportingEnabled => kReleaseMode && _sentryDsn.isNotEmpty;

/// Bootstraps the whole app with crash reporting + global error hooks installed.
///
/// Replaces the hand-rolled `runZonedGuarded` from skill 06's `main.dart`:
///
/// ```dart
/// Future<void> main() => runAppGuarded(() => const ProviderScope(child: App()));
/// ```
///
/// Everything runs inside one guarded zone so uncaught async errors are funneled
/// to a single place (skill 15's outermost net).
Future<void> runAppGuarded(Widget Function() appBuilder) async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await initCrashReporting(appRunner: () => runApp(appBuilder()));
    },
    (Object error, StackTrace stack) {
      // Outermost catch-all. Zone errors are treated as fatal.
      AppLog.fatal('Uncaught zone error', error: error, stackTrace: stack);
      unawaited(_recordError(error, stack, fatal: true));
    },
  )!;
}

/// Initializes the crash reporter and installs the global hooks, then runs the
/// app via [appRunner]. Initializing *before* `runApp` is what lets the backend
/// measure cold-start performance.
Future<void> initCrashReporting({required FutureOr<void> Function() appRunner}) async {
  if (!_reportingEnabled) {
    // Debug / no-DSN: just wire the hooks to logs so behavior is identical,
    // but nothing leaves the device.
    _installLocalHooks();
    await appRunner();
    return;
  }

  await SentryFlutter.init(
    (SentryFlutterOptions options) {
      options
        ..dsn = _sentryDsn
        ..release = _release
        ..dist = _release
        ..environment = kReleaseMode ? 'production' : 'staging'
        // Performance (SKILL §4): sample traces in production to control volume.
        ..tracesSampleRate = 0.2
        ..enableAutoPerformanceTracing = true
        // Privacy: never attach raw request/response bodies (skill 13/24).
        ..maxRequestBodySize = MaxRequestBodySize.never
        ..sendDefaultPii = false
        // Sentry installs FlutterError.onError for us; we keep the red box in debug.
        ..debug = false;
    },
    // appRunner runs inside Sentry's instrumentation (app-start, screen frames).
    appRunner: appRunner,
  );

  // Sentry owns FlutterError.onError once initialized. We still own the platform
  // dispatcher hook (skill 15's second net) and the zone (the runAppGuarded one).
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppLog.error('Uncaught platform error', error: error, stackTrace: stack);
    unawaited(_recordError(error, stack));
    return true; // handled — but logged + reported first (never silent).
  };

  // ── Crashlytics alternative ────────────────────────────────────────────────
  // Instead of SentryFlutter.init above:
  //   await Firebase.initializeApp();
  //   final crashlytics = FirebaseCrashlytics.instance;
  //   await crashlytics.setCrashlyticsCollectionEnabled(_reportingEnabled);
  //   FlutterError.onError = crashlytics.recordFlutterFatalError;
  //   PlatformDispatcher.instance.onError = (error, stack) {
  //     crashlytics.recordError(error, stack, fatal: true);
  //     return true;
  //   };
  //   await appRunner();
  // ────────────────────────────────────────────────────────────────────────────
}

/// Hooks used when reporting is disabled (debug / no DSN): log only, keep red box.
void _installLocalHooks() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details); // the red box — you want to see it in debug.
    AppLog.error(
      'FlutterError',
      error: details.exception,
      stackTrace: details.stack,
    );
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppLog.error('Uncaught platform error', error: error, stackTrace: stack);
    return true;
  };
}

/// Forwards a non-Flutter error to the active backend. Safe no-op when disabled.
Future<void> _recordError(Object error, StackTrace stack, {bool fatal = false}) async {
  if (!_reportingEnabled) return;
  await Sentry.captureException(error, stackTrace: stack);
  // Crashlytics: FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatal);
}

/// Convenience for code that catches a `Failure` (skill 15) and wants to report a
/// handled, non-fatal problem with context. Call from the data/application layer,
/// not from `build`. Keep [context] PII-free.
Future<void> reportHandled(
  Object error,
  StackTrace stack, {
  Map<String, Object?> context = const <String, Object?>{},
}) async {
  AppLog.warning('Handled error', error: error, stackTrace: stack);
  if (!_reportingEnabled) return;
  await Sentry.captureException(
    error,
    stackTrace: stack,
    withScope: (Scope scope) {
      context.forEach((String k, Object? v) => scope.setExtra(k, v));
    },
  );
}
