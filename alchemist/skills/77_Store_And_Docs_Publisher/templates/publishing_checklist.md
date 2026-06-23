# Publishing Bundle Checklist

Run before opening Play Console. Every item must pass.

## Documents

- [ ] `README.md` — current, badges, screenshots slot, setup instructions
- [ ] `docs/ARCHITECTURE.md` — layers, features, data flow
- [ ] `docs/adr/` — key decisions captured (#63)
- [ ] `doc/api/` — generated via `dart doc`, zero warnings
- [ ] `CONTRIBUTING.md` — branch/commit/PR conventions (#19)

## Store copy

- [ ] `publish/play_short_description.txt` — ≤80 characters, one line, includes primary keyword
- [ ] `publish/play_full_description.txt` — ≤4000 characters, features + benefits, no markdown, includes keywords naturally
- [ ] `publish/play_whats_new.txt` — ≤500 characters, user-facing tone, per locale

## Store images

- [ ] `publish/play_feature_graphic.png` — 1024×500 px, ≤1 MB, 24-bit PNG or JPEG
- [ ] `publish/play_phone_1.png` through `play_phone_8.png` — min 320 px wide, ≤8 MB each, real app UI, no status bar
- [ ] Tablet 7": `publish/play_tablet_7in_1.png` … (optional)
- [ ] Tablet 10": `publish/play_tablet_10in_1.png` … (optional)
- [ ] `publish/play_icon.png` — 512×512 px, 32-bit PNG with alpha

## Privacy & compliance

- [ ] `publish/privacy_policy.md` — all data types declared, consent described, user rights
- [ ] Data Safety form answers match the actual SDKs/permissions (#59 scan)
- [ ] Content rating questionnaire answers ready

## Release readiness

- [ ] Version bumped (`pubspec.yaml` + `build.gradle`)
- [ ] Signed AAB built and tested on internal track (#22)
- [ ] Obfuscation symbols archived (#22)
- [ ] Crash dashboard shows no new spikes on internal (#23)
- [ ] Staged rollout % set, rollback plan documented (#22)
- [ ] All copy localized per supported locale (#50)

## Optional (higher conversion)

- [ ] Promo YouTube video URL
- [ ] A/B experiment configured for listing variants (#67)
- [ ] ASO keywords researched and embedded in descriptions (#64)
- [ ] Featured review slot requested

---

**Verdict:** [ ] SHIP / [ ] FIX (see blockers below)

Blockers (if any):
-
