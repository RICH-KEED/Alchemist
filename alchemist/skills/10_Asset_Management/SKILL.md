---
name: Asset Management
description: Build a clean, type-safe asset pipeline for a Flutter/Android app — images (with resolution variants), fonts, SVGs, an adaptive launcher icon, a native splash, and per-flavor assets. Use when adding images/fonts/icons, wiring flutter_gen, setting up the app icon or splash screen, handling remote image caching, or shrinking app size.
when_to_use: Trigger on "add an image/font/icon", "set up the app icon", "splash screen", "generate Assets class", "flutter_gen", "cached_network_image", "why is my app so big", or stage 10 of the pipeline. For brand colors/typography go to skill 04; for per-flavor CI builds go to skill 21.
---

# Asset Management (Stage 10)

Owns the **asset pipeline**: every image, font, SVG, launcher icon, and splash the app ships, accessed **type-safely** via `flutter_gen`. House style is the law — see [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).

**Exit gate:** assets typed via `flutter_gen` (no stringly-typed paths); adaptive launcher icon + native splash render on a device.

This stage depends on the design tokens from **skill 04** (brand colors, the logo source) and feeds **skill 21** (per-flavor icons/splash built in CI).

---

## 1. Folder conventions

Keep a flat, predictable tree under `assets/`. One concern per directory.

```
assets/
├── images/        # raster art, photos, illustrations (.png/.webp/.jpg)
│   ├── logo.png
│   ├── 2.0x/logo.png      # resolution variants — same filename
│   └── 3.0x/logo.png
├── icons/         # SVGs and small vector glyphs (.svg)
│   └── menu.svg
├── fonts/         # .ttf/.otf font files
│   └── Inter-Regular.ttf
└── branding/      # source art for launcher icon + splash (not shipped raw)
    ├── icon_foreground.png
    ├── icon_background.png
    └── splash_logo.png
```

Rules: lowercase `snake_case` filenames; prefer **`.webp`** over `.png` for photos (smaller, lossless mode available); prefer **SVG** over multi-resolution PNGs for flat/line art (one file, infinitely scalable).

---

## 2. Declare assets & fonts in `pubspec.yaml`

Nothing is bundled until it is declared. Declare **directories** (trailing `/`) so new files in them ship automatically.

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/images/
    - assets/icons/
  fonts:
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf
        - asset: assets/fonts/Inter-Medium.ttf
          weight: 500
        - asset: assets/fonts/Inter-Bold.ttf
          weight: 700
```

Full block (with icon/splash/flutter_gen config) lives in [`templates/pubspec_assets.yaml`](templates/pubspec_assets.yaml). The font `family` name is what skill 04's typography tokens reference in `TextTheme`.

---

## 3. Resolution-aware images (`2.0x` / `3.0x`)

Flutter auto-selects a variant by device pixel ratio. Put the base (1x) image at the declared path and higher-density copies in `2.0x/` and `3.0x/` **subfolders using the same filename**:

```
assets/images/logo.png        # 1x  (e.g. 120×120)
assets/images/2.0x/logo.png   # 2x  (240×240)
assets/images/3.0x/logo.png   # 3x  (360×360)
```

Declare only `assets/images/` — the variants are discovered automatically. This applies to raster only; SVGs don't need variants.

---

## 4. SVGs with `flutter_svg`

Vectors stay crisp at any size and shrink app size. Add `flutter_svg` and render with `SvgPicture`:

```dart
import 'package:flutter_svg/flutter_svg.dart';
import 'package:myapp/gen/assets.gen.dart';

// Type-safe (preferred — flutter_gen exposes a .svg() helper):
Assets.icons.menu.svg(width: 24, height: 24);

// Tint to the current theme rather than baking colors into the file:
Assets.icons.menu.svg(
  colorFilter: ColorFilter.mode(
    Theme.of(context).colorScheme.onSurface,
    BlendMode.srcIn,
  ),
);
```

Export SVGs without embedded raster, flatten transforms, and strip editor metadata to keep them tiny.

---

## 5. Type-safe access with `flutter_gen` (no stringly-typed paths)

**Never** write `Image.asset('assets/images/logo.png')` — a typo is a runtime crash. Generate a typed `Assets` class instead. Add the dev dependency and the `flutter_gen` config (see template), then run:

```bash
dart run build_runner build --delete-conflicting-outputs
# or, with the standalone CLI:
fluttergen -c pubspec.yaml
```

This produces `lib/gen/assets.gen.dart` and `lib/gen/fonts.gen.dart`. Use them everywhere:

```dart
import 'package:myapp/gen/assets.gen.dart';

Assets.images.logo.image(width: 120);          // returns an Image widget
Assets.images.logo.provider();                  // returns an ImageProvider
const path = Assets.images.logo.path;           // the String, when you need it
Assets.icons.menu.svg(width: 24);               // SVG helper
FontFamily.inter;                               // typed font family name
```

Rename or delete an asset → the code stops compiling. That is the point. Regenerate after every asset change (wire it into the CI lint step from skill 21). See examples in [`templates/assets_usage.dart`](templates/assets_usage.dart).

---

## 6. Adaptive launcher icon (`flutter_launcher_icons`)

Android adaptive icons are a **foreground** + **background** layer the OS masks into any shape. Android 13+ also supports a **monochrome** layer for themed icons. Configure once, generate per platform:

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  min_sdk_android: 23
  adaptive_icon_foreground: "assets/branding/icon_foreground.png"
  adaptive_icon_background: "#0B5FFF"          # color or an asset path
  adaptive_icon_monochrome: "assets/branding/icon_monochrome.png"  # Android 13 themed icons
  image_path: "assets/branding/icon_legacy.png" # fallback for old launchers
```

```bash
dart run flutter_launcher_icons
```

Keep the foreground logo within the safe zone (the inner ~66% of the 108dp canvas) — the outer ring gets clipped by round/squircle masks. Background should be a flat color or simple shape.

---

## 7. Native splash (`flutter_native_splash`, Android 12+ API)

On Android 12+ the OS owns the splash via the Splash Screen API: a centered icon over a single background color (no full-bleed image). Configure both the modern and legacy paths:

```yaml
flutter_native_splash:
  color: "#FFFFFF"
  color_dark: "#0B0B0F"
  image: "assets/branding/splash_logo.png"        # legacy (pre-12) centered image
  android_12:
    image: "assets/branding/splash_logo.png"      # Android 12+ icon (centered, masked)
    color: "#FFFFFF"
    color_dark: "#0B0B0F"
```

```bash
dart run flutter_native_splash:create
```

Remove the native splash from Dart once the first frame is ready so it doesn't linger:

```dart
import 'package:flutter_native_splash/flutter_native_splash.dart';

void main() {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  runApp(const MyApp());
}
// later, after first frame / bootstrap done:
FlutterNativeSplash.remove();
```

Match the splash background to the launcher background for a seamless cold start.

---

## 8. Per-flavor assets & app icons

Different flavors (dev/staging/prod) get different icons, splash, and assets. Two mechanisms:

- **Android resource dirs**: `android/app/src/<flavor>/res/...` and `android/app/src/<flavor>/assets/` override the `main` set for that flavor at build time.
- **Flutter tooling configs**: `flutter_launcher_icons-<flavor>.yaml` and `flutter_native_splash-<flavor>.yaml`, generated with the `--flavor` flag.

```bash
dart run flutter_launcher_icons -f flutter_launcher_icons-dev.yaml
dart run flutter_native_splash:create --flavors dev
```

Full wiring (dir layout + per-flavor configs + CI hooks) is in [`templates/flavor_assets.md`](templates/flavor_assets.md). Flavor *build* automation belongs to **skill 21**.

---

## 9. Caching remote images (`cached_network_image`) & precaching

Never use a bare `Image.network` for content from the API — it has no disk cache and no state handling. Use `cached_network_image` and render the four states per skill 16:

```dart
CachedNetworkImage(
  imageUrl: product.imageUrl,
  placeholder: (context, url) => const ShimmerBox(),     // skill 16 loading
  errorWidget: (context, url, error) => const Icon(Icons.broken_image),
  fadeInDuration: const Duration(milliseconds: 200),
);
```

**Precache** above-the-fold local images in `didChangeDependencies` so they paint without a flash:

```dart
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  precacheImage(Assets.images.logo.provider(), context);
}
```

See [`templates/assets_usage.dart`](templates/assets_usage.dart).

---

## 10. Keep app size down

- Prefer **vector (SVG)** and **`.webp`** over PNG; compress raster art before committing.
- Ship only the resolution variants you need; don't bundle a 4x asset no device uses.
- Audit what assets actually cost in the bundle:

```bash
flutter build appbundle --analyze-size
flutter build apk --target-platform android-arm64 --analyze-size
```

- Don't declare whole asset *trees* you don't use; remove dead art. Large fonts? Subset to the glyphs you ship.

---

## Definition of done (this stage)

- [ ] `assets/` follows the folder convention; everything used is declared in `pubspec.yaml`.
- [ ] `flutter_gen` runs; **all** asset/font access goes through `Assets.*` / `FontFamily.*` (zero string paths).
- [ ] Adaptive launcher icon (foreground/background, + monochrome for Android 13) generated and rendering.
- [ ] Native splash (Android 12+ API + legacy) generated, shown on cold start, and removed after first frame.
- [ ] Remote images use `cached_network_image` with placeholder + error (skill 16); above-the-fold images precached.
- [ ] `--analyze-size` reviewed; no unused/oversized assets shipped.
- [ ] `flutter analyze` clean under `very_good_analysis`.

Conventions reference: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).
