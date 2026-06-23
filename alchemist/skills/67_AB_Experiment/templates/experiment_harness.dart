/// Experiment harness — deterministic variant assignment, exposure logging,
/// guardrail collection. Built on top of Remote Config (skill 54).
///
/// Usage:
/// ```dart
/// final experiment = ref.read(experimentServiceProvider);
/// final variant = await experiment.assign('new_checkout_v1');
/// if (variant == 'variant_a') {
///   // new checkout flow
/// } else {
///   // control (existing flow)
/// }
/// ```

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
// Import your project's Remote Config, analytics, and logging services.

part 'experiment_harness.g.dart';

/// A single experiment's configuration as received from Remote Config.
class ExperimentConfig {
  final String id;
  final bool isActive;
  final List<String> variants; // e.g. ['control', 'variant_a']
  final Map<String, double> weights; // e.g. {'control': 0.5, 'variant_a': 0.5}
  final DateTime? startDate;
  final DateTime? endDate;

  const ExperimentConfig({
    required this.id,
    required this.isActive,
    required this.variants,
    required this.weights,
    this.startDate,
    this.endDate,
  });

  /// The control variant name. Always the first variant.
  String get control => variants.first;

  /// Parse from the Remote Config JSON value.
  factory ExperimentConfig.fromJson(String id, Map<String, dynamic> json) {
    return ExperimentConfig(
      id: id,
      isActive: json['active'] as bool? ?? false,
      variants: List<String>.from(json['variants'] as List),
      weights: Map<String, double>.from(
        (json['weights'] as Map).map((k, v) => MapEntry(k, (v as num).toDouble())),
      ),
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : null,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
    );
  }
}

/// Result of variant assignment.
class ExperimentAssignment {
  final String experimentId;
  final String variant;
  final bool isControl;
  final DateTime assignedAt;

  const ExperimentAssignment({
    required this.experimentId,
    required this.variant,
    required this.isControl,
    required this.assignedAt,
  });
}

/// Service that manages A/B experiment assignment and logging.
@riverpod
class ExperimentService extends _$ExperimentService {
  // In-memory cache of assignments for this session (sticky within session).
  final Map<String, ExperimentAssignment> _cache = {};

  @override
  Future<ExperimentService> build() async {
    // Dependencies: RemoteConfigService, AnalyticsService, Logger
    // Watch these providers if they exist.
    return this;
  }

  /// Assign a variant for [experimentId]. Deterministic + sticky.
  ///
  /// Falls back to [fallback] (default: 'control') if the experiment is
  /// inactive or the config is unavailable.
  Future<ExperimentAssignment> assign(
    String experimentId, {
    String fallback = 'control',
  }) async {
    // Return cached assignment within this session.
    if (_cache.containsKey(experimentId)) {
      return _cache[experimentId]!;
    }

    // Load experiment config from Remote Config.
    final config = await _loadConfig(experimentId);

    if (config == null || !config.isActive) {
      // Experiment not found or inactive — fallback.
      final assignment = ExperimentAssignment(
        experimentId: experimentId,
        variant: fallback,
        isControl: fallback == 'control',
        assignedAt: DateTime.now().toUtc(),
      );
      _cache[experimentId] = assignment;
      return assignment;
    }

    // Deterministic hash: MD5(userId + experimentId) → variant bucket.
    final userId = await _getUserId();
    final hash = md5.convert(utf8.encode('$userId:$experimentId')).toString();
    // Take first 8 hex chars as an integer in [0, 1).
    final bucket = int.parse(hash.substring(0, 8), radix: 16) / 0xFFFFFFFF;

    // Map bucket to variant based on weights.
    double cumulative = 0.0;
    String assignedVariant = config.control;
    for (final variant in config.variants) {
      cumulative += config.weights[variant] ?? 0.0;
      if (bucket < cumulative) {
        assignedVariant = variant;
        break;
      }
    }

    final assignment = ExperimentAssignment(
      experimentId: experimentId,
      variant: assignedVariant,
      isControl: assignedVariant == config.control,
      assignedAt: DateTime.now().toUtc(),
    );

    _cache[experimentId] = assignment;

    // Log exposure (fire-and-forget — never block UX on analytics).
    _logExposure(assignment);

    return assignment;
  }

  /// Record a guardrail metric for an experiment.
  ///
  /// [value] should be normalized per the guardrail's definition
  /// (e.g. 0.0 = no error, 1.0 = error occurred; or a duration in ms).
  void recordGuardrail({
    required String experimentId,
    required String guardrail,
    required double value,
  }) {
    final assignment = _cache[experimentId];
    final variant = assignment?.variant ?? 'unknown';

    // Log guardrail event.
    // TODO: Replace with the project's analytics service.
    // analytics.logEvent('experiment_guardrail', {
    //   'experiment_id': experimentId,
    //   'variant': variant,
    //   'guardrail': guardrail,
    //   'value': value,
    //   'timestamp': DateTime.now().toUtc().toIso8601String(),
    // });
  }

  /// Check if an experiment is active (for conditional UI branches).
  bool isActive(String experimentId) {
    return _cache.containsKey(experimentId);
  }

  /// Clear session cache (for testing only).
  void clearCache() {
    _cache.clear();
  }

  // ---- Private helpers ----

  Future<ExperimentConfig?> _loadConfig(String experimentId) async {
    // TODO: Replace with Remote Config fetch.
    // final json = await remoteConfig.getString('experiment_$experimentId');
    // if (json.isEmpty) return null;
    // return ExperimentConfig.fromJson(experimentId, jsonDecode(json));
    return null;
  }

  Future<String> _getUserId() async {
    // TODO: Replace with the project's user identification.
    // Return a stable, anonymous identifier for deterministic assignment.
    // If the user is logged in, use hashed user ID.
    // If anonymous, use the installation ID.
    return 'anonymous-user-id';
  }

  void _logExposure(ExperimentAssignment assignment) {
    // TODO: Replace with the project's analytics service.
    // analytics.logEvent('experiment_exposure', {
    //   'experiment_id': assignment.experimentId,
    //   'variant': assignment.variant,
    //   'assigned_at': assignment.assignedAt.toIso8601String(),
    // });
  }
}
