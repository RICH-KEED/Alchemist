---
name: Riverpod State Management
description: Standardize app state on Riverpod 2.x with code generation. Use when wiring screen state, building controllers/notifiers, doing DI, or when the user mentions "state management", "Riverpod", "provider", "AsyncNotifier", or "where does this state live". Produces @riverpod controller + state scaffolds per feature and provider-override tests.
when_to_use: Stage 08 of the pipeline. Trigger after the app is scaffolded (06) and routes exist (07), whenever a feature needs state, async loading, or dependency injection. For pure error/Result types invoke 15; for rendering AsyncValue to UI invoke 16; for DI wiring of repositories invoke 06.
---

# Riverpod State Management

You own how state and dependency injection work in this app. The contract is fixed in
[`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md) §6 — when in doubt, that file wins.

**The house stack:** Riverpod 2.x with **code generation** (`riverpod_annotation` +
`riverpod_generator` + `riverpod_lint`/`custom_lint`). You annotate with `@riverpod`; `build_runner`
emits the `*.g.dart` providers. Hand-writing `Provider(...)`/`StateNotifierProvider(...)` is legacy —
do not produce it.

**Exit gate:** *state wired; provider override tests pass.*

---

## The mental model

A **provider is two things at once**: a unit of *dependency injection* and a unit of *observable
state*. You read providers through a `ref`; Riverpod caches the value and rebuilds watchers when it
changes. That is the whole model — everything below is choosing the right provider kind and the right
`ref` verb.

Layering (see CONVENTIONS §2):

```
presentation (widgets)  ──watch──▶  application (controllers/notifiers)  ──watch──▶  domain repo interface
                                                                                          ▲
                                                                              data layer override (06/11)
```

Widgets never hold business logic. Controllers never import Flutter `material`. Repositories are
injected via a provider so tests can override them.

---

## Choosing a provider kind (always codegen `@riverpod`)

| Need | Annotate | Generates | Use for |
|---|---|---|---|
| Inject a dependency / derive a sync value | `@riverpod` function returning `T` | `Provider<T>` | repositories, config, computed values |
| One-shot async read, no mutations | `@riverpod` function returning `Future<T>` | `FutureProvider<T>` | "load this once" reads |
| Mutable state, sync | `@riverpod` class extending `_$X` with `T build()` | `NotifierProvider` | filters, form state, counters |
| Mutable state, async-loaded + mutations | `@riverpod` class with `Future<T> build()` | `AsyncNotifierProvider` | **the default screen controller** |

> **Default for a screen:** an `@riverpod` class whose `build` returns `Future<State>` (an
> AsyncNotifier). It loads initial data in `build` and exposes mutation methods. See
> [`templates/example_controller.dart`](templates/example_controller.dart).

Add `keepAlive: true` to the annotation for state that must survive losing all listeners (auth,
caches). Omit it — the codegen default — for screen-scoped state, which then auto-disposes.

---

## AsyncValue: the async state envelope

A `Future build()` controller exposes its state as `AsyncValue<T>` — a union of
`AsyncData` / `AsyncLoading` / `AsyncError`. Two rules:

1. **In the controller**, wrap every async mutation in `AsyncValue.guard` so thrown errors become
   `AsyncError` instead of escaping:
   ```dart
   state = const AsyncLoading();
   state = await AsyncValue.guard(() => _repo.fetch());
   ```
   This is the *one* place exceptions are allowed near the boundary, and `guard` converts them for
   you. Repositories themselves still return `Result<T>` (skill 15) — see "Result interop" below.

2. **Rendering** `AsyncValue.when(...)` (loading/data/error → widgets) belongs to **skill 16**, not
   here. Controllers produce `AsyncValue`; UI consumes it. Do not put `.when` UI branches in this
   stage's output.

---

## `ref`: watch vs read vs listen

| Verb | When | Rebuilds on change? |
|---|---|---|
| `ref.watch(p)` | reactive dependency — in a `build` method or another provider | **yes** |
| `ref.read(p)` | one-shot, inside a callback/method (e.g. a button handler, a mutation) | no |
| `ref.listen(p, cb)` | run a **side effect** on change (snackbar, navigation, analytics) | runs `cb` |

Rules of thumb:
- In `build` (widget or provider): **`watch`**. Never `read` to grab a dependency you depend on.
- In an event handler or a notifier mutation method: **`read`** (you want the current value, not a
  subscription).
- For side effects from state changes: **`ref.listen`**, never logic inside `build`.

### `.select` — surgical rebuilds

Watch only the slice you care about so unrelated changes don't rebuild you:

```dart
// rebuilds only when the item COUNT changes, not on every field of every item
final count = ref.watch(itemsControllerProvider.select((s) => s.valueOrNull?.items.length));
```

Reach for `.select` whenever a widget watches a big state object but uses one field.

---

## Families — parameterized providers

Add parameters to the annotated function/class; codegen makes it a family automatically:

```dart
@riverpod
Future<Product> product(Ref ref, {required String id}) =>
    ref.watch(productRepositoryProvider).getById(id);

// usage
ref.watch(productProvider(id: '42'));
```

Each distinct argument set is a separate cached instance. Keep family args small, value-typed, and
`==`-comparable (a `String id`, not a whole object) — args are the cache key.

---

## Lifecycle: autoDispose, keepAlive, onDispose

- **autoDispose is the codegen default.** When the last listener goes away, the provider is disposed
  and its state cleared. Correct for screen state — leave it.
- **`keepAlive: true`** in `@riverpod(keepAlive: true)` for app-lived state (session, settings,
  warm caches).
- **Conditional keep-alive:** call `final link = ref.keepAlive();` after a successful load, then
  `link.close()` to release — e.g. cache a result but let it expire.
- **`ref.onDispose(...)`** to release resources (close a `StreamSubscription`, a `Timer`, a
  controller) exactly when the provider dies. Always pair subscriptions with `onDispose`.

```dart
@riverpod
Stream<int> ticks(Ref ref) {
  final controller = StreamController<int>();
  final timer = Timer.periodic(const Duration(seconds: 1), (t) => controller.add(t.tick));
  ref.onDispose(() { timer.cancel(); controller.close(); });
  return controller.stream;
}
```

---

## Dependency injection & overrides

Repositories are providers (their concrete impl is wired in stage **06**/**11**). A controller pulls
its repo with `ref.watch(xRepositoryProvider)` — it never news up a repository. This is what makes
the controller testable:

```dart
ProviderContainer(overrides: [
  productRepositoryProvider.overrideWithValue(FakeProductRepository()),
]);
```

The **same override mechanism** serves two jobs: injecting fakes in tests, and swapping
implementations (e.g. a mock backend in dev). See
[`templates/controller_test.dart`](templates/controller_test.dart).

### Result interop (skill 15)

Repositories return `Result<T>` (`Ok`/`Err`), they don't throw. Inside a controller you have two
clean options:

```dart
// A) unwrap Result, throw on Err so guard turns it into AsyncError
state = await AsyncValue.guard(() async {
  final res = await _repo.fetch();
  return switch (res) { Ok(:final value) => value, Err(:final failure) => throw failure };
});

// B) pattern-match and set AsyncError yourself (no guard)
final res = await _repo.fetch();
state = switch (res) {
  Ok(:final value) => AsyncData(value),
  Err(:final failure) => AsyncError(failure, StackTrace.current),
};
```

Pick one per project and be consistent. `Failure` is a valid `AsyncError.error` payload — skill 16
maps it to UX.

---

## ANTI-PATTERNS — reject these in review

| Anti-pattern | Why it's wrong | Do instead |
|---|---|---|
| Business logic in `build` | `build` re-runs on every dependency change; logic gets re-executed/duplicated | put logic in methods or derived providers |
| `ref.watch` inside a callback / `onPressed` | creates a subscription at the wrong time; throws or leaks | use `ref.read` in callbacks |
| Creating a provider **inside** `build` | new instance each build → state resets, memory churn | declare providers at top level |
| Storing `BuildContext` in a notifier | context outlives/invalidates; couples state to UI | pass data in; do nav via `ref.listen` in the widget |
| Mutating state in place (`state.items.add(x)`) | same reference → no rebuild, breaks equality | emit a new immutable state (`state = AsyncData(s.copyWith(...))`) |
| `ref.read` for a reactive dependency in `build` | you won't rebuild when it changes — stale UI | use `ref.watch` |
| Side effects (snackbar/nav) in `build` | runs on every rebuild; fires repeatedly | `ref.listen` |
| Hand-written `StateNotifier`/`ChangeNotifier` providers | off-house, more boilerplate, no codegen lints | `@riverpod` Notifier/AsyncNotifier |

`riverpod_lint` + `custom_lint` catch several of these automatically — keep them on and clean.

---

## What you produce (per feature)

Under `lib/features/<feature>/application/`:

1. **State class** — freezed, immutable. See [`templates/example_state.dart`](templates/example_state.dart).
2. **Controller** — `@riverpod` AsyncNotifier with `build` + mutation methods using `AsyncValue.guard`
   and `ref.watch(repoProvider)`. See [`templates/example_controller.dart`](templates/example_controller.dart).
3. **Tests** — `ProviderContainer` with the repo overridden by a mocktail fake; assert
   loading→data and the error path. See [`templates/controller_test.dart`](templates/controller_test.dart).

Then run codegen:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Exit-gate checklist

- [ ] Every screen's state lives in an `@riverpod` Notifier/AsyncNotifier under `application/`.
- [ ] Controllers inject repositories via `ref.watch`, never construct them.
- [ ] Mutations use `AsyncValue.guard` (or explicit `AsyncError`); no exceptions escape.
- [ ] No anti-patterns above; `riverpod_lint`/`custom_lint` clean; `flutter analyze` clean.
- [ ] `*.g.dart` generated and committed; build succeeds.
- [ ] Provider-override tests pass (loading→data **and** error path) — **this is the gate.**

Hand off to **16** (render AsyncValue → loading/data/empty/error) and **11** (real repositories).
