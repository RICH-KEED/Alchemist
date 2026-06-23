// lib/core/responsive/adaptive_scaffold.dart
//
// One scaffold that renders the right navigation affordance for the current
// window size: a bottom NavigationBar on compact, a collapsed NavigationRail on
// medium, and an extended (labelled) rail on expanded. Same destinations, same
// body — only the chrome changes.
//
// Designed to host the StatefulShellRoute from stage 07 (Navigation): pass the
// shell's `currentIndex` as [selectedIndex] and call `navigationShell.goBranch`
// from [onDestinationSelected].
//
// House style: see ../../references/CONVENTIONS.md (§4 — const, extracted
// widgets, tokens for spacing, 48dp touch targets, Semantics).

import 'package:flutter/material.dart';

import 'breakpoints.dart';

// If your AppTokens live elsewhere, fix this import. The extension gives
// `context.tokens.spacing.*` — we never hardcode spacing.
// import '../../app/theme/app_tokens.dart';

/// A single navigation destination, rendered as a `NavigationBar` item, a
/// `NavigationRail` item, or a `NavigationDrawer` item depending on size.
@immutable
class AdaptiveDestination {
  const AdaptiveDestination({
    required this.icon,
    required this.label,
    Widget? selectedIcon,
  }) : selectedIcon = selectedIcon ?? icon;

  final Widget icon;
  final Widget selectedIcon;
  final String label;
}

/// Scaffold that swaps navigation chrome by [WindowSize].
///
/// ```dart
/// AdaptiveScaffold(
///   destinations: const [
///     AdaptiveDestination(icon: Icon(Icons.home_outlined),
///         selectedIcon: Icon(Icons.home), label: 'Home'),
///     AdaptiveDestination(icon: Icon(Icons.list_outlined),
///         selectedIcon: Icon(Icons.list), label: 'Items'),
///   ],
///   selectedIndex: shell.currentIndex,
///   onDestinationSelected: shell.goBranch,
///   body: shell, // the StatefulShellRoute's navigationShell
/// );
/// ```
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.floatingActionButton,
    this.appBar,
    this.railLeading,
    super.key,
  }) : assert(destinations.length >= 2, 'Need >= 2 destinations for nav.');

  final List<AdaptiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  /// The page content shared across all sizes (typically the navigation shell).
  final Widget body;

  /// Optional FAB. On rail layouts it is hoisted into the rail's leading slot
  /// instead of floating, which is the M3 large-screen convention.
  final Widget? floatingActionButton;

  final PreferredSizeWidget? appBar;

  /// Extra widget shown above the rail items (e.g. a menu/logo). Ignored on
  /// compact.
  final Widget? railLeading;

  @override
  Widget build(BuildContext context) {
    final size = context.windowSize;

    if (size.isCompact) {
      return Scaffold(
        appBar: appBar,
        body: SafeArea(child: body),
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: [
            for (final d in destinations)
              NavigationDestination(
                icon: d.icon,
                selectedIcon: d.selectedIcon,
                label: d.label,
              ),
          ],
        ),
      );
    }

    // Medium + expanded: a rail beside the body. Expanded shows labels
    // (extended rail); medium stays collapsed to save horizontal space.
    final extended = size.isExpanded;

    return Scaffold(
      appBar: appBar,
      body: SafeArea(
        child: Row(
          children: [
            _AdaptiveRail(
              destinations: destinations,
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              extended: extended,
              leading: railLeading,
              fab: floatingActionButton,
            ),
            const VerticalDivider(width: 1, thickness: 1),
            // Body fills the remaining width. Its own LayoutBuilder /
            // ResponsiveBuilder can split into list/detail from here.
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// The rail half of [AdaptiveScaffold], extracted into its own widget (per §4:
/// classes over `_buildX` methods) so it rebuilds independently.
class _AdaptiveRail extends StatelessWidget {
  const _AdaptiveRail({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.extended,
    required this.leading,
    required this.fab,
  });

  final List<AdaptiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool extended;
  final Widget? leading;
  final Widget? fab;

  @override
  Widget build(BuildContext context) {
    // Token-driven spacing; replace the literals below by importing AppTokens
    // and using `context.tokens.spacing.*`. Kept inline here so the template
    // compiles standalone.
    const railGap = 8.0;

    return NavigationRail(
      extended: extended,
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      labelType:
          extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
      leading: (leading != null || fab != null)
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) leading!,
                if (fab != null) ...[
                  const SizedBox(height: railGap),
                  fab!,
                ],
              ],
            )
          : null,
      destinations: [
        for (final d in destinations)
          NavigationRailDestination(
            icon: d.icon,
            selectedIcon: d.selectedIcon,
            label: Text(d.label),
          ),
      ],
    );
  }
}
