// lib/features/catalog/application/catalog_state.dart
//
// Immutable screen state for the catalog controller. Freezed gives us value
// equality, copyWith, and (optionally) JSON. The controller emits this wrapped
// in an AsyncValue<CatalogState>; never mutate it in place — always copyWith.
//
// Conventions: ../../../references/CONVENTIONS.md (§6 state contract).

import 'package:freezed_annotation/freezed_annotation.dart';

part 'catalog_state.freezed.dart';

/// Which subset of items the UI is currently showing.
enum CatalogFilter { all, favorites, archived }

/// A single catalog item (domain entity stand-in for the template).
@freezed
class CatalogItem with _$CatalogItem {
  const factory CatalogItem({
    required String id,
    required String title,
    @Default(false) bool isFavorite,
  }) = _CatalogItem;
}

/// The immutable state the [CatalogController] builds and mutates.
///
/// `items` is the full loaded set; `filter` is UI state. Prefer deriving the
/// *visible* list with a getter (or a `.select` in the widget) rather than
/// storing a second filtered copy that can drift.
@freezed
class CatalogState with _$CatalogState {
  const CatalogState._();

  const factory CatalogState({
    @Default(<CatalogItem>[]) List<CatalogItem> items,
    @Default(CatalogFilter.all) CatalogFilter filter,
  }) = _CatalogState;

  /// Items after applying the current [filter]. Pure, no side effects.
  List<CatalogItem> get visibleItems => switch (filter) {
        CatalogFilter.all => items,
        CatalogFilter.favorites => items.where((i) => i.isFavorite).toList(),
        CatalogFilter.archived => const <CatalogItem>[],
      };
}
