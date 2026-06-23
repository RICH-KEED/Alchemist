---
name: Backend Integration
description: Connect a Flutter app to a backend. Use when wiring the data layer (pipeline stage 11) — configuring the dio client, adding interceptors (auth, logging), writing remote data sources + repositories that return Result, mapping DTO↔domain, or deciding REST vs GraphQL vs Firebase/Supabase. Output is endpoints returning mapped domain entities via Result.
when_to_use: Trigger on "connect to the API", "set up dio", "add an auth interceptor", "call the backend", "wire up the repository", "use Firebase/Supabase", or whenever a feature needs real data instead of fakes. For retries/offline use skill 14, for token storage use skill 13, for the Result/Failure types and mappers use skill 15.
---

# Backend Integration (Stage 11 — Build the experience)

Wire the app's **data layer** to a real backend. You own the configured `dio` client (`dioProvider` in `core/network/`), its interceptors, the remote data sources, and the repository implementations that map transport DTOs into domain entities and return `Result<T>`. You do **not** own the `Result`/`Failure` types or the exception→`Failure` mapper (skill 15), token storage (skill 13), or retry/offline policy (skill 14) — you reference them.

Single source of truth for layout and stack: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md). When this skill and CONVENTIONS disagree, **CONVENTIONS wins.**

**Exit gate:** endpoints return mapped domain entities via `Result`.

---

## The data-layer flow (one pass)

```
remote data source ──▶ DTO ──▶ repository impl ──▶ domain entity ──▶ Result<T>
   (dio call,            (freezed +     (try/catch:        (toEntity())     (Ok / Err)
    throws on error)      json)          map exception →
                                         Failure via skill 15)
```

1. **Remote data source** makes the `dio` call and returns **DTOs**. It does *not* catch — `DioException`s propagate up.
2. **DTO** (`freezed` + `json_serializable`) is the only type that knows JSON. It carries a `toEntity()`.
3. **Repository impl** calls the data source inside `try/catch`, maps any exception to a `Failure` via skill 15's mapper, maps the DTO to a domain **entity**, and returns `Result<T>`.
4. Everything downstream (`application`, `presentation`) sees only the domain entity and the `Result` — never JSON, `dio`, or DTOs.

This is exactly the dependency rule from skill 06: `data` is the only layer that touches `dio`/JSON, and exceptions stop at the repository boundary.

---

## Configuring dio and exposing `dioProvider`

The shared client lives in `core/network/dio_client.dart` and is exposed as a `@riverpod` `dioProvider`. Configure it once; every data source watches it.

- **baseUrl** comes from compile-time config (`--dart-define`/flavors — skill 10), never hardcoded per call. Default to a `const String.fromEnvironment('API_BASE_URL', defaultValue: ...)`.
- **Timeouts**: set `connectTimeout` and `receiveTimeout` so a hung socket surfaces as a `TimeoutFailure` rather than spinning forever. (Retry *policy* is skill 14 — here we just bound a single attempt.)
- **Headers**: `Accept: application/json`, `Content-Type: application/json` as `BaseOptions` defaults.
- **Interceptors**: attach in order — auth first (so the token is on the request), then logging (so it logs the final request). Add the resilience interceptor from skill 14 *after* these when it lands.

See [`templates/dio_client.dart`](templates/dio_client.dart) for the canonical provider.

```dart
@riverpod
Dio dio(Ref ref) {
  final dio = Dio(BaseOptions(
    baseUrl: const String.fromEnvironment('API_BASE_URL', defaultValue: 'https://api.example.com'),
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: const {'Accept': 'application/json'},
  ));
  dio.interceptors.addAll([
    AuthInterceptor(ref),       // adds Authorization: Bearer <token>
    LogInterceptor(requestBody: true, responseBody: true), // dev only
  ]);
  return dio;
}
```

---

## The auth interceptor

An `Interceptor` (see [`templates/auth_interceptor.dart`](templates/auth_interceptor.dart)) attaches `Authorization: Bearer <token>` to every outgoing request and provides a hook for 401 handling.

- The **token comes from secure storage (skill 13)** — never from a plaintext pref or a hardcoded constant. The interceptor depends on a *token source* (a small interface) so it doesn't reach into storage details directly and stays testable.
- On **`401 Unauthorized`** the interceptor exposes a refresh hook. The actual refresh-token flow (call refresh endpoint, persist new tokens, retry the original request) is **skill 13's** responsibility — here we only leave the seam and, by default, pass the error through so the repository maps it to an `UnauthorizedFailure`.
- Keep the interceptor *cheap*: read the token, set the header, continue. No business logic.

---

## Error mapping happens at the boundary (skill 15)

Repositories never throw across the layer line. Catch in the repository impl and map with skill 15's mapper:

```dart
// import 'package:<app>/core/error/result.dart';       // Result, Ok, Err
// import 'package:<app>/core/error/error_mapper.dart';  // mapErrorToFailure / DioException.toFailure()

try {
  final dtos = await _remote.fetchTodos();
  return Ok(dtos.map((d) => d.toEntity()).toList());
} on DioException catch (e, st) {
  return Err(mapErrorToFailure(e, st)); // skill 15 owns the mapping table
} on Object catch (e, st) {
  return Err(mapErrorToFailure(e, st));
}
```

Skill 15 owns the `DioException` → `Failure` table (timeouts → `TimeoutFailure`, `401` → `UnauthorizedFailure`, `404` → `NotFoundFailure`, no connection → `NetworkFailure`, else → `UnknownFailure`). Do **not** redefine those types here — import them. See [`templates/example_repository_impl.dart`](templates/example_repository_impl.dart).

---

## REST patterns (the default)

- One data source per feature; methods mirror endpoints (`fetchTodos()`, `fetchTodo(id)`, `createTodo(dto)`).
- Type the response (`dio.get<List<dynamic>>`, `dio.get<Map<String, dynamic>>`) and cast before `fromJson`.
- Send/receive DTOs only. Convert request bodies with `dto.toJson()`; never hand-build JSON maps in the data source.
- Pagination/query params go through `dio`'s `queryParameters`; keep them typed in the data-source method signature.
- See [`templates/example_remote_data_source.dart`](templates/example_remote_data_source.dart) (GET list + GET by id) and [`templates/example_dto.dart`](templates/example_dto.dart).

## GraphQL note (when the backend is GraphQL)

Use `graphql_flutter` (or `ferry` for codegen-heavy apps) instead of raw `dio`. The shape is unchanged: a GraphQL data source issues `QueryOptions`/`MutationOptions`, returns DTOs parsed from `result.data`, and throws on `OperationException`; the repository still maps to `Failure` and returns `Result`. Keep the `GraphQLClient` behind a provider mirroring `dioProvider`, and put auth in the client's `Link` chain (an `AuthLink`) — same role as the dio auth interceptor.

## Firebase / Supabase note (BaaS)

Choose a **BaaS** (Firebase, Supabase) over a custom API when you want managed auth, realtime, and storage with little backend code, and the data model is straightforward. Choose a **custom API** (REST/GraphQL behind dio) when you need bespoke server logic, strict contracts, or portability.

Either way, **the SDK stays behind a repository interface.** A `SupabaseTodoDataSource` or `FirestoreTodoDataSource` replaces the dio data source, but `application`/`presentation` still depend on the same `domain` repository returning `Result<T>`. This keeps the app swappable and testable, and confines `supabase_flutter` / `cloud_firestore` to the `data` layer. (For realtime streams, expose `Stream<Result<T>>` from the repository — same mapping discipline.)

---

## Environment config (skill 10)

- baseUrl, API keys, and feature flags come from **`--dart-define`** (or a `--dart-define-from-file=env/dev.json`) and/or **flavors** (dev/staging/prod). Read them with `String.fromEnvironment` inside `core/network/`, surfaced as a small config object.
- Never commit secrets. Anything sensitive at runtime (tokens) lives in secure storage (skill 13); build-time config is injected by the CI flavor matrix (skill 21).

---

## DI wiring (matches skill 06)

The provider chain is **dio → data source → repository → controller**, each binding the previous. The repository provider returns the **domain interface**, so the rest of the app never sees the impl:

```dart
@riverpod ExampleRemoteDataSource exampleRemoteDataSource(Ref ref) =>
    ExampleRemoteDataSource(ref.watch(dioProvider));

@riverpod ExampleRepository exampleRepository(Ref ref) =>          // domain type
    ExampleRepositoryImpl(ref.watch(exampleRemoteDataSourceProvider));
```

Tests override `dioProvider` (with a `DioAdapter`/mock) or `exampleRepositoryProvider` (with a fake) via `ProviderScope(overrides: [...])` — skill 12 owns the API test setup.

---

## Definition of Done for stage 11

- `core/network/dio_client.dart` exposes a `@riverpod` `dioProvider` with baseUrl-from-env, timeouts, default headers, and attached interceptors.
- `AuthInterceptor` attaches a bearer token sourced from secure storage (skill 13) and leaves a 401 refresh seam.
- Each feature has a remote data source (DTOs, throws) and a repository impl that maps exceptions→`Failure` (skill 15) and DTO→entity, returning `Result<T>`.
- DTOs are `freezed` + `json_serializable` with `toEntity()`; the domain never imports `dio`/JSON.
- `dart run build_runner build` succeeds; **`flutter analyze` is clean**, and **endpoints return mapped domain entities via `Result`.** ✅

References: data-layer shape (skill 06), token storage & refresh (skill 13), retries/offline (skill 14), Result/Failure + mapper (skill 15). Full stage→gate map in [`../../references/PIPELINE.md`](../../references/PIPELINE.md).
