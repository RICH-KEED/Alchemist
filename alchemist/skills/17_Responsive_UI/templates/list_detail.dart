// lib/core/responsive/list_detail.dart
//
// Responsive list/detail (master-detail). On an expanded window the list and
// detail render side-by-side in one screen; on compact, the list is a full
// screen and tapping a row navigates to a separate detail route.
//
// This is the canonical large-screen pattern. The same selection state drives
// both modes — only the *presentation* differs.
//
// House style: see ../../references/CONVENTIONS.md (§4 — tokens for spacing, no
// hardcoded widths, both orientations verified).

import 'package:flutter/material.dart';

import 'breakpoints.dart';

// import '../../app/theme/app_tokens.dart'; // context.tokens.spacing.*

/// A responsive master-detail layout.
///
/// Provide a [list] builder (given a callback to select an item) and a [detail]
/// builder (given the currently selected id, or null). On expanded windows both
/// panes show; on compact, only the list shows and selection is delegated to
/// [onNavigateToDetail] (push a route via go_router).
///
/// ```dart
/// ListDetailLayout(
///   selectedId: state.selectedId,
///   onSelect: controller.select,
///   onNavigateToDetail: (id) =>
///       context.goNamed(AppRoute.itemDetail.name, pathParameters: {'id': id}),
///   list: (context, onTap) => ItemList(onTap: onTap),
///   detail: (context, id) => id == null
///       ? const _NoSelection()
///       : ItemDetail(id: id),
/// );
/// ```
class ListDetailLayout extends StatelessWidget {
  const ListDetailLayout({
    required this.list,
    required this.detail,
    required this.onSelect,
    required this.onNavigateToDetail,
    this.selectedId,
    this.listPaneWidth = 360,
    this.placeholder,
    super.key,
  });

  /// Builds the list/master pane. The provided callback should be wired to each
  /// row's tap so this widget can route correctly per size.
  final Widget Function(BuildContext context, ValueChanged<String> onTap) list;

  /// Builds the detail pane for [selectedId] (null = nothing selected).
  final Widget Function(BuildContext context, String? id) detail;

  /// Updates selection state in the two-pane (expanded) case.
  final ValueChanged<String> onSelect;

  /// Navigates to a standalone detail route in the single-pane (compact) case.
  final ValueChanged<String> onNavigateToDetail;

  final String? selectedId;

  /// Fixed width of the master pane in two-pane mode; the detail pane takes the
  /// rest. A fixed list column + flexible detail is the standard split.
  final double listPaneWidth;

  /// Shown in the detail pane when nothing is selected (two-pane only).
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    // Drive the split off the *incoming constraints*, not the whole window, so
    // this is correct even when nested inside an AdaptiveScaffold's body pane.
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoPane = constraints.maxWidth >= Breakpoints.dualPaneMin;

        if (!twoPane) {
          // Compact: list owns the screen; tapping routes to a detail screen.
          return list(context, onNavigateToDetail);
        }

        // Expanded: side-by-side. Tapping updates in-place selection state.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: listPaneWidth,
              child: list(context, onSelect),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              child: selectedId == null
                  ? (placeholder ?? const _NoSelectionPlaceholder())
                  : detail(context, selectedId),
            ),
          ],
        );
      },
    );
  }
}

/// Default empty state for the detail pane when nothing is selected.
class _NoSelectionPlaceholder extends StatelessWidget {
  const _NoSelectionPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.touch_app_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'Select an item',
            style: theme.textTheme.titleMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
