// lib/core/monitoring/analytics.dart
//
// Stage 23 (Monitoring). A vendor-neutral analytics abstraction so widgets never
// touch a vendor SDK and so debug never pollutes the production dashboard.
//
// Events are derived from the PRD §7 success metrics (skill 02): each "How
// measured → stage 23" row becomes one `AppEvent` constant below. Screen views
// fire from the go_router NavigatorObserver (skill 07).
//
// Privacy (skill 24): collection is gated behind consent; params are minimal and
// non-identifying. Never pass emails, exact location, or free text the user typed.
//
// codegen: `dart run build_runner build --delete-conflicting-outputs`.

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_logger.dart';

part 'analytics.g.dart';

/// The swappable analytics contract. Implementations are selected by build mode
/// and consent in [analyticsService] — call sites only ever see this interface.
abstract interface class AnalyticsService {
  /// Records a screen view. Fire from the router observer, not from `build`.
  Future<void> logScreenView(String screenName);

  /// Records a typed app event. Prefer the helpers on [AnalyticsX] over raw calls.
  Future<void> logEvent(String name, {Map<String, Object?> params});

  /// Associates events with an *opaque* app id (never PII). `null` on sign-out.
  Future<void> setUserId(String? id);

  /// Enables/disables collection. Off until the user consents (skill 24).
  Future<void> setConsent({required bool enabled});
}

/// Canonical event names. One constant per PRD §7 metric → grep-able + rename-safe.
/// Replace the placeholders with the actual metrics from `docs/PRD.md`.
abstract final class AppEvent {
  /// PRD "Activation" — the first time the user reaches the product's "aha".
  static const String activated = 'activated';

  /// PRD "Task success" — the core loop completed without error.
  static const String coreLoopCompleted = 'core_loop_completed';

  /// PRD "Engagement" — the key recurring action (rename per PRD).
  static const String keyAction = 'key_action';

  /// Example domain event used by the typed helper below.
  static const String runLogged = 'run_logged';
}

/// Provides the active [AnalyticsService].
///
/// - Debug → [NoopAnalytics] (logs only; nothing leaves the device).
/// - Release → the real vendor, but still no-op until consent flips it on.
///
/// Override in tests with a fake via `ProviderScope(overrides: [...])`.
@Riverpod(keepAlive: true)
AnalyticsService analyticsService(Ref ref) {
  if (kDebugMode) return const NoopAnalytics();
  return SentryAnalytics();
  // Crashlytics/Firebase: return FirebaseAnalyticsService();
}

/// Debug / pre-consent implementation: routes everything to [AppLog], sends nothing.
final class NoopAnalytics implements AnalyticsService {
  const NoopAnalytics();

  @override
  Future<void> logScreenView(String screenName) async =>
      AppLog.debug('analytics screen: $screenName');

  @override
  Future<void> logEvent(String name, {Map<String, Object?> params = const {}}) async =>
      AppLog.debug('analytics event: $name $params');

  @override
  Future<void> setUserId(String? id) async =>
      AppLog.debug('analytics userId: ${id == null ? 'cleared' : 'set'}');

  @override
  Future<void> setConsent({required bool enabled}) async =>
      AppLog.debug('analytics consent: $enabled');
}

/// Thin Sentry-backed sketch. Forwards events as breadcrumbs + Sentry messages.
/// Replace the bodies with `Sentry.addBreadcrumb(...)` etc. once `sentry_flutter`
/// is wired (kept dependency-free here so the template compiles standalone).
final class SentryAnalytics implements AnalyticsService {
  bool _consented = false;

  @override
  Future<void> logScreenView(String screenName) async {
    if (!_consented) return;
    AppLog.info('screen_view: $screenName');
    // Sentry.addBreadcrumb(Breadcrumb(category: 'navigation', message: screenName));
  }

  @override
  Future<void> logEvent(String name, {Map<String, Object?> params = const {}}) async {
    if (!_consented) return;
    AppLog.info('event: $name $params');
    // Sentry.addBreadcrumb(Breadcrumb(category: 'analytics', message: name, data: params));
  }

  @override
  Future<void> setUserId(String? id) async {
    // Sentry.configureScope((s) => s.setUser(id == null ? null : SentryUser(id: id)));
  }

  @override
  Future<void> setConsent({required bool enabled}) async => _consented = enabled;
}

/// Typed event helpers — call these instead of `logEvent` with stringly params.
/// Keeps every event's parameter shape in one place and PII out by construction.
extension AnalyticsX on AnalyticsService {
  /// PRD activation milestone.
  Future<void> activated() => logEvent(AppEvent.activated);

  /// PRD task-success: the core loop finished cleanly.
  Future<void> coreLoopCompleted({required Duration elapsed}) => logEvent(
        AppEvent.coreLoopCompleted,
        params: {'elapsed_ms': elapsed.inMilliseconds},
      );

  /// Example domain event. Note: coarse, non-identifying params only.
  Future<void> runLogged({required int distanceMeters}) => logEvent(
        AppEvent.runLogged,
        params: {'distance_m': distanceMeters},
      );
}
