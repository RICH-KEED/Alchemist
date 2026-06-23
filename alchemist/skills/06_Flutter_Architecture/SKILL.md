---
name: Flutter Architecture
description: Scaffold a new Flutter app and lay down its architecture. Use when starting the codebase (pipeline stage 06), running `flutter create`, setting up `lib/` layout, wiring Riverpod DI + the repository pattern, or adding a new feature module. Output is a scaffolded `lib/` that passes `flutter analyze` and boots.
when_to_use: Trigger on "scaffold the app", "set up the project structure", "create the Flutter project", "add a feature module", or whenever a build stage (09–17) needs the `lib/` skeleton, DI, and error contract in place first. For routing details use skill 07, for provider design use skill 08, for the error types use skill 15.
---

# Flutter Architecture (Stage 06 — Foundation)

Turn the plan + design (Phase A) into a **scaffolded, analyzer-clean, bootable app**. You own the project structure, the dependency rule, Riverpod-based DI, the repository pattern, and the "add a feature" procedure. You do **not** own the router internals (skill 07), provider design (skill 08), or the `Result`/`Failure` types (skill 15) — you reference them.

Single source of truth for layout and stack: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md). When this skill and CONVENTIONS disagree, **CONVENTIONS wins.**

**Exit gate:** `flutter analyze` is clean under `very_good_analysis`, and the app boots to a screen.

---

## The architecture in one paragraph

Feature-first folders, with a light Clean split *inside* each feature into four layers. **Dependencies point inward**: `presentation → application → domain ← data`. `domain` is pure Dart — it imports nothing from Flutter or other layers and defines the contracts (entities + repository interfaces). `data` implements those contracts, maps DTO ↔ entity, and turns exceptions into `Failure`. `application` holds Riverpod controllers (the only place state lives). `presentation` renders state and calls controller methods — never business logic in `build`.

```
presentation  ──watches/calls──▶  application  ──uses──▶  domain  ◀──implements──  data
   (widgets)                      (controllers)        (entities,            (DTOs, dio,
                                                        repo interfaces)      repo impls)
```

The wiring glue is **Riverpod providers** (our DI container — no `get_it`). A provider graph runs outward-in at runtime but the *source dependencies* still point inward: a controller depends on a `domain` repository *interface*; the concrete `data` implementation is bound to that interface in a provider.

---

## The `lib/` tree (from CONVENTIONS — reuse exactly)

```
lib/
├── main.dart                  # bootstrap: runZonedGuarded + ProviderScope + error hooks
├── app/
│   ├── app.dart               # MaterialApp.router + theme + router wiring
│   ├── router/                # go_router config            (skill 07)
│   └── theme/                 # theme.dart, tokens, schemes (skill 04)
├── core/                      # cross-feature shared code
│   ├── error/                 # Failure, Result, mappers    (skill 15)
│   ├── network/               # dio client, interceptors    (skill 11, 14)
│   └── widgets/               # loading/empty/error states  (skill 16)
└── features/
    └── <feature>/
        ├── data/              # DTOs, data sources, repository impls
        ├── domain/            # entities, value objects, repository interfaces
        ├── application/       # Riverpod notifiers/controllers
        └── presentation/      # screens + widgets for this feature
```

Hard rules (enforced by `riverpod_lint` + review):
- `domain` imports **nothing** from `data`/`application`/`presentation` and nothing from `package:flutter`.
- One feature never imports another feature's internals — share via `core/` or a domain interface.
- `data` is the only layer that touches JSON, dio, or DTOs. **The domain never sees JSON.**

---

## How Riverpod provides DI

The chain for any feature is **data source → repository → controller**, each a provider that depends on the one before it. Bind the **interface** to the **implementation** in the repository provider so the rest of the app only ever sees the `domain` type.

```dart
// data/example_remote_data_source.dart
@riverpod
ExampleRemoteDataSource exampleRemoteDataSource(Ref ref) =>
    ExampleRemoteDataSource(ref.watch(dioProvider)); // dioProvider from core/network (skill 11)

// data/example_repository_impl.dart — returns the DOMAIN interface, not the impl
@riverpod
ExampleRepository exampleRepository(Ref ref) =>
    ExampleRepositoryImpl(ref.watch(exampleRemoteDataSourceProvider));

// application/example_controller.dart — depends on the interface only
@riverpod
class ExampleController extends _$ExampleController {
  @override
  Future<List<ExampleEntity>> build() => _load();
  // ...calls ref.read(exampleRepositoryProvider)
}
```

Why this works: tests override `exampleRepositoryProvider` with a fake via `ProviderScope(overrides: [...])` and never touch the network. See skill 08 for provider design depth and skill 11 for `dioProvider`.

---

## The repository pattern (returns `Result<T>`)

A repository is a `domain` **interface**; its `data` implementation never lets an exception cross the boundary.

```dart
// domain — the contract (pure Dart)
abstract interface class ExampleRepository {
  Future<Result<List<ExampleEntity>>> getExamples();
}

// data — the implementation maps exceptions → Failure, DTO → entity
final class ExampleRepositoryImpl implements ExampleRepository {
  const ExampleRepositoryImpl(this._remote);
  final ExampleRemoteDataSource _remote;

  @override
  Future<Result<List<ExampleEntity>>> getExamples() async {
    try {
      final dtos = await _remote.fetchExamples();
      return Ok(dtos.map((d) => d.toEntity()).toList());
    } on DioException catch (e) {
      return Err(e.toFailure()); // mapper lives in core/error (skill 15)
    }
  }
}
```

`Result<T>` = `Ok<T>` | `Err<T>`; `Failure` is a sealed hierarchy. **Skill 15 owns these types** in `core/error/`. This skill imports them — see the `// TODO(skill-15)` markers in `templates/feature_module/`. Controllers and widgets pattern-match: `switch (result) { Ok() => ..., Err() => ... }`.

---

## Procedure: scaffold a new app

Run from the workspace root. Replace `<org>` / `<app_name>`.

1. **Create the project** (Android-first, but keep iOS clean):
   ```bash
   flutter create \
     --org com.<org> \
     --project-name <app_name> \
     --platforms android,ios \
     --description "<one-line description>" \
     .
   ```
   (Drop `,ios` if Android-only. `minSdk 23` — set in `android/app/build.gradle.kts` per CONVENTIONS.)

2. **Add dependencies.** Merge [`templates/pubspec_deps.yaml`](templates/pubspec_deps.yaml) into `pubspec.yaml`, then:
   ```bash
   flutter pub get
   flutter pub upgrade --major-versions   # take current stable, then re-pin
   ```

3. **Drop in the foundation templates** (rename/relocate as noted):
   - [`templates/analysis_options.yaml`](templates/analysis_options.yaml) → `analysis_options.yaml` (repo root).
   - [`templates/main.dart`](templates/main.dart) → `lib/main.dart`.
   - [`templates/app.dart`](templates/app.dart) → `lib/app/app.dart`.
   - [`templates/feature_module/`](templates/feature_module/) → `lib/features/example/` (your first reference feature; delete once you have real ones).

4. **Create the empty shared dirs** so imports resolve:
   ```bash
   mkdir -p lib/app/router lib/app/theme lib/core/error lib/core/network lib/core/widgets
   ```
   Stage 07 fills `app/router/`, stage 04 fills `app/theme/`, stage 15 fills `core/error/`.

5. **Run codegen** (freezed / json / riverpod):
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   # during active dev: dart run build_runner watch --delete-conflicting-outputs
   ```

6. **Verify the gate:**
   ```bash
   flutter analyze       # must be clean (zero issues) under very_good_analysis
   flutter run           # app boots to a screen
   ```

---

## Checklist: add a new feature `<feature>`

1. `mkdir -p lib/features/<feature>/{domain,data,application,presentation}`.
2. **domain/** — `<feature>_entity.dart` (freezed entity) + `<feature>_repository.dart` (`abstract interface class` returning `Future<Result<...>>`). No Flutter, no JSON.
3. **data/** — `<feature>_dto.dart` (freezed + `json_serializable`, with `toEntity()`), `<feature>_remote_data_source.dart` (dio calls), `<feature>_repository_impl.dart` (maps DTO→entity, exceptions→`Failure`, exposes a `@riverpod` provider bound to the domain interface).
4. **application/** — `<feature>_controller.dart`: a `@riverpod` `AsyncNotifier` whose `build()` loads data via the repository provider; mutation methods set `state = const AsyncLoading()` then guard with `AsyncValue.guard`.
5. **presentation/** — `<feature>_screen.dart`: `ref.watch` the controller, render **all four states** (loading · data · empty · error) using `core/widgets` primitives (skill 16). Side effects via `ref.listen`, not `build`.
6. Register the route in `app/router/` (skill 07).
7. `dart run build_runner build --delete-conflicting-outputs`, then `flutter analyze` must stay clean.

Copy [`templates/feature_module/`](templates/feature_module/) as the canonical shape — it implements every step above.

---

## Definition of Done for stage 06

- `lib/` matches the CONVENTIONS tree; the four feature layers exist and respect the dependency rule.
- `analysis_options.yaml` includes `very_good_analysis` + `custom_lint`/`riverpod_lint`; generated files excluded.
- `main.dart` bootstraps under `runZonedGuarded` inside a `ProviderScope` with `FlutterError.onError` wired.
- `app.dart` renders `MaterialApp.router` off the router provider (skill 07) and light+dark themes (skill 04).
- `dart run build_runner build` succeeds; **`flutter analyze` is clean; the app boots.** ✅

See the stage→artifact→gate map in [`../../references/PIPELINE.md`](../../references/PIPELINE.md).
