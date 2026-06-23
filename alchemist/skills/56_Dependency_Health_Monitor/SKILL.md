---
name: Dependency Health Monitor
description: Score every pub.dev dependency on maintenance, popularity, null-safety/Dart-3 support, known vulnerabilities, abandonment risk, size impact, and breaking-change risk, then emit a health report + prioritized upgrade plan. Use when the user asks "are my dependencies healthy/safe/up to date", before a release, during dependency review, or when picking between packages.
when_to_use: Trigger on "check my dependencies", "audit pubspec", "is package X safe/maintained/abandoned", "what should I upgrade", "any vulnerable packages", "dependency health report", or as a pre-release gate. For a single package recommendation use #57; for routine maintenance PRs hand off to #32.
---

# Dependency Health Monitor

You score the pub.dev dependencies of a Flutter/Android project and produce two
artifacts: a **health report** (per-package scorecard) and a **prioritized
upgrade plan**. Keep everything consistent with the house stack in
[`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md) — the
recommended replacements and "is this on-stack" judgements come from there.

This skill is read-only on the project: it never edits `pubspec.yaml`. It
**reports and recommends**. Acting on the plan (bumping versions, opening PRs)
is the job of **Maintenance Agent (#32)**; choosing a replacement package is
**Package Recommendation (#57)**; license/compliance follow-up is **#58**.

## First actions when invoked

1. **Locate the manifests.** Find `pubspec.yaml` (declared deps + version
   constraints) and `pubspec.lock` (resolved versions, incl. transitive) at the
   project root. If only one exists, use it and note the limitation.
2. **Read the references** ([`CONVENTIONS.md`](../../references/CONVENTIONS.md))
   so you can flag off-stack or duplicate packages.
3. **Run the data collection** — prefer the script (below); it does the network
   work, rate-limits, and degrades gracefully offline.
4. **Score, tier, and report** using the rubric, then build the upgrade plan.

## Direct vs transitive — read both files

- **`pubspec.yaml`** lists what *you* chose and the *constraints* you accepted
  (e.g. `dio: ^5.4.0`). These are the packages you own and can upgrade.
- **`pubspec.lock`** is the resolved graph: every package actually pulled in,
  with its exact version and a `dependency:` field:
  - `direct main` / `direct dev` → declared by you (you control these).
  - `transitive` → pulled in by a dependency (you fix these by upgrading the
    parent, not by adding a direct dep — unless a vuln forces a `dependency_overrides`).
- Score **direct** deps fully. For **transitive** deps, only surface them when
  they carry an advisory or are clearly abandoned (you can't bump them directly,
  but you may need an override or a parent upgrade).

## Data sources

All HTTP, JSON-only, no auth. The script (`scripts/dep_health.py`) handles these;
this section documents what each returns so you can interpret results or query
manually.

| Source | Endpoint | Gives you |
|---|---|---|
| pub.dev package | `https://pub.dev/api/packages/<name>` | latest version, all versions + `published` timestamps (→ cadence), publisher |
| pub.dev score | `https://pub.dev/api/packages/<name>/score` | `grantedPoints`/`maxPoints` (pub points), `likeCount`, `popularityScore`, `downloadCount30Days`, `tags` (incl. `is:null-safe`, `is:dart3-compatible`) |
| OSV advisories | `POST https://api.osv.dev/v1/query` body `{"package":{"ecosystem":"Pub","name":"<name>"},"version":"<v>"}` | known vulnerabilities for the resolved version |

Politeness: serial requests with a small delay, a descriptive User-Agent, and a
short timeout. On any network failure **skip that package with a note** — never
fail the whole run.

## The health rubric (summary)

Full rubric with weights/thresholds: [`templates/health_rubric.md`](templates/health_rubric.md).

Seven dimensions, each scored then weighted into a 0–100 health score:

| Dimension | Signal | Source |
|---|---|---|
| Maintenance | days since last publish + release cadence | package API timestamps |
| Popularity | likes, pub points, popularity %, 30-day downloads | score API |
| Modern-Dart | `is:null-safe` + `is:dart3-compatible` tags | score API tags |
| Vulnerabilities | open OSV advisories for resolved version | OSV |
| Abandonment risk | last publish > 18mo AND low popularity AND/or archived | derived |
| Size impact | heuristic (heavy native/asset packages flagged) | CONVENTIONS + tags |
| Breaking-change risk | semver gap current→latest (major bump = high) | lock vs latest |

Tiers from the weighted score: **Healthy (≥75) · Warn (50–74) · Risk (<50)**,
with hard overrides: any open advisory or `discontinued` package is **Risk**
regardless of score.

## Reading `flutter pub outdated`

`flutter pub outdated` complements the API data — it computes the *resolvable*
versions given your whole constraint set, which the API can't know:

- **Current** = what's in the lock. **Upgradable** = newest allowed by your
  constraints (a `pub get`/`pub upgrade` reaches it). **Resolvable** = newest
  reachable if you also relax sibling constraints. **Latest** = newest on pub.dev.
- If *Upgradable* < *Latest*, your constraint (or a sibling) is pinning you back —
  that's a constraint to loosen, not a missing release.
- Run `flutter pub outdated --json` to merge cleanly with the script's output.

## Upgrade-plan method

For each direct dep with a newer version, classify by the semver gap
(current → latest) and produce an ordered plan:

1. **Security first.** Any package with an open OSV advisory → top of the plan,
   even if the fix is a major bump. Patch to the lowest non-vulnerable version.
2. **Patch / minor = safe.** `x.y.Z` or `x.Y.z` bumps: batch them. Expect no API
   breaks; verify with `flutter pub upgrade` + `flutter analyze` + tests.
3. **Major = review.** `X.y.z` bumps: one PR per package. **Read the
   CHANGELOG / migration guide**, list breaking changes, estimate effort, and
   only then schedule. Never batch majors.
4. **Abandoned → replace, don't bump.** If a package is Risk for abandonment,
   don't plan an upgrade — hand to **#57** to find an on-stack replacement.
5. **Order:** security → low-effort safe batch → majors by value/effort → replacements.

Each plan item names: package, current→target, change class, action, owner skill.

## How this gates releases & triggers maintenance

- **Release gate (#24):** report **must** show zero open advisories on direct
  deps and no Risk-tier direct dep without a tracked follow-up. A failing gate
  blocks the release until #32 acts.
- **Triggers #32 (Maintenance Agent):** the upgrade plan is the work queue —
  #32 opens the safe-batch PR and the per-major PRs.
- **Feeds #57 (Package Recommendation):** every "replace" recommendation is a
  request to #57 with the constraints (on-stack, null-safe, maintained).
- **Hands off to #58 (License/Compliance):** any new/changed license surfaced
  during planning goes to #58 before merge.

## Running the collector

```bash
python "${CLAUDE_SKILL_DIR}/scripts/dep_health.py" pubspec.yaml          # table
python "${CLAUDE_SKILL_DIR}/scripts/dep_health.py" pubspec.lock --osv     # + advisories
python "${CLAUDE_SKILL_DIR}/scripts/dep_health.py" pubspec.yaml --json    # machine-readable
```

Flags: `--osv` (query OSV advisories), `--json` (emit JSON, not a table),
`--include-transitive` (score transitive deps too), `--delay <s>` (rate-limit,
default 0.3). The script reads `pubspec.yaml` *or* `pubspec.lock`; lock gives
exact resolved versions (better for OSV).

Then fill [`templates/health_report.md`](templates/health_report.md) from the
output and the rubric, and write the prioritized upgrade plan at the bottom.

## Output discipline

- Score from **data**, not vibes — cite last-publish dates, points, advisory IDs.
- Be explicit about what was **skipped** (network failures, transitive deps).
- Separate **direct** (actionable now) from **transitive** (needs parent bump).
- Every Risk tier ends with a concrete next action and the owning skill (#32/#57/#58).

See the rubric in [`templates/health_rubric.md`](templates/health_rubric.md) and
the report shape in [`templates/health_report.md`](templates/health_report.md).
