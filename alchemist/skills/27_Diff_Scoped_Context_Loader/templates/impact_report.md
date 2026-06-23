# Impact Report — <change description>

> Diff-scoped context for an edit task. Produced from `.flutter-pipeline/index.json`
> (skill #26) by `scripts/scope.py`. House style: [`../../../references/CONVENTIONS.md`](../../../references/CONVENTIONS.md).
> Scope: **changed files + reverse-dependency closure at depth N** — bounded to O(change), not the whole feature tree.

**Package:** `<my_app>` · **Depth:** `<N>` · **Generated:** `<date>`
**Summary:** `<C>` changed → `<L>` files to load · `<I>` dependents · `<E>` entities

---

## 1. Changed files

The seed set — what the diff (or target symbol) actually touched.

| File | In index? |
|---|---|
| `lib/.../foo.dart` | yes |
| `lib/.../bar.dart` | no — rebuild #26 |

> Files not in the index are new/untracked or non-`lib/`. Re-run skill #26
> (`build_index.py --incremental`) before trusting the closure.

## 2. Files to load (minimal context set)

Load **only** these into context. `[*]` = changed (depth 0); `[+k]` = reverse
dependent at k hops. This is the entire footprint the edit needs — nothing else.

| Marker | File | Hops |
|---|---|---|
| `*` | `lib/.../foo.dart` | 0 |
| `+1` | `lib/.../uses_foo.dart` | 1 |
| `+2` | `lib/.../uses_that.dart` | 2 |

## 3. Impacted entities

Symbols declared in the loaded set — the concrete things a reviewer must re-check.

| Kind | Name | Location | Feature |
|---|---|---|---|
| repository | `AuthRepository` | `lib/features/auth/domain/auth_repository.dart:4` | auth |
| provider | `authStateProvider` | `lib/features/auth/application/auth_providers.dart:3` | auth |
| screen | `LoginScreen` | `lib/features/auth/presentation/login_screen.dart:10` | auth |

**Features touched:** `auth`

## 4. Tests to run

Mirror paths under `test/` (CONVENTIONS §3). `run` = exists in index; `write` =
conventional path to author for new coverage.

| State | Test | Covers |
|---|---|---|
| run | `test/features/auth/domain/auth_repository_test.dart` | `lib/features/auth/domain/auth_repository.dart` |
| write | `test/features/auth/application/auth_providers_test.dart` | `lib/features/auth/application/auth_providers.dart` |

Run command (existing tests only):

```bash
flutter test test/features/auth/domain/auth_repository_test.dart
```

## 5. Risk notes

Heuristic flags over the loaded set — read before editing.

- [ ] **Blast radius:** `<I>` dependents. Wide (>20) → raise coverage first; zero → leaf-local, low risk.
- [ ] **Repository interface in scope** → contract change ripples to every impl + caller via `Result`/`Failure`.
- [ ] **`lib/core/` changed** → cross-feature impact; verify dependents across features.
- [ ] **Routes in scope** → re-check deep links + navigation guards (skill #07).
- [ ] **Unindexed paths** → rebuild #26 for an accurate closure.

---

### Notes on use

- **Pairs with #26 (index):** the closure is only as fresh as the index — run `build_index.py --incremental` first.
- **Pairs with #25 (compression):** feed *Files to load* (§2) to the compressor, not the raw tree, so the loaded set is also token-lean.
- **Pairs with #30 (cost):** the `counts` (changed/load/entities) are the budget inputs — log them to track context spend per edit.
- Raise `--depth` only when a contract (interface/core) changed and you need the full ripple; default `1` is right for leaf edits.
