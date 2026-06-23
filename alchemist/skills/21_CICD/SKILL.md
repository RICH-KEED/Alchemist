---
name: CICD
description: Automate build, test, sign, and distribute for a Flutter/Android app. Use when wiring GitHub Actions (analyze, test with coverage, build a signed AAB), adding Fastlane lanes, choosing Codemagic as an alternative, or injecting a signing keystore from CI secrets. Stage 21 of the pipeline.
when_to_use: Trigger on "set up CI", "GitHub Actions for Flutter", "build and test on every PR", "sign the AAB in CI", "release on tag", "Fastlane lane", "Codemagic", or "automate the build". Pairs with skill 13 (secrets/signing) and hands the actual store upload to skill 22 (Deployment).
---

# CICD — Automate Build, Test, Sign, Distribute (Stage 21)

Turn the repo into a pipeline: every PR is **verified** (format, analyze, test), every tag is
**released** (signed AAB built, debug symbols archived, handed to the store). The keystore and all
credentials live in **CI secrets only** — never in source. House style:
[`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).

This stage consumes the secrets handling from **skill 13** (it owns "no secret in the repo"; CI is
where they get injected) and the coverage gate from **skill 20** (Testing). The final store upload —
`fastlane supply` to Play tracks — belongs to **skill 22** (Deployment); CI here builds and signs
the artifact and stops at "ready to ship".

**Exit gate:** *build + test + sign automated on push/tag.*

---

## 1. The pipeline stages

CI runs the same five stages locally and in the cloud, in order — a failure short-circuits the rest:

```
lint + format  →  analyze  →  test + coverage  →  build  →  sign  →  distribute
   (verify)        (verify)      (verify)         (release path)      (skill 22)
```

| Stage | Command | Gate |
|---|---|---|
| Format | `dart format --output=none --set-exit-if-changed .` | no unformatted files |
| Analyze | `flutter analyze --fatal-infos` | zero issues under `very_good_analysis` |
| Test | `flutter test --coverage` | tests pass; coverage gate met (skill 20) |
| Build | `flutter build apk` (PR) / `appbundle` (tag) | artifact produced |
| Sign | keystore from secret → `key.properties` → `signingConfigs` | release AAB is signed |
| Distribute | `fastlane supply` to internal track | uploaded (skill 22) |

**PR/push = verify** (format, analyze, test, debug build — no signing).
**Tag `v*` = release** (build signed AAB, archive symbols, hand to store). Keep these in two
workflows so a PR never needs signing secrets. See `templates/ci.yaml` and `templates/release.yaml`.

## 2. GitHub Actions — the verify workflow

[`templates/ci.yaml`](templates/ci.yaml) → `.github/workflows/ci.yaml`. Triggers on PRs and pushes
to `main`. Core moves:

- **Set up Flutter** with [`subosito/flutter-action`](https://github.com/subosito/flutter-action),
  pinned to the **stable** channel and a fixed version, with `cache: true` so the SDK is cached.
- **Cache pub and Gradle** so warm runs are fast:
  ```yaml
  - uses: actions/cache@v4
    with:
      path: |
        ~/.pub-cache
        ~/.gradle/caches
        ~/.gradle/wrapper
      key: ${{ runner.os }}-pub-gradle-${{ hashFiles('**/pubspec.lock', '**/gradle-wrapper.properties') }}
  ```
- **Run the verify stages** in order: `flutter pub get` → `dart format --set-exit-if-changed` →
  `flutter analyze` → `flutter test --coverage`.
- **Upload coverage** (`coverage/lcov.info`) as an artifact (or push to Codecov) so the trend is
  visible. The coverage *threshold* is enforced by skill 20's job — CI just runs and reports it.
- **Build a debug APK** (`flutter build apk --debug`) as a smoke test that the Android build wires
  up. No signing here — a debug APK is signed with the auto-generated debug key.

**Matrix** when you support multiple Flutter versions or need to guard an upcoming SDK:

```yaml
strategy:
  fail-fast: false
  matrix:
    flutter: ['3.x.x', 'stable']   # pin one, track the channel on another
```

Keep the build on `ubuntu-latest` for Android (no macOS minutes needed unless you also build iOS).

## 3. Building a signed AAB in CI (the release path)

[`templates/release.yaml`](templates/release.yaml) → `.github/workflows/release.yaml`, triggered on
tags matching `v*`. The signing flow — full walkthrough in
[`templates/signing_setup.md`](templates/signing_setup.md):

1. **Store the keystore as a base64 secret.** Locally: `base64 -w0 upload-keystore.jks` → paste into
   the `ANDROID_KEYSTORE_BASE64` secret. The `.jks` file **never** enters the repo.
2. **In CI, decode it back to a file** under a path Gradle reads:
   ```yaml
   - run: echo "$ANDROID_KEYSTORE_BASE64" | base64 -d > android/app/upload-keystore.jks
     env:
       ANDROID_KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
   ```
3. **Write `android/key.properties`** from secrets (store/key passwords + alias). This file is
   `.gitignore`d (skill 13 §5) and only ever exists on the runner.
4. **`build.gradle` reads `key.properties`** for its `signingConfigs.release` — defensively, so a
   missing file falls back to debug signing instead of crashing. See `signing_setup.md`.
5. **Build with obfuscation** (matches skill 13 §4):
   ```bash
   flutter build appbundle --release \
     --obfuscate --split-debug-info=build/symbols
   ```
6. **Upload the AAB** (`build/app/outputs/bundle/release/app-release.aab`) and the
   **`build/symbols`** directory as artifacts. Symbols are needed to de-obfuscate crash traces
   (skill 23) — archive them per release, keep them out of the repo.

> Never echo a secret to logs. `base64 -d` from an `env:`-injected secret keeps it out of the
> command line; GitHub masks secret values in logs, but don't `cat` `key.properties` or print
> passwords.

## 4. Branch vs tag triggers (verify vs release)

| Trigger | Workflow | Does | Needs secrets? |
|---|---|---|---|
| `pull_request` / push to `main` | `ci.yaml` | format, analyze, test, debug build | No |
| tag `v*` (e.g. `v1.4.0`) | `release.yaml` | signed AAB + symbols + (commented) store upload | Yes (keystore + Play) |

Releasing on a **tag** (not every push to main) means version bumps are deliberate: you tag
`v1.4.0`, CI builds exactly that commit signed, and the artifact's name maps to a git ref. Derive
the build name/number from the tag if you want (`--build-name=${GITHUB_REF_NAME#v}`).

## 5. Fastlane for Android (lanes that wrap the build)

[`templates/Fastfile`](templates/Fastfile) defines three `android` lanes so the same commands run
locally and in CI:

- **`test`** — `flutter test --coverage` (the verify stage as a lane).
- **`build`** — `flutter build appbundle --release --obfuscate --split-debug-info`.
- **`deploy_internal`** — calls `build`, then `supply(track: 'internal', aab: ...)` to push to the
  Play Console **internal** track.

`fastlane supply` needs a **Google Play service-account JSON** (a CI secret, decoded at build time
like the keystore). **The store-upload mechanics, tracks, staged rollout, and metadata belong to
skill 22** — this skill provides the lane skeleton and the CI step that calls it; skill 22 owns the
release strategy. In `release.yaml` the `fastlane supply` step is **commented out** until skill 22
wires the service account and track policy.

## 6. Codemagic — the alternative

Codemagic is a Flutter-native CI/CD (managed macOS/Linux runners, a UI for signing and store
connections). Reach for it **instead of** GitHub Actions when:

- You need **iOS + Android** from one config and don't want to manage macOS runners / Apple
  code-signing yourself (Codemagic manages provisioning profiles and certificates).
- You want **managed Android signing** and Play/App Store publishing configured in a UI rather than
  hand-rolled secret decoding.
- The team prefers a Flutter-specific tool with build minutes included over GitHub-hosted runners.

Stay on **GitHub Actions** when CI already lives next to the code, you're Android-only, and you want
the pipeline as reviewable YAML in the repo (the default for this house). The stages are identical —
format → analyze → test → build → sign → distribute — only the runner and config syntax differ. If
you choose Codemagic, a `codemagic.yaml` mirrors `release.yaml`'s steps; signing still comes from
secrets, never source.

## 7. Secrets management (CI only, never plaintext)

This is skill 13's rule enforced in CI. Concretely:

- **GitHub encrypted secrets** for everything sensitive: `ANDROID_KEYSTORE_BASE64`,
  `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`,
  `PLAY_SERVICE_ACCOUNT_JSON`. Reference them only via `${{ secrets.NAME }}`.
- **Never** commit `*.jks` / `*.keystore` / `key.properties` / service-account JSON / `env/*.json`.
  `.gitignore` covers them (skill 13 §5); CI reconstructs them on the runner and they vanish with it.
- **Prefer OIDC over long-lived keys** where a provider supports it (e.g. GCP Workload Identity
  Federation for Play, or cloud uploads) — short-lived federated tokens via
  `permissions: id-token: write`, no static credential stored at all.
- **Scope and rotate.** Use environment-scoped secrets for the release environment; rotate the
  keystore passwords and service-account key on a schedule; never expose release secrets to
  PR/fork workflows (`pull_request_target` and forked PRs must not see them).
- **Don't print secrets.** No `cat key.properties`, no `echo $PASSWORD`; rely on `env:` injection
  and GitHub's automatic log masking.

---

## Definition of Done (stage 21 exit gate)

- [ ] `ci.yaml` runs on every PR/push to main: format check, `flutter analyze`, `flutter test --coverage`, debug APK build, coverage artifact uploaded.
- [ ] `release.yaml` runs on tag `v*`: keystore decoded from secret → `key.properties` written → signed AAB built `--obfuscate --split-debug-info`; AAB + symbols uploaded.
- [ ] Signing keystore and all credentials are **CI secrets only** — nothing in source; `.gitignore` covers `*.jks`/`key.properties` (skill 13).
- [ ] Pub + Gradle caching configured; Flutter pinned to stable via `subosito/flutter-action`.
- [ ] Fastlane `test` / `build` / `deploy_internal` lanes exist; the `supply` step is staged for skill 22 (Deployment).
- [ ] Codemagic decision recorded (when/why) if chosen over Actions.
- [ ] **build + test + sign run automatically on push and tag** — no manual local step required.
