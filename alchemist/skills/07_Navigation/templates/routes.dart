// lib/app/router/routes.dart
//
// Typed route definitions — the single source of truth for route names and
// paths. Navigate by `name` (decoupled from the URL) or with a typed location
// builder. NEVER hand-concatenate a path string in a widget; use these.
//
// House style: see ../../references/CONVENTIONS.md (routing = go_router).

/// A route's stable [name] (used by `goNamed`) and its [path].
///
/// For nested routes, [path] is the *segment* go_router expects (relative,
/// no leading slash), while the `...Location` builders below return the full
/// absolute URL for `context.go(...)`.
typedef RouteDef = ({String name, String path});

/// All routes in the app. Renaming a route here is a compile error at every
/// call site — that is the point.
abstract final class AppRoute {
  const AppRoute._();

  // --- Auth (full-screen, above the shell) ---
  static const RouteDef login = (name: 'login', path: '/login');

  // --- Shell tabs (bottom navigation branches) ---
  static const RouteDef home = (name: 'home', path: '/');
  static const RouteDef items = (name: 'items', path: '/items');
  static const RouteDef profile = (name: 'profile', path: '/profile');

  // --- Nested detail (lives under the `items` branch) ---
  // Declared with a relative segment because it is a child of `items`.
  static const RouteDef itemDetail = (name: 'itemDetail', path: ':id');

  // --- Full-screen modal (above the shell) ---
  static const RouteDef createItem = (name: 'createItem', path: '/items/new');

  // ---------------------------------------------------------------------------
  // Location builders — typed, no stringly-typed concatenation in features.
  // ---------------------------------------------------------------------------

  /// `/items/42` — full URL for an item detail screen.
  static String itemDetailLocation(String id) => '/items/$id';

  /// `/items/42?tab=specs` — detail with an optional initial tab via query.
  static String itemDetailLocationWithTab(String id, String tab) =>
      '/items/$id?tab=$tab';

  /// `/login?from=/items/42` — login with the destination to return to.
  static String loginLocation({String? from}) =>
      from == null ? login.path : '${login.path}?from=$from';
}
