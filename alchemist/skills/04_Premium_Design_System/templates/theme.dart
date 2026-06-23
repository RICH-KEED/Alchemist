import 'package:flutter/material.dart';

import 'app_tokens.dart';
import 'color_schemes.dart';
import 'typography.dart';

/// Assembles the app's [ThemeData] from the design tokens.
///
/// This is the single place where the seed color, typography, the [AppTokens]
/// extension, and the component themes come together. Widgets must read from
/// `Theme.of(context)` / `context.tokens` — never hardcode colors or sizes.
///
/// Wire into `MaterialApp.router`:
/// ```dart
/// MaterialApp.router(
///   theme: AppTheme.light,
///   darkTheme: AppTheme.dark,
///   themeMode: ThemeMode.system,
///   routerConfig: router,
/// );
/// ```
abstract final class AppTheme {
  /// Light theme.
  static final ThemeData light = _build(
    scheme: lightColorScheme,
    tokens: AppTokens.light(),
  );

  /// Dark theme.
  static final ThemeData dark = _build(
    scheme: darkColorScheme,
    tokens: AppTokens.dark(),
  );

  static ThemeData _build({
    required ColorScheme scheme,
    required AppTokens tokens,
  }) {
    final textTheme = buildTextTheme(scheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      // Register the non-M3 token set so it travels with the theme.
      extensions: <ThemeExtension<dynamic>>[tokens],

      // --- Component themes: the "specs" every widget inherits. ---
      appBarTheme: AppBarTheme(
        elevation: tokens.elevation.level0,
        scrolledUnderElevation: tokens.elevation.level2,
        centerTitle: true,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: scheme.surfaceTint,
        titleTextStyle: textTheme.titleLarge,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.lg),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: tokens.radius.mdBorder),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, 48),
          elevation: tokens.elevation.level1,
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.lg),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: tokens.radius.mdBorder),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.lg),
          textStyle: textTheme.labelLarge,
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(borderRadius: tokens.radius.mdBorder),
        ),
      ),

      cardTheme: CardThemeData(
        elevation: tokens.elevation.level1,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: scheme.surfaceTint,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: tokens.radius.lgBorder),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.md,
          vertical: tokens.spacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: tokens.radius.mdBorder,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: tokens.radius.mdBorder,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: tokens.radius.mdBorder,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: tokens.radius.mdBorder,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: tokens.radius.mdBorder,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),

      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: tokens.radius.smBorder),
        labelStyle: textTheme.labelLarge,
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: tokens.spacing.md,
        thickness: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: tokens.radius.mdBorder),
      ),
    );
  }
}
