// ---------------------------------------------------------------------------
// Feature Flag Service — type-safe wrapper over Firebase Remote Config with
// local overrides, Riverpod providers, feature gating widgets, and route guards.
//
// Dependencies (add to pubspec.yaml):
//   firebase_core: ^3.x
//   firebase_remote_config: ^5.x
//   flutter_riverpod: ^2.x
//   riverpod_annotation: ^2.x
//   shared_preferences: ^2.x
//   freezed_annotation: ^2.x
//   go_router: ^14.x
//
// Dev dependencies:
//   freezed: ^2.x
//   json_serializable: ^2.x
//   build_runner: ^2.x
// ---------------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'feature_flag_service.freezed.dart';
part 'feature_flag_service.g.dart';

// =============================================================================
// 1. Typed FeatureFlag sealed class
// =============================================================================

/// A compile-time-verified feature flag key with a known type [T].
///
/// Define every flag in the app as a static constant of one of the subclasses.
/// The compiler guarantees that callers always get the right type back — there
/// are no stringly-typed lookups anywhere in the codebase.
@freezed
sealed class FeatureFlag<T> with _$FeatureFlag<T> {
  // -- Concrete flag declarations --------------------------------------------
  //
  // Add every flag your app needs below.  Use the pattern:
  //
  //   static const enableNewCheckout = FlagBool(
  //     key: 'enable_new_checkout',
  //     defaultValue: false,
  //   );
  //
  // Group flags by feature or risk profile.  Kill-switches get their own
  // section and default to true.

  // ---- Feature gates (default off) ----
  // Example:
  // static const enableNewCheckout = FlagBool(
  //   key: 'enable_new_checkout',
  //   defaultValue: false,
  // );

  // ---- Configuration (typed values) ----
  // Example:
  // static const searchDebounceMs = FlagInt(
  //   key: 'search_debounce_ms',
  //   defaultValue: 300,
  // );

  // ---- Kill switches (default on) ----
  // Example:
  // static const killSwitchPayments = FlagBool(
  //   key: 'kill_switch_payments',
  //   defaultValue: true,
  // );

  // ---- Experiment variants ----
  // Example:
  // static const checkoutRedesignVariant = FlagString(
  //   key: 'checkout_redesign_variant',
  //   defaultValue: 'control',
  // );

  const FeatureFlag._();

  /// The Remote Config key string.  Never used directly by consumers.
  String get key;

  /// The safe compile-time default returned when Remote Config is unavailable.
  T get defaultValue;

  // -- Bool ----------------------------------------------------------------

  const factory FeatureFlag.bool({
    required String key,
    required bool defaultValue,
  }) = FlagBool;

  // -- Int -----------------------------------------------------------------

  const factory FeatureFlag.int({
    required String key,
    required int defaultValue,
  }) = FlagInt;

  // -- Double ---------------------------------------------------------------

  const factory FeatureFlag.double({
    required String key,
    required double defaultValue,
  }) = FlagDouble;

  // -- String ---------------------------------------------------------------

  const factory FeatureFlag.string({
    required String key,
    required String defaultValue,
  }) = FlagString;

  // -- JSON (Map<String, dynamic>) ------------------------------------------

  const factory FeatureFlag.json({
    required String key,
    required Map<String, dynamic> defaultValue,
  }) = FlagJson;
}

// =============================================================================
// 2. FeatureFlagService — the single source of truth for flag evaluation
// =============================================================================

/// Evaluates feature flags by walking the priority chain:
///
///   1. Local override  (developer menu / .env / test injection)
///   2. Remote Config   (last-fetched value cached in memory)
///   3. Compile-time default  (from [FeatureFlag.defaultValue])
///
/// Every `get<T>(flag)` call is synchronous after [initialize] completes.
/// The app renders with defaults immediately; Remote Config fetches happen
/// in the background and new values propagate reactively via the Riverpod
/// provider.
class FeatureFlagService {
  FeatureFlagService({
    required FirebaseRemoteConfig remoteConfig,
    SharedPreferencesAsync? prefs,
  })  : _remoteConfig = remoteConfig,
        _prefs = prefs;

  final FirebaseRemoteConfig _remoteConfig;
  final SharedPreferencesAsync? _prefs;

  /// Local overrides keyed by flag key.  null means "no override — fall through."
  final Map<String, Object?> _localOverrides = {};

  /// Whether the service has completed its first fetch + activate.
  bool _initialized = false;

  // -- Public API -----------------------------------------------------------

  /// Returns true after the first [initialize] call completes.
  bool get isInitialized => _initialized;

  /// Push default values to Remote Config and perform the first fetch.
  ///
  /// Call once in [main] before running the app.  The app renders with
  /// defaults if this call fails — use [lastFetchStatus] for UI feedback.
  Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Collect every flag's default into a plain map for Remote Config.
    final defaults = <String, dynamic>{
      for (final flag in _allFlags) flag.key: flag.defaultValue,
    };
    await _remoteConfig.setDefaults(defaults);

    await _remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: kDebugMode
          ? Duration.zero
          : const Duration(minutes: 5),
    ));

    await _fetchAndActivate();
    _initialized = true;
  }

  /// Fetch remote values and activate them immediately.
  ///
  /// Safe to call from a background timer or on app resume.  Returns true if
  /// new values were activated, false if cached values are still current.
  Future<bool> _fetchAndActivate() async {
    try {
      await _remoteConfig.fetch().timeout(const Duration(seconds: 10));
      return await _remoteConfig.activate();
    } on FirebaseException catch (e, st) {
      // Log the error (use your app's logger) and fall back to cached defaults.
      debugPrint('FeatureFlagService fetch failed: $e\n$st');
      return false;
    } on TimeoutException catch (e, st) {
      debugPrint('FeatureFlagService fetch timed out: $e\n$st');
      return false;
    }
  }

  /// Public fetch + activate that can be called on a timer.
  Future<void> fetchAndActivate() => _fetchAndActivate();

  /// Type-safe evaluation — the return type is locked to [T].
  ///
  /// Priority:
  ///   1. Local override (if set)
  ///   2. Remote Config (last cached)
  ///   3. Compile-time default
  T get<T>(FeatureFlag<T> flag) {
    // 1. Check local override
    if (_localOverrides.containsKey(flag.key)) {
      final override = _localOverrides[flag.key];
      if (override is T) return override;
    }

    // 2. Check Remote Config (has the key and the value matches the expected type)
    try {
      final remoteValue = switch (flag) {
        FlagBool() => _remoteConfig.getBool(flag.key) as T?,
        FlagInt() => _remoteConfig.getInt(flag.key) as T?,
        FlagDouble() => _remoteConfig.getDouble(flag.key) as T?,
        FlagString() => _remoteConfig.getString(flag.key) as T?,
        FlagJson() => _remoteConfig.getValue(flag.key).asMap()
            .map((k, v) => MapEntry(k, v as Object)) // we cannot narrow Value to T
            as T?,
      };
      if (remoteValue != null) return remoteValue;
    } catch (_) {
      // Key missing or type mismatch — fall through to default.
    }

    // 3. Compile-time default
    return flag.defaultValue;
  }

  /// Convenience: returns the bool value of a flag (most common case).
  bool isEnabled(FeatureFlag<bool> flag) => get(flag);

  /// Set a local override for testing / dev.  Pass null to remove.
  void setLocalOverride<T>(FeatureFlag<T> flag, T? value) {
    _localOverrides[flag.key] = value;
  }

  /// Remove all local overrides.
  void clearLocalOverrides() => _localOverrides.clear();

  // -- Internal helpers -----------------------------------------------------

  /// Every flag the app defines.  Populate from your [FeatureFlag] subclass.
  ///
  /// In practice this is a static list maintained alongside the flag
  /// declarations.  For a real app you would extract this from the sealed
  /// class via code generation or a static const list.
  static final List<FeatureFlag> _allFlags = <FeatureFlag>[
    // FeatureFlags.enableNewCheckout,
    // FeatureFlags.searchDebounceMs,
    // ... add every flag here so defaults are complete
  ];
}

// =============================================================================
// 3. Riverpod providers
// =============================================================================

/// The singleton [FeatureFlagService] instance.
///
/// Override this in tests with a fake service.
final featureFlagServiceProvider = Provider<FeatureFlagService>((ref) {
  // In production this is seeded in main() via override.
  throw UnimplementedError('Override featureFlagServiceProvider in main()');
});

/// Evaluate a single [FeatureFlag<bool>] reactively.
///
/// Usage:
/// ```dart
/// final enabled = ref.watch(featureFlagProvider(FeatureFlags.enableNewCheckout));
/// ```
///
/// Returns the flag's value (rebuilt when overrides or Remote Config change).
final featureFlagProvider =
    FutureProvider.family<bool, FeatureFlag<bool>>((ref, flag) {
  final service = ref.watch(featureFlagServiceProvider);
  return service.get(flag);
});

/// Evaluate a [FeatureFlag<String>] — useful for experiment variant flags.
final stringFlagProvider =
    FutureProvider.family<String, FeatureFlag<String>>((ref, flag) {
  final service = ref.watch(featureFlagServiceProvider);
  return service.get(flag);
});

/// Evaluate a [FeatureFlag<int>].
final intFlagProvider =
    FutureProvider.family<int, FeatureFlag<int>>((ref, flag) {
  final service = ref.watch(featureFlagServiceProvider);
  return service.get(flag);
});

/// Evaluate a [FeatureFlag<double>].
final doubleFlagProvider =
    FutureProvider.family<double, FeatureFlag<double>>((ref, flag) {
  final service = ref.watch(featureFlagServiceProvider);
  return service.get(flag);
});

// =============================================================================
// 4. FeatureGate widget
// =============================================================================

/// Conditionally renders [child] when [flag] is true, otherwise renders
/// [fallback] (if provided) or an empty [SizedBox.shrink].
///
/// This is the primary widget-level gating primitive.  It reads the flag
/// reactively via Riverpod, so a Remote Config change will swap widgets
/// without a full rebuild.
///
/// Usage:
/// ```dart
/// FeatureGate(
///   flag: FeatureFlags.enableNewCheckout,
///   fallback: const OldCheckoutScreen(),
///   child: const NewCheckoutScreen(),
/// )
/// ```
class FeatureGate extends ConsumerWidget {
  const FeatureGate({
    super.key,
    required this.flag,
    this.fallback,
    required this.child,
  });

  /// The bool flag that gates [child].
  final FeatureFlag<bool> flag;

  /// Widget to show when the flag is false.  If omitted, renders nothing.
  final Widget? fallback;

  /// Widget shown when the flag is true.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncValue = ref.watch(featureFlagProvider(flag));

    // While the flag is loading (first fetch), render a safe default.
    return asyncValue.when(
      loading: () =>
          fallback ?? const SizedBox.shrink(), // safe: defaults to hidden
      error: (_, __) =>
          fallback ?? const SizedBox.shrink(), // safe: errors hide the feature
      data: (enabled) => enabled ? child : (fallback ?? const SizedBox.shrink()),
    );
  }
}

// =============================================================================
// 5. Route guard (go_router)
// =============================================================================

/// Static helper for go_router redirect guards.
///
/// Usage in router config:
/// ```dart
/// GoRoute(
///   path: '/new-checkout',
///   redirect: (context, state) async {
///     return FeatureFlagGate.redirectIfDisabled(
///       FeatureFlags.enableNewCheckout,
///       fallbackPath: '/checkout',
///     );
///   },
///   builder: (_, __) => const NewCheckoutScreen(),
/// )
/// ```
///
/// This is intentionally NOT a Riverpod-dependent class so it can be used
/// in the router configuration before the ProviderScope is available.
/// The trade-off: the gate reads the flag synchronously from the service
/// (which has already initialised by the time routing fires).
class FeatureFlagGate {
  FeatureFlagGate._();

  /// Returns a redirect path if [flag] is disabled; null if the route should
  /// proceed normally.
  ///
  /// [service] must be the already-initialised [FeatureFlagService] instance.
  /// Pass it from your app-level provider or from a top-level variable set
  /// in main().
  static String? redirectIfDisabled(
    FeatureFlag<bool> flag, {
    required String fallbackPath,
  }) {
    // The service is read from a top-level holder that main() populates.
    // If somehow called before initialisation, redirect to be safe.
    final service = _serviceHolder;
    if (service == null) return fallbackPath; // safe: redirect
    return service.isEnabled(flag) ? null : fallbackPath;
  }

  /// Populate this in main() after the service is initialised.
  static FeatureFlagService? _serviceHolder;

  /// Call once in main() after service initialisation.
  static void hold(FeatureFlagService service) {
    _serviceHolder = service;
  }
}

// =============================================================================
// 6. Initialisation in main.dart (usage example — not runnable code)
// =============================================================================

/// Example bootstrap.  Copy the structure into your app's main.dart.
///
/// ```dart
/// Future<void> main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   final remoteConfig = FirebaseRemoteConfig.instance;
///   final service = FeatureFlagService(remoteConfig: remoteConfig);
///   await service.initialize();
///   FeatureFlagGate.hold(service);
///
///   runApp(
///     ProviderScope(
///       overrides: [
///         featureFlagServiceProvider.overrideWithValue(service),
///       ],
///       child: const MyApp(),
///     ),
///   );
/// }
/// ```

// =============================================================================
// 7. Fake implementation for tests
// =============================================================================

/// An in-memory fake that satisfies the [FeatureFlagService] interface for
/// unit and widget tests.  Inject via [ProviderScope] overrides.
///
/// Usage:
/// ```dart
/// testWidgets('shows old checkout when flag is false', (tester) async {
///   await tester.pumpWidget(
///     ProviderScope(
///       overrides: [
///         featureFlagServiceProvider.overrideWithValue(
///           FakeFeatureFlagService({
///             FeatureFlags.enableNewCheckout: false,
///           }),
///         ),
///       ],
///       child: const FeatureGate(
///         flag: FeatureFlags.enableNewCheckout,
///         fallback: Text('old'),
///         child: Text('new'),
///       ),
///     ),
///   );
///   expect(find.text('old'), findsOneWidget);
///   expect(find.text('new'), findsNothing);
/// });
/// ```
class FakeFeatureFlagService extends FeatureFlagService {
  /// [flags] maps flag keys (or flag instances' `.key`) to their desired values.
  /// Any flag not in this map returns its [FeatureFlag.defaultValue].
  FakeFeatureFlagService(this._values)
      : super(remoteConfig: FirebaseRemoteConfig.instance);

  final Map<String, Object?> _values;

  @override
  T get<T>(FeatureFlag<T> flag) {
    if (_values.containsKey(flag.key)) {
      final v = _values[flag.key];
      if (v is T) return v;
    }
    return flag.defaultValue;
  }

  @override
  bool isEnabled(FeatureFlag<bool> flag) => get(flag);

  @override
  Future<void> initialize() async {} // no-op

  // Note: FakeFeatureFlagService is intentionally minimal — it only overrides
  // the evaluation path.  Tests that need fetch/activate behaviour should
  // mock the FirebaseRemoteConfig instance instead.
}
