// test/flutter_test_config.dart
//
// GLOBAL test configuration. Flutter auto-discovers a file named exactly
// `flutter_test_config.dart` at the root of `test/` and wraps EVERY test in this
// `testExecutable` — so this is the one place to make goldens deterministic for
// the whole suite.
//
// Why it matters (skill 44 §2): the default test font is `Ahem`, which renders
// every glyph as a box. A golden taken with Ahem diffs against itself fine but
// tells you nothing about real text, and any font-metric change silently shifts
// layout. Loading real fonts ONCE here means every golden in the suite renders
// real glyphs with stable metrics.
//
// Conventions: ../../references/CONVENTIONS.md

import 'dart:async';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Load the fonts the app ships so goldens render real glyphs.
  await _loadAppFonts();

  await testMain();
}

// ---------------------------------------------------------------------------
// Font loading.
//
// EASIEST: depend on `golden_toolkit` (or `alchemist`) and call its loader,
// which also pulls in Material/Cupertino icon fonts:
//
//   import 'package:golden_toolkit/golden_toolkit.dart';
//   ...
//   await loadAppFonts();
//
// The hand-rolled version below has no extra dependency: it registers each
// bundled .ttf declared under `flutter: fonts:` in pubspec.yaml. Add an entry
// per family/weight you ship. Keep the family names in sync with pubspec.
// ---------------------------------------------------------------------------

Future<void> _loadAppFonts() async {
  // family -> list of bundled asset paths (one per weight/style).
  const fonts = <String, List<String>>{
    'Inter': [
      'assets/fonts/Inter-Regular.ttf',
      'assets/fonts/Inter-Medium.ttf',
      'assets/fonts/Inter-SemiBold.ttf',
      'assets/fonts/Inter-Bold.ttf',
    ],
  };

  for (final entry in fonts.entries) {
    final loader = FontLoader(entry.key);
    for (final asset in entry.value) {
      loader.addFont(
        rootBundle.load(asset),
      );
    }
    await loader.load();
  }
}
