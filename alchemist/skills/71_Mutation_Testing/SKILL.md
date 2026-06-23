---
name: Mutation Testing Harness
description: Mutate Flutter/Dart source — re-run tests — surviving mutants reveal weak or assertion-free tests. Coverage % lies; mutation score measures real strength. Use after stage 20 Testing to find blind spots and harden the test suite before release.
when_to_use: Trigger on "mutation test", "find weak tests", "test quality audit", "are my tests actually testing anything", "mutation coverage", "how good is my test suite really", or after stage 20 Testing to harden the test suite. Always followed by #70 test generation to fix the weak tests it flags.
---

# Mutation Testing Harness (#71)

You answer the question: **"Are these tests actually catching bugs?"** By systematically mutating production code and re-running the test suite, you separate real assertions from theater. A passing test that never asserts anything concrete is worthless — this skill proves it.

Coverage % is a liar. 90% line coverage with zero assertions per branch means nothing. **Mutation score** — `killed / total` — measures the percentage of intentional bugs your tests actually caught. That number is the real test health metric.

House style: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md). Feeds **#70 (Test Generation)** — for every surviving mutant, #70 generates a test that would have killed it.

---

## The golden rule

> A test that passes after the logic is broken is not a test — it is a participation trophy.

Every test must assert a **specific, observable outcome**. If you can mutate the production code and the test still passes, the test has no teeth. This skill exposes those gaps.

---

## Step 1 — Select mutation targets

Do NOT mutate every file (combinatorial explosion). Pick 3-8 high-value files per run, focused on one module at a time:

| Priority | What to mutate | Why |
|---|---|---|
| 1 | **Business logic** — `domain/` entities, value objects, validation, invariants | Bugs here = wrong behavior, hard to detect manually |
| 2 | **State management** — `application/` notifiers, controllers, use-case logic | Wrong state = wrong UI, often untested at the logic level |
| 3 | **Data mapping** — DTO-to-domain mappers, field transformations | Mapping bugs are silent and common; nulls propagate silently |
| 4 | **Core utilities** — extensions, `Result`/`Failure` helpers, math/date utils | Used everywhere; one bug here cascades |

**What NOT to mutate** — the full exclusion list lives in [`templates/mutation_scrub.md`](templates/mutation_scrub.md), but the headlines:
- Generated files (`*.g.dart`, `*.freezed.dart`, `*.mocks.dart`)
- Logging/tracing calls — they are side-effects, not logic
- `@override` annotations and framework wiring
- Test files, configuration/constants, thin package wrappers
- Annotations and code-generator directives

---

## Step 2 — Apply mutations

For each target file, apply **one mutation at a time**, re-run the relevant test file, record the result, then **revert before the next**. Never stack mutations — you lose traceability.

### Mutation operators

| Operator | Original | Mutant | What it catches |
|---|---|---|---|
| **Arithmetic flip** | `x + 1` | `x - 1` | Tests not verifying computed values |
| **Condition invert** | `if (isValid)` | `if (!isValid)` | Missing branch coverage; assertion-free paths |
| **Return replace** | `return Ok(x)` | `return Err(Failure(...))` | Tests only checking success, never errors |
| **Null swap** | `return result` | `return null` | Missing null-safety assertions |
| **Boundary shift** | `if (x > 0)` | `if (x > 1)` | Off-by-one edge cases |
| **Boundary flip** | `if (x > 0)` | `if (x >= 0)` | Boundary value testing |
| **Boolean operator swap** | `a && b` | `a \|\| b` | Compound condition coverage |
| **Remove guard** | `if (x == null) return;` | (delete guard) | Null-safety path coverage |
| **Remove statement** | `validate(input);` | (delete line) | Side-effect verification |
| **Swap arguments** | `combine(a, b)` | `combine(b, a)` | Parameter-order correctness |

Full operator descriptions and checklist in [`templates/mutation_scrub.md`](templates/mutation_scrub.md).

### Per-mutation cycle

1. Apply one mutation to the file.
2. Run the relevant test(s): `flutter test test/path/to/target_test.dart`.
3. Record: **KILLED** (at least one test fails) or **SURVIVED** (all tests pass).
4. Revert the mutation. Repeat with the next operator.

Dart lacks a mature automated mutation framework (unlike Stryker/JS or PIT/Java). If one emerges (a Dart port of Stryker, or a custom `dart_mutator` package), update this skill to use it. Until then, this is a manual but rigorous process.

---

## Step 3 — Score and diagnose

### Mutation score

```
score = killed / (total - equivalent) * 100%
```

Equivalent mutants — mutations that don't change observable behavior (e.g., `x + 0` to `x - 0`) — are excluded from the denominator. Judgment is required: if you can't argue the mutation truly doesn't change behavior, count it.

| Score | Verdict | Action |
|---|---|---|
| **>90%** | Strong — test suite catches real bugs reliably | Low priority hardening; ship with confidence |
| **70-90%** | Good — a few blind spots to address | Fix HIGH-priority survivors before release |
| **50-70%** | Moderate gaps — invest in hardening | Do not rely on tests as a safety net without fixes |
| **<50%** | Weak — false confidence | Significant hardening needed; treat as untested code |

### Diagnose each survivor

For every surviving mutant, determine the root cause:

| Root cause | Meaning | Fix |
|---|---|---|
| **No test covers this path** | The mutated line is never exercised | Write a test that exercises this branch/edge case |
| **Test has no assertion** | Code runs but nothing is checked | Add an assertion that would fail on this mutation |
| **Assertion too weak** | Asserts `isNotNull` when it should assert exact value | Strengthen to precise assertion (`equals(expected)`) |
| **Equivalent mutant** | Mutation doesn't change observable behavior | Exclude from score; document |
| **Dead code** | The mutated line is never reached in production | Remove the dead code (do not write a test to cover it) |

---

## Step 4 — Produce the mutation report

Fill [`templates/mutation_report.md`](templates/mutation_report.md):

1. **Scope** — which files were mutated, total mutants applied.
2. **Results table** — per mutant: file, line, original, mutation, operator, result, root cause (if survived).
3. **Score and operator breakdown** — mutation score; counts per operator (killed/survived).
4. **Survivor analysis** — per survivor: root cause, recommended test to add or strengthen, priority (HIGH/MEDIUM/LOW).
5. **Verdict** — score, confidence level, go/no-go recommendation.

---

## Step 5 — Harden via #70 and re-run

Mutation testing finds gaps; **#70 (Test Generation)** fills them:

1. For each surviving mutant (excluding equivalents), invoke **#70** to generate or strengthen the specific test that should have caught it.
2. Verify the new test **fails against the mutant** (it must — otherwise the test is still too weak).
3. Run the full clean suite — all tests pass on unmutated code.
4. Re-apply the mutation — confirm it is now KILLED.
5. Update the mutation report: move entries from "survived" to "killed," recalculate score.

Keep `flutter analyze` clean throughout — the edit-test-revert cycle can leave artifacts.

---

## Concrete example

**Target:** `auth_notifier.dart` — a Riverpod AsyncNotifier with `signIn(email, password)`:
```dart
Future<void> signIn(String email, String password) async {
  if (email.isEmpty) {
    state = const AsyncError(ValidationFailure('Email required'), StackTrace.empty);
    return;
  }
  state = const AsyncLoading();
  final result = await _authRepo.signIn(email, password);
  state = result is Ok ? AsyncData(result.value) : AsyncError(result.failure, StackTrace.empty);
}
```

**Mutants applied (5), tests run (3 existing):**

| # | Mutation | Operator | Existing test | Result |
|---|---|---|---|---|
| 1 | `if (!email.isEmpty)` | Condition invert | `test('signIn succeeds with valid email')` — never passes empty email | **SURVIVED** — no test for empty-email path |
| 2 | `return;` after `if (email.isEmpty)` deleted | Remove guard | Same — always provides valid email | **SURVIVED** — guard never exercised |
| 3 | `AsyncData(result.value)` → `return null;` | Null swap | Only asserts `isA<AsyncData>()` — doesn't check value | **SURVIVED** — assertion too weak |
| 4 | `result is Ok` → `result is Err` | Condition invert | Test stubs repo to return `Ok` — no branch that returns `Err` | **SURVIVED** — error path uncovered |
| 5 | `Ok ? data : error` → `Err ? data : error` | Return replace | This flips the ternary — test asserts `AsyncData` regardless | **SURVIVED** — success value never concretely checked |

**Score: 0/5 = 0%.** Three existing tests, zero survivors killed — the suite is pure theater despite 100% line coverage.

**Resolution via #70:** Generate tests for empty-email guard, error-branch from repo, concrete user value in `AsyncData`, and null return detection. Re-apply mutants 1-5 after the new tests land — all killed. Score moves to 100%.

---

## Limitations

- **Not automated** — Dart lacks a production-ready mutation testing framework. This skill guides a manual, systematic process.
- **High token cost** — each mutation is edit + test-run + revert. Be selective: 3-8 files, 3-10 mutations per file.
- **Equivalent mutants require judgment** — no algorithm to auto-detect them. Reason about whether the mutation truly changes observable behavior.
- **UI code excluded** — widget tests check presence and interaction, not logic correctness. Mutating widget code yields mostly equivalent mutants. Mutation-test the logic behind widgets instead.

---

## Cross-references

| Skill | Relationship |
|---|---|
| **20 Testing** | Produces the test suite this skill audits |
| **70 Test Generation** | Generates tests for surviving mutants — the hardening loop |
| **41 Analyzer AutoFix** | Keep `flutter analyze` clean during edit-test-revert cycles |
| **72 Contract Golden Drift** | Contract-level correctness companion in Phase D quality guard |

Report template: [`templates/mutation_report.md`](templates/mutation_report.md). Mutation checklist: [`templates/mutation_scrub.md`](templates/mutation_scrub.md).
