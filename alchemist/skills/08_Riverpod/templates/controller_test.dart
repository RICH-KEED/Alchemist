// test/features/catalog/application/catalog_controller_test.dart
//
// Provider-override test: inject a mocktail fake repository through a
// ProviderContainer, pump the controller, and assert state transitions.
// This is the stage-08 exit gate — loading→data AND the error path must pass.
//
// Conventions: ../../../references/CONVENTIONS.md (§6). No real network.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

// Source under test (illustrative paths for the template).
import 'package:my_app/features/catalog/application/catalog_controller.dart';
import 'package:my_app/features/catalog/application/catalog_state.dart';
import 'package:my_app/features/catalog/domain/catalog_repository.dart';
import 'package:my_app/core/error/result.dart'; // Ok, Err, NetworkFailure

class MockCatalogRepository extends Mock implements CatalogRepository {}

void main() {
  late MockCatalogRepository repo;

  // Helper: build a container with the repo overridden and auto-tear-down.
  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  const items = [
    CatalogItem(id: '1', title: 'Alpha'),
    CatalogItem(id: '2', title: 'Beta', isFavorite: true),
  ];

  setUp(() {
    repo = MockCatalogRepository();
  });

  group('CatalogController.build', () {
    test('loading → data when the repository returns Ok', () async {
      when(() => repo.fetchItems())
          .thenAnswer((_) async => const Ok(items));

      final container = makeContainer();

      // Before the future resolves the state is loading.
      expect(
        container.read(catalogControllerProvider),
        const AsyncLoading<CatalogState>(),
      );

      // `.future` awaits the build's Future → resolves to data.
      final state = await container.read(catalogControllerProvider.future);
      expect(state.items, items);
      expect(state.filter, CatalogFilter.all);

      expect(
        container.read(catalogControllerProvider).hasValue,
        isTrue,
      );
      verify(() => repo.fetchItems()).called(1);
    });

    test('loading → error when the repository returns Err', () async {
      when(() => repo.fetchItems())
          .thenAnswer((_) async => const Err(NetworkFailure('offline')));

      final container = makeContainer();

      // Awaiting `.future` should throw the unwrapped Failure.
      await expectLater(
        container.read(catalogControllerProvider.future),
        throwsA(isA<NetworkFailure>()),
      );

      final async = container.read(catalogControllerProvider);
      expect(async.hasError, isTrue);
      expect(async.error, isA<NetworkFailure>());
    });
  });

  group('mutations', () {
    test('setFilter emits new state without touching the repo', () async {
      when(() => repo.fetchItems())
          .thenAnswer((_) async => const Ok(items));

      final container = makeContainer();
      await container.read(catalogControllerProvider.future);

      container.read(catalogControllerProvider.notifier).setFilter(
            CatalogFilter.favorites,
          );

      final state = container.read(catalogControllerProvider).requireValue;
      expect(state.filter, CatalogFilter.favorites);
      expect(state.visibleItems.map((i) => i.id), ['2']);
    });

    test('toggleFavorite surfaces AsyncError on repo failure', () async {
      when(() => repo.fetchItems())
          .thenAnswer((_) async => const Ok(items));
      when(() => repo.toggleFavorite(any()))
          .thenAnswer((_) async => const Err(NetworkFailure('boom')));

      final container = makeContainer();
      await container.read(catalogControllerProvider.future);

      await container
          .read(catalogControllerProvider.notifier)
          .toggleFavorite('1');

      expect(container.read(catalogControllerProvider).hasError, isTrue);
    });
  });
}
