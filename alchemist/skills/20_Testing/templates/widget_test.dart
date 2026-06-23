// test/features/profile/presentation/profile_screen_widget_test.dart
//
// Widget test: pump a real screen inside ProviderScope with the controller's
// repository overridden by a mocktail fake. Assert the loading→data transition
// and a tap interaction. No real network — the gate for widget-level tests.
//
// Uses the shared pumpApp harness in ../support/test_helpers.dart.
// Conventions: ../../../references/CONVENTIONS.md (§6 state, §7 done).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:my_app/core/error/result.dart'; // Ok, Err, NetworkFailure
import 'package:my_app/features/profile/domain/profile_repository.dart';
import 'package:my_app/features/profile/presentation/profile_screen.dart';

// Re-use the harness + fakes + builders.
import '../../../support/test_helpers.dart';

void main() {
  late MockProfileRepository repo;

  setUpAll(registerTestFallbacks);

  setUp(() {
    repo = MockProfileRepository();
  });

  // The provider the screen's controller reads to get its repository.
  // Override with the fake so the real network is never touched.
  List<Override> get overrides =>
      [profileRepositoryProvider.overrideWithValue(repo)];

  group('ProfileScreen', () {
    testWidgets('shows loading, then renders the profile (loading→data)',
        (tester) async {
      // A Completer lets us observe the loading frame before resolving.
      final completer = Completer<Result<dynamic>>();
      when(() => repo.fetchProfile()).thenAnswer((_) => completer.future);

      await tester.pumpApp(const ProfileScreen(), overrides: overrides);

      // First frame: the future is still pending → loading state.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsNothing);

      // Resolve the repository, then pump to rebuild with data.
      completer.complete(Ok(buildProfile()));
      await tester.pump(); // settle the resolved future into the tree

      // Data state: profile fields render, loading gone.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('ada@example.com'), findsOneWidget);
      verify(() => repo.fetchProfile()).called(1);
    });

    testWidgets('tapping refresh re-fetches and updates the UI', (tester) async {
      when(() => repo.fetchProfile())
          .thenAnswer((_) async => Ok(buildProfile()));

      await tester.pumpApp(const ProfileScreen(), overrides: overrides);
      await tester.pump(); // resolve initial load → data

      // Change what the repo returns, then tap refresh.
      when(() => repo.fetchProfile())
          .thenAnswer((_) async => Ok(buildProfile(name: 'Grace Hopper')));

      await tester.tap(find.byKey(const Key('profile_refresh')));
      await tester.pumpAndSettle(); // let the refresh animation/future complete

      expect(find.text('Grace Hopper'), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsNothing);
      verify(() => repo.fetchProfile()).called(2); // initial + refresh
    });

    testWidgets('renders the error state when the repository fails',
        (tester) async {
      when(() => repo.fetchProfile())
          .thenAnswer((_) async => const Err(NetworkFailure('offline')));

      await tester.pumpApp(const ProfileScreen(), overrides: overrides);
      await tester.pump();

      // The error UX (skill 16) renders, with a retry affordance.
      expect(find.text('offline'), findsOneWidget);
      expect(find.byKey(const Key('profile_retry')), findsOneWidget);
    });
  });
}
