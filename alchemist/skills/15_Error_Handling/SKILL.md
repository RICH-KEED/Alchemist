---
name: Error Handling
description: Make errors first-class. Use when wiring error handling, defining the Failure/Result types, mapping exceptions at the data boundary, adding a global error boundary, or designing user-facing error states. Owns the canonical core/error/result.dart + failure.dart that every other skill imports. Pipeline stage 15.
when_to_use: Trigger on "handle errors", "Result type", "Failure type", "what happens when the API fails", "global error boundary", "error screen", "catch crashes", or any time a layer needs to fail without throwing. Do this early in Phase C — stages 11/14/16 consume these contracts. For rich loading/empty UI defer to skill 16; for crash-report delivery defer to skill 23.
---

# Error Handling

Stage 15 of [the pipeline](../../references/PIPELINE.md). This skill owns the app's
**error contract**: the `Result<T>` and `Failure` types that every other skill
imports. Get them exactly right — they are load-bearing. House style:
[`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md) §5.

**Exit gate:** no uncaught errors; every failure has UX + a log entry.

---

## The philosophy (non-negotiable)

1. **No raw exceptions cross a layer.** Anything thrown by `dio`, `dart:io`,
   parsing, etc. is caught at the **data boundary** and turned into a typed
   `Failure`.
2. **Fallible operations return `Result<T>`.** Repositories and use-cases return
   `Future<Result<T>>` — `Ok(value)` or `Err(failure)`. They never `throw`.
3. **The UI pattern-matches.** Widgets `switch` over `Result` / `AsyncValue` and
   render an explicit error state. No silent failures.
4. **Every failure has a user-facing story.** A title, a message, and — wherever
   meaningful — a recovery action. "Something went wrong" with no way out is a
   bug (see anti-patterns).
5. **Every failure is logged once**, with its `cause`/`stackTrace`, on its way to
   the crash reporter (skill 23).

```
exception ──▶ mapError() ──▶ Failure ──▶ Err<T> ──▶ UI switch ──▶ FailureUx
 (data src)   (data layer)   (typed)    (Result)    (presentation)  (copy + action)
```

---

## What this skill installs

Copy these into `lib/core/error/` (create the templates verbatim — other skills
import these exact paths):

| Template | Path | Role |
|---|---|---|
| `result.dart` | `core/error/result.dart` | `Result<T>` = `Ok`/`Err` + helpers |
| `failure.dart` | `core/error/failure.dart` | sealed `Failure` hierarchy |
| `error_mapper.dart` | `core/error/error_mapper.dart` | `mapError(error, st) → Failure` |
| `failure_x.dart` | `core/error/failure_x.dart` | `Failure → FailureUx` (title/msg/action) |
| `app_error_boundary.dart` | `core/error/app_error_boundary.dart` | widget boundary + release `ErrorWidget.builder` |

---

## 1. The Result type

`sealed class Result<T>` with exactly two cases — `Ok<T>(value)` and
`Err<T>(failure)` — plus helpers (`fold`, `when`, `map`, `flatMap`, `mapErr`,
`getOrElse`, `valueOrNull`, `failureOrNull`, `isOk`, `isErr`). See
[`templates/result.dart`](templates/result.dart). Use `runCatchingAsync` to lift
a throwing call into a `Result` in one line.

---

## 2. The Failure hierarchy

`sealed class Failure` (carries `message`, optional `cause`, `stackTrace`) with
subclasses: **NetworkFailure**, **TimeoutFailure**, **UnauthorizedFailure**,
**NotFoundFailure**, **ValidationFailure** (with `fieldErrors`), **CacheFailure**,
**UnknownFailure** (with `code`). Sealed → the UI and `failure_x` switch
exhaustively; adding a case is a compile error until you handle it everywhere.
See [`templates/failure.dart`](templates/failure.dart).

> `Failure.message` is **developer-facing** (logs only). Never show it to a user
> — go through `failure_x.dart`.

---

## 3. Mapping exceptions → Failure (data boundary)

[`templates/error_mapper.dart`](templates/error_mapper.dart) has the single
`Failure mapError(Object error, StackTrace st)`:

- `DioException` by `type`: timeouts → `TimeoutFailure`; `connectionError` /
  `badCertificate` → `NetworkFailure`; `badResponse` → by **status**:
  400/422 → `ValidationFailure`, 401/403 → `UnauthorizedFailure`, 404 →
  `NotFoundFailure`, other → `NetworkFailure(statusCode)`.
- `TimeoutException` → `TimeoutFailure`; `FormatException` → `ValidationFailure`;
  `SocketException` (by name) → `NetworkFailure`.
- An already-typed `Failure` passes through; everything else → `UnknownFailure`.

Use it in data sources via the `result.dart` helper:

```dart
@override
Future<Result<User>> fetchUser(String id) => runCatchingAsync(
      () async => UserDto.fromJson(await _api.getUser(id)).toDomain(),
      mapError: mapError, // exceptions never escape this call
    );
```

---

## 4. Mapping Failure → user-facing copy

[`templates/failure_x.dart`](templates/failure_x.dart) exposes
`failure.ux → FailureUx(title, message, actionLabel?)`. The UI reads this — it
never composes its own copy from `Failure.message`. `actionLabel` is the
recovery affordance (`Retry`, `Sign in`, `Go back`); `null` means dismiss-only
(e.g. `ValidationFailure`, whose recovery is inline field errors).

---

## 5. The global boundary

Three app-wide nets, **set in `main.dart` (skill 06)**; crash delivery is wired
in **skill 23** (this skill leaves typed hooks/placeholders):

```dart
void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    installReleaseErrorWidget();           // from app_error_boundary.dart

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      // TODO(skill-23): crashReporter.recordFlutterError(details);
      log('FlutterError', error: details.exception, stackTrace: details.stack);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      // TODO(skill-23): crashReporter.recordError(error, stack);
      log('PlatformError', error: error, stackTrace: stack);
      return true; // handled
    };

    runApp(const ProviderScope(child: MyApp()));
  }, (error, stack) {
    // TODO(skill-23): crashReporter.recordError(error, stack, fatal: true);
    log('ZoneError', error: error, stackTrace: stack);
  });
}
```

- `FlutterError.onError` — errors in the widget tree (build/layout/paint).
- `PlatformDispatcher.instance.onError` — uncaught async / platform errors.
- `runZonedGuarded` — the outermost catch-all; the zone must wrap `runApp`.

`installReleaseErrorWidget()` swaps Flutter's red error box for a calm fallback
in **release only** (debug keeps the red box — you want to see it).

---

## 6. Per-screen & per-subtree error states

- Wrap a screen body (or a risky section) in
  **`AppErrorBoundary`** so one broken widget can't crash the app; it renders a
  fallback with a `retry` callback and forwards details to the global handler.
- For expected, recoverable failures, the screen switches over its
  `AsyncValue`/`Result` and shows the error state. Rich loading/empty/skeleton UI
  is **skill 16's** job — here just render the error with `failure.ux`:

```dart
ref.watch(userProvider).when(
  loading: () => const LoadingView(),          // skill 16
  error: (e, _) {
    final ux = (e is Failure ? e : mapError(e, StackTrace.current)).ux;
    return ErrorView(
      title: ux.title,
      message: ux.message,
      actionLabel: ux.actionLabel,
      onAction: () => ref.invalidate(userProvider),
    );
  },
  data: (user) => UserView(user),
);
```

---

## Anti-patterns (reject these in review)

- **Catch-and-ignore** — `try { ... } catch (_) {}`. Every catch maps to a
  `Failure` and logs. No empty catches.
- **Generic dead-end** — "Something went wrong" with no recovery action and no
  log entry. Give it a `FailureUx` with an action, or a reason it has none.
- **Leaking `Failure.message` to users** — it's for logs; use `failure.ux`.
- **`throw` across a layer** — repositories/use-cases return `Result`, never throw.
- **Swallowing in the zone** — the global handlers must *log/report*, not just
  `return true` silently.
- **`catch (e) { rethrow as UnknownFailure }` everywhere** — map at ONE boundary
  (`mapError`), not scattered ad-hoc.

---

## Exit gate checklist

- [ ] `result.dart` + `failure.dart` exist at `core/error/` and compile.
- [ ] Data sources funnel every call through `mapError` — no `throw` escapes.
- [ ] Every `Failure` subclass maps to a `FailureUx` (exhaustive switch compiles).
- [ ] `FlutterError.onError`, `PlatformDispatcher.onError`, `runZonedGuarded` set
      in `main.dart`; release `ErrorWidget.builder` installed.
- [ ] Every async surface renders an error state with a recovery action.
- [ ] Every failure produces exactly one log entry (crash hooks ready for 23).
