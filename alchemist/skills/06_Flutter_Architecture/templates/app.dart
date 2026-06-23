import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provided by stage 07 (Navigation): a Riverpod `routerProvider` exposing the
// configured `GoRouter`, living in `lib/app/router/router.dart`.
import 'router/router.dart';

// Provided by stage 04 (Premium Design System): `AppTheme.light` / `AppTheme.dark`
// (built from ColorScheme.fromSeed + AppTokens ThemeExtension) in
// `lib/app/theme/theme.dart`.
import 'theme/theme.dart';

/// Root application widget.
///
/// Uses [MaterialApp.router] so navigation is driven declaratively by
/// `go_router` (stage 07). Light and dark themes are both first-class; the OS
/// setting selects between them via [ThemeMode.system].
class App extends ConsumerWidget {
  /// Creates the root application widget.
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'App', // TODO: replace with the real app name from the PRD (stage 02).
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
    );
  }
}
