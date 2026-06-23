// Accessibility guideline widget tests (skill 45).
//
// Drives Flutter's built-in accessibility guideline matchers against a screen:
//   - textContrastGuideline    → WCAG AA text contrast (4.5:1 / 3:1)
//   - androidTapTargetGuideline → 48dp minimum touch targets (Android/Material)
//   - labeledTapTargetGuideline → every tappable element has a semantic label
// Plus a dynamic-type test that pumps the screen at textScaler 2.0 and asserts
// no layout overflow.
//
// Usage: copy into test/, replace `_screenUnderTest()` with your real screen
// (wrapped in whatever providers/theme it needs), then `flutter test`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Replace this with the screen you are auditing, wrapped in its real theme so
/// the contrast check sees the actual ColorScheme. Keep it a MaterialApp so
/// Directionality, MediaQuery, and Material ancestors exist.
Widget _screenUnderTest({TextScaler textScaler = TextScaler.noScaling}) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
      // 48dp tap targets app-wide — one of the cheapest a11y wins.
      materialTapTargetSize: MaterialTapTargetSize.padded,
    ),
    home: Builder(
      builder: (context) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(textScaler: textScaler),
          // ↓↓↓ Replace _DemoScreen with your screen under audit. ↓↓↓
          child: const _DemoScreen(),
        );
      },
    ),
  );
}

void main() {
  group('Accessibility guidelines', () {
    testWidgets('meets WCAG AA text contrast', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_screenUnderTest());
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('meets 48dp Android tap-target size', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_screenUnderTest());
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('every tap target is labeled', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_screenUnderTest());
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });

  group('Dynamic type', () {
    testWidgets('does not overflow at textScaler 2.0', (tester) async {
      await tester.pumpWidget(
        _screenUnderTest(textScaler: const TextScaler.linear(2.0)),
      );
      await tester.pumpAndSettle();
      // A RenderFlex overflow throws during layout; takeException surfaces it.
      expect(
        tester.takeException(),
        isNull,
        reason: 'Screen overflowed at 2.0x text scale — let text wrap / grow.',
      );
    });
  });
}

/// Demo screen showing the *passing* shape: labeled targets, 48dp buttons,
/// role-based colors. Delete this and audit your own screen instead.
class _DemoScreen extends StatelessWidget {
  const _DemoScreen();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          // tooltip doubles as the semantic label → passes labeled + 48dp.
          IconButton(
            tooltip: 'Edit profile',
            onPressed: () {},
            icon: const Icon(Icons.edit),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Account details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            // onSurfaceVariant is contrast-safe vs opacity-faded onSurface.
            Text(
              'Manage how others see you.',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () {},
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}
