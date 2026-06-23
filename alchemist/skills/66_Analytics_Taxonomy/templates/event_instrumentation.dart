// =============================================================================
// Event instrumentation — mixin, observer, funnel tracker, consent gate
// =============================================================================
// Copy relevant pieces into lib/core/analytics/ or your feature layers.

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'analytics_taxonomy.dart';

// ---------------------------------------------------------------------------
// Consent gate
// ---------------------------------------------------------------------------
enum AnalyticsConsent { granted, denied, undetermined }

final consentGateProvider = StateProvider<AnalyticsConsent>(
  (ref) => AnalyticsConsent.undetermined,
);

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  final consent = ref.watch(consentGateProvider);
  if (consent == AnalyticsConsent.granted) {
    return ref.watch(_realAnalyticsServiceProvider);
  }
  return NoOpAnalyticsService();
});

final _realAnalyticsServiceProvider = Provider<AnalyticsService>(
  (ref) => NoOpAnalyticsService(), // replace with FirebaseAnalyticsService
);

// ---------------------------------------------------------------------------
// EventTracker mixin
// ---------------------------------------------------------------------------
/// Mix into widgets / controllers for a scoped track() method.
///
/// ```dart
/// class SearchController with EventTracker {
///   @override String get featureName => 'search';
///   void onQuerySubmitted(String q) {
///     track(UserActionEvent(
///       timestamp: DateTime.now(), sessionId: sid, userIdHash: uidHash,
///       action: 'submitted', target: '${featureName}_query',
///       metadata: {'query_length': q.length},
///     ));
///   }
/// }
/// ```
mixin EventTracker {
  String get featureName;
  AnalyticsService? _service;
  void bindService(AnalyticsService s) => _service = s;
  void track(AnalyticsEvent event) {
    final s = _service;
    if (s == null) {
      debugPrint('[EventTracker] service not bound — event lost: ${event.name}');
      return;
    }
    s.logEvent(event);
  }
}

// ---------------------------------------------------------------------------
// AnalyticsRiverpodObserver
// ---------------------------------------------------------------------------
/// Attach to ProviderContainer.observers. Logs state transitions for business
/// providers whose names start with a known prefix.
class AnalyticsRiverpodObserver extends ProviderObserver {
  final AnalyticsService _service;
  final String Function() _sessionId;
  final String Function() _userIdHash;

  AnalyticsRiverpodObserver({
    required AnalyticsService service,
    required String Function() sessionId,
    required String Function() userIdHash,
  }) : _service = service, _sessionId = sessionId, _userIdHash = userIdHash;

  @override
  void didUpdateProvider(ProviderBase<Object?> provider, Object? prev, Object? next,
      ProviderContainer container) {
    super.didUpdateProvider(provider, prev, next, container);
    final name = provider.name ?? '';
    if (_isBusiness(name) && next is String) {
      _service.logEvent(BusinessOutcomeEvent(
        timestamp: DateTime.now(), sessionId: _sessionId(), userIdHash: _userIdHash(),
        outcome: '${name}_$next',
      ));
    }
  }

  static const _prefixes = ['checkout', 'onboarding', 'subscription', 'purchase'];
  bool _isBusiness(String n) => _prefixes.any((p) => n.startsWith(p));
}

// ---------------------------------------------------------------------------
// FunnelTracker
// ---------------------------------------------------------------------------
/// Usage:
/// ```dart
/// final tracker = FunnelTracker(
///   funnelName: 'onboarding', steps: ['onboarding_step1_started', ...],
///   service: svc, sessionId: sidFn, userIdHash: uidFn,
/// );
/// tracker.step('onboarding_step1_started');
/// ```
class FunnelTracker {
  final String funnelName;
  final List<String> steps;
  final AnalyticsService _service;
  final String Function() _sessionId;
  final String Function() _userIdHash;

  int _currentIndex = -1;
  late final List<int> _counts = List.filled(steps.length, 0);

  FunnelTracker({
    required this.funnelName, required this.steps, required AnalyticsService service,
    required String Function() sessionId, required String Function() userIdHash,
  }) : _service = service, _sessionId = sessionId, _userIdHash = userIdHash;

  int get currentStep => _currentIndex;

  void step(String eventName) {
    final next = _currentIndex + 1;
    if (next < steps.length && steps[next] == eventName) _currentIndex = next;
    final idx = steps.indexOf(eventName);
    if (idx >= 0) _counts[idx]++;
    _service.logEvent(BusinessOutcomeEvent(
      timestamp: DateTime.now(), sessionId: _sessionId(), userIdHash: _userIdHash(),
      outcome: eventName, funnelStep: funnelName,
    ));
  }

  double get completionRate =>
      _counts[0] == 0 ? 0 : _counts.last / _counts[0];

  double dropOffRate(int from, int to) {
    if (from >= _counts.length || to >= _counts.length || _counts[from] == 0) return 0;
    return max(0, 1 - (_counts[to] / _counts[from]));
  }
}

// ---------------------------------------------------------------------------
// Global error instrumentation
// ---------------------------------------------------------------------------
/// Call once in main() before runApp():
/// ```dart
/// setupErrorInstrumentation(service, sessionIdFn, userIdHashFn);
/// ```
void setupErrorInstrumentation(
  AnalyticsService service,
  String Function() sessionId,
  String Function() userIdHash,
) {
  FlutterError.onError = (d) {
    FlutterError.presentError(d);
    service.logEvent(ErrorEvent(
      timestamp: DateTime.now(), sessionId: sessionId(), userIdHash: userIdHash(),
      errorType: 'flutter_error', errorMessage: d.exceptionAsString(),
      stackTrace: d.stack, isFatal: false,
    ));
  };
  PlatformDispatcher.instance.onError = (e, s) {
    service.logEvent(ErrorEvent(
      timestamp: DateTime.now(), sessionId: sessionId(), userIdHash: userIdHash(),
      errorType: 'platform_error', errorMessage: e.toString(),
      stackTrace: s, isFatal: true,
    ));
    return true;
  };
}
