# Per-flavor assets, app icons & splash

Give each flavor (dev / staging / prod) its own launcher icon, splash, and
overridable assets. Flavor *build* automation (signing, CI matrix) is **skill 21** —
this file covers only the asset wiring.

> Assumes flavors are already declared in `android/app/build.gradle`
> (`productFlavors { dev {...} staging {...} prod {...} }`) and via Flutter's
> `--flavor` flag. If not, set those up first.

---

## 1. Android resource & asset overrides (build-time)

Android merges per-flavor source sets over `main`. Anything in a flavor dir
**replaces** the `main` equivalent for that flavor:

```
android/app/src/
├── main/
│   ├── res/                  # default launcher icon, mipmaps, colors
│   └── ...
├── dev/
│   ├── res/                  # dev-only mipmap/ic_launcher, splash colors
│   └── assets/               # dev-only bundled files (override main)
├── staging/
│   └── res/
└── prod/
    └── res/
```

Use this for resources Android resolves natively (mipmaps, `values/colors.xml`,
the Android 12 splash theme). flutter_launcher_icons / flutter_native_splash
write into these dirs for you — see below.

---

## 2. Per-flavor launcher icons (`flutter_launcher_icons`)

Create one config file per flavor at the project root. The filename suffix after
the dash is the flavor name; the tool writes icons into that flavor's res dir.

`flutter_launcher_icons-dev.yaml`:

```yaml
flutter_launcher_icons:
  android: true
  ios: false
  min_sdk_android: 23
  adaptive_icon_foreground: "assets/branding/dev/icon_foreground.png"
  adaptive_icon_background: "#9333EA"                  # distinct dev color
  adaptive_icon_monochrome: "assets/branding/dev/icon_monochrome.png"
  image_path: "assets/branding/dev/icon_legacy.png"
```

`flutter_launcher_icons-prod.yaml` mirrors it with prod art/colors.

Generate (the `-f` config flavor must match the build `--flavor`):

```bash
dart run flutter_launcher_icons -f flutter_launcher_icons-dev.yaml
dart run flutter_launcher_icons -f flutter_launcher_icons-prod.yaml
```

Tip: give non-prod flavors a visibly different icon/color so testers never confuse builds.

---

## 3. Per-flavor splash (`flutter_native_splash`)

`flutter_native_splash` reads a `flavors:` map. Put per-flavor configs in
their own files and pass `--flavors`:

`flutter_native_splash-dev.yaml`:

```yaml
flutter_native_splash:
  color: "#F5F3FF"
  color_dark: "#1E1B2E"
  image: "assets/branding/dev/splash_logo.png"
  android_12:
    image: "assets/branding/dev/splash_logo.png"
    color: "#F5F3FF"
    color_dark: "#1E1B2E"
```

Generate per flavor:

```bash
dart run flutter_native_splash:create --flavors dev   --path flutter_native_splash-dev.yaml
dart run flutter_native_splash:create --flavors prod  --path flutter_native_splash-prod.yaml
```

Match each flavor's splash background to that flavor's launcher background for a
seamless cold start.

---

## 4. Flavor-specific bundled assets in Dart

For assets you read from Dart (not native res), keep a folder per flavor and
select at runtime via the flavor/env value resolved at startup:

```
assets/
└── flavors/
    ├── dev/config.json
    ├── staging/config.json
    └── prod/config.json
```

Declare `assets/flavors/` in `pubspec.yaml`, regenerate flutter_gen, then pick
the right one from your `AppFlavor` enum (resolved at bootstrap):

```dart
import 'package:myapp/gen/assets.gen.dart';

String configAssetFor(AppFlavor flavor) => switch (flavor) {
      AppFlavor.dev => Assets.flavors.dev.config.path,
      AppFlavor.staging => Assets.flavors.staging.config.path,
      AppFlavor.prod => Assets.flavors.prod.config.path,
    };
```

(`AppFlavor` is the sealed/enum flavor type defined alongside your flavor setup.)

---

## 5. Wire into CI (handoff to skill 21)

Regenerate icons/splash for the target flavor **inside the build job**, before
`flutter build`, so artifacts are never stale:

```bash
dart run build_runner build --delete-conflicting-outputs        # flutter_gen
dart run flutter_launcher_icons -f flutter_launcher_icons-$FLAVOR.yaml
dart run flutter_native_splash:create --flavors $FLAVOR --path flutter_native_splash-$FLAVOR.yaml
flutter build appbundle --flavor $FLAVOR -t lib/main_$FLAVOR.dart
```

Skill 21 owns the matrix/secrets that run this per flavor on push/tag.
