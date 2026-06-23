// test/features/profile/presentation/goldens/profile_card_golden_test.dart
//
// Golden test: render a component in LIGHT and DARK at fixed sizes and compare
// against committed reference PNGs. Catches visual regressions that finder-based
// widget tests miss. Ties to skill 17 (goldens across sizes) and CONVENTIONS §4
// (light + dark are both first-class).
//
// DETERMINISM (a golden that drifts is worse than none):
//   1. Load real fonts — the default test font is `Ahem` (boxes). Load app
//      fonts in flutter_test_config.dart (see note at bottom) or here.
//   2. Pin the size — never let the host window decide.
//   3. No real network / clock / random — override providers, inject a clock.
//   4. Run goldens on ONE pinned CI environment so anti-aliasing matches.
//
// Generate / refresh (then REVIEW the PNG diff in the PR — do not accept blind):
//   flutter test --update-goldens \
//     test/features/profile/presentation/goldens/profile_card_golden_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_app/app/theme/app_theme.dart'; // lightTheme / darkTheme
import 'package:my_app/features/profile/presentation/widgets/profile_card.dart';

import '../../../../support/test_helpers.dart'; // buildProfile, withSurfaceSize

void main() {
  // Sizes that matter for this component (phone + tablet width).
  const sizes = <String, Size>{
    'phone': Size(390, 320),
    'tablet': Size(840, 360),
  };

  Widget framed(ThemeData theme) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Scaffold(
        body: Center(
          // Deterministic data — no DateTime.now(), no network.
          child: ProfileCard(profile: buildProfile()),
        ),
      ),
    );
  }

  for (final theme in const {'light': true, 'dark': false}.entries) {
    final themeData = theme.value ? lightTheme : darkTheme;

    for (final size in sizes.entries) {
      testWidgets('ProfileCard golden — ${theme.key} @ ${size.key}',
          (tester) async {
        await withSurfaceSize(tester, size.value, () async {
          await tester.pumpWidget(framed(themeData));
          await tester.pumpAndSettle();

          await expectLater(
            find.byType(ProfileCard),
            matchesGoldenFile(
              'profile_card_${theme.key}_${size.key}.png',
            ),
          );
        });
      });
    }
  }
}

// ---------------------------------------------------------------------------
// One-time deterministic font loading. Put this in:
//   test/flutter_test_config.dart
// so EVERY test in the suite renders real glyphs. Example:
//
//   import 'dart:async';
//   import 'package:flutter_test/flutter_test.dart';
//
//   Future<void> testExecutable(FutureOr<void> Function() testMain) async {
//     TestWidgetsFlutterBinding.ensureInitialized();
//     await loadAppFonts(); // from golden_toolkit / alchemist, or roll your
//                           // own with FontLoader over your bundled .ttf files.
//     await testMain();
//   }
//
// With `alchemist` you can instead use `goldenTest(...)` which loads fonts and
// disables platform-specific rendering for stable cross-machine CI goldens.
// ---------------------------------------------------------------------------
