// lib/features/catalog/application/catalog_controller.dart
//
// The default screen controller shape: an @riverpod AsyncNotifier whose `build`
// returns Future<State>. It loads initial data via an injected repository and
// exposes mutation methods that use AsyncValue.guard.
//
// Run codegen after editing:
//   dart run build_runner build --delete-conflicting-outputs
//
// Conventions: ../../../references/CONVENTIONS.md  (§6 state, §5 Result/Failure)
// Result/Failure types are owned by skill 15; repositories by skills 06/11.

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'catalog_state.dart';
// Domain contract + Result types (illustrative import paths for the template).
import '../domain/catalog_repository.dart'; // CatalogRepository, catalogRepositoryProvider
import '../../../core/error/result.dart'; // Result, Ok, Err, Failure

part 'catalog_controller.g.dart';

/// Controls the catalog screen's state.
///
/// `build` is the initial load — its returned Future becomes the first
/// AsyncData (or AsyncError). Mutation methods reassign [state]; they wrap async
/// work in [AsyncValue.guard] so a thrown [Failure] becomes AsyncError instead
/// of crashing the zone.
///
/// autoDispose is the codegen default (no `keepAlive`), correct for screen
/// state — it clears when the screen is popped.
@riverpod
class CatalogController extends _$CatalogController {
  // Pull the repo reactively; tests override this provider with a fake.
  CatalogRepository get _repo => ref.watch(catalogRepositoryProvider);

  @override
  Future<CatalogState> build() async {
    final items = await _load();
    return CatalogState(items: items);
  }

  /// Re-fetch from the repository, surfacing loading then data/error.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final items = await _load();
      // Preserve the current filter across a refresh.
      final filter = state.valueOrNull?.filter ?? CatalogFilter.all;
      return CatalogState(items: items, filter: filter);
    });
  }

  /// Pure UI mutation — no I/O, so no guard needed. Emits a new immutable state.
  void setFilter(CatalogFilter filter) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(filter: filter));
  }

  /// Optimistic-ish toggle that persists via the repo and reconciles on error.
  Future<void> toggleFavorite(String id) async {
    final current = state.valueOrNull;
    if (current == null) return;

    state = await AsyncValue.guard(() async {
      final res = await _repo.toggleFavorite(id);
      // Result interop: unwrap Ok, rethrow Failure so guard → AsyncError.
      final updated = switch (res) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      };
      final items = [
        for (final i in current.items)
          if (i.id == id) updated else i,
      ];
      return current.copyWith(items: items);
    });
  }

  /// Loads items and unwraps the repository's Result into a plain list,
  /// throwing the Failure so the caller's `guard` (or `build`) converts it.
  Future<List<CatalogItem>> _load() async {
    final Result<List<CatalogItem>> res = await _repo.fetchItems();
    return switch (res) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
  }
}
