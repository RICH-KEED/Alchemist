# Signing setup — keystore from CI secrets (stage 21)

How to generate an upload keystore, get it into CI as a secret, and reconstruct
`android/key.properties` + the Gradle `signingConfigs` **on the runner** at build time.

> **Golden rule (skill 13 §5):** the keystore and all passwords live in **CI secrets only**.
> Never commit `*.jks` / `*.keystore` / `key.properties` / service-account JSON. CI rebuilds these
> files on the runner; they disappear when the runner does.

---

## 1. Generate an upload keystore (once, locally)

Use **Play App Signing**: you keep an *upload* key; Google holds the real app-signing key. Losing
the upload key is recoverable (you can reset it via Play) — but still treat it as a secret.

```bash
keytool -genkey -v \
  -keystore upload-keystore.jks \
  -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

You'll set a **store password**, a **key password**, and the **alias** (`upload` above). Record
these in your secret manager — you will paste them into CI secrets, not into a file.

Add to `.gitignore` (skill 13 already lists these):

```gitignore
**/*.jks
**/*.keystore
**/key.properties
play-service-account.json
env/*.json
build/symbols/
```

## 2. Base64-encode the keystore into a CI secret

Secrets can only hold text, so encode the binary `.jks` to a single base64 line:

```bash
# Linux: -w0 disables wrapping so it's one line. macOS: use `base64 -i upload-keystore.jks`.
base64 -w0 upload-keystore.jks
```

Copy the entire output. In GitHub: **Repo → Settings → Secrets and variables → Actions → New
repository secret** (or an environment-scoped secret for the `release` environment). Create:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | the base64 string from above |
| `ANDROID_KEYSTORE_PASSWORD` | the store password |
| `ANDROID_KEY_PASSWORD` | the key password |
| `ANDROID_KEY_ALIAS` | the alias (e.g. `upload`) |
| `PLAY_SERVICE_ACCOUNT_JSON` | base64 of the Play service-account JSON (skill 22) |

## 3. Reconstruct the files in CI (release.yaml does this)

Decode the keystore and write `key.properties` from the other secrets. These two steps are already
in [`release.yaml`](release.yaml):

```yaml
- name: Decode keystore from secret
  env:
    ANDROID_KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
  run: echo "$ANDROID_KEYSTORE_BASE64" | base64 -d > android/app/upload-keystore.jks

- name: Write key.properties
  env:
    KEYSTORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
    KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
    KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
  run: |
    {
      echo "storePassword=$KEYSTORE_PASSWORD"
      echo "keyPassword=$KEY_PASSWORD"
      echo "keyAlias=$KEY_ALIAS"
      echo "storeFile=upload-keystore.jks"
    } > android/key.properties
```

`storeFile` is **relative to `android/app/`** (where Gradle resolves it), so `upload-keystore.jks`
matches the decode path above.

> Inject secrets via `env:` and pipe — never put a password on the command line and never `cat`
> `key.properties`. GitHub masks secret values in logs; don't defeat it by printing them.

## 4. Wire `build.gradle` to read `key.properties` (defensively)

In `android/app/build.gradle` (Groovy DSL). Reading is **defensive**: if `key.properties` is absent
(e.g. a local debug build, or a fork without secrets) the release build falls back to debug signing
instead of failing the configure step.

```gradle
// Top of android/app/build.gradle, before `android { }`.
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    // ...

    signingConfigs {
        release {
            if (keystorePropertiesFile.exists()) {
                keyAlias keystoreProperties['keyAlias']
                keyPassword keystoreProperties['keyPassword']
                storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
                storePassword keystoreProperties['storePassword']
            }
        }
    }

    buildTypes {
        release {
            // Use the real release signing only when key.properties is present; otherwise debug.
            signingConfig keystorePropertiesFile.exists()
                ? signingConfigs.release
                : signingConfigs.debug

            // Build hardening from skill 13 §4:
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'),
                          'proguard-rules.pro'
        }
    }
}
```

`rootProject.file('key.properties')` resolves to `android/key.properties` (the path CI wrote in
step 3). `storeFile` inside it is relative to `android/app/`.

## 5. Verify

- Locally without secrets: `flutter build appbundle --release` succeeds (debug-signed) — proves the
  fallback works and configure never crashes.
- In CI on a tag: the run produces `app-release.aab` signed with the upload key. Confirm the
  artifact uploads and `build/symbols` is archived.
- Confirm no secret appears in logs and no `*.jks` / `key.properties` was committed
  (`git status` clean).

The store upload (`fastlane supply` / `upload_to_play_store`) and the Play service account are
owned by **skill 22 (Deployment)** — this doc gets you to a signed AAB, ready to ship.
