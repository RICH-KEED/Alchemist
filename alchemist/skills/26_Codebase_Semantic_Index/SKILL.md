---
name: Codebase Semantic Index
description: Build and maintain a persistent, incremental index of a Flutter app's symbols so skills query the index instead of re-reading the tree. Use when a skill needs to find where something lives ("where is auth state?", "list all routes", "what depends on X?"), when onboarding to an unfamiliar app, or when scoping a change — and BEFORE any token-heavy operation that would otherwise grep/read lib/**. Trigger phrases — "index the codebase", "build the semantic index", "where is X", "what depends on X", "list all routes/providers/screens".
when_to_use: Run this first in any session that will touch an existing Flutter app — it is the MEMORY foundation the token-economy cluster (Diff-Scoped Loader #27, Onboarding #36, Triage #38) depends on. Re-run with `--incremental` after edits. For a brand-new empty scaffold there is nothing to index yet; build it once feature code exists.
---

# Codebase Semantic Index

You maintain a **persistent map of an app's symbols** at `.flutter-pipeline/index.json`, so that other skills can answer "where / what / what-depends-on" by reading a small JSON file instead of re-walking `lib/**`. This is the prerequisite for the whole token-economy cluster.

House style this index understands: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md) (feature-first layout, Riverpod, go_router, freezed, `Result`/`Failure`, repository interfaces).

## Why an index (the token economy)

Without an index, every "find the auth provider" or "what uses `result.dart`?" question costs a full grep + multiple file reads — and the next skill pays it again. The cost grows with the **size of the app**: O(app).

With an index, the answer is one JSON read; rebuilds touch only **changed files**: O(change). The index is the shared memory that makes Diff-Scoped Loading (#27), Onboarding (#36), and Triage (#38) cheap. Build it once, keep it warm with `--incremental`, query it everywhere.

## What it indexes

Six entity kinds + a file dependency edge list — exactly the things the pipeline reasons about:

| Kind | Extracted from (house style) |
|---|---|
| **feature** | each `lib/features/<name>/` directory |
| **screen** | `class X extends ConsumerWidget / StatelessWidget / StatefulWidget / ConsumerStatefulWidget / HookConsumerWidget / HookWidget` |
| **provider** | `@riverpod` class (`extends _$X`), `@riverpod` function (`Foo foo(Ref ref)`), and manual `final xProvider = ...Provider(...)` |
| **route** | go_router `GoRoute(path:, name:)` **and** the `RouteDef x = (name:, path:)` table in `routes.dart` (the literal source of truth) |
| **repository** | `abstract [interface] class XRepository` (interface) + `class XRepositoryImpl implements XRepository` (impl) |
| **model** | `@freezed` classes |
| *(edges)* | project-internal imports → file-level `dependsOn[]` (external `package:` imports excluded) |

Generated files (`*.g.dart`, `*.freezed.dart`, `*.gr.dart`, `*.config.dart`) are skipped — they add noise, not new symbols.

> Note on routes: house style declares paths once in `routes.dart` as `RouteDef` tuples and references them in `GoRoute(path: AppRoute.x.path)`. The script captures the literal tuples directly and de-duplicates the reference-based GoRoutes against them, so you get one clean route per definition.

## The index schema

Full annotated schema: [`templates/index_schema.json`](templates/index_schema.json). Shape:

```jsonc
{
  "schemaVersion": 1,
  "package": "my_app",
  "counts": { "feature": 2, "screen": 4, "provider": 5, "route": 5, "repository": 2, "model": 2 },
  "entities": [
    { "id": "provider:lib/features/auth/application/auth_providers.dart#authStateProvider",
      "kind": "provider", "name": "authStateProvider", "style": "manual",
      "file": "lib/features/auth/application/auth_providers.dart", "line": 3,
      "feature": "auth", "dependsOn": ["lib/core/..."] },
    { "id": "route:lib/app/router/routes.dart#login",
      "kind": "route", "name": "login", "path": "/login", "routeVar": "login",
      "file": "lib/app/router/routes.dart", "line": 5, "dependsOn": [] }
  ],
  "files": [ { "file": "...", "mtime": 0.0, "dependsOn": ["..."] } ]
}
```

Every entity carries `id`, `kind`, `name`, `file`, `line`, and `dependsOn[]`. `line` lets a consumer jump straight to a declaration (`Read` with `offset`) instead of scanning. Kind-specific fields (`base`, `style`, `path`, `role`, …) are documented in the schema.

## Building & maintaining the index

Runnable script (stdlib Python 3, no deps): [`scripts/build_index.py`](scripts/build_index.py).

```bash
# Full build — run once per session against an existing app:
python3 "${CLAUDE_SKILL_DIR}/scripts/build_index.py" <project_root>

# Incremental — after edits; reuses unchanged files (only re-scans files
# newer than the existing index). This is the steady-state command:
python3 "${CLAUDE_SKILL_DIR}/scripts/build_index.py" <project_root> --incremental
```

`<project_root>` defaults to the current directory and must contain `lib/`. Output defaults to `<root>/.flutter-pipeline/index.json` (override with `--out`). It prints a summary:

```
semantic index -> .flutter-pipeline/index.json
  mode: incremental  -  package: my_app
  files: 9 (scanned 1, reused 8)
  entities: 2 features, 4 screens, 7 providers, 5 routes, 2 repositories, 2 models
```

### Incremental updates (only changed files)

`--incremental` reads the previous index, then for each Dart file reuses its prior entities/edges if the file's mtime is `<=` the index's mtime; otherwise it re-scans just that file. A corrupt or missing index falls back to a full build. If git is available, a tighter changed-set is `git diff --name-only` ∩ `lib/**/*.dart` — re-run the script after touching those.

**When to rebuild:** after any code change a downstream skill will query. Cheap rule: run `--incremental` at the top of any session and after each batch of edits. Re-run a **full** build if `schemaVersion` in the file differs from the script's (schema drift).

## Query patterns

Copy-paste jq / python one-liners: [`templates/query_examples.md`](templates/query_examples.md). The essentials:

- **"Where is auth state?"** → filter `entities` where `kind=="provider"` and name matches `auth`; read `file:line`.
- **"List all routes"** → `entities` where `kind=="route"` → `path`, `name`, location.
- **"What depends on X?"** (change impact) → `files` where `dependsOn` contains the target path → the dependent files.
- **"What does file X import?"** → that file's `dependsOn[]`.
- **"Everything in feature Y"** → `entities` where `feature=="Y"`.
- **"Jump to a symbol"** → match by `name`, read `file:line` directly — no tree scan.

Always read `.counts` first as a cheap header before pulling the full list.

## Integration with graphify

The index is graph-shaped already: entity `id`s are nodes, file-level `dependsOn` edges connect them. To get community/architecture views — god-node detection, clustered feature boundaries, layering violations — export nodes+edges (recipe at the end of [`templates/query_examples.md`](templates/query_examples.md)) and feed them to **graphify** (`/graphify`). Use the index for precise lookups; use graphify for the bird's-eye structure and "which files are central / tangled" questions.

## How other skills consume it

This skill is the **memory foundation** for the token-economy cluster — they read `.flutter-pipeline/index.json` rather than re-deriving structure:

- **Diff-Scoped Loader (#27)** — maps a git diff to the impacted entities via `files[].dependsOn`, then loads only those files + their reverse-dependents. The index is what makes "scoped" possible.
- **Onboarding (#36)** — answers "how is this app laid out?" from `counts`, features, routes, and the dependency graph, with zero tree-walking.
- **Triage (#38)** — turns an error/stack frame into the owning entity (`file:line` → feature/provider/repository) and its blast radius (reverse edges).
- **Master Orchestrator (#01)** and any stage skill — confirm an artifact exists / find where a symbol lives before doing deeper work.

Keep the index fresh (`--incremental`) so these skills stay cheap. If a consumer hits a `STALE` entity (file no longer exists — see the drift check in the query examples), trigger a rebuild before trusting the index.

## Output discipline

- The index is a **derived artifact** — never hand-edit `index.json`; regenerate it.
- It is per-project and lives under `.flutter-pipeline/` alongside `STATE.md` (the pipeline's other memory). Both are safe to commit or to `.gitignore`; committing lets reviewers query without a local build.
- Report what changed after a build (the summary line) so the user can see the index is current before downstream skills rely on it.
