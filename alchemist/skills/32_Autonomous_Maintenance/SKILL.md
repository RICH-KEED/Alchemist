---
name: Autonomous Maintenance Agent
description: Scheduled agent that bumps deps/SDK, fixes new lints, regenerates code, runs tests, and opens a PR — proactive health sweeps on a cron-based cadence. Use to keep a Flutter project evergreen between features. Pairs with #33 Self-Healing CI (which reacts to red runs) and delegates fixes to #37 (build) and #41 (lint).
when_to_use: Trigger on "run the maintenance sweep", "bump dependencies", "check for stale deps", "run weekly health check", "upgrade Flutter SDK", "regenerate codegen after a pub upgrade", "open a maintenance PR", "what is the maintenance schedule". Pairs with #33 Self-Healing CI — #32 is the scheduler that opens PRs, #33 is the reactor that heals any resulting red CI.
---

# Autonomous Maintenance Agent (Roadmap #32)

A green codebase rots when nobody looks. This agent runs **proactive health sweeps** on a
configured cadence — it checks out, upgrades dependencies, fixes anything the upgrade breaks,
regenerates codegen, runs the full test suite, and opens a single reviewable PR. If CI goes red,
**#33 (Self-Healing CI)** picks up the baton. House style:
[`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).

> Safety first: this agent **never auto-merges**, never force-pushes, never touches secrets, and
> always opens a PR as the final artifact — a human reviews and merges. Every sweep is bounded in
> scope and time.

---

## 1. Cadence configuration

Sweep timing lives in [`templates/maintenance_config.yaml`](templates/maintenance_config.yaml).
The agent reads it, decides what to run, and skips anything not due.

| Schedule | Trigger | What it does |
|---|---|---|
| **weekly** | cron (e.g. `0 8 * * 1` — Monday 8 AM) | `flutter pub upgrade`, analyze, test, build_runner |
| **monthly** | cron (e.g. `0 8 1 * *`) | `flutter pub upgrade --major-versions`, full regression suite |
| **on-push** | workflow trigger on `main` changes | fast checks: analyze + test only (no version bumps) |

The config YAML also declares:
- **scope**: which packages to touch (all, pinned list, or exclude list)
- **auto_fix**: whether to let #41 auto-fix new lints
- **pr_labels**, **reviewers**, **max_attempts** per package group
- CI commands to run (`test_command`, `analyze_command`)

---

## 2. The sweep loop

```
1. CHECKOUT   branch maintenance/<date> from latest main (or configured base)
2. READ       parse maintenance_config.yaml — what is due today?
3. UPGRADE    flutter pub upgrade [--major-versions]  (scope: all/pinned/exclude)
4. ANALYZE    flutter analyze --no-fatal-infos
5. FIX LINT   if auto_fix=true → delegate to Analyzer Auto-Fix (#41)
              if analyzer passes → skip
              if judgment lints → log them, do NOT auto-fix
6. CODEGEN    dart run build_runner build --delete-conflicting-outputs
7. ANALYZE 2  re-run analyze (codegen may have shifted the landscape)
8. TEST       flutter test (full suite; see config for custom command)
9. PR         git add + commit + push → gh pr create with PR template (§4)
```

**Step 5 routing**: exactly the same rules as #33 §3 — only mechanical lints get auto-fixed.
Anything that lands in the JUDGMENT bucket (e.g. `use_build_context_synchronously`) is **logged
in the PR body** and left for the human reviewer.

**Step 6 — why rebuild**: `freezed`, `json_serializable`, and `riverpod_generator` all produce
generated files. After a major pub upgrade, stale generated code is the #1 cause of misleading
analyzer errors. Always regenerate before the second analyze.

**Failure at any step**: if the agent cannot self-repair within `max_attempts` per step, it stops
the sweep and opens a **"Maintenance blocked"** issue instead of a PR — same template fields but
with a `blocked` label and a clear next-step for the human.

---

## 3. Scope control

The config YAML's `scope` block determines exactly what gets upgraded:

| Scope mode | Behavior |
|---|---|
| `all` | Every dependency in `pubspec.yaml` — direct + transitive (default for monthly) |
| `pinned` | Only the list under `packages:` in scope |  
| `exclude` | Everything except the list under `exclude:` in scope |

Example: pin `dio` to a known-good version while upgrading everything else:

```yaml
scope:
  mode: pinned
  packages:
    - riverpod
    - freezed
    - go_router
```

The agent runs one package group at a time (commit per group) so a single problematic dep does
not block the whole sweep.

---

## 4. The maintenance PR

Every sweep produces exactly one PR. If the sweep spans multiple package groups, each group is
its own atomic commit on the same maintenance branch.

The PR body follows [`templates/maintenance_pr_template.md`](templates/maintenance_pr_template.md):

1. **What was bumped** — package name, old → new version, whether major (breaking)
2. **What broke** — analyzer errors, test failures, codegen regressions triggered by the bump
3. **What was fixed** — auto-fixed lints, manual interventions, codegen regeneration
4. **Test results** — `pass` / `N failures` / `skipped (reason)`
5. **Reviewer notes** — anything a human needs to check (JUDGMENT lints, flaky tests, deprecation warnings)

PR labels come from config (`pr_labels`); reviewers from config (`reviewers`).

---

## 5. Safety rails

Same non-negotiable rails as #33 — these two agents share a safety contract:

- **Never auto-merge.** The PR is opened; a human clicks merge. No `gh pr merge`, ever.
- **Bounded scope.** One dependency group per commit; the sweep stops at `max_attempts` per step.
  No chasing cascading breakage unbounded.
- **No secrets in source.** The agent never writes or modifies secret files. If a secret is needed
  for a test to pass, the PR notes it — the human configures the CI secret.
- **Minimal, reviewable diffs.** One concern per commit. No opportunistic refactors riding along.
- **No destructive git.** No force-push, no history rewrite, no deleting tests to make the sweep
  green.
- **Honest gates.** A passing PR means `flutter test` returned 0, not "looks fine." Report only
  what the test suite proves.
- **Clean revert path.** Every commit is a single package-group upgrade so a human can `git revert`
  one dep without losing the rest.

---

## 6. Gating — when to skip a sweep

The agent checks the following before starting and skips (with a comment on the last PR) if any
are true:

- `main` branch CI is currently red (there is nothing to maintain — fix first)
- An open maintenance PR already exists (don't stack PRs)
- `pubspec.lock` has not changed since the last successful sweep (nothing to upgrade)

---

## 7. How it pairs with #33 (Self-Healing CI)

**#32 is the scheduler; #33 is the reactor.** Division of labor:

| Concern | #32 Autonomous Maintenance | #33 Self-Healing CI |
|---|---|---|
| Trigger | Cron / schedule / on-push | Red CI run |
| Action | Upgrade deps, fix lints, codegen, test, open PR | Fetch logs, classify, apply fix, re-run |
| Output | Maintenance PR | Heal report (green or escalated) |
| Fixers used | #41 (lint), build_runner (codegen) | #37 (build), #41 (lint), bounded manual fixes |
| Safety | No auto-merge, bounded scope | No auto-merge, bounded attempts |

When a #32 maintenance PR turns CI red, **#33 heals that run** using its loop. Both share the
same fixers (#37 for build, #41 for lint) and the same safety rails.

---

See [`templates/maintenance_config.yaml`](templates/maintenance_config.yaml) for cadence/scope
tuning, [`templates/maintenance_pr_template.md`](templates/maintenance_pr_template.md) for the PR
body shape, and house style in
[`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).
