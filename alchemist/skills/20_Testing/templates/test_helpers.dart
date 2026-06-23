// test/support/test_helpers.dart
//
// Shared test infrastructure for the whole suite:
//   - pumpApp(): wraps a widget in ProviderScope + MaterialApp (theme + nav)
//                with overrides, so widget tests get an identical, real-ish tree.
//   - data builders + fakes: construct domain objects with sensible defaults
//                and reusable mocktail fakes for repositories.
//
// Import this from any widget/integration test instead of re-deriving the
// wrapper. Conventions: ../../../references/CONVENTIONS.md (§6, §7).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Illustrative imports — point these at your real app code.
import 'package:my_app/app/theme/app_theme.dart'; // lightTheme / darkTheme (stage 04)
import 'package:my_app/features/profile/domain/profile.dart';
import 'package:my_app/features/profile/domain/profile_repository.dart';

// ---------------------------------------------------------------------------
// pumpApp — the canonical widget-test harness.
// ---------------------------------------------------------------------------

extension PumpApp on WidgetTester {
  /// Pumps [child] inside a ProviderScope + MaterialApp.
  ///
  /// - [overrides] inject fakes for the providers the widget reads.
  /// - [themeMode] flips light/dark (goldens pump both).
  /// - [navigatorObservers] let a test assert navigation happened.
  ///
  /// Returns the [ProviderContainer] so a test can read providers directly.
  Future<ProviderContainer> pumpApp(
    Widget child, {
    List<Override> overrides = const [],
    ThemeMode themeMode = ThemeMode.light,
    List<NavigatorObserver> navigatorObservers = const [],
  }) async {
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);

    await pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeMode,
          navigatorObservers: navigatorObservers,
          // `home` keeps the harness simple; for router-driven screens pump
          // MaterialApp.router with an overridden GoRouter instead.
          home: Scaffold(body: child),
        ),
      ),
    );
    return container;
  }
}

/// Forces a fixed logical size for a test body, then restores it.
/// Use for size-dependent widget tests and goldens (skill 17 / stage 20).
Future<void> withSurfaceSize(
  WidgetTester tester,
  Size size,
  Future<void> Function() body,
) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await body();
}

// ---------------------------------------------------------------------------
// Data builders — defaults you can override per test.
// ---------------------------------------------------------------------------

/// Build a [Profile] with sensible defaults; override only what a test cares
/// about. When the model gains a field, change it here, not in every test.
Profile buildProfile({
  String id = 'u_1',
  String name = 'Ada Lovelace',
  String email = 'ada@example.com',
  bool isVerified = true,
}) {
  return Profile(
    id: id,
    name: name,
    email: email,
    isVerified: isVerified,
  );
}

// ---------------------------------------------------------------------------
// Fakes — reusable across unit, widget, and integration tests.
// ---------------------------------------------------------------------------

class MockProfileRepository extends Mock implements ProfileRepository {}

/// Call once in `setUpAll` if any stub uses `any()` with a non-primitive type.
void registerTestFallbacks() {
  registerFallbackValue(buildProfile());
}
