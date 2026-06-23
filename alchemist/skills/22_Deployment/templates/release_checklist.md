# Pre-Release Checklist — Play Store (Stage 22)

Run before promoting past internal testing. A box is checked only when it's objectively true.
Anything unchecked is a blocker, not a "later". Pairs with the skill 24 launch gate.

## Version & build
- [ ] `pubspec.yaml` `version: x.y.z+build` bumped (semver name reflects the change).
- [ ] `versionCode` strictly **greater** than the highest code already on the target track.
- [ ] In CI, `versionCode` is auto-incremented/monotonic (skill 21) — not hand-edited.
- [ ] Release notes / changelog written and mapped to this `versionCode`.

## Signing
- [ ] Enrolled in **Play App Signing** (Google holds the app signing key).
- [ ] **Upload keystore** exists, is backed up securely, and is **not in git**.
- [ ] `key.properties` present locally / generated in CI; **not committed**.
- [ ] `signingConfig signingConfigs.release` wired — build is upload-signed, **not** debug-signed.

## Build artifact
- [ ] Built with `flutter build appbundle --release` → a signed `.aab` (not an APK).
- [ ] Built with `--obfuscate --split-debug-info=build/symbols`.
- [ ] **Symbol map** (`build/symbols`) archived for this `versionCode` (skill 23 deobfuscation).
- [ ] R8 `mapping.txt` archived / uploaded to Play for native deobfuscation.
- [ ] `minifyEnabled true` + `shrinkResources true` on for release.
- [ ] `targetSdkVersion` meets Play's current minimum target API level; `minSdk 23`.
- [ ] `.aab` verified installable locally (bundletool) or via internal track.

## Store listing
- [ ] Title (≤30), short (≤80), and full (≤4000) descriptions complete.
- [ ] Hi-res icon 512×512 + feature graphic 1024×500 uploaded.
- [ ] ≥2 phone screenshots (tablet shots if tablets are supported — skill 17).
- [ ] "What's new" changelog filled in for this release.

## Compliance (Play hard gates)
- [ ] **Data safety** form complete and matches actual app behavior + privacy policy.
- [ ] **Content rating** (IARC) questionnaire submitted.
- [ ] Privacy policy URL set; ads declaration + permissions justified.
- [ ] Target audience / news / financial / COVID declarations as applicable.

## Verification
- [ ] **Pre-launch report** reviewed; no blocking crashes/ANRs/security findings.
- [ ] Smoke-tested on the **internal track** by a real tester (the stage exit gate).
- [ ] Crash/analytics (skill 23) confirmed reporting from a release build.

## Rollout & rollback
- [ ] **Staged rollout** plan written (e.g. 10% → 50% → 100% with soak windows).
- [ ] Metrics to watch defined (crash-free rate, ANRs, ratings) and who watches them.
- [ ] **Rollback plan**: halt rollout on regression; fix-forward with a higher `versionCode`
      (Play cannot un-publish a versionCode).
