# Changelog Example

## Expected input (commits between v1.2.0..v1.3.0)

```
abc123 feat: add dark mode
def456 feat(auth): biometric login
ghi789 fix: crash on null profile image
jkl012 fix(offline): stale data after sync
mno345 perf: reduce main thread work on startup
pqr678 docs: update README with screenshots
stu901 chore: bump dependencies
vwx234 refactor: extract form validation to shared widget
yz0123 test: add widget tests for settings screen
345678 build: upgrade compileSdk to 34
```

## Generated full changelog (CHANGELOG.md entry)

```markdown
## [1.3.0] — 2026-06-23

### Features
- Added dark mode — switch between light and dark themes in Settings.
- **Auth:** Added biometric login (fingerprint + face unlock).

### Bug Fixes
- Fixed a crash when loading profiles without an avatar image.
- **Offline:** Fixed stale data displaying after background sync.

### Performance
- Reduced main thread work on startup.

### Documentation
- Updated README with screenshots.

### Chores
- Bumped dependencies.

### Refactoring
- Extracted form validation to a shared widget.

### Testing
- Added widget tests for the settings screen.

### Build System
- Upgraded compileSdk to 34.
```

## Generated Play Store "What's New" (whats_new.txt)

```
Dark mode is here! Switch between light and dark in Settings.
Unlock the app with your fingerprint or face — biometric login is live.
Fixed a crash when loading profiles without an avatar image.
Fixed stale data displaying after background sync.
Improved app startup performance.
```

## Edge cases handled

- **No conventional prefix:** commits without a prefix go under "Other".
- **Breaking changes:** commits with `!` or `BREAKING CHANGE:` footer get a dedicated "Breaking Changes" section at the top, and a **[BREAKING]** flag in their type section.
- **Single tag / first release:** use `--from $(git rev-list --max-parents=0 HEAD)` for the root commit.
- **0 user-facing commits:** Play "What's New" should say "Bug fixes and performance improvements." (the standard fallback).
- **>500 char limit:** Play summary truncates with "…and more improvements."
