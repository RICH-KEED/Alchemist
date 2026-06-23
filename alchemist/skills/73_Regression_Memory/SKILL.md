---
name: Regression_Memory
description: Records every fixed bug's signature/root-cause/fix/guarding-test — warns when a change risks reintroducing one. Feeds skill 38 (Runtime_Exception_Triage).
when_to_use: After fixing a bug and before merging the PR (record entry) — on PR open/push in CI via check_regressions.py (scan for regressions) — during code review when a diff touches files with known regression signatures.
---

# Regression Memory

Records every shipped bug fix as a structured entry so the pipeline can detect when a new change risks reintroducing a previously-fixed defect. Feeds **skill 38** (Runtime_Exception_Triage) for automated triage and **skill 20** (Testing) for guard enforcement.

Conventions: `../../references/CONVENTIONS.md`

---

## Exit gate

- `regression.json` has one entry for every shipped fix
- `check_regressions.py` runs in CI on every PR open/push and exits clean (0)
- Every HIGH or MEDIUM confidence match is posted as a PR review comment

---

## Regression entry schema

Every entry in the regression database MUST include these fields:

| Field | Type | Description |
|---|---|---|
| `bug_id` | string | Unique ID, e.g. `REG-001` |
| `title` | string | Human-readable one-liner |
| `signature.files` | string[] | File paths involved in the bug |
| `signature.functions` | string[] | Function names in the call stack |
| `signature.patterns` | string[] | Regex patterns from the faulty code |
| `signature.error_type` | string | Exception class or error category |
| `root_cause` | string | Category key (see below) |
| `fix_commit` | string | SHA of the fix commit |
| `guarding_test` | string | Path to test that would have caught this |
| `tags` | string[] | Freeform tags for filtering |
| `date` | string | ISO date of the fix |

---

## When to record

Record a regression entry **immediately after fixing a bug, before merging the PR**. The entry belongs in `.flutter-pipeline/regressions.json` in the project root. If the file does not exist, create it with `{"version": 1, "entries": []}` as the skeleton.

Do NOT defer recording — the signature is freshest in your mind right after the fix. A missing entry means the pipeline cannot warn about that regression.

---

## Signature design

A good signature uniquely identifies the bug's footprint so that future diffs can be scanned for similarities. A signature is a tuple of:

1. **File paths** — the `.dart` files where the bug lived. Use paths relative to the project root (e.g. `lib/features/payment/data/payment_repository.dart`).
2. **Function names** — the specific functions/methods in the call stack. Class methods use `ClassName.methodName` notation. Riverpod providers use the provider variable name.
3. **Code patterns** — regex snippets that match the faulty code structure. These should capture the "shape" of the bug, not the exact fixed code. For example:
   - `.map\(.*\)\.toList\(\)` for missing null checks in chained iterables
   - `ref\.watch\(.*\.future\)` for a provider that should be `ref.listen` instead
   - `await.*\.then\(` for a missing error handler on a Future chain
4. **Error type** — the exception class name (e.g. `NullThrownError`, `StateError`, `MissingPluginException`). Use `NullSafety` as the umbrella for all null-reference crashes.

A signature is **too narrow** if it matches only the exact fixed line — it would never flag a reintroduction. It is **too broad** if it matches innocuous code in every file — it would flood CI with false positives. Aim for patterns that are ~20-80 characters and appear once or twice in the affected file.

---

## Root cause categories

| Category | Description |
|---|---|
| `null_safety` | Null reference access, late-initialized not ready, nullable not checked |
| `concurrency_race` | Race conditions, Future ordering, isolate deadlocks |
| `state_lifecycle` | Provider disposed too early, widget not mounted, state accessed after dispose |
| `api_contract_mismatch` | Backend returns unexpected shape, enum mismatch, field rename |
| `platform_channel` | MethodChannel type mismatch, MissingPluginException, platform not implemented |
| `rendering_layout` | RenderFlex overflow, intrinsic sizing loops, repaint storms |
| `memory` | Memory leak, image cache blowup, retained reference after dispose |
| `permission` | Missing permission declaration, runtime permission denied |
| `navigation` | Route not found, deep link parsing, nested Navigator push failure |

---

## check_regressions.py

Location: `${CLAUDE_SKILL_DIR}/scripts/check_regressions.py`

Standard-library-only Python 3 script. Reads the regression DB, diffs the current branch against `origin/main`, and reports any signature matches.

### Invocation

```bash
python3 ${CLAUDE_SKILL_DIR}/scripts/check_regressions.py \
  --db .flutter-pipeline/regressions.json \
  --base origin/main
```

### Match confidence

| Confidence | Condition |
|---|---|
| HIGH | Same file + same function + pattern match |
| MEDIUM | Same file + pattern match (no function overlap) |
| LOW | Same file only (no function or pattern match) |

### Output format

```
HIGH: REG-003 — NullSafety in PaymentRepository.getCards — lib/features/payment/data/payment_repository.dart: getCards
MEDIUM: REG-007 — Race condition in AuthNotifier.login — lib/features/auth/auth_notifier.dart: ^\.map\(.*\)\.toList\(\)$
```

### Exit codes

- `0` — no matches or only LOW confidence
- `1` — one or more HIGH or MEDIUM confidence matches found

### JSON mode

Pass `--json` to output findings as a JSON array:

```json
[{"confidence": "HIGH", "bug_id": "REG-003", "title": "Title", "file": "path", "function": "func", "pattern": "regex"}]
```

---

## CI integration

Add to the project's CI workflow (GitHub Actions example):

```yaml
- name: Check regressions
  run: |
    python3 skills/73_Regression_Memory/scripts/check_regressions.py \
      --db .flutter-pipeline/regressions.json
```

On HIGH or MEDIUM matches, the CI step fails. Use the `--json` flag to capture findings and post them as PR review comments via the GitHub API (`gh pr review`).

---

## Testing guard

Every regression entry MUST link to a guarding test — the test that would have caught the original bug. The `guarding_test` field points to the test file path (e.g. `test/features/payment/data/payment_repository_test.dart`).

Before merging a fix:
1. Write the test FIRST (TDD — confirm it fails on the buggy code)
2. Apply the fix (confirm the test passes)
3. Record the regression entry linking to that test

The pipeline verifies that every `guarding_test` path exists and is executed in CI. Missing or unexecuted tests are reported as pipeline failures.

---

## Pipeline connections

| Skill | Direction | Purpose |
|---|---|---|
| **20 — Testing** | Feed | Each regression entry's guarding test must be in the test suite |
| **38 — Runtime_Exception_Triage** | Feed | Triage tooling uses regression DB to classify crashes by known signatures |
| **01 — Master_Orchestrator** | Consumer | Orchestrator reads `regressions.json` to track fix history per milestone |

---

## Related

- `../../references/CONVENTIONS.md` — Dart 3, Riverpod 2.x, sealed Failure/Result patterns
- `../20_Testing/SKILL.md` — Test suite organization and guarding test patterns
- `../38_Runtime_Exception_Triage/SKILL.md` — Crash triage pipeline that consumes regression signatures
