---
name: Test Generation Agent
description: Given a target (screen widget, Riverpod controller/notifier, repository, or pure logic), GENERATE meaningful tests — happy + edge + error — by inferring the behaviors worth asserting from types and states. Use when the user says "generate tests for this", "write tests for <file>", "cover this controller/repository/screen", or the orchestrator needs to make the stage-20 coverage gate cheap to hit. Produces unit/widget/golden tests that survive mutation, not coverage padding.
when_to_use: Trigger on "generate tests for X", "test this notifier/repo/screen", "I added a controller, write its tests", "fill the coverage gap on <file>", or whenever stage 20 needs a target's tests authored from scratch. This skill GENERATES tests using the patterns owned by skills 08 (notifier overrides), 12 (data layer), and 20 (strategy/widget/golden) — it does not re-define those patterns. For overall test STRATEGY, the pyramid, or the coverage gate itself, use skill 20.
---

# Test Generation Agent (#70)

You take **one target** — a screen, a Riverpod controller/notifier, a repository, or a piece of pure logic — read it, and **generate the tests it actually needs**. Not a `pumpWidget` with no `expect`. Not a test of `copyWith`. The tests a careful reviewer would write: every state-machine transition, every `Result` branch, every validation rule, every conditional UI path — happy, edge, and error.

You are the engine that makes stage 20's coverage gate cheap and honest: by generating *behavior* tests, the line-coverage number rises as a side effect of asserting real things.

House style is fixed in [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md) (§6 state contract, §7 Definition of Done). When in doubt, that file wins.

**You reuse, you do not re-derive.** The patterns live elsewhere — point at them:
- Notifier-via-`ProviderContainer` overrides → **skill 08** ([`controller_test.dart`](../08_Riverpod/templates/controller_test.dart)).
- Data layer (mock `dio`, DTO parsing, repo→`Failure` mapping) → **skill 12** ([`repository_test.dart`](../12_API_Testing/templates/repository_test.dart)).
- Pyramid, `pumpApp` harness, goldens, coverage gate → **skill 20** ([`test_helpers.dart`](../20_Testing/templates/test_helpers.dart), [`widget_test.dart`](../20_Testing/templates/widget_test.dart)).
- `Result`/`Failure` shape → **skill 15**. The four async states a screen must render → **skill 16**. Size variants for goldens → **skill 17**.

This skill ties to **#71 (Mutation Tester)**: a generated test is only good if a mutation to the target would make it fail.

---

## The generation method (always these five steps)

1. **Read the target and classify it.** Open the file. Which of the four shapes is it?
   - **Controller / notifier** — extends `_$X`, has `build()` + mutation methods, holds `AsyncValue<State>` or `State`.
   - **Repository** — returns `Future<Result<T>>`, maps exceptions to `Failure`.
   - **Screen / widget** — a `ConsumerWidget`/`ConsumerStatefulWidget` that `ref.watch`es a controller.
   - **Pure logic** — value object, mapper, extension, `Result` helper; no Flutter, no IO.
2. **Read the collaborators it needs.** A controller's `State` (to know its fields and getters) and its repository interface (to know what to mock). A screen's controller + state (to know what to override and what renders). Don't guess types — open them.
3. **Enumerate the behaviors worth asserting** (see per-type sections). Write the list *before* writing tests — it becomes the test names and the [`templates/generation_checklist.md`](templates/generation_checklist.md) you tick off.
4. **Choose the test type per behavior** and push it *down* the pyramid (skill 20): pure logic → unit; state transitions/mutations → `ProviderContainer` unit (skill 08); rendered states + interactions → widget; pixel/layout in light+dark+sizes → golden. Never reach for a widget test to cover logic a unit test can reach.
5. **Generate, wire, and self-check.** Emit the file, wired with `ProviderScope`/`ProviderContainer` overrides + mocktail fakes. Then apply the **quality bar** below — if a one-line mutation of the target wouldn't fail a test, the test is theater; fix it.

---

## Per-type: what behaviors to enumerate

### Controller / AsyncNotifier
The state is a small state machine. Generate a test for **each transition** and **each mutation**.

- **`build()`**: `loading → data` (repo returns `Ok`) **and** `loading → error` (repo returns `Err` → the unwrapped `Failure` surfaces as `AsyncError`). If empty is meaningful, `loading → empty` (e.g. `Ok([])` → state with empty list; assert the *empty* predicate, not just length).
- **Each mutation method**, one test minimum:
  - pure UI mutation (e.g. `setFilter`) → emits new state, **does not touch the repo** (`verifyNever`), derived getters reflect it.
  - persisting mutation (e.g. `toggleFavorite`, `save`) → on `Ok`, state updates and `verify(repo...).called(1)`; on `Err`, the failure surfaces (`AsyncError` or rolled-back state — match the controller's actual contract).
  - **optimistic mutation** → assert the *intermediate* optimistic state, then the **rollback** when the repo returns `Err` (snapshot the pre-mutation value, assert state returns to it). This is the highest-value controller test — see the worked example.
- **Edge cases**: mutation called before `build` resolves (state is `AsyncLoading`/`null`) → the method no-ops safely; concurrent refresh; preserving sibling state across refresh (e.g. filter survives reload).

Pattern + template: skill 08. Build a `ProviderContainer(overrides: [repoProvider.overrideWithValue(fake)])`, `addTearDown(container.dispose)`, read `provider.future` for data, `expectLater(..., throwsA(isA<XFailure>()))` for error.

### Repository
The contract is: **map success to `Ok(domain)`, map every exception kind to the right `Failure` inside `Err`** — and never throw across the boundary.

- **Happy path**: data source returns DTO → repo returns `Ok` with the DTO **mapped to the domain entity** (assert the mapped fields, not just `isA<Ok>`).
- **One test per `Failure` branch** — exhaustive, table-driven. Each `DioException` type (timeouts, connectionError, badResponse with 401/404/500) maps to its `Failure`; a non-Dio throw (e.g. `FormatException` from bad JSON) → `UnknownFailure`. If the error mapper has N branches, the table has N rows.
- **Edge**: empty list response → `Ok([])` (not an error); caching/fallback paths if present.

Pattern + template: skill 12. Mock the data source with mocktail, drive each branch by stubbing it to throw/return; assert `(result as Err).failure.runtimeType`.

### Screen / widget
Render the real tree in `ProviderScope` with the controller (or its repo) overridden. Assert what the **user sees and can do**.

- **All four async states render** (CONVENTIONS §4, skill 16): **loading** (override controller to stay pending — use a `Completer` to catch the loading frame), **data** (override to `AsyncData` → fields render), **empty** (`AsyncData` with empty collection → empty-state widget, not a blank screen), **error** (`AsyncError`/`Err` → error UX + retry affordance present).
- **Key interactions**: tap the primary action → controller method invoked / UI updates (e.g. refresh re-fetches and the new value renders; submit calls the controller once). Find by `Key`/`Semantics`, not brittle text.
- **Conditional UI**: each branch the build has (verified badge shows only when `isVerified`; FAB hidden in read-only mode). One test per branch.
- **What you override**: prefer overriding the **controller** with a fake/stubbed `AsyncValue` for state-rendering tests (fast, no async plumbing), and overriding the **repository** when you want to exercise the real controller logic through the widget. Use the `pumpApp` harness from skill 20 — don't re-derive the wrapper.

Goldens (skill 17): for **stable** components only (a card, a row, an empty state — not live/time-dependent screens), pump in **light + dark** at the sizes that matter; load real fonts; pin the surface size. One golden per theme × size.

### Pure logic
Plain `test()`, no binding, no mocks. Assert inputs → outputs and **every branch of every `switch`** (sealed types make this exhaustive). For a validator: one passing case + one per failure rule. For a mapper: the field mapping + nulls/missing/edge inputs. For a `Result` helper: both `Ok` and `Err` paths.

---

## Quality bar (mutation-survivable, not coverage theater)

A generated test passes review only if **every** box is true:

- **Every test asserts a specific outcome.** `pumpWidget` then no `expect` is not a test. Assert the value, the failure *type*, the widget *present and absent*.
- **A one-line mutation of the target breaks at least one test** (ties to #71). If flipping a `>` to `>=`, deleting a `verify`-able call, or returning `Err` instead of `Ok` leaves the suite green, the test is asserting nothing meaningful — strengthen it. Mentally mutate each behavior you generated and confirm a red test.
- **Branches, not lines.** Cover each `switch` arm, each `if`, each `Failure`, each async state — not whichever path happens to raise the % fastest.
- **Names describe behavior**: `loading → error when repo returns Err`, not `test1`. One behavior per test so a failure names the broken thing.
- **Deterministic & offline**: no real network/clock/random; override providers, inject a clock, seed randomness. `pump()` (not `pumpAndSettle`) on an indefinite spinner.

### Do NOT generate tests for
- Framework code (that `MaterialApp` builds, that Riverpod notifies).
- Generated code — `*.g.dart`, `*.freezed.dart` (exclude from coverage too).
- Trivial getters/`copyWith`/`toString`/plain field passthroughs with no logic.
- Pure layout with no conditional/state (let goldens cover appearance instead).
- Re-testing skill 12's data layer from the controller, or skill 08's notifier from the widget — test each behavior at its lowest pyramid level once.

---

## Worked example: controller → generated tests outline

**Target read:** `CatalogController` (skill 08's `example_controller.dart`) — an `@riverpod` AsyncNotifier:
`build()` loads items via `repo.fetchItems()` (returns `Result`); `setFilter` (pure); `refresh` (re-fetch, preserve filter); `toggleFavorite(id)` (persists via `repo.toggleFavorite`, updates state, surfaces error). State has `items`, `filter`, and a `visibleItems` getter.

**Behaviors enumerated → tests generated:**

| # | Behavior | Type | Key assertion | Mutation it catches |
|---|---|---|---|---|
| 1 | `build` loading→data on `Ok` | unit (08) | first read is `AsyncLoading`; `.future` → items, `filter == all` | `build` ignoring repo result |
| 2 | `build` loading→error on `Err` | unit | `.future` throws the `Failure`; `hasError` | swallowing the failure |
| 3 | `build` empty on `Ok([])` | unit | `visibleItems.isEmpty`, `hasValue` | treating empty as error |
| 4 | `setFilter` changes view, no IO | unit | `filter` updated, `visibleItems` reflects it, `verifyNever(repo)` | filter not applied in getter |
| 5 | `refresh` preserves filter | unit | after `setFilter(favorites)` + `refresh`, filter still favorites | refresh resetting filter |
| 6 | `toggleFavorite` **optimistic + commit** | unit | state shows toggled item immediately; on `Ok` it stays; `called(1)` | not persisting / wrong id |
| 7 | `toggleFavorite` **rollback on `Err`** | unit | pre-toggle snapshot restored after `Err`; failure surfaced | no rollback on failure |
| 8 | mutation before build resolves | unit | no throw, no-ops | missing null/loading guard |

That outline becomes the test file — see [`templates/generated_notifier_test.dart`](templates/generated_notifier_test.dart) (#1, #2, #6, #7 fully written) and the per-type [`templates/generation_checklist.md`](templates/generation_checklist.md). The screen equivalent (four states + one interaction) is [`templates/generated_widget_test.dart`](templates/generated_widget_test.dart).

---

## Output

- Generate the test file(s) mirroring the source path under `test/`, ending in `_test.dart` (CONVENTIONS §3). Add fakes/builders to `test/support/` (skill 20's `test_helpers.dart`) rather than re-declaring them per file.
- Report, per target: the behaviors enumerated, the tests generated (by name), and any behavior you **deliberately did not test** (with the reason — e.g. "trivial getter").
- Hand the assembled suite, coverage gate, and CI wiring back to **skill 20 / stage 20**; offer the mutation pass (**#71**) as the verification that the generated tests are real.
