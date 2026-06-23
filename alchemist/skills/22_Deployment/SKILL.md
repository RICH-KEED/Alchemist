---
name: Deployment
description: Ship a Flutter app to the Google Play Store — versioning, release signing (upload key + Play App Signing), building a signed app bundle, Play Console tracks (internal → closed → open → production), staged rollout, and store metadata. Use when cutting a first release, setting up release signing, publishing to an internal/closed/production track, automating uploads with fastlane supply, or preparing store listing + compliance forms.
when_to_use: Trigger on "release to the Play Store", "set up app signing", "build a signed app bundle / aab", "publish to internal track", "staged rollout", "automate Play uploads", "store listing / metadata", "data safety form", or stage 22 of the pipeline. Pairs with skill 13 (signing/obfuscation), 21 (CI runs these builds), 23 (mapping upload for crash deobfuscation), and 24 (final launch gate).
---

# Deployment — Ship to Google Play (Stage 22)

Take a built, hardened, tested app and get it onto the Play Store the right way: a clean
version scheme, a release **signing config you control**, a signed **app bundle (`.aab`)**, the
Play Console **track ladder**, a **staged rollout**, and complete **store metadata + compliance
forms**. House style: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).

This stage consumes the obfuscation/build-hardening from **skill 13**, runs inside the pipelines
from **skill 21**, hands the symbol map to **skill 23** for crash deobfuscation, and is gated for
launch by **skill 24**.

> **Scope note.** This is shipping *your own* app under *your own* Play developer account. Nothing
> here circumvents store policy — it helps you comply with it (signing, data safety, target API).

**Exit gate:** *an internal-track release succeeds* — a signed `.aab` is uploaded, processed, and
installable by an internal tester.

---

## 1. Versioning (`pubspec.yaml` → versionName / versionCode)

Flutter derives both Android version fields from one line in `pubspec.yaml`:

```yaml
version: 1.4.0+57   # <semantic name>+<build number>
```

- `1.4.0` → Android **`versionName`** (the human string shown in the store).
- `57` → Android **`versionCode`** (the integer Play uses to order releases).

Rules:
- **`versionCode` must strictly increase** on every upload to a track — Play rejects a re-used or
  lower code. It need not equal the semver; it just has to climb.
- Override per build without editing `pubspec` via flags (handy in CI):

  ```bash
  flutter build appbundle --release --build-name=1.4.0 --build-number=57
  ```

- **Auto-increment in CI** (skill 21): tie `versionCode` to the build pipeline so it's monotonic and
  never hand-managed. Common patterns:

  ```bash
  # GitHub Actions run number as the build number
  flutter build appbundle --release --build-number=${{ github.run_number }}
  ```

  ```bash
  # fastlane: read the highest code already on Play and bump it
  build_number=$(($(google_play_track_version_codes(track: "internal").max) + 1))
  ```

- Keep `versionName` driven by your release process (git tag like `v1.4.0`), `versionCode` driven by
  CI. Record the mapping in release notes so a crash's version is traceable.

## 2. Release signing — upload key vs. app signing key

There are **two** keys. Understanding the split is the whole game:

| Key | Who holds it | What it does |
|---|---|---|
| **App signing key** | **Google** (Play App Signing) | The key Play uses to sign the APKs delivered to users. Google generates/guards it. |
| **Upload key** | **You** | The key *you* sign your `.aab` with to prove it's you. Play verifies it, strips it, re-signs with the app signing key. |

Enroll in **Play App Signing** (default for all new apps). Then:

- You only ever manage the **upload key**. If you lose it, Google can **reset** it — you are not
  bricked the way you would be if you held the one-and-only signing key.
- **Never lose / never commit** the upload keystore. Back it up securely (password manager / secret
  vault), keep it out of git (skill 13 §5: `.gitignore` covers `*.jks`, `key.properties`).

### Create the upload keystore

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

### Wire it without hardcoding secrets

Put the passwords/paths in `android/key.properties` (git-ignored) and read them from Gradle.
Templates:
- [`templates/key.properties.example`](templates/key.properties.example) — the file format + a
  **DO NOT COMMIT** warning.
- [`templates/build.gradle.signing.md`](templates/build.gradle.signing.md) — the `signingConfigs` /
  `buildTypes` Groovy snippet that loads `key.properties`, plus `minifyEnabled` / `shrinkResources`.

In CI (skill 21) the keystore is base64-decoded from a secret and `key.properties` is generated at
build time — the secrets never touch the repo.

## 3. Build the release app bundle

Play wants an **App Bundle (`.aab`)**, not an APK — Play generates per-device APKs from it.

```bash
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
```

Always pair release builds with Dart obfuscation + a saved symbol map (skill 13 §4, skill 23):

```bash
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=build/symbols
```

- `--obfuscate` renames Dart symbols; `--split-debug-info` writes the **symbol map** to
  `build/symbols`. **Archive that directory per release** — it's the only way to deobfuscate Dart
  crash traces later (hand off to **skill 23**). Each `versionCode` needs its own saved map.
- R8/ProGuard handles the native/Android side via `minifyEnabled true` + `shrinkResources true`
  (see the build.gradle template). Upload the R8 **`mapping.txt`** to Play for native deobfuscation.
- Inspect locally before uploading: `bundletool build-apks --bundle=app-release.aab ...` to verify
  it installs.

## 4. Play Console first-time setup

Before the first upload (one-time, manual — you do this in the browser):

1. **Create the app** in Play Console; set default language, app/game, free/paid.
2. **Enroll in Play App Signing** (accept the default — Google holds the app signing key).
3. Complete the **App content** declarations (these are hard gates, see §7): privacy policy URL,
   **data safety** form, **content rating** questionnaire, ads declaration, target audience,
   news/COVID/financial declarations as applicable.
4. Set up the **store listing** (§6).
5. Upload the first `.aab` to the **internal testing** track.

## 5. Tracks + staged rollout

Promote up the ladder — never ship straight to production:

```
internal  →  closed (alpha)  →  open (beta)  →  production
(your team)  (invited testers) (public opt-in)  (everyone, staged %)
```

- **internal**: up to 100 testers, available in minutes, no review wait — this is your **exit gate**.
- **closed**: a wider invited group (email lists / Google Groups) for real-world QA.
- **open**: anyone with the opt-in link; surfaces the pre-launch report at scale.
- **production**: the public release. **Always use a staged rollout** — start small and ramp:

  | Step | Rollout % | Watch |
  |---|---|---|
  | 1 | 5–10% | crash-free rate, ANRs (skill 23), ratings |
  | 2 | 20–50% | same, 24–48h soak |
  | 3 | 100% | full release |

  If metrics regress, **halt the rollout** (don't increase %) or **roll back** by halting and
  shipping a fixed higher `versionCode` — Play has no "un-publish a versionCode"; you fix forward.

Each promotion can reuse the same `.aab` (promote the artifact) or upload a new one.

## 6. Store listing assets & metadata

The listing is part of the release. Keep it **version-controlled** in the fastlane `supply`
directory layout so it deploys with the build:

```
android/fastlane/metadata/android/en-US/
├── title.txt                 # ≤ 30 chars
├── short_description.txt      # ≤ 80 chars
├── full_description.txt       # ≤ 4000 chars
├── changelogs/
│   └── default.txt            # "what's new" (≤ 500 chars) — or <versionCode>.txt
└── images/
    ├── icon/                  # 512×512 PNG
    ├── featureGraphic/        # 1024×500
    └── phoneScreenshots/      # 2–8, 16:9 or 9:16
```

Placeholder copies live in [`templates/store_metadata/`](templates/store_metadata/) — copy them into
the path above and fill them in. Required assets: hi-res icon (512×512), feature graphic
(1024×500), and **at least 2 phone screenshots**. Provide tablet shots if you support tablets
(skill 17, responsive UI).

## 7. Compliance gates (Play will block release otherwise)

These are not optional — Play rejects releases that skip them:

- **Data safety form** — declare what data you collect/share, why, and your encryption/deletion
  practices. Must match what the app actually does (and your privacy policy).
- **Content rating** — complete the IARC questionnaire; an unrated app can't go to production.
- **Target API level** — Play enforces a minimum **`targetSdk`** for new releases (it rises yearly;
  set it to the level Play currently mandates). Bump `targetSdkVersion` in `android/app/build.gradle`
  to clear this; `minSdk` stays 23 per CONVENTIONS.
- **Pre-launch report** — after an internal/closed upload, Play auto-runs your app on real devices
  and reports crashes, ANRs, accessibility, and security findings. Review and fix before promoting.
- Privacy policy URL, ads declaration, permissions justification (esp. sensitive permissions).

Skill 24 (Production_Readiness) treats all of these as a final hard gate before the public release.

## 8. Automated uploads (fastlane supply / Play Developer API)

Manual uploads are fine for the first release; automate from then on (skill 21 runs this in CI):

- **`fastlane supply`** uploads the `.aab`, metadata, and `mapping.txt`, and sets the track + rollout:

  ```ruby
  # android/fastlane/Fastfile
  lane :internal do
    upload_to_play_store(
      track: 'internal',
      aab: '../build/app/outputs/bundle/release/app-release.aab',
      mapping: '../build/app/outputs/mapping/release/mapping.txt',
      release_status: 'completed',
    )
  end

  lane :production do
    upload_to_play_store(
      track: 'production',
      aab: '../build/app/outputs/bundle/release/app-release.aab',
      rollout: '0.1',                       # 10% staged rollout
    )
  end
  ```

- Auth uses a **Google Play service account JSON** with the *Release manager* role, stored as a CI
  secret (skill 21). `supply init` can pull the existing listing down once enrolled.
- Under the hood this is the **Google Play Developer API**; fastlane is the convenient wrapper. Use
  it directly if you need finer control.

---

## Definition of Done (stage 22 exit gate)

- [ ] `version: x.y.z+build` set; `versionCode` strictly increases (auto-incremented in CI, skill 21).
- [ ] Enrolled in **Play App Signing**; **upload keystore** created, backed up, **not in git**.
- [ ] `key.properties` + `signingConfigs` wired; release build is signed (not debug-signed).
- [ ] `flutter build appbundle --release --obfuscate --split-debug-info` produces a signed `.aab`;
      symbol map + `mapping.txt` archived per `versionCode` (handed to skill 23).
- [ ] `minifyEnabled` / `shrinkResources` on for release.
- [ ] Store listing complete (title, descriptions, icon, feature graphic, ≥2 screenshots).
- [ ] **Data safety**, **content rating**, **target API level**, privacy policy — all done.
- [ ] Pre-launch report reviewed; no blocking findings.
- [ ] **Internal-track release uploaded, processed, and installable by a tester** ← the gate.
- [ ] Staged-rollout plan + rollback (fix-forward) plan written before any production push.

See the full pre-release checklist in [`templates/release_checklist.md`](templates/release_checklist.md).
