# Mutation Scrub Checklist

Run this checklist **before every mutation run** to choose targets wisely and avoid wasting cycles on mutations that produce noise instead of signal.

---

## 1. Choose your scope

Pick **3-8 files** from a single module/feature. Do not mix features — results must be coherent so the test-hardening plan is focused.

- [ ] Scope is one module/feature (e.g., `features/auth/`, `core/error/`)
- [ ] 3-8 production files selected
- [ ] Each file has a matching `_test.dart` under `test/`
- [ ] Tests pass cleanly on unmutated code before starting (`flutter test test/<module>/`)

---

## 2. What NOT to mutate

Skip these files and patterns entirely. Mutations here produce only false positives or equivalent mutants with zero diagnostic value.

### File-level exclusions

- [ ] **Generated files** — `*.g.dart`, `*.freezed.dart`, `*.mocks.dart`, `*.gen.dart`, `*.gr.dart`
- [ ] **Test files** — any file ending in `_test.dart`
- [ ] **Configuration/constants** — files that only declare `const` values or environment config
- [ ] **Build/entry-point files** — `main.dart`, `main_development.dart`, `main_production.dart`
- [ ] **Asset/codegen registry** — `gen/assets.gen.dart`, `gen/fonts.gen.dart`

### Pattern-level exclusions (within allowed files)

- [ ] **Logging calls** — `logger.d(...)`, `logger.e(...)`, `log(...)` — side-effects, not logic
- [ ] **`print(...)` statements** — same as logging; should not exist per CONVENTIONS anyway
- [ ] **`@override` annotations** — framework wiring, not testable logic
- [ ] **`@riverpod` / `@freezed` / `@JsonSerializable` annotations** — codegen directives
- [ ] **`super.*` calls** in lifecycle methods (`initState`, `build`, `dispose`)
- [ ] **Third-party thin wrappers** — a class whose only job is calling one external package method
- [ ] **`assert(...)` in debug mode** — only runs in debug; mutation is invisible to tests
- [ ] **`toString()`, `copyWith()`, `==` and `hashCode`** — generated or trivial; mutations here are usually equivalent
- [ ] **`noSuchMethod` / `invoke` code** — framework dynamic-dispatch
- [ ] **`export` declarations** and `part`/`part of` directives

---

## 3. Mutation operators — full descriptions

Apply each operator one at a time. Revert before the next. Record kill/survive per operator.

### Arithmetic flip
Replace an arithmetic operator with its inverse.
- `+` → `-`, `-` → `+`
- `*` → `/`, `/` → `*`
- `%` → `*`
**Catches:** tests not verifying computed numeric results. If a calculation changes and no test fails, the tests are not checking the output.

### Condition invert
Replace a boolean condition with its negation.
- `if (condition)` → `if (!condition)`
- `while (condition)` → `while (!condition)`
- Ternary: `x ? a : b` → `!x ? a : b`
**Catches:** missing branch coverage; tests that only verify one path through a conditional. Every `if` needs at least two tests — one per branch.

### Return replace
Replace a return value with a different value of the same type.
- `return Ok(value)` → `return Err(Failure('mutated'))`
- `return data` → `return null`
- `return true` → `return false`
- `return items` → `return []` (empty collection)
- `return user` → `return User.empty()` (sentinel value)
**Catches:** tests that only check `isA<Ok>()` without verifying the value inside; tests that never exercise the error path; tests that accept any non-null result as success.

### Null swap
Replace a non-null return or assignment with `null`.
- `return result` → `return null`
- `final x = compute()` → `final x = null`
**Catches:** missing null-safety assertions; tests that never verify a non-null result; code paths that assume a value is non-null without asserting it.

### Boundary shift
Shift a numeric boundary by 1.
- `if (x > 0)` → `if (x > 1)`
- `if (x >= 5)` → `if (x >= 6)`
- `if (x < 10)` → `if (x < 9)`
- `if (x <= max)` → `if (x <= max - 1)`
**Catches:** off-by-one bugs; tests that never test threshold values. Every boundary needs tests at `boundary`, `boundary-1`, and `boundary+1`.

### Boundary flip
Flip `>` to `>=` or vice versa; flip `<` to `<=` or vice versa.
- `if (x > 0)` → `if (x >= 0)`
- `if (x < max)` → `if (x <= max)`
**Catches:** missing boundary-value tests. The difference between `>` and `>=` matters exactly at the boundary value — if the test never provides that exact value, the mutation survives.

### Boolean operator swap
Swap `&&` with `||`, or vice versa.
- `a && b` → `a || b`
- `a || b` → `a && b`
**Catches:** incomplete truth-table coverage. Every combination of `(a,b)` — `(T,T), (T,F), (F,T), (F,F)` — must be tested; if any pair is missing, one of these swaps will survive.

### Remove guard
Delete a guard clause.
- `if (x == null) return;` → delete the entire `if` block
- `if (!isValid) throw ...;` → delete the throw
- Early return → delete, let control flow through
**Catches:** missing tests for the guarded-against condition. Guards are defensive code — if no test exercises the condition they protect against, the guard is untested.

### Remove statement
Delete a non-control-flow statement.
- A method call — `validate(input);` → delete
- An assignment — `x = compute();` → delete
- A side-effect — `await prefs.setString(k, v);` → delete
**Catches:** missing side-effect verification. The test ran the code but never checked what the code actually did — no `verify`, no state assertion.

### Swap arguments
Swap the order of two arguments in a function call.
- `combine(a, b)` → `combine(b, a)`
- `subtract(x, y)` → `subtract(y, x)`
**Catches:** missing argument-order verification. When argument types are the same (both `String`, both `int`), the compiler won't catch a swap — only a test checking the output will.

---

## 4. Per-mutation execution checklist

For each mutation applied:

- [ ] Mutation is a single change (not a multi-line rewrite)
- [ ] Mutation applies to executable code, not annotations or whitespace
- [ ] Run `flutter test test/<path>/<target>_test.dart` — not the entire suite
- [ ] Record result immediately: KILLED / SURVIVED / EQUIVALENT / TIMED-OUT
- [ ] If SURVIVED, note which specific test should have caught it (or note "no test covers this path")
- [ ] **Revert the mutation** before applying the next
- [ ] Confirm the file is back to its original state: `git diff` shows nothing

---

## 5. After the run

- [ ] All mutations from this batch have been reverted; `git diff` is clean
- [ ] Full test suite still passes on clean code: `flutter test`
- [ ] `flutter analyze` passes with zero issues
- [ ] Mutation report (`templates/mutation_report.md`) is filled for this batch
- [ ] Survivors are passed to skill **#70** for test generation/hardening
- [ ] Re-run survivors after hardening to confirm they are now killed
