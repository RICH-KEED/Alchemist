import 'package:flutter/material.dart';

/// The single brand seed. Every Material 3 color role for both light and dark
/// is generated from this one value, guaranteeing a harmonious, accessible
/// palette. Replace with the brand/PRD color — change it here and nowhere else.
const Color kSeedColor = Color(0xFF4F46E5); // indigo 600

/// Light [ColorScheme] derived from [kSeedColor].
final ColorScheme lightColorScheme = ColorScheme.fromSeed(
  seedColor: kSeedColor,
);

/// Dark [ColorScheme] derived from the same seed.
final ColorScheme darkColorScheme = ColorScheme.fromSeed(
  seedColor: kSeedColor,
  brightness: Brightness.dark,
);

/// Semantic colors that Material 3 has no first-class role for.
///
/// These are referenced by `AppTokens` (see `app_tokens.dart`) rather than
/// used directly, so widgets always go through the token layer. Tuned for
/// adequate contrast against the M3 surface colors in each mode.
abstract final class SemanticPalette {
  // --- Light ---
  static const Color success = Color(0xFF1E8E3E);
  static const Color onSuccess = Color(0xFFFFFFFF);
  static const Color warning = Color(0xFFB26A00);
  static const Color onWarning = Color(0xFFFFFFFF);
  static const Color info = Color(0xFF1A73E8);
  static const Color onInfo = Color(0xFFFFFFFF);

  // --- Dark (lighter, slightly desaturated for dark surfaces) ---
  static const Color successDark = Color(0xFF6CD292);
  static const Color onSuccessDark = Color(0xFF00390F);
  static const Color warningDark = Color(0xFFF2B765);
  static const Color onWarningDark = Color(0xFF3D2400);
  static const Color infoDark = Color(0xFF8AB4F8);
  static const Color onInfoDark = Color(0xFF062E6F);
}
