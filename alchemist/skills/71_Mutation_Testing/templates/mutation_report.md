# Mutation Testing Report

## Scope

| Field | Value |
|---|---|
| Date | YYYY-MM-DD |
| Target module/feature | e.g., `features/auth/domain/` |
| Files mutated | N (list paths) |
| Total mutants applied | N |
| Killed | N |
| Survived | N |
| Equivalent (ignored) | N |
| Timed out / errored | N |
| **Mutation score** | **(killed / (total - equivalent)) * 100%** |

---

## Score interpretation

| Score | Verdict | Action |
|---|---|---|
| >90% | **Strong** — test suite catches real bugs reliably | Low-priority hardening; ship with confidence |
| 70-90% | **Good** — a few blind spots to address | Fix HIGH-priority survivors before release |
| 50-70% | **Moderate gaps** — invest in hardening | Do not rely on tests as a safety net without fixes |
| <50% | **Weak** — false confidence | Significant hardening needed; treat as untested code |

---

## Results table

| # | File | Line | Original | Mutation | Operator | Result | Root cause (if survived) |
|---|---|---|---|---|---|---|---|
| 1 | `auth_notifier.dart` | 42 | `if (email.isNotEmpty)` | `if (!email.isNotEmpty)` | Condition invert | KILLED | — |
| 2 | `auth_notifier.dart` | 42 | `if (email.isNotEmpty)` | `if (email.isNotEmpty \|\| true)` | Boolean operator swap | SURVIVED | No test exercises empty-email path |
| 3 | `value_objects.dart` | 15 | `return Email(value)` | `return null` | Null swap | KILLED | — |
| 4 | `value_objects.dart` | 22 | `value.length >= 6` | `value.length >= 7` | Boundary shift | SURVIVED | Assertion is `isA<Email>()` — too weak; should verify exact value |
| 5 | `value_objects.dart` | 22 | `value.length >= 6` | `value.length > 6` | Boundary flip | KILLED | — |
| 6 | `token_storage.dart` | 8 | `await prefs.setString(...)` | (deleted line) | Remove statement | SURVIVED | No test verifies token was persisted |
| 7 | `auth_repository.dart` | 55 | `return Ok(user)` | `return Err(UnknownFailure())` | Return replace | KILLED | — |
| ... | | | | | | | |

---

## Operator breakdown

| Operator | Applied | Killed | Survived | Kill rate |
|---|---|---|---|---|
| Arithmetic flip (`+` → `-`) | N | N | N | N% |
| Condition invert (`if (x)` → `if (!x)`) | N | N | N | N% |
| Return replace (`Ok` → `Err`) | N | N | N | N% |
| Null swap (`return x` → `return null`) | N | N | N | N% |
| Boundary shift (`> 0` → `> 1`) | N | N | N | N% |
| Boundary flip (`>` → `>=`) | N | N | N | N% |
| Boolean operator swap (`&&` → `\|\|`) | N | N | N | N% |
| Remove guard (delete null-check) | N | N | N | N% |
| Remove statement (delete line) | N | N | N | N% |
| Swap arguments (`f(a,b)` → `f(b,a)`) | N | N | N | N% |
| **Totals** | N | N | N | N% |

---

## Survivor analysis

For each surviving mutant — root cause, recommended hardening, and priority.

### Survivor 1: `auth_notifier.dart:42` — Boolean operator swap

- **Original:** `if (email.isNotEmpty)`
- **Mutation:** `if (email.isNotEmpty || true)` — always true
- **Root cause:** No test covers the empty-email path. The test always provides a valid email, so the condition is always true regardless — the mutation was invisible.
- **Recommended test:** Add `test('returns error when email is empty')` — calls `signIn('', 'password')` and asserts `AsyncError` with `ValidationFailure`.
- **Priority:** **HIGH** — input validation gap

### Survivor 2: `value_objects.dart:22` — Boundary shift

- **Original:** `value.length >= 6`
- **Mutation:** `value.length >= 7`
- **Root cause:** Test assertion is `expect(result, isA<Email>())` — only checks the type, not the value. A 6-character email was expected to be valid; the mutation made it invalid, but the test never checked the actual email value.
- **Recommended test:** Strengthen assertion to `expect(result.value, equals('a@b.co'))` — assert the exact parsed value, not just the type.
- **Priority:** **MEDIUM** — type-only assertion

### Survivor 3: `token_storage.dart:8` — Remove statement

- **Original:** `await prefs.setString('auth_token', token)`
- **Mutation:** Line deleted — token never persisted
- **Root cause:** No test verifies the side effect. The test only asserts `repository.saveToken()` returns `Ok` — it never checks that `shared_preferences` actually received the token.
- **Recommended test:** Override `SharedPreferences` with a fake; after `saveToken`, assert `prefs.getString('auth_token')` equals the expected token.
- **Priority:** **HIGH** — side-effect verification gap

---

## Weak test list

Tests that failed to kill any mutant or that survived multiple operator applications:

| Test name | Path | Survivors missed | Issue |
|---|---|---|---|
| `signIn succeeds with valid email` | `auth_notifier_test.dart` | #2, #4, #5 | Only tests happy path with valid inputs |
| `Email can be created` | `value_objects_test.dart` | #4 | Asserts only `isA<Email>()`, never checks value |
| `saveToken returns success` | `token_storage_test.dart` | #6 | Does not verify persistence side effect |
| ... | | | |

---

## Suggested fixes (feed to #70)

These are the hardening tasks to pass to **skill 70 (Test Generation)**:

1. [ ] **HIGH** — Add empty-input validation tests for `auth_notifier.dart` (guard clauses: empty email, empty password, null inputs)
2. [ ] **HIGH** — Add side-effect verification for `token_storage.dart` persistence (mock `SharedPreferences`, assert key/value written)
3. [ ] **HIGH** — Add error-branch test for `auth_notifier.dart` — stub repo to return `Err`, assert `AsyncError` propagates
4. [ ] **MEDIUM** — Strengthen `Email` value-object test from `isA<Email>()` to exact value assertion
5. [ ] **MEDIUM** — Add boundary-value test for `Email` — lengths 5, 6, 7 at the validation threshold
6. [ ] **LOW** — Add test for null return path in `auth_repository.dart` result mapping
7. [ ] ...

---

## Verdict

- [ ] **PASS** — mutation score > 90%. Test suite is reliable.
- [ ] **HARDEN** — score 70-90%. Address HIGH-priority survivors before release.
- [ ] **CRITICAL** — score < 70%. Major test gaps exist; do not rely on tests as a safety net.

| | |
|---|---|
| **Score** | XX% |
| **Confidence** | LOW / MODERATE / HIGH |
| **Recommendation** | Go / NO-GO / GO-WITH-HARDENING |
| **Approved by** | Name / Date |
