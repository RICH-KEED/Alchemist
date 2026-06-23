// lib/core/coach_marks/onboarding_state.dart
//
// Persisted, VERSIONED completion state for onboarding flows and coach-mark
// tours. Governs "show only on first launch" (Responsibility 5) and "replay
// from Settings" (Responsibility 6).
//
// House style: Riverpod 2.x codegen + shared_preferences (see CONVENTIONS §1).
// Run `dart run build_runner build` to generate `onboarding_state.g.dart`.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'onboarding_state.g.dart';

/// Canonical IDs for every onboarding surface. Bump the version suffix when a
/// screen changes enough to re-coach returning users (e.g. `home.v1` -> `home.v2`).
abstract final class OnboardingIds {
  static const intro = 'onboarding.intro.v1';
  static const homeTour = 'coach.home.v1';
  static const checkoutTour = 'coach.checkout.v1';

  /// Every known ID, used by `resetAll()` (replay everything).
  static const all = <String>[intro, homeTour, checkoutTour];
}

const _prefsKeyPrefix = 'onboarding_completed:';

/// Provides the app's [SharedPreferences].
///
/// Override this in `main.dart` after `SharedPreferences.getInstance()` so the
/// rest of the app can read it synchronously:
///
/// ```dart
/// final prefs = await SharedPreferences.getInstance();
/// runApp(ProviderScope(
///   overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
///   child: const App(),
/// ));
/// ```
@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) =>
    throw UnimplementedError('Override sharedPreferencesProvider in main.dart');

/// Tracks which onboarding flows / coach tours the user has completed.
///
/// State is the set of completed IDs. First launch of a surface = its ID is
/// absent => the UI auto-starts it once, then calls [complete].
@Riverpod(keepAlive: true)
class OnboardingController extends _$OnboardingController {
  @override
  Set<String> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs
        .getKeys()
        .where((k) => k.startsWith(_prefsKeyPrefix))
        .map((k) => k.substring(_prefsKeyPrefix.length))
        .toSet();
  }

  /// Whether [id] has been completed (so it should NOT be shown again).
  bool isCompleted(String id) => state.contains(id);

  /// Mark [id] complete and persist it. Idempotent.
  Future<void> complete(String id) async {
    if (state.contains(id)) return;
    await ref.read(sharedPreferencesProvider).setBool('$_prefsKeyPrefix$id', true);
    state = {...state, id};
  }

  /// Clear a single flow/tour so it shows again (Settings "replay this tour").
  Future<void> reset(String id) async {
    await ref.read(sharedPreferencesProvider).remove('$_prefsKeyPrefix$id');
    state = {...state}..remove(id);
  }

  /// Clear every known flow/tour (Settings "show all onboarding again").
  Future<void> resetAll() async {
    final prefs = ref.read(sharedPreferencesProvider);
    for (final id in OnboardingIds.all) {
      await prefs.remove('$_prefsKeyPrefix$id');
    }
    state = {};
  }
}

/// Convenience: watch whether a specific surface still needs to be shown.
@riverpod
bool needsOnboarding(Ref ref, String id) =>
    !ref.watch(onboardingControllerProvider).contains(id);
