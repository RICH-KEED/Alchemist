// integration_test/app_smoke_test.dart
//
// Integration smoke flow: run the REAL app on a device/emulator and drive it
// like a user — launch → navigate → perform a core action → assert. Proves the
// pieces are wired together (routing, real providers, real rendering) in a way
// unit/widget tests cannot. Keep it to the app's spine; push logic depth down
// the pyramid to unit tests.
//
// Run on an emulator:
//   flutter test integration_test/app_smoke_test.dart
// CI / device-farm invocation is stage 21's job — hand it off there.
//
// Conventions: ../references/CONVENTIONS.md.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// The real app shell. `MyApp` is your MaterialApp.router root (stage 06).
import 'package:my_app/app/app.dart';
// Override only what must not be real (e.g. point at a mock/staging backend).
import 'package:my_app/features/profile/domain/profile_repository.dart';

void main() {
  // Required: enables real-device test bindings + screenshot/timeline hooks.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('app smoke flow', () {
    testWidgets('launch → open Profile → refresh → see content',
        (tester) async {
      // Launch the real app. Override outbound IO so the smoke test is
      // deterministic; everything else (router, providers, UI) is real.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Swap in a fake/staging repo so we don't depend on prod network.
            // profileRepositoryProvider.overrideWithValue(StagingProfileRepository()),
          ],
          child: const MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. App launched — we land on the home screen.
      expect(find.byKey(const Key('home_screen')), findsOneWidget);

      // 2. Navigate to Profile via the bottom navigation.
      await tester.tap(find.byKey(const Key('nav_profile')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('profile_screen')), findsOneWidget);

      // 3. Perform a core action — pull a fresh profile.
      await tester.tap(find.byKey(const Key('profile_refresh')));
      await tester.pumpAndSettle();

      // 4. Assert the outcome — content rendered, no error surface.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(const Key('profile_name')), findsOneWidget);
    });
  });
}
