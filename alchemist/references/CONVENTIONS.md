# Alchemist House Style (CONVENTIONS)

The single source of truth for the Alchemist skill pipeline. Every skill links here.
When a skill's guidance and this file disagree, **this file wins** — fix the skill.

> Targets: Flutter (stable channel) · Dart 3.x · Android-first (Material 3), code stays cross-platform-clean · `minSdk 23` (Android 6) unless a project says otherwise.
>
> **Visual styles:** The [UI Style Taxonomy](UI_STYLE_TAXONOMY.md) catalogs 140+ design aesthetics (Cyberpunk, Glassmorphism, Bento, Swiss Design, Fintech, etc.) — skill 04 maps the chosen style into Material 3 tokens. All styles ultimately compile to `ThemeData` + `AppTokens`.

---

## 1. The standard stack

| Concern | Default | Why |
|---|---|---|
| Language | **Dart 3** — sealed classes, records, pattern matching, exhaustive `switch` | type-safe state & errors |
| Lints | **`very_good_analysis`** | strict, opinionated, catches real bugs |
| State management | **Riverpod 2.x** + `riverpod_generator`, `riverpod_lint`, `custom_lint` | testable, no `BuildContext` coupling, least boilerplate |
| Immutable models | **`freezed`** + `json_serializable` | unions, copyWith, value equality |
| Errors | typed **`Failure`** sealed hierarchy + **`Result<T>`** (`Success`/`FailureResult`) | no raw exceptions crossing layers |
| Routing | **`go_router`** | declarative, deep-link & Android App Links ready |
| Networking | **`dio`** (+ `retrofit` optional) | interceptors, cancellation, error mapping |
| DI | **Riverpod providers** (no `get_it` needed) | one mechanism, override in tests |
| Local storage | `shared_preferences` (prefs) · `drift` or `isar` (db) · `flutter_secure_storage` (secrets) | fit-for-purpose |
| Theming | **Material 3**, `ColorScheme.fromSeed`, custom `ThemeExtension` tokens | premium, consistent, themeable |
| Assets/codegen | `flutter_gen` for assets/fonts/colors | no stringly-typed paths |
| Testing | `flutter_test` · `mocktail` · golden (`alchemist` or built-in) · `integration_test` | unit→widget→golden→e2e |
| Crash/analytics | **Sentry** or **Firebase Crashlytics** + analytics + `logger` | observability from day one |
| Codegen runner | `build_runner` | freezed/json/riverpod generation |

Avoid: `setState` for anything beyond trivial local widget state, `GetX`, global singletons, business logic in widgets, `print` (use `logger`), `dynamic`, swallowing exceptions.

---

## 2. Project layout (feature-first + light Clean)

```
lib/
├── main.dart                  # bootstrap: runZonedGuarded + ProviderScope + error hooks
├── app/
│   ├── app.dart               # MaterialApp.router + theme + router wiring
│   ├── router/                # go_router config (07)
│   └── theme/                 # theme.dart, tokens, color schemes (04)
├── core/                      # cross-feature: errors, network, result, extensions, utils
│   ├── error/                 # Failure, Result, error mappers (15)
│   ├── network/               # dio client, interceptors, resilience (11,14)
│   └── widgets/               # shared UI primitives (loading, empty, error) (16)
└── features/
    └── <feature>/
        ├── data/              # DTOs, data sources, repository impls
        ├── domain/            # entities, value objects, repository interfaces
        ├── application/       # Riverpod notifiers/controllers, use-case logic
        └── presentation/      # screens, widgets for this feature
```

Rules:
- **Dependencies point inward**: `presentation → application → domain ← data`. `domain` imports nothing from other layers.
- One feature never imports another feature's internals — share via `core/` or a domain interface.
- `data` maps DTO ↔ domain entity; **domain never sees JSON**.

---

## 3. Naming

- Files: `snake_case.dart`. Types: `PascalCase`. members/vars: `camelCase`. constants: `camelCase` (not SCREAMING).
- Riverpod providers (codegen): annotate functions/classes; generated name is `<thing>Provider`.
- One public class per file where practical; file name matches the class.
- Test files mirror source path under `test/` and end in `_test.dart`.

---

## 4. Widget hygiene (the "awesome UI" baseline)

- Prefer **`const`** constructors everywhere possible; add `keys` to list items.
- **Extract widgets into classes**, not `_buildX()` methods (classes rebuild less, read better).
- Never hardcode colors/sizes — pull from `Theme.of(context).colorScheme` and `AppTokens` (ThemeExtension): spacing, radii, durations.
- Every async surface renders all four states: **loading · data · empty · error** (see skill 16).
- Respect spacing scale (4/8-based), 48dp min touch targets, and `Semantics` for a11y.
- Light + dark themes are both first-class. Test in both.

---

## 5. Result & error contract (used everywhere)

```dart
sealed class Result<T> { const Result(); }
final class Ok<T> extends Result<T> { final T value; const Ok(this.value); }
final class Err<T> extends Result<T> { final Failure failure; const Err(this.failure); }

sealed class Failure { final String message; const Failure(this.message); }
// e.g. NetworkFailure, TimeoutFailure, UnauthorizedFailure, NotFoundFailure,
//      ValidationFailure, CacheFailure, UnknownFailure
```

- Repositories return `Future<Result<T>>` (or `Result<T>`), never throw across the boundary.
- Map low-level exceptions (DioException, etc.) to `Failure` in the `data` layer (skill 15).
- UI pattern-matches: `switch (result) { Ok() => ..., Err() => ... }`.

Skill 15 owns the canonical `Failure`/`Result` template; all other skills import it.

---

## 6. State management contract (Riverpod)

- Screen state lives in an `AsyncNotifier`/`Notifier` in `application/`.
- Widgets `ref.watch` state and call controller methods; **no business logic in `build`**.
- Use `ref.watch(p.select(...))` to minimize rebuilds.
- Tests override providers with fakes via `ProviderContainer(overrides: [...])` — never hit real network.
- Side effects (navigation, snackbars) via `ref.listen`, not inside `build`.

---

## 7. Definition of Done (per feature)

A feature is "done" only when: compiles with **zero analyzer warnings** under `very_good_analysis`; all four async states implemented; light+dark verified; unit + widget tests pass; strings/colors/sizes tokenized; no `TODO` left without an issue link; doc comment on every public API.

---

## 8. Pipeline artifacts

The 24-stage pipeline produces hand-off artifacts tracked by the orchestrator in `.flutter-pipeline/STATE.md`. See `PIPELINE.md` for the stage→artifact→gate map.
