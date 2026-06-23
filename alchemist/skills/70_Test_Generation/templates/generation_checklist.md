# Test Generation Checklist (per target)

Work top to bottom for the target's type. Each box is a **behavior**, which becomes a
test name. Skip a box only with a written reason (e.g. "no empty state — list is always
non-empty by construction"). Patterns: skills 08 (notifier), 12 (data), 20 (widget/golden),
15 (Result/Failure), 16 (four states), 17 (golden sizes). House style: `../../references/CONVENTIONS.md`.

> Done = every applicable box ticked, every test asserts a specific outcome, and a one-line
> mutation of the target would turn at least one test red (the #71 bar).

---

## Controller / AsyncNotifier  → unit via `ProviderContainer` (skill 08)

State machine — one test per transition:
- [ ] `build`: **loading → data** (repo `Ok`) — first read is `AsyncLoading`; `.future` resolves to expected state.
- [ ] `build`: **loading → error** (repo `Err`) — `.future` throws the `Failure`; `hasError` is true; `error` is the right type.
- [ ] `build`: **empty** (repo `Ok` with empty collection) — empty predicate/getter true, `hasValue` true (empty ≠ error).

Mutations — one test per method:
- [ ] **Pure UI mutation** (e.g. `setFilter`) — new state emitted; derived getters reflect it; `verifyNever(() => repo...)`.
- [ ] **Persisting mutation, success** — on `Ok`: state updates, `verify(() => repo.x(...)).called(1)` with the right args.
- [ ] **Persisting mutation, failure** — on `Err`: failure surfaces per the controller's contract (`AsyncError` or rolled-back state).
- [ ] **Optimistic mutation** — assert the **intermediate optimistic state** before the repo resolves.
- [ ] **Optimistic rollback** — snapshot pre-mutation state; on `Err` assert it is **restored**.

Edge / guard cases:
- [ ] Mutation invoked **before `build` resolves** (state loading/null) — no throw, no-op.
- [ ] Sibling state **preserved across `refresh`** (e.g. filter survives reload).
- [ ] Concurrent / double-invocation safe (if the controller guards it).

Do NOT test: the generated `*.g.dart`, framework wiring, trivial passthrough setters.

---

## Repository  → unit with mocked data source (skill 12)

- [ ] **Happy path** — data source returns DTO → `Ok` with DTO **mapped to domain entity**; assert mapped fields.
- [ ] **One row per `Failure` branch** (table-driven, exhaustive — match the error mapper arm-for-arm):
  - [ ] connection/send/receive timeout → `TimeoutFailure`
  - [ ] connectionError → `NetworkFailure`
  - [ ] badResponse 401 → `UnauthorizedFailure`
  - [ ] badResponse 404 → `NotFoundFailure`
  - [ ] badResponse 5xx / other → `NetworkFailure` (or project default)
  - [ ] non-Dio throw (bad JSON / parse) → `UnknownFailure`
- [ ] **Never throws across the boundary** — every path returns a `Result`.
- [ ] **Edge** — empty response → `Ok([])` not an error; cache/fallback path if present.

Do NOT test: dio internals, the DTO's generated `fromJson` line-by-line (cover via one parse test in skill 12's data_source_test).

---

## Screen / widget  → widget test in `ProviderScope` (skills 20, 16)

Use the `pumpApp` harness (skill 20 `test_helpers.dart`); override the controller or its repo.

Four async states — all must render (CONVENTIONS §4):
- [ ] **Loading** — controller pending (use a `Completer`); spinner present; use `pump()` not `pumpAndSettle`.
- [ ] **Data** — `AsyncData` with content; the fields/rows render; loading gone.
- [ ] **Empty** — `AsyncData` with empty collection; the **empty-state widget** renders (not a blank screen).
- [ ] **Error** — `AsyncError`/`Err`; error message + **retry affordance** (`find.byKey`) present.

Interactions & conditional UI:
- [ ] **Primary interaction** — tap action → controller method called / UI updates (find by `Key`/`Semantics`).
- [ ] **One test per conditional branch** in `build` (badge shown only when X; FAB hidden when read-only).
- [ ] No business logic asserted here that a unit test already covers — push it down.

Do NOT test: exact pixels (that is goldens), `MaterialApp`/`Theme` existence, static layout with no state.

---

## Golden  → light + dark × sizes (skill 17)

For **stable** components only (card / row / empty state — never live-data or time-dependent screens):
- [ ] Light theme at each target size (phone + tablet as relevant).
- [ ] Dark theme at each target size.
- [ ] Real fonts loaded; surface size pinned; no network/clock/random in the rendered widget.
- [ ] PNGs committed; diff reviewed in the PR (never accept `--update-goldens` blind).

---

## Pure logic  → plain `test()` (skill 20)

- [ ] Happy path: representative input → expected output.
- [ ] **Every `switch` arm** of every sealed type exercised (exhaustive).
- [ ] Validator: one pass + **one per failure rule**.
- [ ] Mapper: field mapping + null/missing/edge inputs.
- [ ] `Result` helper: both `Ok` and `Err` paths.

Do NOT test: trivial getters, `copyWith`, `toString`, `==`/`hashCode` from freezed.

---

## Final self-check (every target)

- [ ] Every test has at least one meaningful `expect`.
- [ ] Mentally mutate each behavior (flip a comparison, drop a call, return `Err` for `Ok`) — a test goes red.
- [ ] Test names describe behavior; one behavior per test.
- [ ] Deterministic & offline; mirrors source path under `test/`, ends `_test.dart`.
- [ ] Coverage rises as a *byproduct* — generated code excluded; logic near-exhaustive.
