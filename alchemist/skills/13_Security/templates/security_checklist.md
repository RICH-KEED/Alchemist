# Pre-Release Security Checklist — OWASP MASVS-L1

Defensive hardening checklist for **this app's own** users and data. Run before every release.
The stage 13 gate is green only when **every** item is checked. Anything unchecked is a blocker.

> Aligned to OWASP MASVS (Mobile Application Security Verification Standard) Level 1 (L1) —
> the standard hardening baseline for a consumer app. Android specifics called out inline.

---

## STORAGE (MASVS-STORAGE)

- [ ] Access & refresh tokens stored only in `flutter_secure_storage` (Keystore-backed).
- [ ] No secrets in `SharedPreferences`, plaintext db columns, files, or source.
- [ ] `AndroidOptions(encryptedSharedPreferences: true)` set.
- [ ] No sensitive data (tokens, PII) written to logs — `logger`/`print` audited.
- [ ] Sensitive data wiped on logout / account switch (`SecureStore.wipe()` / `TokenRepository.clear()`).
- [ ] `android:allowBackup="false"` **or** backup rules exclude secure storage & token files.
- [ ] No sensitive data in clipboard-by-default, autofill, or app-snapshot caches.

## CRYPTO (MASVS-CRYPTO)

- [ ] No hardcoded encryption keys, secrets, or API keys in the app.
- [ ] Relies on platform crypto (Keystore / EncryptedSharedPreferences) — no home-rolled crypto.
- [ ] No deprecated/weak algorithms (MD5, SHA-1 for security, DES, ECB).
- [ ] Randomness for security uses a CSPRNG (`Random.secure()`), not `Random()`.

## NETWORK / TLS (MASVS-NETWORK)

- [ ] All traffic over HTTPS/TLS; `android:usesCleartextTraffic="false"`.
- [ ] Network Security Config disallows cleartext (no `<domain cleartextTrafficPermitted="true">`).
- [ ] Certificate/SPKI pinning configured on the dio client (`configureCertificatePinning`).
- [ ] At least one **backup pin** shipped; rotation plan documented.
- [ ] dio logging interceptor redacts `Authorization` and other secret headers; off/minimal in release.
- [ ] No secrets in URL query strings.

## PLATFORM (MASVS-PLATFORM)

- [ ] `FLAG_SECURE` on screens showing tokens, payments, or PII (blocks screenshots & switcher preview).
- [ ] Biometric/local-auth gate (`local_auth`) on sensitive flows, with device-credential fallback.
- [ ] Exported `Activity`/`Service`/`Receiver`/`Provider` reviewed — `android:exported` explicit & minimal.
- [ ] Deep links / App Links validated; no unauthenticated entry into sensitive screens (skill 07 guards).
- [ ] No sensitive data passed through implicit intents or unprotected IPC.
- [ ] WebView (if any): JavaScript & file access disabled unless required; no untrusted content.

## CODE (MASVS-CODE)

- [ ] Release build uses `--obfuscate --split-debug-info=build/symbols`.
- [ ] `minifyEnabled true` + `shrinkResources true` + ProGuard/R8 rules in release buildType.
- [ ] Symbol map archived per release (for de-obfuscating crash traces — skill 23).
- [ ] No debug code, test endpoints, or verbose logging in release builds.
- [ ] Secrets injected via `--dart-define-from-file` / CI secrets (skill 21) — none in repo.
- [ ] `.gitignore` covers `*.jks`, `*.keystore`, `key.properties`, `env/*.json`, `build/symbols`.
- [ ] Dependencies scanned for known vulnerabilities; pinned versions; no abandoned packages.
- [ ] Privileged operations enforced **server-side** — no trust placed in client-embedded keys.

## RESILIENCE (MASVS-RESILIENCE, L1 baseline)

- [ ] App functions correctly under normal TLS validation + pinning (no accidental bypass left in).
- [ ] Debuggable flag off in release (`android:debuggable` not set / false).
- [ ] No test backdoors, hidden menus, or hardcoded test credentials shipped.

---

## Sign-off

- [ ] All boxes above checked.
- [ ] Exit gate met: **no secret in plaintext; MASVS-L1 checks pass.**

Reviewer: ____________________   Release/version: ____________   Date: ____________
