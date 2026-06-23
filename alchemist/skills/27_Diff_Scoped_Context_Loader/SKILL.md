---
name: Diff-Scoped Context Loader
description: For any edit task, load ONLY the changed files plus their direct dependents instead of the whole feature tree — bounding context to O(change). Use before editing existing Flutter code, when reviewing a diff, or when asked "what does this change affect / what should I re-test". Trigger phrases — "scope this change", "what's the blast radius", "what do I need to load to edit X", "impact of this diff".
when_to_use: Reach for this the moment an edit targets existing code and you'd otherwise read a whole feature into context. It reads skill #26's index — build/refresh that first. Pairs with #25 (compress the loaded set) and #30 (budget the spend). For onboarding to an unfamiliar app use #36; for turning a stack trace into its owning entity use #38; for greenfield code with nothing to depend on yet, just write it.
---

# Diff-Scoped Context Loader

When you edit existing code, the expensive mistake is loading the **whole feature** — every screen, provider, repository, and model in `lib/features/<x>/` — when the change only touches one file and a handful of callers. This skill loads the **minimal set**: the changed files plus their reverse-dependency closure, depth-capped, read straight from skill #26's index. Context cost becomes **O(change)**, not O(feature-tree).

House style this skill assumes: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md) (feature-first layout, inward-pointing deps `presentation → application → domain ← data`, mirrored `test/` paths, `Result`/`Failure` contracts).

## Why scope (the token economy)

Loading a feature to change one file pays for code you never touch, and the next edit pays again. Reverse-dependency scoping pays only for the change and what the change can break:

- **changed files** — what the diff edited (hop 0),
- **reverse dependents** — files that import them, transitively, capped at `--depth N` (hops 1..N),
- nothing else.

The closure comes from the index's `files[].dependsOn` edges (forward imports), walked backwards. No source tree is touched — one JSON read, offline. This is the cheap inner loop of the token-economy cluster.

## The method

1. **Get the change set.** Either a git diff (`git diff --name-only`) or a target symbol you're about to edit. For a symbol, look it up in the index (#26 query: match by `name` → `file`) to get its file.
2. **Refresh the index.** Run skill #26 `build_index.py --incremental` so edges are current. A stale index gives a wrong closure.
3. **Reverse-dependency walk.** From each changed file, BFS over reverse edges (importee → importers) up to `--depth N` (default **1**). Depth 0 = changed files only; depth 1 = direct dependents; raise it only when a contract changed (see below).
4. **Emit the minimal set.** The script prints: the **files to load**, the **impacted entities** in them (screen/provider/route/repository/model with `file:line`), the **features touched**, the **tests to run** (mirrored `test/` paths, flagged exists vs. write), and **risk notes**.
5. **Load only that set.** Read those files (jump to entity `line`s). Hand the set to #25 to compress, and log the `counts` to #30 as the edit's budget.

### Choosing depth

- **Leaf edit** (widget body, a private method) → `--depth 1`. Direct callers are enough.
- **Contract change** (a `Repository` interface, a `core/` file, a shared model, a route) → `--depth 2`+. Changes here ripple; load the wider ripple. The script raises a risk note for exactly these cases so you know to widen.
- Never load the whole feature "to be safe" — that defeats the skill. If the closure is genuinely huge, that *is* the finding (high blast radius → raise coverage), not a reason to abandon scoping.

## The script

Runnable stdlib Python 3 (no deps): [`scripts/scope.py`](scripts/scope.py). It reads the index and a changed-file list and prints the scoped context (text or `--json`).

```bash
# From a git diff (most common) — depth 1:
git diff --name-only | python3 "${CLAUDE_SKILL_DIR}/scripts/scope.py" --root <project_root>

# Equivalent, letting the script shell out to git:
python3 "${CLAUDE_SKILL_DIR}/scripts/scope.py" --git --root <project_root>

# A single target file you're about to edit, wider depth, JSON for tooling:
python3 "${CLAUDE_SKILL_DIR}/scripts/scope.py" \
    lib/features/auth/domain/auth_repository.dart \
    --root <project_root> --depth 2 --json
```

Changed files may come from positional args, `--files "a.dart b.dart"`, stdin (a pipe), or `--git`. Paths are normalized to the index's `lib/`-relative form, so raw `git` output (repo-root paths, Windows backslashes) works as-is. Defaults: `--index <root>/.flutter-pipeline/index.json`, `--depth 1`. Exit codes: `0` ok · `1` no index (build #26 first) · `2` no changed files · `3` bad args.

Output template for writing up the result: [`templates/impact_report.md`](templates/impact_report.md).

## Worked example

Auth lives in `lib/features/auth/` with this dependency chain (arrows = "imports"):

```
login_screen.dart → auth_providers.dart → auth_repository.dart (interface) ← auth_repository_impl.dart
                                                    ↑
                                          core/error/result.dart
```

You need to **change the `AuthRepository` interface** (add a method). Naively you'd load all of `features/auth/`. Instead:

```bash
git diff --name-only            # -> lib/features/auth/domain/auth_repository.dart
python3 "${CLAUDE_SKILL_DIR}/scripts/scope.py" --git --root . --depth 1
```

Output (abridged):

```
diff-scoped context  (package: my_app, depth: 1)
  1 changed -> 3 files to load, 2 dependents, 3 entities

FILES TO LOAD  (changed + reverse deps)
  [*]  lib/features/auth/domain/auth_repository.dart
  [+1] lib/features/auth/application/auth_providers.dart
  [+1] lib/features/auth/data/auth_repository_impl.dart

IMPACTED ENTITIES
  - repository AuthRepository      ...domain/auth_repository.dart:4   (auth)
  - repository AuthRepositoryImpl  ...data/auth_repository_impl.dart:8 (auth)
  - provider   authStateProvider   ...application/auth_providers.dart:3 (auth)

TESTS TO RUN
  [run ] test/features/auth/domain/auth_repository_test.dart
  [write] test/features/auth/data/auth_repository_impl_test.dart

RISK NOTES
  ! A repository INTERFACE is in scope — re-check all impls and callers;
    contract changes propagate via Result/Failure.
```

You load **3 files, not the ~8 in the feature** — `login_screen.dart` is *not* a direct dependent of the interface (it depends on the provider), so at depth 1 it stays out. The impl must implement the new method, the provider may need wiring, and the risk note tells you the interface change ripples — so you re-run the existing repo test and write the missing impl test. Need the screen too? It surfaces at `--depth 2`.

## How it pairs with the cluster

- **#26 Codebase Semantic Index** — the source of truth. Its `files[].dependsOn` edges *are* the dependency graph this skill walks backwards. Always build/refresh (`--incremental`) before scoping; a `STALE` entity means rebuild.
- **#25 Context Compression Engine** — feed it the **files-to-load set** (not the raw tree). Scope decides *which* files; #25 makes each one token-lean. Use them in series: scope → compress → edit.
- **#30 Token Budget Governor** — the report's `counts` (changed / files-to-load / entities) are the budget inputs. Log them per edit so the governor can track and cap context spend; a wide blast radius is a budget signal.
- **#36 Onboarding / #38 Triage** — siblings on the same index. #36 answers "how is the app laid out" (forward, top-down); #38 turns a stack frame into its entity + blast radius (reverse, like this skill but seeded by an error). This skill is the edit-time path.

## Output discipline

- The closure is only as good as the index — never scope against a stale or missing `index.json`; rebuild first.
- Report the **minimal set + impacted entities + tests + risk notes** (use the template), then load only that set. Do not silently widen depth — if you raise it, say why (contract change).
- Surface unindexed changed paths (new/untracked files) explicitly: they seed the closure but carry no edges until the index is rebuilt.
