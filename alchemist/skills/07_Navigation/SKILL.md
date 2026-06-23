---
name: Navigation
description: Wire up app navigation with go_router driven by a Riverpod routerProvider — typed routes, a StatefulShellRoute bottom-nav with preserved tab state, auth redirects/guards, a 404 error route, and deep links / Android App Links. Use after the app is scaffolded (stage 06) and you have a screen inventory + nav map (docs/UX.md). Produces lib/app/router/* and hands a reachable, deep-link-ready route tree to the feature build stages.
when_to_use: Trigger on "set up routing", "add go_router", "bottom nav / tab bar with state", "auth redirect / route guard", "deep links" or "Android App Links", "404 page", or when the orchestrator enters stage 07. If the router already exists and the user only wants screen state, go to stage 08 (Riverpod) instead.
---

# Navigation (Stage 07)

You own the app's route tree. Turn the screen inventory and navigation map from `docs/UX.md` into a typed, declarative **go_router** configuration exposed through a **Riverpod `routerProvider`**, with a bottom-nav shell, auth guards, a 404 route, and working deep links / Android App Links. Stay aligned with the house style in [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md) (§ stack: routing = `go_router`).

**Output artifact:** `lib/app/router/*` — `router.dart` (the `routerProvider`) and `routes.dart` (typed route defs).
**Exit gate:** *every screen in the inventory is reachable, and deep links resolve to the right screen.*
**Consumes:** stage 06's `app.dart` (`MaterialApp.router` wires this router) and stage 08's auth state provider (the `redirect` reads it).

---

## The process

1. **Read `docs/UX.md`** — the screen inventory and nav map are your spec. Every screen becomes a route; the nav map becomes the tree shape (which screens are tabs, which are nested/detail).
2. **Define typed routes first** — names + path builders in [`templates/routes.dart`](templates/routes.dart). No stringly-typed `context.go('/items/$id')` anywhere in feature code.
3. **Build the `routerProvider`** ([`templates/router.dart`](templates/router.dart)): a `StatefulShellRoute.indexedStack` for bottom nav, nested detail routes with path params, the auth `redirect`, and the `errorBuilder`.
4. **Wire deep links** — enable platform deep linking, parse path/query params, configure **Android App Links** ([`templates/android_app_links.md`](templates/android_app_links.md)).
5. **Verify the gate** — walk the inventory: each screen reachable, each deep link resolves, guarded routes redirect when logged out.

---

## 1. Router as a Riverpod provider

The router is a **provider**, not a global. That lets the `redirect` read auth state and lets tests override it. Stage 06's `app.dart` watches it:

```dart
// lib/app/app.dart (stage 06) — for reference, do not rewrite here
class MyApp extends ConsumerWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      routerConfig: router,
      theme: ref.watch(lightThemeProvider),
      darkTheme: ref.watch(darkThemeProvider),
    );
  }
}
```

Build the `GoRouter` **once** and keep it stable — don't recreate it on every auth change. Instead, hold the `GoRouter` in a `Ref.keepAlive`/non-rebuilding provider and let it **re-evaluate `redirect`** via a `refreshListenable` (see §4). Recreating the router on rebuild loses navigation state. See [`templates/router.dart`](templates/router.dart).

---

## 2. Typed routes (no stringly-typed nav)

Centralize every name + path in one place so a renamed route is a compile error, not a runtime 404. Pattern in [`templates/routes.dart`](templates/routes.dart):

```dart
abstract final class AppRoute {
  static const home = (name: 'home', path: '/');
  static const items = (name: 'items', path: '/items');
  // detail is nested under items; `path` is the *segment*, `location` builds the full URL
  static const itemDetail = (name: 'itemDetail', path: ':id');
  static String itemDetailLocation(String id) => '/items/$id';
}
```

Navigate by **name** with params (decoupled from the URL shape) or by the typed location builder:

```dart
context.goNamed(AppRoute.itemDetail.name, pathParameters: {'id': id});
// or
context.go(AppRoute.itemDetailLocation(id));
```

Rules:
- **Never** hand-concatenate a path in a widget. Use a builder from `routes.dart`.
- Names are stable identifiers; paths can change without touching call sites (when you navigate by name).
- For generated, fully type-safe routes you may adopt `go_router_builder` (`@TypedGoRoute`); the records approach above is the zero-codegen baseline this skill ships.

---

## 3. Bottom-nav shell with preserved state

For a tab bar where each tab keeps its own navigation stack and scroll position, use **`StatefulShellRoute.indexedStack`**. Each branch is an independent `Navigator`; switching tabs preserves the inactive branches' state.

```dart
StatefulShellRoute.indexedStack(
  builder: (context, state, navigationShell) =>
      ScaffoldWithNavBar(navigationShell: navigationShell), // hosts the NavigationBar
  branches: [
    StatefulShellBranch(routes: [GoRoute(path: '/', ...)]),       // Home tab
    StatefulShellBranch(routes: [GoRoute(path: '/items', ...)]),  // Items tab (+ nested detail)
    StatefulShellBranch(routes: [GoRoute(path: '/profile', ...)]),// Profile tab
  ],
)
```

The shell widget switches branches with `navigationShell.goBranch(index)`; the selected index is `navigationShell.currentIndex`. Detail routes (e.g. item detail) nest **inside** the relevant branch so the bottom bar stays visible and back returns within the tab. Full widget in [`templates/router.dart`](templates/router.dart).

Use `parentNavigatorKey: rootNavigatorKey` on a `GoRoute` to push it **above** the shell (full-screen, no bottom bar) — e.g. a modal create screen.

---

## 4. Auth redirect / guards

The top-level `redirect` is the guard. It reads the auth provider (stage 08) and rewrites the destination when the user is unauthenticated.

```dart
redirect: (context, state) {
  final isLoggedIn = ref.read(authStateProvider).valueOrNull?.isAuthenticated ?? false;
  final goingToLogin = state.matchedLocation == AppRoute.login.path;
  if (!isLoggedIn && !goingToLogin) {
    // preserve intended destination so we can bounce back after login
    return '${AppRoute.login.path}?from=${state.uri.path}';
  }
  if (isLoggedIn && goingToLogin) return AppRoute.home.path;
  return null; // no redirect
}
```

**Re-evaluate on auth change.** A `redirect` only runs on navigation events. To force it to run when auth state flips (login/logout), give the router a `refreshListenable` that fires on auth changes — bridge the Riverpod auth provider to a `Listenable`:

```dart
// In the provider: turn the auth stream into a Listenable for go_router.
final listenable = ValueNotifier<int>(0);
ref.listen(authStateProvider, (_, __) => listenable.value++);
ref.onDispose(listenable.dispose);
// ... GoRouter(refreshListenable: listenable, ...)
```

Now logging out anywhere instantly redirects guarded screens to login; logging in bounces back to the saved `from` destination. Keep guard logic **only** in `redirect` (and per-route `redirect` for fine-grained cases) — never scatter `if (!loggedIn) context.go(...)` in `build`.

---

## 5. Error / 404 route

Always supply an `errorBuilder` (or an `errorPageBuilder` for custom transitions) so an unknown URL — common from deep links and typos — lands on a friendly screen, not a red error box.

```dart
GoRouter(
  errorBuilder: (context, state) => RouteErrorScreen(error: state.error),
  // ...
)
```

`RouteErrorScreen` should show the bad path, a short message, and a "Go home" action (`context.go(AppRoute.home.path)`). Render it across light + dark per [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md) §4.

---

## 6. Deep linking & Android App Links

**Enable deep linking.** go_router parses incoming URIs automatically; on Android you must declare an intent-filter. Set `<meta-data android:name="flutter_deeplinking_enabled" android:value="true"/>` is **not** required when using go_router (it handles routing) — but you do need the platform intent-filter so Android hands the URL to your app.

**Path & query params** come off `GoRouterState`:

```dart
GoRoute(
  path: ':id',                 // /items/42
  name: AppRoute.itemDetail.name,
  builder: (context, state) {
    final id = state.pathParameters['id']!;        // '42'
    final tab = state.uri.queryParameters['tab'];  // /items/42?tab=specs
    return ItemDetailScreen(id: id, initialTab: tab);
  },
)
```

**Android App Links** (verified `https://` links that open the app with no chooser) need three things — full walkthrough in [`templates/android_app_links.md`](templates/android_app_links.md):

1. An `<intent-filter>` with `android:autoVerify="true"` for your `https` host in `AndroidManifest.xml`.
2. A `.well-known/assetlinks.json` file hosted at the domain root, containing your app's **SHA-256 signing-cert fingerprint**.
3. A signing cert whose fingerprint matches (debug *and* the upload/Play-signing cert if you want verified links in release).

Custom-scheme deep links (`myapp://items/42`) don't need verification but also don't show as web URLs — prefer App Links for shareable, trusted links.

---

## 7. Testing routes

The gate is "all screens reachable; deep links resolve." Make that mechanical:

- **Initial location & deep-link resolution:** build the router with `initialLocation: '/items/42'` inside a `ProviderScope` (override auth to logged-in) and pump; assert `ItemDetailScreen` with the right `id` renders.
- **Guard:** override the auth provider to logged-out, navigate to a guarded route, assert you land on login with `from` set; flip auth to logged-in, assert the `refreshListenable` bounces you back.
- **Unknown route:** pump `initialLocation: '/nope'`; assert `RouteErrorScreen` renders.
- **Tab state preserved:** in the shell, push a detail in tab B, switch to tab A and back, assert the detail is still on top of tab B's stack.

Override the router in widget tests via the provider:

```dart
ProviderScope(
  overrides: [routerProvider.overrideWith((ref) => buildTestRouter(initialLocation: '/items/42'))],
  child: const MyApp(),
);
```

---

## Exit gate (must pass before the build stages)

- [ ] Every screen in `docs/UX.md`'s inventory has a route and is reachable from the nav map.
- [ ] Bottom-nav tabs use `StatefulShellRoute.indexedStack`; inactive tab state is preserved.
- [ ] All navigation goes through typed routes in `routes.dart` — no stringly-typed paths in features.
- [ ] `redirect` guards protected routes and re-evaluates on auth change (`refreshListenable`).
- [ ] An `errorBuilder` 404 screen renders for unknown routes.
- [ ] At least one deep link (path + query param) resolves to the right screen.
- [ ] Android App Links configured: intent-filter `autoVerify="true"` + `assetlinks.json` documented.
- [ ] Route tests cover reachability, a deep link, the guard, and the 404.

When green, record `lib/app/router/*` in `.flutter-pipeline/STATE.md` and hand off to **stage 08 (Riverpod)** for per-feature state.
