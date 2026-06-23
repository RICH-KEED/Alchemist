# Android App Links — configuration

App Links are **verified `https://` deep links**: tapping `https://example.com/items/42`
opens your app directly (no "open with" chooser) and routes via go_router. Verification
proves you own the domain by matching your app's signing-cert fingerprint against a file
hosted on that domain.

Three pieces must line up: **(1)** the `<intent-filter>` in `AndroidManifest.xml`, **(2)**
the `assetlinks.json` hosted at your domain, **(3)** the signing-cert SHA-256 fingerprint
that appears in both the app and the JSON.

> Custom-scheme links (`myapp://items/42`) need **no** verification, but aren't real web
> URLs and can be hijacked by other apps. Prefer App Links for shareable, trusted links.

---

## 1. `AndroidManifest.xml` intent-filter

Add inside the **main launcher `<activity>`** (usually `.MainActivity`) in
`android/app/src/main/AndroidManifest.xml`, alongside the existing `MAIN`/`LAUNCHER` filter:

```xml
<activity
    android:name=".MainActivity"
    android:launchMode="singleTop"
    android:exported="true">

    <!-- existing launcher intent-filter stays as-is -->
    <intent-filter>
        <action android:name="android.intent.action.MAIN" />
        <category android:name="android.intent.category.LAUNCHER" />
    </intent-filter>

    <!-- App Links: verified https deep links -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />

        <!-- Match https://example.com/... ; add a <data> per host you own. -->
        <data android:scheme="https" />
        <data android:host="example.com" />
        <!-- Optionally scope to a path so not every URL opens the app: -->
        <!-- <data android:pathPrefix="/items" /> -->
    </intent-filter>

    <!-- (Optional) custom scheme, NOT auto-verified: myapp://items/42 -->
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="myapp" android:host="items" />
    </intent-filter>
</activity>
```

Notes:
- `android:autoVerify="true"` is what triggers Android to fetch `assetlinks.json` and verify
  ownership on install. Without it, your `https` links still work but show the chooser.
- Put `scheme` and `host` in **separate `<data>` tags** (Android merges them).
- go_router parses the incoming URI automatically — no extra meta-data flag is needed when
  go_router is your router. Just make sure the path maps to a defined route.

---

## 2. `assetlinks.json`

Host this **exactly** at:

```
https://example.com/.well-known/assetlinks.json
```

It must be served over **HTTPS**, return `200` with `Content-Type: application/json`, with
**no redirects** and reachable without authentication.

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.example.myapp",
      "sha256_cert_fingerprints": [
        "AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90"
      ]
    }
  }
]
```

- `package_name` = your `applicationId` from `android/app/build.gradle`.
- `sha256_cert_fingerprints` accepts **multiple** entries — list every cert that signs a build
  you want verified (debug, upload, and Play App Signing).

---

## 3. Get the SHA-256 fingerprint

**Debug cert (local testing):**

```bash
keytool -list -v -alias androiddebugkey \
  -keystore ~/.android/debug.keystore \
  -storepass android -keypass android
```

**Release / upload cert:**

```bash
keytool -list -v -alias <your-alias> -keystore /path/to/upload-keystore.jks
```

Copy the line labelled `SHA256:` (colon-separated hex) into `sha256_cert_fingerprints`.

**Play App Signing:** if enrolled, Google **re-signs** your app, so the fingerprint that
verifies in production is the one in **Play Console → Setup → App integrity → App signing
key certificate**. Add that SHA-256 to the JSON too (Play Console even shows a ready-made
`assetlinks.json` snippet). Without it, links won't verify on Play-installed builds.

---

## 4. Verify it works

```bash
# Re-trigger domain verification on a connected device/emulator:
adb shell pm verify-app-links --re-verify com.example.myapp

# Check verification status (look for "verified" per host):
adb shell pm get-app-links com.example.myapp

# Fire a link and confirm the app opens on the right screen:
adb shell am start -a android.intent.action.VIEW \
  -d "https://example.com/items/42?tab=specs" com.example.myapp
```

Google's **Statement List Generator and Tester** (search "Digital Asset Links tester") will
validate your hosted `assetlinks.json` against the package + fingerprint.

---

## Checklist

- [ ] `<intent-filter android:autoVerify="true">` with `https` scheme + your host in the manifest.
- [ ] `MainActivity` is `android:exported="true"` and `singleTop`.
- [ ] `assetlinks.json` live at `https://<host>/.well-known/assetlinks.json` (HTTPS, no redirect, `200`).
- [ ] `package_name` matches `applicationId`.
- [ ] SHA-256 fingerprint(s) for **every** signing cert (debug, upload, Play) listed.
- [ ] `adb shell pm get-app-links` shows the host as `verified`.
- [ ] Firing the URL via `adb` opens the correct go_router screen.
