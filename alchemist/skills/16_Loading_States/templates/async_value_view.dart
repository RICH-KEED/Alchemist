// core/widgets/async_value_view.dart
//
// The canonical async-surface renderer. Owned by skill 16 (Loading_States).
// Maps a Riverpod AsyncValue<T> to the FOUR states every data surface must
// render: loading -> data -> empty -> error (see CONVENTIONS.md §4).
//
// Controllers (skill 08) produce AsyncValue<T>; this widget consumes it. It is
// the ONLY place `.when` UI branching should live — features compose this, they
// do not re-implement it.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Skill 15 owns the error UX. ErrorStateView already maps a Failure to friendly
// copy via the `failure_x.dart` extension, so we just hand it the error object.
//   import 'package:app/core/error/failure.dart';
//   import 'package:app/core/widgets/error_state.dart';
import 'error_state.dart';
import 'empty_state.dart';
import 'skeletons.dart';

/// Renders an [AsyncValue] across all four async states with one consistent
/// policy, so no feature hand-rolls `.when` branches (and forgets the empty
/// or error case — the usual bug).
///
/// ```dart
/// final state = ref.watch(productsControllerProvider);
/// return AsyncValueView<List<Product>>(
///   value: state,
///   isEmpty: (items) => items.isEmpty,
///   onRetry: () => ref.invalidate(productsControllerProvider),
///   loading: (_) => const ProductListSkeleton(),
///   empty: (_) => EmptyState(
///     icon: Icons.inventory_2_outlined,
///     title: 'No products yet',
///     message: 'Products you add will show up here.',
///     actionLabel: 'Add product',
///     onAction: () => context.push('/products/new'),
///   ),
///   data: (items) => ProductList(items: items),
/// );
/// ```
///
/// State selection order:
/// 1. [AsyncError]            -> [error] (defaults to [ErrorStateView]).
/// 2. data present + [isEmpty] true -> [empty] (defaults to a neutral message).
/// 3. data present            -> [data].
/// 4. [AsyncLoading]          -> [loading] (defaults to a centered spinner;
///    pass a skeleton from [skeletons.dart] for a premium feel).
///
/// While *refreshing* (we already have data but a reload is in flight) the
/// builder keeps showing [data] — refresh is surfaced by a [RefreshIndicator]
/// or a footer, never by collapsing the whole surface back to a spinner.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    required this.value,
    required this.data,
    this.isEmpty,
    this.empty,
    this.loading,
    this.error,
    this.onRetry,
    this.skipLoadingOnRefresh = true,
    super.key,
  });

  /// The state envelope from a controller (skill 08).
  final AsyncValue<T> value;

  /// Builds the populated, non-empty UI.
  final Widget Function(T data) data;

  /// Treats a *successful* value as "empty" (e.g. an empty list). When it
  /// returns true the [empty] builder is used instead of [data]. Omit for
  /// surfaces that can never be empty (a single object, a profile, …).
  final bool Function(T data)? isEmpty;

  /// Builds the empty state. Defaults to a neutral [EmptyState]; supply your
  /// own for a helpful cause + primary action (strongly preferred).
  final Widget Function(T data)? empty;

  /// Builds the loading state. Defaults to a centered [CircularProgressIndicator];
  /// pass a skeleton matching the final layout for a premium feel.
  final Widget Function(AsyncValue<T> previous)? loading;

  /// Builds the error state. Defaults to [ErrorStateView] (skill 15 UX) wired
  /// to [onRetry].
  final Widget Function(Object error, StackTrace? stackTrace)? error;

  /// Retry callback for the default error state — typically
  /// `() => ref.invalidate(theControllerProvider)`.
  final VoidCallback? onRetry;

  /// When true (default), a reload that happens while data is already on screen
  /// keeps showing the data instead of flashing the loading state.
  final bool skipLoadingOnRefresh;

  @override
  Widget build(BuildContext context) {
    // Error wins, but only when there's no data to keep showing. If we have
    // stale data + an error (a failed refresh), prefer keeping data on screen;
    // the controller/widget should surface the error via a SnackBar instead.
    if (value.hasError && !value.hasValue) {
      return error?.call(value.error!, value.stackTrace) ??
          ErrorStateView.fromError(
            value.error!,
            stackTrace: value.stackTrace,
            onRetry: onRetry,
          );
    }

    return value.when(
      skipLoadingOnRefresh: skipLoadingOnRefresh,
      skipLoadingOnReload: skipLoadingOnRefresh,
      data: (resolved) {
        if (isEmpty?.call(resolved) ?? false) {
          return empty?.call(resolved) ?? _defaultEmpty(context);
        }
        return data(resolved);
      },
      loading: () => loading?.call(value) ?? const _CenteredSpinner(),
      error: (err, st) =>
          error?.call(err, st) ??
          ErrorStateView.fromError(err, stackTrace: st, onRetry: onRetry),
    );
  }

  Widget _defaultEmpty(BuildContext context) => const EmptyState(
        icon: Icons.inbox_outlined,
        title: 'Nothing here yet',
        message: 'There is nothing to show right now.',
      );
}

class _CenteredSpinner extends StatelessWidget {
  const _CenteredSpinner();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
}

/// Pull-to-refresh wrapper that pairs naturally with [AsyncValueView]. Wrap a
/// scrollable surface so the user can reload without losing the current data.
///
/// ```dart
/// AsyncRefreshView(
///   onRefresh: () => ref.refresh(productsControllerProvider.future),
///   child: AsyncValueView(...),
/// );
/// ```
class AsyncRefreshView extends StatelessWidget {
  const AsyncRefreshView({
    required this.onRefresh,
    required this.child,
    super.key,
  });

  /// Awaited by the [RefreshIndicator] — return the controller's `.future` so
  /// the spinner stays until the reload completes.
  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: onRefresh,
        child: child,
      );
}
