# White Label Setup Guide

Step-by-step instructions to onboard a new brand and produce its flavored, signed build.

## 1. Define the brand in brand_config.yaml

Add a new brand entry under the `brands:` key in `brand_config.yaml`. Provide all required fields:

- `display_name`, `bundle_id_suffix` (must be unique)
- Color seeds for `primary`, `secondary`, `tertiary`
- `api_base_url`, `auth_domain`
- Feature flags, legal links, and signing alias

See `templates/brand_config.yaml` for the complete schema and examples.

## 2. Place per-flavor Android resources

Create the flavor-specific resource directory:

```
android/app/src/<flavor>/
  res/
    mipmap-hdpi/
      ic_launcher.png
    mipmap-mdpi/
      ic_launcher.png
    mipmap-xhdpi/
      ic_launcher.png
    mipmap-xxhdpi/
      ic_launcher.png
    mipmap-xxxhdpi/
      ic_launcher.png
    drawable/
      splash.png
```

## 3. Place Flutter-side assets

```
assets/<flavor>/
  icon/
    ic_launcher.png
  splash/
    splash.png
```

Register the new directory in `pubspec.yaml` under `flutter.assets`.

## 4. Generate the flavor block

Run the flavor generator to sync `android/app/build.gradle`:

```bash
dart run tool/generate_flavors.dart
```

This reads `brand_config.yaml` and writes the `productFlavors {}` block with one entry per brand, each setting its own `applicationId` and `resValue "app_name"`.

## 5. Provision the per-brand keystore

Place the keystore at the path declared in `brand_config.yaml` (e.g. `keystores/<brand>.keystore`). Store keystore passwords in CI secrets — never commit them.

For CI (GitHub Actions), encode the keystore:

```bash
base64 -w0 keystores/<brand>.keystore > keystores/<brand>.keystore.b64
```

Store the base64 blob in a repository secret named `KEYSTORE_<BRAND>_BASE64`.

## 6. Add the brand to the CI matrix

In `.github/workflows/build_brands.yml`, add the new flavor name to the `matrix.brand` list. The workflow builds all brands in parallel.

## 7. Build and validate

```bash
# Clean build for the new brand
flutter clean && flutter pub get
dart run build_runner build
dart run tool/generate_flavors.dart

flutter build appbundle --flavor <brand>

# Verify applicationId
aapt dump badging build/app/outputs/bundle/<brand>Release/app-<brand>-release.aab \
  | grep "package:"

# Verify signing
jarsigner -verify -verbose -certs \
  build/app/outputs/bundle/<brand>Release/app-<brand>-release.aab
```

## 8. Test the flavored build

- Install on a device and confirm the launcher name matches `display_name`.
- Verify the app icon and splash screen use the correct brand assets.
- Confirm the color palette matches the seed colors defined in the config.
- Hit the brand's `api_base_url` from within the app and verify 200 responses.
- Check that feature flags match the config (disabled features are hidden/greyed out).

## 9. Sign the release

The build script (`tool/build_all_brands.sh`) uses `jarsigner` with the per-brand keystore. For Play Store signing, upload the unsigned AAB and let Play Signing handle it. For direct distribution, sign with:

```bash
jarsigner -verbose -sigalg SHA256withRSA -digestalg SHA-256 \
  -keystore keystores/<brand>.keystore \
  build/app/outputs/bundle/<brand>Release/app-<brand>-release.aab \
  <keystore_alias>
```
