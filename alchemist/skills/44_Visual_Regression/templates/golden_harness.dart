// test/golden/golden_harness.dart
//
// The visual-regression harness. `pumpGolden` renders a widget DETERMINISTICALLY
// — inside a ProviderScope (fakes for data), under a given ThemeData, at a pinned
// logical size — then settles to a stable frame ready for `matchesGoldenFile`.
//
// `goldenMatrix` runs a builder across the theme × size matrix (skill 44 §1) and
// captures one golden per cell, naming files <name>_<theme>_<size>.png so a failing
// CI artifact is self-describing.
//
// DETERMINISM (skill 44 §2) is the whole game:
//   - fonts: loaded once for the suite in test/flutter_test_config.dart.
//   - size: pinned here via setSurfaceSize — never the host window.
//   - data: pass `overrides` so providers return fixed fakes (no network).
//   - time/random: inject a fixed clock; no DateTime.now()/Random in the tree.
//
// Conventions: ../../references/CONVENTIONS.md (§4 widget hygiene, §6 Riverpod).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Illustrative import — point at your real theme (stage 04).
import 'package:my_app/app/theme/app_theme.dart'; // lightTheme / darkTheme

/// A named device size for the golden matrix. Values track stage 17 breakpoints.
class GoldenDevice {
  const GoldenDevice(this.name, this.size, {this.devicePixelRatio = 1});

  final String name;
  final Size size;
  final double devicePixelRatio;
}

/// The default capture matrix: phone (compact) + tablet (expanded).
/// Add a landscape entry only where the layout genuinely changes.
const kGoldenDevices = <GoldenDevice>[
  GoldenDevice('phone', Size(390, 844)),
  GoldenDevice('tablet', Size(840, 1180)),
];

/// The two themes — both are first-class (CONVENTIONS §4).
const kGoldenThemes = <String, bool>{'light': true, 'dark': false};

/// Pumps [child] in a deterministic golden context and settles it.
///
/// - [overrides] inject fakes so the tree renders fixed data (no network/clock).
/// - [light] selects [lightTheme] (true) or [darkTheme] (false).
/// - [device] pins the logical size + devicePixelRatio.
///
/// After this returns the tree is at a stable, settled frame — call
/// `expectLater(find..., matchesGoldenFile(...))` next.
Future<void> pumpGolden(
  WidgetTester tester,
  Widget child, {
  required bool light,
  required GoldenDevice device,
  List<Override> overrides = const [],
}) async {
  // Pin the surface size; restore after the test so cases don't bleed.
  await tester.binding.setSurfaceSize(device.size);
  tester.view.devicePixelRatio = device.devicePixelRatio;
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
    tester.view.devicePixelRatio = 1.0;
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: light ? lightTheme : darkTheme,
        home: Scaffold(body: child),
      ),
    ),
  );

  // Settle to a fixed frame — no mid-animation captures (skill 44 §2/§7).
  await tester.pumpAndSettle();
}

/// Captures a golden of [build()] across every theme × [devices] cell.
///
/// Produces files `<name>_<theme>_<device>.png` under the test's `goldens/`
/// folder. Call inside `void main()`:
///
/// ```dart
/// void main() {
///   goldenMatrix(
///     'home',
///     build: () => const HomeScreen(),
///     overrides: [homeControllerProvider.overrideWith(() => FakeHomeController())],
///   );
/// }
/// ```
void goldenMatrix(
  String name, {
  required Widget Function() build,
  List<Override> overrides = const [],
  List<GoldenDevice> devices = kGoldenDevices,
  Finder? finder,
}) {
  for (final theme in kGoldenThemes.entries) {
    for (final device in devices) {
      testWidgets('$name golden — ${theme.key} @ ${device.name}',
          (tester) async {
        await pumpGolden(
          tester,
          build(),
          light: theme.value,
          device: device,
          overrides: overrides,
        );

        await expectLater(
          finder ?? find.byType(MaterialApp),
          matchesGoldenFile('goldens/${name}_${theme.key}_${device.name}.png'),
        );
      });
    }
  }
}
