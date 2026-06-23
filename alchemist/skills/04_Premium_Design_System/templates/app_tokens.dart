import 'package:flutter/material.dart';

import 'color_schemes.dart';

/// Non-Material-3 design tokens, exposed as a [ThemeExtension] so they travel
/// with [ThemeData] and animate (via [lerp]) across light/dark transitions.
///
/// Material 3 already models color *roles* (`ColorScheme`) and typography
/// (`TextTheme`); [AppTokens] carries everything it does not: the spacing and
/// radius scales, elevation steps, motion, and the semantic colors
/// (success / warning / info).
///
/// Access it anywhere via:
/// ```dart
/// final tokens = Theme.of(context).extension<AppTokens>()!;
/// ```
/// or with the [BuildContextTokens] helper: `context.tokens.spacing.md`.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.spacing,
    required this.radius,
    required this.elevation,
    required this.motion,
    required this.semantic,
  });

  /// Light-mode token set. Spacing/radii/elevation/motion are mode-agnostic;
  /// only the semantic colors differ between light and dark.
  factory AppTokens.light() => AppTokens(
        spacing: const AppSpacing(),
        radius: const AppRadius(),
        elevation: const AppElevation(),
        motion: const AppMotion(),
        semantic: AppSemanticColors.light,
      );

  /// Dark-mode token set.
  factory AppTokens.dark() => AppTokens(
        spacing: const AppSpacing(),
        radius: const AppRadius(),
        elevation: const AppElevation(),
        motion: const AppMotion(),
        semantic: AppSemanticColors.dark,
      );

  final AppSpacing spacing;
  final AppRadius radius;
  final AppElevation elevation;
  final AppMotion motion;
  final AppSemanticColors semantic;

  @override
  AppTokens copyWith({
    AppSpacing? spacing,
    AppRadius? radius,
    AppElevation? elevation,
    AppMotion? motion,
    AppSemanticColors? semantic,
  }) {
    return AppTokens(
      spacing: spacing ?? this.spacing,
      radius: radius ?? this.radius,
      elevation: elevation ?? this.elevation,
      motion: motion ?? this.motion,
      semantic: semantic ?? this.semantic,
    );
  }

  @override
  AppTokens lerp(covariant ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    // Spacing, radii, elevation and motion are constant across modes, so they
    // snap rather than interpolate; only the semantic colors are lerped to keep
    // theme cross-fades smooth.
    return AppTokens(
      spacing: t < 0.5 ? spacing : other.spacing,
      radius: t < 0.5 ? radius : other.radius,
      elevation: t < 0.5 ? elevation : other.elevation,
      motion: t < 0.5 ? motion : other.motion,
      semantic: semantic.lerp(other.semantic, t),
    );
  }
}

/// 4/8-based spacing scale. Premium layouts lean on the upper half.
@immutable
class AppSpacing {
  const AppSpacing();

  final double xs = 4;
  final double sm = 8;
  final double md = 16;
  final double lg = 24;
  final double xl = 32;
  final double xxl = 48;
}

/// Corner radius scale. `pill` is effectively fully rounded.
@immutable
class AppRadius {
  const AppRadius();

  final double sm = 8;
  final double md = 12;
  final double lg = 16;
  final double xl = 24;
  final double pill = 999;

  Radius get smRadius => Radius.circular(sm);
  Radius get mdRadius => Radius.circular(md);
  Radius get lgRadius => Radius.circular(lg);
  Radius get xlRadius => Radius.circular(xl);

  BorderRadius get smBorder => BorderRadius.circular(sm);
  BorderRadius get mdBorder => BorderRadius.circular(md);
  BorderRadius get lgBorder => BorderRadius.circular(lg);
  BorderRadius get xlBorder => BorderRadius.circular(xl);
}

/// Elevation steps in dp. Kept low and consistent — M3 favours tonal surface
/// tints over heavy shadows.
@immutable
class AppElevation {
  const AppElevation();

  final double level0 = 0;
  final double level1 = 1;
  final double level2 = 3;
  final double level3 = 6;
  final double level4 = 8;
  final double level5 = 12;
}

/// Motion tokens: a small, fixed set of durations and curves so every
/// transition in the app feels like part of one system.
@immutable
class AppMotion {
  const AppMotion();

  final Duration fast = const Duration(milliseconds: 120);
  final Duration medium = const Duration(milliseconds: 240);
  final Duration slow = const Duration(milliseconds: 400);

  /// Default easing for most UI changes.
  final Curve standard = Curves.easeInOutCubicEmphasized;

  /// For high-emphasis enter/exit (FABs, dialogs, hero moments).
  final Curve emphasized = Curves.easeOutCubic;
}

/// Semantic colors Material 3 has no role for. Each `on*` is the readable
/// foreground for content placed on the matching surface.
@immutable
class AppSemanticColors {
  const AppSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.info,
    required this.onInfo,
  });

  /// Light-mode semantic palette, sourced from [SemanticPalette].
  static const AppSemanticColors light = AppSemanticColors(
    success: SemanticPalette.success,
    onSuccess: SemanticPalette.onSuccess,
    warning: SemanticPalette.warning,
    onWarning: SemanticPalette.onWarning,
    info: SemanticPalette.info,
    onInfo: SemanticPalette.onInfo,
  );

  /// Dark-mode semantic palette (slightly lighter, desaturated tones read
  /// better on dark surfaces).
  static const AppSemanticColors dark = AppSemanticColors(
    success: SemanticPalette.successDark,
    onSuccess: SemanticPalette.onSuccessDark,
    warning: SemanticPalette.warningDark,
    onWarning: SemanticPalette.onWarningDark,
    info: SemanticPalette.infoDark,
    onInfo: SemanticPalette.onInfoDark,
  );

  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;
  final Color info;
  final Color onInfo;

  AppSemanticColors lerp(AppSemanticColors other, double t) {
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
    );
  }
}

/// Ergonomic access to [AppTokens] from any widget.
///
/// ```dart
/// Padding(padding: EdgeInsets.all(context.tokens.spacing.md));
/// ```
extension BuildContextTokens on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
