---
name: Self-Healing CI Agent
description: On a CI failure, ingest the run logs, classify the failure family, apply a targeted fix, commit, and re-run — escalating to a human if unresolved after N attempts. Use when a GitHub Actions job goes red and you want the agent to triage and self-repair instead of hand-debugging. Delegates build errors to Build Doctor (#37) and lints to Analyzer Auto-Fix (#41).
when_to_use: Trigger on "CI is red", "the build failed on main", "fix the failing GitHub Actions run", "self-heal the pipeline", "a flaky test broke CI", or any failed-run URL/log paste. Pairs with #32 Autonomous Maintenance (which schedules health sweeps) and routes individual failures to #37 (build) and #41 (lint). For a local build failure with no CI involved, call #37 directly instead.
---

# Self-Healing CI Agent (Roadmap #33)

A red CI run is a fixable event, not a dead end. Your job is to **fetch the failed run's logs,
classify which failure family broke it, route to the right fixer, commit a bounded fix, and re-run**
— looping until green or until you hit the attempt cap, at which point you **escalate to a human**
with a clean summary. You orchestrate; the deep fixes belong to other skills. House style:
[`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).

You are an orchestrator, not a new fixer engine:
- **Build / compile / version failures** → delegate to **Build Doctor (#37)** (`diagnose.py`).
- **Lint / format / analyzer failures** → delegate to **Analyzer Auto-Fix (#41)**.
- **Flaky test, version-solve pin, signing/secret, timeout, network** → apply the bounded action in
  this skill's taxonomy (no separate skill owns these).

> Safety first: this skill **never auto-merges**, never force-pushes, never touches secrets in
> plaintext, and never runs unbounded. Every heal is attempt-capped and ends in *green* or
> *escalated-with-a-summary*.

---

## 1. The heal loop

Run this loop for one failed run. Default cap **N = 3** fix attempts.

```
1. FETCH    gh run view <run-id> --log-failed > ci.log   (full failed-job log)
2. CLASSIFY pick the failure family from §2 taxonomy (or run diagnose.py for build)
3. ROUTE    hand the log to the fixer/action for that family
4. APPLY    let the fixer produce the edit; keep the diff minimal and scoped
5. COMMIT   one focused commit on the SAME branch (never main directly; never merge)
6. RE-RUN   gh run rerun <run-id> --failed   (or push triggers a fresh run)
7. WATCH    gh run watch <new-run-id> --exit-status
   - green        -> DONE: report what healed it (§5)
   - red, same    -> attempts++; if attempts < N go to 2 (re-classify; layers peel)
   - red, new fam -> attempts++; if attempts < N go to 2 (new family, new route)
   - attempts==N  -> STOP: escalate with the heal report (§4)
```

Why re-classify each pass: failures stack. A signing fix can reveal a version-solve error underneath;
a build fix can reveal a flaky test. The *top* family changes as you peel layers — never assume the
second run fails for the same reason as the first.

### Fetching the right log

```bash
gh run list --branch <branch> --status failure --limit 5      # find the run id
gh run view <run-id>                                           # job/step overview
gh run view <run-id> --log-failed > ci.log                    # only failed steps' logs
gh run view <run-id> --job <job-id> --log > job.log           # one job's full log
```

Capture the **full** failed-step log, not the last line — the cause sits above `Process completed
with exit code 1` (the same rule Build Doctor applies to Gradle output). Pipe build logs straight to
the diagnoser:

```bash
gh run view <run-id> --log-failed | \
  python "${CLAUDE_SKILL_DIR}/../37_Build_Doctor/scripts/diagnose.py" --json
```

---

## 2. The failure taxonomy

Eight families. Full signals → fixer → escalation rule in
[`templates/failure_taxonomy.md`](templates/failure_taxonomy.md); the index:

| Family | Telltale in the log | Fixer / action | Auto-safe? |
|---|---|---|---|
| **build** | Gradle/AGP/Kotlin/JDK errors, `namespace not specified`, `Execution failed for task` | **Build Doctor #37** (`diagnose.py` → exact edit) | only LOW-risk edits |
| **lint** | `flutter analyze` non-zero, lint rule names, `error •/warning •` lines | **Analyzer Auto-Fix #41** (format + `dart fix` loop) | yes (mechanical) |
| **format** | `dart format --set-exit-if-changed` exited 1; "would change" files | run `dart format .` (a subset of #41) | yes |
| **test-flake** | a test passes on re-run; timeouts in one test; network/timing in test output | **retry the test once**; if it then passes, quarantine + file an issue | retry only |
| **version-solve** | `version solving failed`, `Because … depends on …` chain (pub) | **Build Doctor #37 family G** → pin one constraint in `pubspec.yaml` | pin only, no upgrades |
| **signing** | `keystore … not found`, `key.properties` missing, `SigningConfig … null` | **config CI secret/keystore decode** (skill 13 / #21) | NEVER auto-edit secrets |
| **timeout** | job killed at the runner limit; `The job running … has exceeded the maximum` | bump caches / split job / raise `timeout-minutes` (bounded) | yes, bounded |
| **network** | `Could not resolve`, `Connection reset`, maven/pub fetch failed, 5xx from a mirror | **re-run once** (transient); if persists, pin repo/mirror | re-run first |

**Classification precedence** when a log matches several: *signing/secrets* and *version-solve* are
diagnosed by Build Doctor but **never** healed by editing secrets — pin or configure only. *network*
and *test-flake* get **one** free re-run before any code change (they are often transient). *build*
and *lint* get a real fix on the first pass.

---

## 3. Routing to the fixers

For each classified family, hand off precisely — do not re-implement the fixer's logic here.

- **build / version-solve →** Invoke **Build Doctor (#37)**. Feed it `ci.log`. It returns a ranked
  cause + the exact file/edit. Apply **only** edits Build Doctor marks low-risk (a namespace add, a
  single-axis-in-a-set version bump from its matrix, a pin). If the diagnosis is "plugin bug" or
  "environment, not project," **do not edit** — escalate (that bucket is a human/upstream fix).
- **lint / format →** Invoke **Analyzer Auto-Fix (#41)**. Run its `analyze_fix.sh` loop. It applies
  the mechanical sweep and returns `CLEAN ✅` or a JUDGMENT list. If anything lands in JUDGMENT
  (e.g. `use_build_context_synchronously`, removing `dynamic`), **stop and escalate** — those are not
  auto-fixable per §41's rules.
- **test-flake →** Re-run the failing test in isolation
  (`flutter test path/to/foo_test.dart`). If it passes, the original failure was flaky: add the test
  to a quarantine list (or mark `@Tags(['flaky'])`) and **open an issue** rather than deleting it.
  Never silence a test that fails deterministically — that's a real regression, route it as a bug.
- **signing →** Do **not** put any secret in source. The fix is a CI-config change: confirm the
  keystore decode step and `key.properties` write from secrets exist (skill 13 §5 / #21 §3). If a
  secret is missing, **escalate** with the exact secret name to add — you cannot create secrets.
- **timeout →** Apply one bounded mitigation: enable/repair pub+Gradle caching, raise
  `timeout-minutes` by a sane increment, or split a monolithic job. Re-run. Don't chase the same
  timeout more than once.
- **network →** Re-run the run **once** (transient mirror/5xx). If it recurs, treat as a real
  resolution problem and route to Build Doctor family C (pin a repo, add a mirror).

---

## 4. Safety rails

These are non-negotiable. They are what makes "self-healing" safe to run unattended.

- **Never auto-merge.** Heals land as commits on the failing branch (or a `ci/self-heal/<run-id>`
  branch) and, at most, open a PR. A human merges. No `gh pr merge`, ever, from this loop.
- **Bounded attempts.** Hard cap `N = 3` fix attempts per run. After N, stop and escalate — never
  loop unbounded (same rule #41 enforces on its analyzer loop).
- **No secrets in source.** Signing/secret failures are configured, never committed. If a secret is
  absent, escalate with its name; do not invent or inline it.
- **Minimal, reviewable diffs.** One family, one focused commit. No opportunistic refactors riding
  along (mirrors #41's "keep auto-fix diffs reviewable").
- **No destructive git.** No force-push, no history rewrite, no deleting tests to make CI pass.
  Flaky tests are quarantined + issue-filed, not removed.
- **Honest gates.** Green means the re-run actually passed (`gh run watch --exit-status` returned 0),
  not "probably fine." Report only what the run proves.
- **Escalate with a summary**, always — even on success report what healed it. On give-up, produce
  [`templates/heal_report.md`](templates/heal_report.md): failure class, action taken, attempts,
  and the precise human next-step.

---

## 5. Escalation & reporting

Whether the loop ends green or gives up, emit the report from
[`templates/heal_report.md`](templates/heal_report.md):

1. **Failure class** — the family (or families, in peel order) from §2.
2. **Action taken** — which fixer/action ran each attempt and the resulting diff/commit.
3. **Attempts** — `n / N`, with the outcome of each re-run.
4. **Result** — `HEALED ✅` (run green) or `ESCALATED` with the exact human next-step (e.g. "add
   secret `ANDROID_KEYSTORE_BASE64`", "plugin `foo` is namespace-less — pin or report upstream",
   "lint `use_build_context_synchronously` needs a `mounted` guard — judgment call").

Escalate **immediately** (don't burn attempts) when: Build Doctor classifies it as a plugin/upstream
or environment bug; #41 returns a JUDGMENT lint; a required secret is missing; or a test fails
deterministically (a real regression, not a flake). Post the report as a PR/issue comment — see
[`templates/self_heal.yaml`](templates/self_heal.yaml) for the workflow that does this automatically.

## 6. The unattended workflow

[`templates/self_heal.yaml`](templates/self_heal.yaml) → `.github/workflows/self-heal.yaml` runs on
`workflow_run` **completed + conclusion == failure** of your CI workflow. It downloads the failed
run's logs, runs Build Doctor's `diagnose.py` over them, and **posts the diagnosis as an issue/comment**
(the `gh` write steps are commented out so a human opts in before the bot writes to the repo). It is
diagnosis-and-notify by default — actual auto-commit fixes stay an explicit, opt-in step, consistent
with the no-auto-merge rail.

## 7. How it pairs with #32 (Autonomous Maintenance)

**#32 is the scheduler; #33 is the reactor.** #32 runs proactive health sweeps (dependency bumps,
periodic `flutter analyze`/test, stale-branch checks) on a cadence and **opens PRs**; when one of
*its* PRs turns CI red, **#33 heals that run** with this loop. Division of labor: #32 decides *what
maintenance to attempt and when*; #33 decides *how to recover a specific failed run*. Both share the
same fixers (#37 build, #41 lint) and the same safety rails — bounded, no auto-merge, human-in-loop.

---

See the full taxonomy in [`templates/failure_taxonomy.md`](templates/failure_taxonomy.md), the
workflow in [`templates/self_heal.yaml`](templates/self_heal.yaml), the output shape in
[`templates/heal_report.md`](templates/heal_report.md), and house style in
[`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).
