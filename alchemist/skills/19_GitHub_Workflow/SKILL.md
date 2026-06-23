---
name: GitHub Workflow
description: Set up repository hygiene and collaboration for a Flutter app — branching strategy, Conventional Commits, PR/issue templates, CODEOWNERS, a Flutter .gitignore, and review norms. Use when initializing a repo, fixing messy git history/process, or wiring the `.github/` folder before CI (stage 21) runs on PRs.
when_to_use: Trigger on "set up the repo", "add PR/issue templates", "what's our branching/commit convention", "add CODEOWNERS", "fix our .gitignore", or at pipeline stage 19. For automated build/test pipelines use stage 21 (CICD); for release tagging/store upload use stage 22 (Deployment).
---

# GitHub Workflow

Stage **19** of the [pipeline](../../references/PIPELINE.md). You make the repository safe to collaborate in: a clear branching model, machine-readable commit messages, templates that force good PRs and issues, ownership rules, branch protection, and a correct Flutter `.gitignore`. Everything here serves the house style in [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).

**Exit gate:** PR/issue templates live; commit & branch conventions set. (Branch protection on `main` requires CI from stage 21 — wire the requirement here, enforce it once 21 lands.)

This stage is **process + config files**, not feature code. You scaffold the `.github/` folder, drop in a `.gitignore`, document the conventions, and (optionally) add commit linting. Then you confirm the team can branch, commit, and open a PR the same way every time.

## First actions when invoked

1. **Check what exists.** Look for `.github/`, `.gitignore`, `CODEOWNERS`, and existing branch protection. Don't clobber a customized `.gitignore` — diff against the template and merge.
2. **Pick the branching model** with the user (default: trunk-based / GitHub Flow, below).
3. **Copy the templates** from `templates/` into the repo root (`.gitignore`) and `.github/` (PR template, issue templates, CODEOWNERS), adjusting org/team handles.
4. **Document the commit convention** (copy `templates/commit_convention.md` into the repo or link it from the README produced in stage 18).
5. **Set branch protection** on `main` (manual, GitHub UI/CLI — see below).

## Branching model

Default to **GitHub Flow / trunk-based with short-lived feature branches**. `main` is always releasable; CI is green on `main` at all times.

- Branch off `main`, do the work, open a PR, merge back, delete the branch. **Keep branches short-lived** (hours to a couple of days) to minimize merge pain.
- One logical change per branch. If it's getting big, split it.
- **Naming** (`type/short-kebab-summary`, optionally with an issue number):

  | Prefix | For | Example |
  |---|---|---|
  | `feat/` | new feature | `feat/oauth-login` |
  | `fix/` | bug fix | `fix/142-null-token-crash` |
  | `chore/` | tooling, deps, config | `chore/bump-riverpod` |
  | `refactor/` | no behavior change | `refactor/extract-result` |
  | `docs/` | docs only | `docs/adr-supabase` |
  | `test/` | tests only | `test/login-golden` |

- **Merge strategy:** prefer **Squash and merge** so `main` history is one clean Conventional Commit per PR — the PR title becomes the commit, which feeds changelogs and semver in stages 21/22. Avoid merge commits unless the team wants full branch history.
- If a project needs release stabilization windows, add a `release/x.y` branch model and say so in the README; otherwise keep it simple.

## Conventional Commits

Use [Conventional Commits](https://www.conventionalcommits.org/) so history is machine-readable. This is what lets stages **21 (CICD)** and **22 (Deployment)** auto-generate changelogs and derive **semver** bumps from commit types, then tie versions to **release tags** (`vX.Y.Z`).

Format: `type(scope): subject`

- **Types:** `feat` (→ minor), `fix` (→ patch), `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.
- **Scope** (optional) = the feature or area, matching the `features/<feature>` or `core/` layout from CONVENTIONS §2: `feat(auth): ...`, `fix(network): ...`, `chore(deps): ...`.
- **Breaking changes** → append `!` after the type/scope **and** add a `BREAKING CHANGE:` footer. This forces a **major** bump.
- **Subject:** imperative mood, lower-case, no trailing period, ≤ 72 chars.
- Reference issues in the footer: `Closes #142`.

```text
feat(auth)!: replace session cookie with JWT

Login now returns a JWT; the old /session endpoint is gone.

BREAKING CHANGE: clients must send Authorization: Bearer <token>.
Closes #87
```

Full cheat sheet + commitlint config: [`templates/commit_convention.md`](templates/commit_convention.md).

## Pull request practice

- **Small PRs.** A reviewer should grasp the whole change in one sitting. Big features land as a stack of small PRs behind a flag, not one mega-PR.
- **Every PR uses the template** ([`templates/.github/pull_request_template.md`](templates/.github/pull_request_template.md)): summary, what changed, how it was tested, screenshots for UI, and a checklist.
- **Link the issue** it closes (`Closes #NN`) so the board stays in sync.
- **CI must be green.** PRs cannot merge with a failing or pending required check (the analyze + test jobs from stages 20/21).
- **At least one approving review** before merge. The author never approves their own PR.
- The PR **checklist is non-negotiable** and must include: `flutter analyze` clean (zero warnings under `very_good_analysis`), tests added/updated and passing, both light + dark verified for UI changes, public APIs documented, no stray `TODO` without an issue link — i.e. the CONVENTIONS §7 Definition of Done.
- Resolve every review thread before merging; reviewers re-request changes rather than approving with unresolved blockers.

## Issue templates

Ship two, under `templates/.github/ISSUE_TEMPLATE/`:

- **Bug report** ([`bug_report.md`](templates/.github/ISSUE_TEMPLATE/bug_report.md)) — repro steps, expected vs actual, device/OS/Flutter version, logs/screenshots.
- **Feature request** ([`feature_request.md`](templates/.github/ISSUE_TEMPLATE/feature_request.md)) — problem, proposed solution, alternatives, scope.

Both carry default labels (`bug` / `enhancement`) so triage is automatic.

## CODEOWNERS

[`templates/.github/CODEOWNERS`](templates/.github/CODEOWNERS) auto-requests reviews from the right people per path. Replace the placeholder handles with real GitHub users/teams. Path patterns mirror CONVENTIONS §2 (e.g. `lib/app/theme/` → design owner, `lib/core/network/` → backend owner, `.github/` → maintainers). With branch protection's "require review from Code Owners", a CODEOWNERS match becomes a required approval.

## Protecting `main`

Configure on GitHub (Settings → Branches → branch protection rule for `main`), or via CLI:

```bash
gh api -X PUT repos/:owner/:repo/branches/main/protection \
  -f required_status_checks='{"strict":true,"contexts":["analyze","test"]}' \
  -F enforce_admins=true \
  -f required_pull_request_reviews='{"required_approving_review_count":1,"require_code_owner_reviews":true}' \
  -f restrictions=null
```

Enable: **require a PR before merging**, **require status checks** (`analyze`, `test` from stages 20/21 — once those jobs exist), **require ≥1 approving review**, **require Code Owner review**, **require branches up to date**, **require conversation resolution**, and **block force-pushes / deletions**. Until stage 21 defines the check names, set up the rule and add the contexts when CI is live.

## Optional: commit linting & hooks

For teams that want the convention enforced automatically (recommended once the team is >1):

- **commitlint** + `@commitlint/config-conventional` validates commit messages in CI and locally.
- **lefthook** (Dart-friendly, single binary) or **husky** runs git hooks: a `commit-msg` hook to run commitlint, and a `pre-commit`/`pre-push` hook to run `dart format --set-exit-if-changed .` and `flutter analyze`.

Sample `lefthook.yml` and the commitlint config live in [`templates/commit_convention.md`](templates/commit_convention.md). Keep hooks fast — push the heavy test run to CI, not the local hook.

## Definition of done for this stage

- `.gitignore` correct for Flutter/Dart/Android (no secrets, no build output, generated Dart **kept**).
- `.github/` has the PR template, both issue templates, and CODEOWNERS with real handles.
- Branching + commit conventions documented (README link or `commit_convention.md` in repo).
- Branch protection rule on `main` created (required checks wired or queued for stage 21).
- Optional: commitlint + hooks installed if the team opted in.

When all boxes are checked, report the gate green to the orchestrator and hand off to stage 20 (Testing) / 21 (CICD), which consume these checks.
