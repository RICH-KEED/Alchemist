---
name: Security
description: Harden a Flutter/Android app — secure token & secret storage, TLS certificate pinning, build obfuscation/minification, secrets management, biometric auth, and an OWASP MASVS-L1 checklist. Use when wiring secure storage for tokens, pinning certificates, removing secrets from the repo, gating sensitive flows with biometrics, or hardening a build before release.
when_to_use: Trigger on "store tokens securely", "certificate pinning", "obfuscate the build", "no secrets in the repo", "add biometric lock", "make the app secure", or stage 13 of the pipeline. Pairs with skill 11 (the auth interceptor reads the token source defined here) and skill 21 (CI injects the secrets this skill keeps out of source).
---

# Security — App Hardening (Stage 13)

Defensive hardening for **your own** app and **your own** users' data. This stage adds the
controls that keep tokens, secrets, and traffic safe: Keystore-backed storage, TLS pinning,
obfuscated builds, biometric gating, and a release checklist. It consumes the dio client from
skill 11 (the auth interceptor reads the token source defined here) and the CI secrets handling
from skill 21. House style: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).

> **Scope note.** Everything here protects the app's own users and data. We do **not** bypass,
> attack, or weaken any system. Pinning, obfuscation, and biometrics raise the cost of attacking
> *this* app; they are not offensive tooling.

**Exit gate:** *no secret in plaintext; MASVS-L1 checks pass.*

---

## 1. Secure storage for tokens (never SharedPreferences, never source)

Tokens and secrets go in **`flutter_secure_storage`**, which is backed by the **Android Keystore**
(`EncryptedSharedPreferences` / AES-GCM with a hardware-backed key where available).

**Rules:**
- Access & refresh tokens, session keys, and any user secret → secure storage **only**.
- **Never** `SharedPreferences`, `drift`/`isar` plaintext columns, log lines, or hardcoded constants.
- **Never** commit secrets to source or `.dart` files. See §5.
- Wipe everything on logout, account switch, or detected compromise (§2).

Wrap the plugin in a `@riverpod` `SecureStore` ([`templates/secure_storage.dart`](templates/secure_storage.dart))
so the rest of the app depends on typed methods, not raw string keys, and so tests can override it:

```dart
final store = ref.read(secureStoreProvider);
await store.writeAccessToken(token);
final access = await store.readAccessToken();
await store.wipe(); // logout
```

`AndroidOptions(encryptedSharedPreferences: true)` is set in the template so values land in the
Keystore-backed store rather than legacy plaintext prefs.

## 2. Token lifecycle (access / refresh / rotation / wipe)

[`templates/token_repository.dart`](templates/token_repository.dart) is the single source of truth
for tokens. It is what the **skill 11 auth interceptor** reads and what login/logout flows write.

- **Login** → `saveTokens(access, refresh)`.
- **Authorize requests** → interceptor calls `currentAccessToken`.
- **Rotation** → on `401`, the interceptor refreshes once, calls `saveTokens` with the new pair
  (refresh-token rotation: the old refresh token is replaced, never reused), retries the request.
- **Logout / refresh failure / account switch** → `clear()` wipes both tokens from the Keystore.
- Treat refresh failure as "session is gone": clear, then route to login (no silent retry loop).

The interceptor lives in skill 11; this skill owns where the tokens are stored and how they rotate.

## 3. TLS certificate pinning (dio)

Pin the server's **public key (SHA-256 SPKI hash)**, not the leaf certificate — keys survive cert
renewal, so SPKI pins rotate far less often. [`templates/cert_pinning.dart`](templates/cert_pinning.dart)
configures dio's `HttpClient` with a `badCertificateCallback` that compares the presented chain's
SPKI hashes against your pin set.

```dart
final dio = Dio();
configureCertificatePinning(dio, pins: SecurityPins.production);
```

**Operational rules (read the template comments):**
- **Always ship a backup pin** — pin the *current* key **and** the next/rotation key. A single pin
  + an expired cert = a bricked app that cannot reach its backend.
- Pin to your CA or intermediate's SPKI if your provider rotates leaf keys frequently.
- **Rotation strategy:** ship backup pins one release *before* you rotate the server cert, so
  installed clients already trust the new key when the switch happens.
- Pinning supplements, never replaces, normal TLS validation — invalid chains still fail.
- Keep pins in code/config you control, not fetched at runtime (that defeats the purpose).
- Obtain pins from a cert/key you control: see the `openssl` recipe in the template header.

## 4. Build hardening (obfuscation, minification, R8/ProGuard)

Release builds must strip symbols and shrink/obfuscate native + Dart code.

```bash
# Dart-level obfuscation; keep the symbol map to de-obfuscate crash traces (skill 23).
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=build/symbols
```

`android/app/build.gradle` (release buildType):

```gradle
buildTypes {
    release {
        minifyEnabled true          // R8 code shrinking
        shrinkResources true        // drop unused resources
        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'),
                      'proguard-rules.pro'
    }
}
```

- Keep `build/symbols` out of the repo but archived per release so Crashlytics/Sentry traces
  remain readable (hand off to skill 23).
- Add `proguard-rules.pro` keep-rules for any reflection-based libs (e.g. some JSON/serialization).
- Verify the release bundle: class/method names are obfuscated and no debug logging remains.

## 5. Secrets management (keep keys out of the repo)

**No secret belongs in source, `.dart` files, `AndroidManifest`, or version control.**

- Compile-time values via `--dart-define` / **`--dart-define-from-file`**:

  ```bash
  flutter build appbundle --release --dart-define-from-file=env/prod.json
  ```

  ```dart
  const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  ```

- `env/*.json` holds **only non-sensitive** config (base URLs, flags). Real secrets (signing
  keys, API server keys) live in **CI secrets** — see skill 21 — and are injected at build time.
- **Keep real keys server-side.** A mobile app is an untrusted client: any embedded key is
  extractable. Put privileged operations behind your backend, not behind a client-side key.
- `.gitignore` must cover `*.jks`, `*.keystore`, `key.properties`, `env/*.json`, `build/symbols`.

## 6. Biometric / local auth (gate sensitive flows)

Use **`local_auth`** to require biometric/device-credential confirmation before sensitive actions
(viewing tokens-protected data, payments, changing security settings).

```dart
final auth = LocalAuthentication();
final ok = await auth.authenticate(
  localizedReason: 'Confirm to view your account',
  options: const AuthenticationOptions(
    biometricOnly: false,   // allow PIN/pattern fallback
    stickyAuth: true,
  ),
);
if (!ok) return; // do not proceed
```

- Biometrics gate the **UI/flow**; they are not a substitute for server-side authorization.
- Always offer a device-credential fallback so users without enrolled biometrics aren't locked out.
- Re-authenticate on resume for high-sensitivity screens; don't cache the "passed" state forever.

## 7. Misc Android hardening

- **`FLAG_SECURE`** on sensitive screens — blocks screenshots & hides content in the app switcher:
  ```dart
  // Android only; wrap in defaultTargetPlatform == TargetPlatform.android.
  const MethodChannel('app/secure').invokeMethod('setFlagSecure', true);
  ```
  (or use a small plugin) on screens showing tokens, payment, or PII.
- **No secret logging.** Never `logger`/`print` tokens, headers, or PII. Strip verbose logging in
  release; redact `Authorization` in any dio logging interceptor.
- **`android:usesCleartextTraffic="false"`** in `AndroidManifest` + a Network Security Config that
  disallows cleartext — all traffic is HTTPS.
- **Backup rules:** set `android:allowBackup="false"` (or a `dataExtractionRules`/`fullBackupContent`
  that **excludes** secure storage and token files) so secrets aren't swept into cloud backups.
- Set `minSdk 23` (Keystore + biometrics baseline; matches CONVENTIONS).

## 8. OWASP MASVS-L1 checklist

Run [`templates/security_checklist.md`](templates/security_checklist.md) before every release. The
gate is green only when every L1 item is checked: storage, crypto, network/TLS, platform, code, and
resilience. Anything unchecked is a blocker, not a "later".

---

## Definition of Done (stage 13 exit gate)

- [ ] Tokens & secrets in Keystore-backed `flutter_secure_storage` — **nothing** in SharedPreferences/source.
- [ ] `TokenRepository` wired as the auth interceptor's token source (skill 11); rotation + wipe-on-logout work.
- [ ] dio TLS pinning live with a **backup pin** and a documented rotation plan.
- [ ] Release build runs with `--obfuscate --split-debug-info` + `minifyEnabled`/`shrinkResources`.
- [ ] No secret in the repo; config via `--dart-define-from-file`, real secrets in CI (skill 21).
- [ ] Biometric gate on sensitive flows; `FLAG_SECURE`, `cleartextTraffic=false`, backup excludes secrets.
- [ ] **MASVS-L1 checklist passes** — every item checked.
