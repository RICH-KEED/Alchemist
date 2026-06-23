<!--
PR template (stage 19). Keep PRs small and focused.
The checklist mirrors the Definition of Done in references/CONVENTIONS.md §7.
-->

## Summary

<!-- One or two sentences: what does this PR do and why? -->

Closes #<!-- issue number -->

## Changes

<!-- Bullet the notable changes. Group by feature/area (matches features/<feature> or core/). -->

-
-

## Testing

<!-- How did you verify this? Commands run, scenarios covered, devices used. -->

- [ ] `flutter analyze` is clean (zero warnings under `very_good_analysis`)
- [ ] `flutter test` passes (unit / widget / golden as relevant)
- Manual verification:

## Screenshots / recordings

<!-- Required for any UI change. Show light AND dark where relevant. Delete if not a UI change. -->

| Before | After |
|--------|-------|
|        |       |

## Checklist

- [ ] Conventional Commit title (`type(scope): subject`) — squash-merge uses it
- [ ] PR is small and scoped to one logical change
- [ ] Linked the issue this closes
- [ ] `flutter analyze` clean; `dart format` applied
- [ ] Tests added/updated and passing
- [ ] All four async states handled where data is shown (loading · data · empty · error)
- [ ] Light + dark themes verified for UI changes
- [ ] Public APIs have doc comments
- [ ] No stray `TODO` without a linked issue
- [ ] Docs/ADRs updated if behavior or architecture changed (stage 18)
- [ ] Breaking changes called out here and in the commit footer (`BREAKING CHANGE:`)
