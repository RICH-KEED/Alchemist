// lib/core/monitoring/app_logger.dart
//
// Stage 23 (Monitoring). The single app-wide logging entry point — use `AppLog`
// everywhere instead of `print` / `debugPrint` (CONVENTIONS §1 forbids `print`).
//
// Responsibilities:
//   • level discipline (trace/debug dev-only; info+ ships in release),
//   • redaction of PII/secrets (ties to skill 13),
//   • routing warning+ logs to the crash reporter as breadcrumbs (skill 23 §5),
//     so a crash arrives with the trail that led to it.
//
// pubspec:  logger: ^2.0.0
//
// REDACTION NOTE: never pass tokens, passwords, full request/response bodies,
// emails, or precise location into these methods. When unsure, log an id or a
// count — not the value. `redact()` masks the common cases; it is a safety net,
// not a license to log secrets.

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// App-wide structured logger. Static facade over a configured `logger` instance.
abstract final class AppLog {
  static final Logger _logger = Logger(
    // Release drops trace/debug; debug shows everything.
    level: kReleaseMode ? Level.info : Level.trace,
    filter: ProductionFilter(),
    printer: kReleaseMode
        // Terse, parse-friendly output for release log sinks / breadcrumbs.
        ? SimplePrinter(printTime: true, colors: false)
        // Readable, colorized output during development.
        : PrettyPrinter(methodCount: 2, errorMethodCount: 8, colors: true),
    // Fan-out: console + (in release) crash-reporter breadcrumbs.
    output: MultiOutput([
      ConsoleOutput(),
      if (kReleaseMode) _BreadcrumbOutput(),
    ]),
  );

  static void trace(String message) => _logger.t(_safe(message));
  static void debug(String message) => _logger.d(_safe(message));
  static void info(String message) => _logger.i(_safe(message));

  static void warning(String message, {Object? error, StackTrace? stackTrace}) =>
      _logger.w(_safe(message), error: error, stackTrace: stackTrace);

  /// Use where a `Failure` is created (skill 15: "logged exactly once").
  static void error(String message, {Object? error, StackTrace? stackTrace}) =>
      _logger.e(_safe(message), error: error, stackTrace: stackTrace);

  /// About-to-crash severity. The crash reporter also captures the actual crash.
  static void fatal(String message, {Object? error, StackTrace? stackTrace}) =>
      _logger.f(_safe(message), error: error, stackTrace: stackTrace);

  static String _safe(String message) => redact(message);
}

/// Masks the most common PII/secret patterns. Best-effort — prefer not logging
/// the sensitive value at all (see file header). Extend per skill 13's data map.
String redact(String input) {
  return input
      // Bearer / auth tokens.
      .replaceAll(RegExp(r'(?i)(bearer\s+)[A-Za-z0-9._\-]+'), r'$1<redacted>')
      // Email addresses.
      .replaceAll(
        RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}'),
        '<email>',
      )
      // password=... / token=... / secret=... key/value pairs.
      .replaceAll(
        RegExp(r'(?i)(password|token|secret|api[_-]?key)=([^\s&]+)'),
        r'$1=<redacted>',
      );
}

/// Forwards warning+ logs to the crash reporter as breadcrumbs (skill 23 §5).
/// Kept dependency-free so the template compiles standalone; wire the real call
/// once `sentry_flutter` / `firebase_crashlytics` is present.
class _BreadcrumbOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    if (event.level.value < Level.warning.value) return;
    for (final String line in event.lines) {
      // Sentry:      Sentry.addBreadcrumb(Breadcrumb(message: line, level: ...));
      // Crashlytics: FirebaseCrashlytics.instance.log(line);
      assert(() {
        // No-op placeholder; replace with the backend call above.
        return true;
      }());
    }
  }
}
