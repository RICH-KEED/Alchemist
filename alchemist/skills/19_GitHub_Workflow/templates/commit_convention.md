# Conventional Commits — cheat sheet

We use [Conventional Commits](https://www.conventionalcommits.org/) so history is machine-readable and stages 21 (CICD) / 22 (Deployment) can auto-build changelogs and derive semver bumps tied to release tags.

## Format

```text
type(scope): subject

[optional body — what & why, wrap at 72]

[optional footer(s): BREAKING CHANGE: ..., Closes #NN]
```

- **Subject:** imperative mood, lower-case, no trailing period, ≤ 72 chars. ("add", not "added"/"adds".)
- **Scope** (optional): the feature/area, matching the `features/<feature>` or `core/` layout — e.g. `auth`, `network`, `theme`, `deps`.

## Types and their semver effect

| Type | Use for | Version bump |
|---|---|---|
| `feat` | a new feature | **minor** |
| `fix` | a bug fix | **patch** |
| `perf` | performance improvement | patch |
| `refactor` | code change, no behavior change | none |
| `docs` | docs only | none |
| `style` | formatting/whitespace, no code change | none |
| `test` | adding/fixing tests | none |
| `build` | build system / dependencies | none |
| `ci` | CI config & scripts | none |
| `chore` | tooling, housekeeping | none |
| `revert` | reverts a previous commit | per reverted change |

## Breaking changes → major bump

Append `!` after the type/scope **and** add a `BREAKING CHANGE:` footer:

```text
feat(auth)!: replace session cookie with JWT

BREAKING CHANGE: clients must send Authorization: Bearer <token>.
```

## Examples

```text
feat(auth): add Google OAuth sign-in
fix(network): map DioException timeouts to TimeoutFailure
refactor(core): extract Result into core/error
docs(adr): record decision to use Supabase backend
chore(deps): bump riverpod to 2.5.1
test(login): add golden test for dark theme
perf(list): cache thumbnails to cut scroll jank
revert: feat(auth): add Google OAuth sign-in

This reverts commit a1b2c3d.
```

## Optional: enforce with commitlint

`package.json` (root, dev tooling only):

```json
{
  "devDependencies": {
    "@commitlint/cli": "^19.0.0",
    "@commitlint/config-conventional": "^19.0.0"
  }
}
```

`commitlint.config.js`:

```js
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'scope-enum': [1, 'always', ['auth', 'network', 'theme', 'core', 'deps', 'ci', 'router']],
    'subject-case': [2, 'always', 'lower-case'],
    'header-max-length': [2, 'always', 72],
  },
};
```

## Optional: git hooks with lefthook

`lefthook.yml` (root) — keep hooks fast; heavy tests stay in CI:

```yaml
commit-msg:
  commands:
    commitlint:
      run: npx --no -- commitlint --edit {1}

pre-commit:
  parallel: true
  commands:
    format:
      glob: "*.dart"
      run: dart format --set-exit-if-changed {staged_files}
    analyze:
      run: flutter analyze

pre-push:
  commands:
    test:
      run: flutter test
```

Install: `dart pub global activate lefthook` (or `npm i -D lefthook`) then `lefthook install`.
Prefer **husky** instead? Put the same commands in `.husky/commit-msg` and `.husky/pre-commit`.
