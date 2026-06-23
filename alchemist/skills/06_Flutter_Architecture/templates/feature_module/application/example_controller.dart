import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/example_repository_impl.dart';
import '../domain/example_entity.dart';

part 'example_controller.g.dart';

/// Screen-level state for the `example` feature.
///
/// An [AsyncNotifier]: `build()` performs the initial load, and the framework
/// exposes the result as an `AsyncValue` (loading / data / error) that the
/// screen renders. All business logic lives here — never in `build` of a widget
/// (see ../../../../SKILL.md and CONVENTIONS §6).
@riverpod
class ExampleController extends _$ExampleController {
  @override
  Future<List<ExampleEntity>> build() => _load();

  Future<List<ExampleEntity>> _load() {
    final repo = ref.read(exampleRepositoryProvider);
    // Once stage 15 lands, `getExamples()` returns `Result<List<...>>`; unwrap:
    //
    //   final result = await repo.getExamples();
    //   return switch (result) {
    //     Ok(:final value) => value,
    //     Err(:final failure) => throw failure, // AsyncValue.guard captures it
    //   };
    //
    // Placeholder against the interim Future-returning signature:
    return repo.getExamples();
  }

  /// Re-fetches the list, surfacing loading + error states to the UI.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  /// Optimistically toggles a single item's favorite flag.
  Future<void> toggleFavorite(String id) async {
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncData([
      for (final e in current)
        if (e.id == id) e.copyWith(isFavorite: !e.isFavorite) else e,
    ]);
    // TODO(stage-11): persist the change through the repository, then reconcile.
  }
}
