---
name: Changelog Generator
description: Generate human-readable changelogs and Play Store "What's New" text from Conventional Commits between two git tags — group by type (feat, fix, perf, docs), rewrite in user-facing tone, and output both a markdown changelog and a Play-ready summary.
when_to_use: Trigger on "generate changelog", "what's new for this release", "changelog since last release", "write release notes", or before any Play Store submission that needs a changelog entry.
---

# Changelog Generator

You produce two artifacts from the git history between two tags:

1. **Full changelog** (`CHANGELOG.md` entry) — structured, developer-readable, grouped by Conventional Commit type.
2. **Play Store "What's New"** (`fastlane/metadata/android/en-US/changelogs/<versionCode>.txt`) — ≤500 chars, user-facing tone, highlights only.

House style: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md). This skill feeds [stage 22 Deployment](../22_Deployment/SKILL.md) and [stage 64 App_Store_Optimization](../64_App_Store_Optimization/SKILL.md).

---
## Step 1 — Determine the tag range

Find the relevant tags:

```bash
git tag --sort=-creatordate | head -5
```

- If the user specifies a version (e.g., "v1.3.0"), use `v1.2.0..v1.3.0` (the prior tag as base).
- If unspecified, use the **two most recent tags** — `<previous_tag>..<latest_tag>`.
- If there is only one tag (first release), use the full history from the first commit.
- If no tags exist, use a date range or the user's specified commit range.

Confirm the range with the user before proceeding.

---
## Step 2 — Collect commits

Run the changelog script:

```bash
python3 "${CLAUDE_SKILL_DIR}/scripts/changelog.py" \
  --from <previous_tag> --to <latest_tag> \
  --repo <path_to_git_repo>
```

The script does:
1. Reads commits between the two tags via `git log --oneline --no-merges`.
2. Parses Conventional Commit prefixes (`feat:`, `fix:`, `perf:`, `docs:`, `refactor:`, `test:`, `ci:`, `chore:`, `style:`, `build:`).
3. Groups commits by type.
4. Strips the prefix for the user-facing version.
5. Outputs a structured markdown changelog + a Play Store "What's New" summary.

If the script is unavailable (stdlib Python), do the same manually with `git log`.

---
## Step 3 — Review and polish

The script produces a draft. Review it:

### Full changelog (CHANGELOG.md)

- **Group order:** Features → Bug Fixes → Performance → Other.
- **Breaking changes** (commits with `!` or `BREAKING CHANGE:` footer) go in a separate, prominent section at the top.
- **Scope:** if commits use scopes (`feat(auth):`), group by scope within each type.
- **Tone:** third person, past tense. "Added dark mode support" not "Add dark mode".
- **Link:** if the project has issue tracking, link issue numbers in the commit messages.

### Play Store "What's New" (≤500 chars)

- **User-facing only:** skip `docs`, `ci`, `chore`, `test`, `refactor`, `style` — these mean nothing to a user.
- **Benefit-first:** translate technical commits into user benefits:
  - `feat: add dark mode toggle` → "Dark mode is here! Switch between light and dark themes in Settings."
  - `fix: crash on Android 6 when opening camera` → "Fixed a crash when opening the camera on older devices."
  - `perf: lazy-load image carousel` → "The app launches faster and scrolls more smoothly."
- **3-5 bullet points max.** Users scan, they don't read. Lead with the most exciting feature.
- **No technical jargon:** no "refactored", "migrated to Riverpod 2.5", "upgraded Gradle".

---
## Step 4 — Write the output files

Write the artifacts:

1. **Full changelog** — prepend to the project's `CHANGELOG.md` (create if missing), using the Keep a Changelog format.
2. **Play Store "What's New"** — write to `fastlane/metadata/android/en-US/changelogs/<versionCode>.txt`.
3. **Per-locale variants** — if localization is active (skill 50), produce translated "What's New" for each locale directory.

---
## Example

Given a tag range `v1.2.0..v1.3.0` with commits:

```
feat: add dark mode
feat(auth): biometric login
fix: crash on null profile image
fix(offline): stale data after sync
perf: reduce main thread work on startup
docs: update README with screenshots
```

### Full changelog entry
```markdown
## [1.3.0] — 2026-06-23

### Features
- **Auth:** Added biometric login (fingerprint + face unlock).
- Added dark mode — switch between light and dark themes in Settings.

### Bug Fixes
- Fixed a crash when loading profiles without an avatar image.
- **Offline:** Fixed stale data displaying after background sync.

### Performance
- Reduced startup time by deferring non-critical initialization.
```

### Play Store "What's New"
```
Dark mode is here! Switch between light and dark in Settings.
Unlock the app with your fingerprint or face — biometric login is live.
We fixed a crash with missing profile images and an issue where offline data wasn't refreshing.
The app now launches faster.
```

---
## Cross-references

- **22 Deployment** — consumes the "What's New" text for Play Console upload.
- **64 App_Store_Optimization** — the listing optimization; changelog style should match the description tone.
- **50 Localization_i18n** — if changelogs need translation for non-English locales.

The script at [`scripts/changelog.py`](scripts/changelog.py) automates commit collection and grouping. Run it first, then polish.
