import 'package:flutter/material.dart';
// House stack uses `google_fonts`. Swap the family in one place (`_fontFamily`)
// to restyle the whole app. Example with the package:
//
//   import 'package:google_fonts/google_fonts.dart';
//   TextStyle base() => GoogleFonts.inter();
//
// To keep this template dependency-free and compilable as-is, we set the
// family by name. Add `inter` to pubspec fonts (or use google_fonts) so it
// resolves at runtime.

/// The display/body typeface for the whole app. Placeholder: **Inter** — a
/// clean, highly legible grotesque that reads as premium at small sizes.
/// A premium system uses one (at most two) typefaces.
const String _fontFamily = 'Inter';

/// Builds the Material 3 [TextTheme] (15 roles) for a given [ColorScheme].
///
/// The five role groups, largest → smallest:
/// - **display**  — hero / marketing-scale text, used sparingly.
/// - **headline** — page and section titles.
/// - **title**    — card titles, app-bar titles, list headers.
/// - **body**     — paragraph and default content text.
/// - **label**    — buttons, chips, captions, overlines.
///
/// Color is applied from the scheme so text is correct in light and dark.
TextTheme buildTextTheme(ColorScheme scheme) {
  final onSurface = scheme.onSurface;
  final onSurfaceVariant = scheme.onSurfaceVariant;

  TextStyle style({
    required double size,
    required FontWeight weight,
    required double height,
    double letterSpacing = 0,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      color: color ?? onSurface,
    );
  }

  return TextTheme(
    // Display — generous, tight tracking, light weight for elegance.
    displayLarge: style(size: 57, weight: FontWeight.w400, height: 1.12, letterSpacing: -0.25),
    displayMedium: style(size: 45, weight: FontWeight.w400, height: 1.16),
    displaySmall: style(size: 36, weight: FontWeight.w400, height: 1.22),

    // Headline — section and page titles, medium weight for presence.
    headlineLarge: style(size: 32, weight: FontWeight.w600, height: 1.25),
    headlineMedium: style(size: 28, weight: FontWeight.w600, height: 1.29),
    headlineSmall: style(size: 24, weight: FontWeight.w600, height: 1.33),

    // Title — component and list headers.
    titleLarge: style(size: 22, weight: FontWeight.w600, height: 1.27),
    titleMedium: style(size: 16, weight: FontWeight.w600, height: 1.50, letterSpacing: 0.15),
    titleSmall: style(size: 14, weight: FontWeight.w600, height: 1.43, letterSpacing: 0.1),

    // Body — paragraph text. Comfortable line height (~1.4–1.5).
    bodyLarge: style(size: 16, weight: FontWeight.w400, height: 1.50, letterSpacing: 0.15),
    bodyMedium: style(size: 14, weight: FontWeight.w400, height: 1.43, letterSpacing: 0.25),
    bodySmall: style(size: 12, weight: FontWeight.w400, height: 1.33, letterSpacing: 0.4, color: onSurfaceVariant),

    // Label — buttons, chips, captions. Slightly wider tracking for clarity.
    labelLarge: style(size: 14, weight: FontWeight.w600, height: 1.43, letterSpacing: 0.1),
    labelMedium: style(size: 12, weight: FontWeight.w600, height: 1.33, letterSpacing: 0.5),
    labelSmall: style(size: 11, weight: FontWeight.w600, height: 1.45, letterSpacing: 0.5, color: onSurfaceVariant),
  );
}
