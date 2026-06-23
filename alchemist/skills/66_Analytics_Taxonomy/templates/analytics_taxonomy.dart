// =============================================================================
// Analytics Taxonomy — typed event model, service abstraction, auto observer
// =============================================================================
// Copy into lib/core/analytics/. Requires: flutter_riverpod, go_router, crypto.

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
String _hash(String raw) => sha256.convert(utf8.encode(raw)).toString();
String _sanitize(String msg) => msg
    .replaceAll(RegExp(r'[\w\.\-]+@[\w\-]+\.\w+'), '[email]')
    .replaceAll(RegExp(r'https?://\S+'), '[url]')
    .replaceAll(RegExp(r'(\/[\w\-\.]+)+'), '[path]');
String _stackHash(StackTrace? s) =>
    s == null ? 'no-stack' : sha256.convert(utf8.encode(s.toString())).toString().substring(0, 8);

// ---------------------------------------------------------------------------
// Sealed event hierarchy
// ---------------------------------------------------------------------------
sealed class AnalyticsEvent {
  DateTime get timestamp;
  String get sessionId;
  String get userIdHash;
  String get name;
  Map<String, Object> toJson();
}

class ScreenViewEvent implements AnalyticsEvent {
  @override final DateTime timestamp;
  @override final String sessionId;
  @override final String userIdHash;
  final String screenName;
  final String? previousScreen;
  final int? durationMs;

  const ScreenViewEvent({
    required this.timestamp, required this.sessionId, required this.userIdHash,
    required this.screenName, this.previousScreen, this.durationMs,
  });

  @override String get name => 'screen_$screenName';

  @override Map<String, Object> toJson() {
    final j = <String, Object>{
      'event_name': name, 'event_category': 'screen_view',
      'timestamp': timestamp.toIso8601String(),
      'session_id': sessionId, 'user_id_hash': userIdHash,
      'screen_name': screenName,
    };
    if (previousScreen != null) j['previous_screen'] = previousScreen!;
    if (durationMs != null) j['duration_ms'] = durationMs!;
    return j;
  }
}

class UserActionEvent implements AnalyticsEvent {
  @override final DateTime timestamp;
  @override final String sessionId;
  @override final String userIdHash;
  final String action;
  final String target;
  final Map<String, Object?>? metadata;

  const UserActionEvent({
    required this.timestamp, required this.sessionId, required this.userIdHash,
    required this.action, required this.target, this.metadata,
  });

  @override String get name => '${target}_$action';

  @override Map<String, Object> toJson() {
    final j = <String, Object>{
      'event_name': name, 'event_category': 'user_action',
      'timestamp': timestamp.toIso8601String(),
      'session_id': sessionId, 'user_id_hash': userIdHash,
      'action': action, 'target': target,
    };
    if (metadata != null) {
      for (final e in metadata!.entries) {
        if (e.value != null) j[e.key] = e.value!;
      }
    }
    return j;
  }
}

class BusinessOutcomeEvent implements AnalyticsEvent {
  @override final DateTime timestamp;
  @override final String sessionId;
  @override final String userIdHash;
  final String outcome;
  final num? value;
  final String? funnelStep;

  const BusinessOutcomeEvent({
    required this.timestamp, required this.sessionId, required this.userIdHash,
    required this.outcome, this.value, this.funnelStep,
  });

  @override String get name => outcome;

  @override Map<String, Object> toJson() {
    final j = <String, Object>{
      'event_name': name, 'event_category': 'business_outcome',
      'timestamp': timestamp.toIso8601String(),
      'session_id': sessionId, 'user_id_hash': userIdHash, 'outcome': outcome,
    };
    if (value != null) j['value'] = value!;
    if (funnelStep != null) j['funnel_step'] = funnelStep!;
    return j;
  }
}

class ErrorEvent implements AnalyticsEvent {
  @override final DateTime timestamp;
  @override final String sessionId;
  @override final String userIdHash;
  final String errorType;
  final String errorMessage;
  final String stackTraceHash;
  final bool isFatal;

  ErrorEvent({
    required this.timestamp, required this.sessionId, required this.userIdHash,
    required String errorType, required String errorMessage,
    required StackTrace? stackTrace, required this.isFatal,
  })  : errorType = errorType,
        errorMessage = _sanitize(errorMessage),
        stackTraceHash = _stackHash(stackTrace);

  @override String get name => isFatal ? 'error_fatal_$errorType' : 'error_$errorType';

  @override Map<String, Object> toJson() => {
    'event_name': name, 'event_category': 'error_event',
    'timestamp': timestamp.toIso8601String(),
    'session_id': sessionId, 'user_id_hash': userIdHash,
    'error_type': errorType, 'error_message': errorMessage,
    'stack_trace_hash': stackTraceHash, 'is_fatal': isFatal,
  };
}

// ---------------------------------------------------------------------------
// AnalyticsService abstraction
// ---------------------------------------------------------------------------
abstract class AnalyticsService {
  Future<void> logEvent(AnalyticsEvent event);
  Future<void> setUserProperty(String key, String value);
  Future<void> setUserId(String userId);
}

class NoOpAnalyticsService implements AnalyticsService {
  @override Future<void> logEvent(AnalyticsEvent event) async {}
  @override Future<void> setUserProperty(String key, String value) async {}
  @override Future<void> setUserId(String userId) async {}
}

// ---------------------------------------------------------------------------
// go_router screen-view observer
// ---------------------------------------------------------------------------
class AnalyticsObserver extends RouteObserver<PageRoute<dynamic>> {
  final AnalyticsService _service;
  final String Function() _sessionId;
  final String Function() _userIdHash;
  String? _previousScreen;

  AnalyticsObserver({
    required AnalyticsService service,
    required String Function() sessionId,
    required String Function() userIdHash,
  }) : _service = service, _sessionId = sessionId, _userIdHash = userIdHash;

  @override void didPush(Route<dynamic> route, Route<dynamic>? prev) {
    super.didPush(route, prev);
    _log(route);
  }
  @override void didPop(Route<dynamic> route, Route<dynamic>? prev) {
    super.didPop(route, prev);
    if (prev != null) _log(prev);
  }
  @override void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) _log(newRoute);
  }
  void _log(Route<dynamic> route) {
    final name = route.settings.name ?? 'unknown';
    _service.logEvent(ScreenViewEvent(
      timestamp: DateTime.now(), sessionId: _sessionId(), userIdHash: _userIdHash(),
      screenName: name, previousScreen: _previousScreen,
    ));
    _previousScreen = name;
  }
}

// ---------------------------------------------------------------------------
// Funnel provider
// ---------------------------------------------------------------------------
class AnalyticsFunnel {
  final String name;
  final List<String> steps;
  int _currentStep = -1;

  AnalyticsFunnel({required this.name, required this.steps});

  bool get isComplete => _currentStep >= steps.length - 1;

  int advance(String eventName) {
    final next = _currentStep + 1;
    if (next < steps.length && steps[next] == eventName) _currentStep = next;
    return _currentStep;
  }

  double get completionRate => steps.isEmpty ? 0 : (_currentStep + 1) / steps.length;
}

final analyticsFunnelProvider = Provider.family<AnalyticsFunnel, String>(
  (ref, name) => throw UnimplementedError('Override with your funnel definitions'),
);
