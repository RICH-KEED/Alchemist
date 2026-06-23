// lib/core/responsive/breakpoints.dart
//
// Window size classes + a breakpoint set, a `context.windowSize` extension, a
// `ResponsiveBuilder`, and a value-by-size helper. This is the single source of
// truth for "how wide are we?" — features never compare raw pixel widths.
//
// House style: see ../../references/CONVENTIONS.md (§4 widget hygiene; no
// hardcoded sizes — pull spacing/radii from AppTokens).

import 'package:flutter/widgets.dart';

/// Material 3 window **width** size classes.
///
/// These map to Google's official breakpoints and drive almost every adaptive
/// decision (which navigation affordance, single-pane vs. list/detail, column
/// counts). Heights have their own classes in M3, but width is what 95% of
/// layouts branch on, so that is what we model here.
///
/// - [compact]  : `width < 600`  — phones in portrait. Bottom `NavigationBar`.
/// - [medium]   : `600 <= width < 840` — large phones landscape, small tablets,
///   foldables unfolded. Collapsed `NavigationRail`.
/// - [expanded] : `width >= 840` — tablets, desktops, foldables landscape.
///   Extended rail / `NavigationDrawer`, and list/detail side-by-side.
enum WindowSize {
  compact,
  medium,
  expanded;

  bool get isCompact => this == WindowSize.compact;
  bool get isMedium => this == WindowSize.medium;
  bool get isExpanded => this == WindowSize.expanded;

  /// True for medium *or* expanded — i.e. anything wide enough to show a rail
  /// instead of a bottom bar.
  bool get isAtLeastMedium => this != WindowSize.compact;
}

/// The width thresholds (in logical pixels) between window size classes.
///
/// Centralised so a breakpoint tweak is one edit, never a scatter of magic
/// numbers. These are the M3 defaults; override per-project if a design calls
/// for it, but do it *here*.
abstract final class Breakpoints {
  const Breakpoints._();

  /// `< this` is [WindowSize.compact].
  static const double compactMax = 600;

  /// `< this` (and `>= compactMax`) is [WindowSize.medium].
  static const double mediumMax = 840;

  /// Above this width a list/detail layout should show both panes at once.
  /// (Same as [mediumMax] by default, named separately so the intent is clear
  /// at the call site.)
  static const double dualPaneMin = mediumMax;

  /// Classify a logical-pixel width into a [WindowSize].
  static WindowSize sizeForWidth(double width) {
    if (width < compactMax) return WindowSize.compact;
    if (width < mediumMax) return WindowSize.medium;
    return WindowSize.expanded;
  }
}

/// Read the current [WindowSize] from `MediaQuery`.
///
/// Prefer this for *app-level* decisions (which nav affordance the whole
/// scaffold shows). For a *single widget* that must adapt to the box it is
/// actually given (a card in a grid, a pane), use [ResponsiveBuilder] /
/// `LayoutBuilder` instead — `MediaQuery` reports the whole window, not your
/// widget's constraints.
extension WindowSizeContext on BuildContext {
  /// The window size class derived from the current window width.
  WindowSize get windowSize =>
      Breakpoints.sizeForWidth(MediaQuery.sizeOf(this).width);

  /// Shorthand: are we on a compact (phone-portrait-ish) layout?
  bool get isCompact => windowSize.isCompact;

  /// The current orientation. Landscape on a phone is still [WindowSize.medium]
  /// or higher by width, so branch on whichever the layout actually needs.
  Orientation get orientation => MediaQuery.orientationOf(this);
}

/// Pick one of three values by the current [WindowSize], with sensible
/// fall-through: a missing [medium] falls back to [compact], a missing
/// [expanded] falls back to [medium] (then [compact]).
///
/// ```dart
/// final columns = responsiveValue(context, compact: 1, medium: 2, expanded: 3);
/// ```
T responsiveValue<T>(
  BuildContext context, {
  required T compact,
  T? medium,
  T? expanded,
}) {
  switch (context.windowSize) {
    case WindowSize.compact:
      return compact;
    case WindowSize.medium:
      return medium ?? compact;
    case WindowSize.expanded:
      return expanded ?? medium ?? compact;
  }
}

/// Builds different widget trees per [WindowSize], driven by the **incoming
/// constraints** (via `LayoutBuilder`) rather than the whole window. That makes
/// it correct inside a pane or split view, not just at the top of the tree.
///
/// Provide [compact] at minimum; [medium]/[expanded] fall through to the
/// smaller builder when omitted (same rule as [responsiveValue]).
///
/// ```dart
/// ResponsiveBuilder(
///   compact: (context) => const _PhoneBody(),
///   expanded: (context) => const _TabletBody(),
/// );
/// ```
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    required this.compact,
    this.medium,
    this.expanded,
    super.key,
  });

  final WidgetBuilder compact;
  final WidgetBuilder? medium;
  final WidgetBuilder? expanded;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Breakpoints.sizeForWidth(constraints.maxWidth);
        switch (size) {
          case WindowSize.compact:
            return compact(context);
          case WindowSize.medium:
            return (medium ?? compact)(context);
          case WindowSize.expanded:
            return (expanded ?? medium ?? compact)(context);
        }
      },
    );
  }
}
