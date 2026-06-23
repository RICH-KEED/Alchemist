import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

/// Application entry point.
///
/// Everything runs inside a [runZonedGuarded] so that *any* uncaught
/// asynchronous error is funneled to a single place. Synchronous framework
/// errors go through [FlutterError.onError]; both are stubbed here and wired to
/// real crash reporting in stage 23 (Monitoring).
void main() {
  runZonedGuarded<void>(
    () {
      // Must run inside the same zone as `runApp`.
      WidgetsFlutterBinding.ensureInitialized();

      // Synchronous Flutter framework errors (build/layout/paint).
      FlutterError.onError = (FlutterErrorDetails details) {
        // In debug, dump to console; in release, report. Skill 23 wires the
        // crash reporter (Sentry / Crashlytics) here.
        FlutterError.presentError(details);
        // TODO(skill-23): forward `details` to the crash reporter.
      };

      // Errors that escape the Flutter framework (e.g. platform channels).
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        // TODO(skill-23): forward (error, stack) to the crash reporter.
        debugPrint('Uncaught platform error: $error');
        return true;
      };

      runApp(
        // ProviderScope is the root of the Riverpod DI graph (skill 08).
        // Tests replace it with `ProviderScope(overrides: [...])`.
        const ProviderScope(
          child: App(),
        ),
      );
    },
    (Object error, StackTrace stack) {
      // Uncaught async errors from the guarded zone land here.
      // TODO(skill-23): forward (error, stack) to the crash reporter.
      debugPrint('Uncaught zone error: $error');
    },
  );
}
