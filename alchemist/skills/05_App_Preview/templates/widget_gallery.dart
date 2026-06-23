// Widget gallery — a storybook-style preview app (stage 05 App_Preview).
//
// Renders REAL Flutter widgets against the REAL project theme so look & feel
// can be approved before features are built. See ../SKILL.md and
// ../../../references/CONVENTIONS.md.
//
// Run it:   flutter run -t previews/widget_gallery.dart
// (Place this file at previews/widget_gallery.dart, or under lib/preview/.)
//
// Dependency-light on purpose: only flutter + your stage-04 theme.
//
// Heavier alternative — the `widgetbook` package gives device frames, knobs,
// and addons. Graduate to it only when the team wants that tooling:
//   dependencies: widgetbook: ^3.x   (then wrap stories as WidgetbookComponents)
//   See https://pub.dev/packages/widgetbook
//
// ---------------------------------------------------------------------------
// THEME WIRING (stage 04). This template expects stage 04 to export:
//   - ThemeData appTheme()        // light
//   - ThemeData appThemeDark()    // dark
//   - AppTokens (a ThemeExtension with spacing/radii/durations)
// Adjust the import path + the two theme calls below if your project names
// differ. Everything else stays the same.
//
//   import 'package:<your_app>/app/theme/theme.dart';
//
// Until stage 04's theme is importable, the _FallbackTheme below keeps this
// file compilable on its own. DELETE the fallback block and switch to the
// real import as soon as stage 04 lands.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

void main() => runApp(const GalleryApp());

/// A single named preview entry: a [label] and the widget [builder] that
/// renders it. Keep builders cheap and `const` where possible.
class Story {
  const Story(this.label, this.builder);
  final String label;
  final WidgetBuilder builder;
}

/// Register your stories here. Early on, use the samples below to prove the
/// theme; as real screens/components land, add a story per key screen from
/// docs/UX.md and per notable component (reuse the real widget classes).
final List<Story> kStories = <Story>[
  Story('Buttons', (c) => const _ButtonsStory()),
  Story('Card', (c) => const _CardStory()),
  Story('Sample screen', (c) => const _SampleScreenStory()),
  Story('Color & token swatches', (c) => const _SwatchStory()),
];

/// The gallery shell: a [MaterialApp] wired to the project's light & dark
/// themes with a dark-mode toggle and a master/detail story list.
class GalleryApp extends StatefulWidget {
  const GalleryApp({super.key});

  @override
  State<GalleryApp> createState() => _GalleryAppState();
}

class _GalleryAppState extends State<GalleryApp> {
  ThemeMode _mode = ThemeMode.light;
  int _selected = 0;

  void _toggleMode() => setState(
        () => _mode = _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light,
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Widget Gallery',
      debugShowCheckedModeBanner: false,
      // Swap these two for stage 04's appTheme() / appThemeDark().
      theme: _FallbackTheme.light(),
      darkTheme: _FallbackTheme.dark(),
      themeMode: _mode,
      home: Builder(
        builder: (context) {
          final story = kStories[_selected];
          return Scaffold(
            appBar: AppBar(
              title: Text('Gallery · ${story.label}'),
              actions: <Widget>[
                IconButton(
                  tooltip: 'Toggle light/dark',
                  onPressed: _toggleMode,
                  icon: Icon(
                    _mode == ThemeMode.light
                        ? Icons.dark_mode_outlined
                        : Icons.light_mode_outlined,
                  ),
                ),
              ],
            ),
            drawer: Drawer(
              child: SafeArea(
                child: ListView.builder(
                  itemCount: kStories.length,
                  itemBuilder: (context, i) => ListTile(
                    title: Text(kStories[i].label),
                    selected: i == _selected,
                    onTap: () {
                      setState(() => _selected = i);
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ),
            ),
            body: story.builder(context),
          );
        },
      ),
    );
  }
}

// ===========================================================================
// Example stories. Replace/extend with real components & screens over time.
// All of them read from Theme.of(context) + AppTokens — never hardcode.
// ===========================================================================

class _ButtonsStory extends StatelessWidget {
  const _ButtonsStory();

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Padding(
      padding: EdgeInsets.all(t.spaceLg),
      child: Wrap(
        spacing: t.spaceMd,
        runSpacing: t.spaceMd,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          FilledButton(onPressed: () {}, child: const Text('Filled')),
          FilledButton.tonal(onPressed: () {}, child: const Text('Tonal')),
          ElevatedButton(onPressed: () {}, child: const Text('Elevated')),
          OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
          TextButton(onPressed: () {}, child: const Text('Text')),
          const FilledButton(onPressed: null, child: Text('Disabled')),
          IconButton(onPressed: () {}, icon: const Icon(Icons.favorite_border)),
        ],
      ),
    );
  }
}

class _CardStory extends StatelessWidget {
  const _CardStory();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppTokens.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(t.spaceLg),
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(t.spaceLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Card title', style: theme.textTheme.titleLarge),
                SizedBox(height: t.spaceSm),
                Text(
                  'Supporting text rendered with the real type scale and '
                  'color scheme from the design system.',
                  style: theme.textTheme.bodyMedium,
                ),
                SizedBox(height: t.spaceMd),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () {},
                    child: const Text('Action'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A representative screen so stakeholders see the theme in a real layout.
/// Replace with an actual screen class from docs/UX.md as it gets built.
class _SampleScreenStory extends StatelessWidget {
  const _SampleScreenStory();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppTokens.of(context);
    return ListView(
      padding: EdgeInsets.all(t.spaceLg),
      children: <Widget>[
        Text('Welcome back', style: theme.textTheme.headlineSmall),
        SizedBox(height: t.spaceXs),
        Text(
          'Here is what is happening today.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: t.spaceLg),
        for (var i = 0; i < 4; i++) ...<Widget>[
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.bolt,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              title: Text('Item ${i + 1}'),
              subtitle: const Text('Secondary line of supporting text'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ),
          SizedBox(height: t.spaceSm),
        ],
        SizedBox(height: t.spaceMd),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add),
          label: const Text('Add new'),
        ),
      ],
    );
  }
}

/// Token + color sheet: a quick visual audit of the design system's
/// ColorScheme roles and the AppTokens spacing scale.
class _SwatchStory extends StatelessWidget {
  const _SwatchStory();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = AppTokens.of(context);
    final swatches = <_Swatch>[
      _Swatch('primary', scheme.primary, scheme.onPrimary),
      _Swatch('secondary', scheme.secondary, scheme.onSecondary),
      _Swatch('tertiary', scheme.tertiary, scheme.onTertiary),
      _Swatch('error', scheme.error, scheme.onError),
      _Swatch('surface', scheme.surface, scheme.onSurface),
      _Swatch('surfaceVariant', scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant),
    ];
    return ListView(
      padding: EdgeInsets.all(t.spaceLg),
      children: <Widget>[
        Text('Color roles', style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: t.spaceSm),
        Wrap(
          spacing: t.spaceSm,
          runSpacing: t.spaceSm,
          children: swatches,
        ),
        SizedBox(height: t.spaceLg),
        Text('Spacing scale', style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: t.spaceSm),
        for (final s in <(String, double)>[
          ('xs', t.spaceXs),
          ('sm', t.spaceSm),
          ('md', t.spaceMd),
          ('lg', t.spaceLg),
          ('xl', t.spaceXl),
        ])
          Padding(
            padding: EdgeInsets.symmetric(vertical: t.spaceXs / 2),
            child: Row(
              children: <Widget>[
                SizedBox(width: 40, child: Text(s.$1)),
                Container(
                  height: 16,
                  width: s.$2,
                  color: scheme.primary,
                ),
                SizedBox(width: t.spaceSm),
                Text('${s.$2.toStringAsFixed(0)} dp'),
              ],
            ),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.label, this.bg, this.fg);
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      width: 150,
      height: 64,
      padding: EdgeInsets.all(t.spaceSm),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(t.radiusMd),
      ),
      alignment: Alignment.bottomLeft,
      child: Text(label, style: TextStyle(color: fg)),
    );
  }
}

// ===========================================================================
// FALLBACK THEME + TOKENS — keeps this file compilable standalone.
//
// DELETE this entire block once stage 04's theme is importable, and replace:
//   - `import 'package:flutter/material.dart';` keep
//   - add: import 'package:<your_app>/app/theme/theme.dart';
//   - theme:      appTheme()
//   - darkTheme:  appThemeDark()
// Stage 04 owns the canonical AppTokens ThemeExtension; this mirror exists
// only so the gallery runs before stage 04 is wired in.
// ===========================================================================

/// Mirror of stage 04's design tokens. Replace with the real `AppTokens`
/// from `lib/app/theme/` — same field names so stories don't change.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    this.spaceXs = 4,
    this.spaceSm = 8,
    this.spaceMd = 16,
    this.spaceLg = 24,
    this.spaceXl = 40,
    this.radiusMd = 12,
  });

  final double spaceXs;
  final double spaceSm;
  final double spaceMd;
  final double spaceLg;
  final double spaceXl;
  final double radiusMd;

  /// Convenience accessor; throws if the extension isn't registered on the
  /// theme (a clear signal that the gallery isn't wired to the design system).
  static AppTokens of(BuildContext context) =>
      Theme.of(context).extension<AppTokens>() ?? const AppTokens();

  @override
  AppTokens copyWith({
    double? spaceXs,
    double? spaceSm,
    double? spaceMd,
    double? spaceLg,
    double? spaceXl,
    double? radiusMd,
  }) {
    return AppTokens(
      spaceXs: spaceXs ?? this.spaceXs,
      spaceSm: spaceSm ?? this.spaceSm,
      spaceMd: spaceMd ?? this.spaceMd,
      spaceLg: spaceLg ?? this.spaceLg,
      spaceXl: spaceXl ?? this.spaceXl,
      radiusMd: radiusMd ?? this.radiusMd,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      spaceXs: _lerp(spaceXs, other.spaceXs, t),
      spaceSm: _lerp(spaceSm, other.spaceSm, t),
      spaceMd: _lerp(spaceMd, other.spaceMd, t),
      spaceLg: _lerp(spaceLg, other.spaceLg, t),
      spaceXl: _lerp(spaceXl, other.spaceXl, t),
      radiusMd: _lerp(radiusMd, other.radiusMd, t),
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

/// Minimal stand-in for stage 04's `appTheme()` / `appThemeDark()`.
class _FallbackTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4F46E5), // replace with stage-04 seed
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: const <ThemeExtension<dynamic>>[AppTokens()],
    );
  }
}
