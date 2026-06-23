---
name: white_label_engine
description: From a brand config matrix (colors — name — icon — endpoints) — generate N flavored signed Android builds using Flutter flavors — Material 3 per-brand theming — and CI matrix orchestration
when_to_use: When adding a new white-label brand — when modifying the brand config — when the build pipeline needs per-brand signing — when asked to regenerate all branded builds from the config matrix
---

# 62 — White Label Engine

From a single codebase, produce multiple independently-branded, flavored, signed Android app bundles. Each brand is driven by a declarative YAML matrix that controls name, icon, colors, endpoints, features, and legal links. The engine loops over every brand entry, runs `flutter build appbundle --flavor <brand>`, signs with per-brand keystores, and validates the output.

## Exit gate

`flutter build appbundle --flavor <brand>` succeeds for every brand defined in the matrix. Each output bundle has the correct applicationId, launcher name, icon, splash, Material 3 color palette, and API endpoints for that brand.

---

## 1. Brand config matrix

The source of truth is `brand_config.yaml` (see `templates/brand_config.yaml`). Every brand entry declares:

| Field | Purpose |
|---|---|
| `display_name` | Launcher label shown to the user |
| `bundle_id_suffix` | Appended to the base package to form a unique `applicationId` |
| `version_name_override` | Optional per-brand version string (defaults to global version) |
| `colors.primary`, `colors.secondary`, `colors.tertiary` | Seed colors passed to `ColorScheme.from(seed:)` |
| `assets.icon_path` | Path relative to `assets/<flavor>/` for the launcher icon |
| `assets.splash_path` | Path relative to `assets/<flavor>/` for the splash image |
| `endpoints.api_base_url` | Base URL for REST/GraphQL API calls |
| `endpoints.auth_domain` | OAuth/OIDC authority domain |
| `features` | Map of feature-flag → `enabled` boolean |
| `legal.privacy_url`, `legal.terms_url`, `legal.support_email` | Links surfaced in-app |
| `signing.keystore_alias` | Alias within the per-brand keystore used for signing |

Validation rule: every brand must have a unique `bundle_id_suffix`. The matrix loader (`brand_matrix.dart`) reads and validates the YAML at startup so misconfiguration fails early.

## 2. Flutter flavor setup

### android/app/build.gradle

```groovy
flavorDimensions "brand"

// Generated block — one productFlavor per brand
productFlavors {
    acmepro {
        dimension "brand"
        applicationId "${defaultApplicationId}.acmepro"
        resValue "string", "app_name", "AcmePro"
    }
    globexapp {
        dimension "brand"
        applicationId "${defaultApplicationId}.globexapp"
        resValue "string", "app_name", "GlobexApp"
    }
    // … additional brands from matrix
}
```

The brand matrix loader tool (`tool/generate_flavors.dart`) reads `brand_config.yaml` and writes the `productFlavors {}` block into `android/app/build.gradle` so flavors stay in sync with the config automatically.

Each flavor gets its own `applicationId` by concatenating the base `applicationId` with `bundle_id_suffix`. The `resValue` for `app_name` removes the launcher label from `AndroidManifest.xml` and uses this flavor-scoped resource instead.

## 3. Theme generation

Per-brand Material 3 theming uses `ColorScheme.fromSeed` with the brand's primary seed. A custom `ThemeExtension` named `AppTokens` carries brand-specific overrides that survive `ThemeData` copy boundaries.

```dart
// lib/theme/brand_theme.dart
ThemeData buildBrandTheme(Color primarySeed, BrandConfig config) {
  final scheme = ColorScheme.fromSeed(
    seedColor: Color(int.parse(primarySeed)),
    brightness: Brightness.light,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    extensions: [AppTokens.fromBrand(config)],
  );
}
```

The flavor is resolved at runtime via a Riverpod provider that reads `package_info_plus` to determine `applicationId`, looks up the matching brand config, and exposes the `ThemeData` via `themeProvider`. This means a single APK/bundle carries only one brand's theme — no runtime switching overhead.

## 4. Asset swapping

Per-flavor assets live under `assets/<flavor>/`:

```
assets/
  acmepro/
    icon/
      ic_launcher.png
    splash/
      splash.png
  globexapp/
    icon/
      ic_launcher.png
    splash/
      splash.png
```

Flutter's flavor-aware asset loading is wired through `flutter_gen`. The `pubspec.yaml` declares:

```yaml
flutter:
  assets:
    - assets/acmepro/
    - assets/globexapp/
flutter_gen:
  assets:
    outputs:
      class_name: Assets
      package_parameter_enabled: true
```

At build time, `flutter_gen` generates a per-flavor `Assets` class. The app resolves which asset path to use based on the active flavor, not the current platform. Launcher icons and splash are handled by the Android flavor resource directories (`android/app/src/<flavor>/res/`).

## 5. Build orchestration

The build script at `tool/build_all_brands.sh` iterates the brand matrix:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Read brand keys from YAML
BRANDS=$(yq eval '.brands | keys | .[]' brand_config.yaml)

for BRAND in $BRANDS; do
  echo "=== Building $BRAND ==="
  flutter clean
  flutter pub get
  dart run tool/generate_flavors.dart

  flutter build appbundle --flavor "$BRAND" \
    --dart-define=BRAND="$BRAND"

  # Sign with per-brand keystore
  KEYSTORE=$(yq eval ".brands.$BRAND.signing.keystore_path" brand_config.yaml)
  ALIAS=$(yq eval ".brands.$BRAND.signing.keystore_alias" brand_config.yaml)

  jarsigner -verbose -sigalg SHA256withRSA -digestalg SHA-256 \
    -keystore "$KEYSTORE" \
    "build/app/outputs/bundle/${BRAND}Release/app-${BRAND}-release.aab" \
    "$ALIAS"

  echo "=== $BRAND bundle signed ==="
done
```

Key behaviors:
- `flutter clean` between brands ensures no cross-contamination.
- `--dart-define=BRAND=$BRAND` lets Dart code read the active brand at compile time.
- Per-brand keystore paths are resolved from the matrix; never hard-coded.
- Exit non-zero on first failure so CI can catch it.

## 6. CI integration (GitHub Actions)

Matrix strategy in `.github/workflows/build_brands.yml`:

```yaml
strategy:
  matrix:
    brand: [acmepro, globexapp, initechmobile]
steps:
  - uses: actions/checkout@v4
  - uses: subosito/flutter-action@v2
    with:
      flutter-version: "3.29.x"
  - run: dart run tool/generate_flavors.dart
  - run: flutter build appbundle --flavor ${{ matrix.brand }}
  - uses: actions/upload-artifact@v4
    with:
      name: ${{ matrix.brand }}-bundle
      path: build/app/outputs/bundle/${{ matrix.brand }}Release/*.aab
```

Each brand builds in parallel. Artifact retention can be set per-brand. Keystore secrets are injected via GitHub Actions secrets per brand (e.g. `KEYSTORE_ACMEPRO_BASE64`).

## 7. Checklist

- [ ] `brand_config.yaml` is valid YAML with unique `bundle_id_suffix` per brand
- [ ] `productFlavors {}` block in `android/app/build.gradle` matches every brand in the matrix
- [ ] Per-brand keystore exists and alias is correct
- [ ] Per-brand launcher icons exist in `android/app/src/<flavor>/res/`
- [ ] Splash assets exist under `assets/<flavor>/splash/`
- [ ] `buildBrandTheme()` produces distinct ColorSchemes for each brand seed
- [ ] `flutter build appbundle --flavor <brand>` exits 0 for every brand
- [ ] Each output `.aab` has the correct `applicationId` (verify with `aapt dump badging`)
- [ ] All per-brand API endpoints are reachable from a test device
- [ ] CI matrix builds all brands and uploads artifacts

---

**References:** `../../references/CONVENTIONS.md` for Dart 3, Riverpod 2.x, Material 3 + ThemeExtension tokens, flutter_gen, and Android-first conventions.
