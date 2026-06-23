// lib/app/router/router.dart
//
// The app's GoRouter, exposed as a Riverpod provider so:
//   * the auth `redirect` can read the auth provider (stage 08), and
//   * tests can override the whole router.
//
// The router is built ONCE and kept stable; auth changes re-run `redirect`
// via `refreshListenable` rather than rebuilding the router (which would lose
// navigation state).
//
// House style: ../../references/CONVENTIONS.md (routing = go_router, Riverpod DI).
//
// PLACEHOLDER SCREENS: HomeScreen / ItemsScreen / ItemDetailScreen /
// ProfileScreen / LoginScreen / CreateItemScreen / RouteErrorScreen and
// `authStateProvider` are stubbed at the bottom so this file compiles in
// isolation. In a real app, delete the stubs and import the real widgets +
// the auth provider from stage 08.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'routes.dart';

// Navigator keys: one root (above the shell) + one per shell branch.
final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellHomeKey = GlobalKey<NavigatorState>(debugLabel: 'shellHome');
final _shellItemsKey = GlobalKey<NavigatorState>(debugLabel: 'shellItems');
final _shellProfileKey = GlobalKey<NavigatorState>(debugLabel: 'shellProfile');

/// The application router. `app.dart` (stage 06) does:
/// `MaterialApp.router(routerConfig: ref.watch(routerProvider))`.
final routerProvider = Provider<GoRouter>((ref) {
  // Bridge the Riverpod auth provider to a Listenable so go_router re-runs
  // `redirect` whenever auth state flips (login / logout).
  final authListenable = ValueNotifier<int>(0);
  final sub = ref.listen<AsyncValue<AuthState>>(
    authStateProvider,
    (_, __) => authListenable.value++,
    fireImmediately: false,
  );
  ref.onDispose(() {
    sub.close();
    authListenable.dispose();
  });

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoute.home.path,
    debugLogDiagnostics: true,
    refreshListenable: authListenable,
    redirect: (context, state) {
      final isLoggedIn =
          ref.read(authStateProvider).valueOrNull?.isAuthenticated ?? false;
      final goingToLogin = state.matchedLocation == AppRoute.login.path;

      if (!isLoggedIn && !goingToLogin) {
        // Preserve where the user was headed so we can bounce back post-login.
        return AppRoute.loginLocation(from: state.uri.path);
      }
      if (isLoggedIn && goingToLogin) {
        final from = state.uri.queryParameters['from'];
        return (from != null && from.isNotEmpty) ? from : AppRoute.home.path;
      }
      return null; // no redirect
    },
    errorBuilder: (context, state) => RouteErrorScreen(error: state.error),
    routes: [
      // --- Full-screen routes (above the bottom-nav shell) ---
      GoRoute(
        path: AppRoute.login.path,
        name: AppRoute.login.name,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoute.createItem.path,
        name: AppRoute.createItem.name,
        parentNavigatorKey: _rootNavigatorKey, // pushed over the shell
        builder: (context, state) => const CreateItemScreen(),
      ),

      // --- Bottom-nav shell: each branch keeps its own stack & scroll. ---
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ScaffoldWithNavBar(navigationShell: navigationShell),
        branches: [
          // Tab 0 — Home
          StatefulShellBranch(
            navigatorKey: _shellHomeKey,
            routes: [
              GoRoute(
                path: AppRoute.home.path,
                name: AppRoute.home.name,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          // Tab 1 — Items (with a nested detail route that keeps the bottom bar)
          StatefulShellBranch(
            navigatorKey: _shellItemsKey,
            routes: [
              GoRoute(
                path: AppRoute.items.path,
                name: AppRoute.items.name,
                builder: (context, state) => const ItemsScreen(),
                routes: [
                  GoRoute(
                    path: AppRoute.itemDetail.path, // ':id' (relative segment)
                    name: AppRoute.itemDetail.name,
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      final tab = state.uri.queryParameters['tab'];
                      return ItemDetailScreen(id: id, initialTab: tab);
                    },
                  ),
                ],
              ),
            ],
          ),
          // Tab 2 — Profile
          StatefulShellBranch(
            navigatorKey: _shellProfileKey,
            routes: [
              GoRoute(
                path: AppRoute.profile.path,
                name: AppRoute.profile.name,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

/// Hosts the [NavigationBar] and switches shell branches while preserving the
/// inactive branches' navigation state.
class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      // Tapping the active tab again pops it back to its initial route.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _goBranch,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.list_outlined), label: 'Items'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

// =============================================================================
// PLACEHOLDERS — delete in a real app; import the real widgets + auth provider.
// =============================================================================

/// Stub auth state. Replace with stage 08's real auth provider/notifier.
class AuthState {
  const AuthState({required this.isAuthenticated});
  final bool isAuthenticated;
}

/// Stub provider. Stage 08 provides the real `authStateProvider`
/// (e.g. an `AsyncNotifierProvider<AuthNotifier, AuthState>`).
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Stream.value(const AuthState(isAuthenticated: true));
});

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Home'));
}

class ItemsScreen extends StatelessWidget {
  const ItemsScreen({super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: TextButton(
          onPressed: () =>
              context.go(AppRoute.itemDetailLocation('42')),
          child: const Text('Open item 42'),
        ),
      );
}

class ItemDetailScreen extends StatelessWidget {
  const ItemDetailScreen({required this.id, this.initialTab, super.key});
  final String id;
  final String? initialTab;
  @override
  Widget build(BuildContext context) =>
      Center(child: Text('Item $id (tab: ${initialTab ?? "—"})'));
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Profile'));
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Login'));
}

class CreateItemScreen extends StatelessWidget {
  const CreateItemScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Create item'));
}

/// 404 / unknown-route screen. Render across light + dark (CONVENTIONS §4).
class RouteErrorScreen extends StatelessWidget {
  const RouteErrorScreen({required this.error, super.key});
  final Exception? error;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error?.toString() ?? 'Unknown route'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go(AppRoute.home.path),
              child: const Text('Go home'),
            ),
          ],
        ),
      ),
    );
  }
}
