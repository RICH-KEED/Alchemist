# ADR-0002: Riverpod 2.x as the State Standard (not Bloc)

## Status
Accepted (2026-06-20)

## Context
Flutter state management has many choices. The two strongest contenders for a
large, testable app are:

1. **Riverpod 2.x** — compile-safe DI, no BuildContext coupling, `riverpod_generator`
   for codegen, `riverpod_lint` + `custom_lint` for compile-time validation.
2. **Bloc** — stream-based, widely adopted, separate boilerplate per event/state.

## Decision
We chose **Riverpod 2.x** as the house standard because:

- Provider overrides make testing trivial — inject fakes via `ProviderContainer`
  without DI frameworks or service locators.
- `AsyncNotifier` with codegen provides type-safe async state with built-in
  loading/error/data discriminated unions.
- `ref.listen` handles side effects (navigation, snackbars) without mixing them
  into `build()`.
- `ref.watch(p.select(...))` gives fine-grained rebuild control without manual
  `Equatable` or `freezed` for every state class.
- It composes naturally with go_router via `ref.watch` in redirect guards.
- One mechanism for DI and state — no `get_it` needed.

## Consequences

- Skill 08 (Riverpod) provides the canonical patterns.
- Skill 40 (State Leak Auditor) and Skill 73 (Regression Memory) target Riverpod
  provider lifecycles specifically.
- All scaffolded code (skill 06) defaults to Riverpod patterns.
- Bloc is not prohibited for projects that already use it, but the pipeline's
  standard templates and health checks assume Riverpod.
