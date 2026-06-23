---
name: App Icon Generator
description: Generate the complete app icon suite for Android (and iOS) — all 9 density buckets from mdpi to xxxhdpi, adaptive icon layers (foreground, background, monochrome for Android 13 themed icons), notification icon, and the Play Store 512×512 icon. Uses flutter_launcher_icons to auto-apply. If the user has no source image, generates a detailed, optimized prompt for DALL-E / Midjourney / Stable Diffusion to create the icon artwork, then guides them through the image→icon pipeline. Use when the user says "generate app icon", "create launcher icons", "app icon for all sizes", "adaptive icon", "what should my icon look like", or "icon prompt".
when_to_use: Trigger on "app icon", "generate icons", "launcher icon", "icon for all densities", "adaptive icon generate", "what icon should I make", or when stage 10 (Asset Management) needs the source icon image. Also invoked automatically by stage 22 (Deployment) for the Play Store icon.
---

# App Icon Generator

Produce a complete, production-ready Android app icon in every required density and format — from a source image, or from a generated image-model prompt if the user has nothing yet.

---

## Phase A — Do they have a source image?

### Yes — they have a PNG/SVG

1. Confirm the source is at least 1024×1024 px (preferably 2048×2048 for headroom).
2. Wire `flutter_launcher_icons` (see [`templates/flutter_launcher_icons.yaml`](templates/flutter_launcher_icons.yaml)):
   - `image_path` → the source
   - `adaptive_icon_foreground` → same image (or a simplified variant; recommend keeping the core mark, removing text)
   - `adaptive_icon_background` → solid brand color or simple gradient from `ColorScheme.primary`
   - `android: true, ios: true`
   - `min_sdk_android: 21`
3. Add adaptive icon monochrome layer for Android 13+ themed icons (foreground as 1-bit alpha silhouette).
4. Run `dart run flutter_launcher_icons` (or `flutter pub run flutter_launcher_icons`).
5. Verify outputs in `android/app/src/main/res/mipmap-*`.

### No — generate a prompt

If the user has no icon artwork, generate a **detailed, model-optimized prompt** using the app's PRD + brand tokens from skill 04:

#### The prompt formula

```
A professional mobile app icon for a <app-type> app called "<app name>".
<brand-color> palette, <mood> aesthetic. <key visual element>.
Flat 2D vector style with clean lines, 2-3 colors max, bold silhouette,
no text, transparent or solid background. Centered composition with padding.
Standalone icon, no device frame, no shadow, no gradient background.
Designed for a 512x512 Android adaptive icon with 33% safe zone margin.
App icon style, Play Store ready, Material Design iconography.
```

#### Domain-specific elements (add based on PRD):

| App type | Visual elements to include |
|---|---|
| Habit tracker | Checkmark, streak fire, calendar grid, checkmark in circle |
| Fitness | Dumbbell, running figure, heart + pulse, mountain peak |
| Finance | Shield + dollar, graph arrow up, wallet, key |
| Productivity | Lightning bolt, checkmark in box, gear + star, hourglass |
| Social | Speech bubble, heart, people silhouette, camera |
| Food/delivery | Fork + knife, plate, bag, scooter |
| Education | Book, graduation cap, lightbulb, open pages |
| Music/audio | Headphones, waveform, note, vinyl disc |
| Health | Cross / heartbeat, leaf, pill, stethoscope |
| Shopping | Cart, bag, tag, barcode |
| Travel | Plane, compass, pin/marker, globe |
| Kids | Crayon, blocks, star + moon, balloon |

#### Midjourney prompt example:
```
A professional flat vector app icon for a habit tracker --stylize 250 --style 2d-vector --ar 1:1 --no text,letters,words,device,shadow,photo
```

#### DALL-E 3 prompt example:
```
A clean flat 2D vector mobile app icon: a mint-green circular checkmark inside a rounded square with dark teal background. No text, no shadows, no device frame. Bold minimal silhouette, centered with 33% padding. App icon style for Play Store.
```

#### Stable Diffusion (SDXL) prompt example:
```
flat vector app icon, (habit tracker), circular checkmark, teal and mint green palette, bold minimal silhouette, clean lines, 2 colors, centered composition, padding around edges, transparent background, no text, no shadows, no device, 2d vector art style
Negative: photo, realistic, 3d, shadow, text, letters, words, gradient, device frame, screenshot, busy, complex, more than 3 colors
```

---

## Phase B — Generate all density variants

Wire the source into `flutter_launcher_icons` and configure these outputs:

### Android launcher icons (adaptive)

| Density | Size | Path |
|---|---|---|
| mdpi | 48×48 | `mipmap-mdpi/ic_launcher.png` |
| hdpi | 72×72 | `mipmap-hdpi/ic_launcher.png` |
| xhdpi | 96×96 | `mipmap-xhdpi/ic_launcher.png` |
| xxhdpi | 144×144 | `mipmap-xxhdpi/ic_launcher.png` |
| xxxhdpi | 192×192 | `mipmap-xxxhdpi/ic_launcher.png` |

Plus adaptive layer files: `ic_launcher_foreground.png`, `ic_launcher_background.png`, `ic_launcher_monochrome.png` at each density.

### Android notification icon

A separate, simpler variant — white silhouette on transparent, 24dp:
- `android/app/src/main/res/drawable-*/ic_notification.png` at all densities.

### Play Store icon

- 512×512 px, 32-bit PNG (RGBA), max 1 MB
- This is the full-color app icon — same as the launcher source, just at exact 512×512.
- Output: `publish/play_icon.png`

### iOS (if building iOS)

- `ios/Runner/Assets.xcassets/AppIcon.appiconset/` — all ~20 required sizes via `flutter_launcher_icons` ios config.

### Feature graphic icon inset (optional)

- The feature graphic (skill 77) can optionally include the app icon as a small centered element at 180×180 px. Extract this from the source.

---

## Phase C — Auto-apply and verify

1. Run `dart run flutter_launcher_icons` (and/or `flutter pub run flutter_launcher_icons`).
2. Verify every density bucket has files.
3. For adaptive icons, verify `ic_launcher.xml` in `mipmap-anydpi-v26` references foreground + background drawables.
4. Run the app on an emulator — the icon should render on the launcher, the recent apps screen, and the app info screen.
5. If monochrome is configured, verify it renders when the device uses a themed icon (Android 13+, long-press home screen → Wallpaper & style → Themed icons).

---

## Quality bar

- Icon is recognizable at 48×48 px (mdpi) — the smallest launcher size.
- Adaptive icon has 33% safe zone (the inner 66% is the visible area after the OEM mask).
- Monochrome layer is a clean 1-bit silhouette (black pixels = visible; transparency = transparent).
- Notification icon is pure white silhouette on transparent (Android tints it for you).
- Play Store icon is exactly 512×512, PNG 32-bit, under 1 MB.

See [`templates/flutter_launcher_icons.yaml`](templates/flutter_launcher_icons.yaml) for the full config and [`templates/icon_prompt_guide.md`](templates/icon_prompt_guide.md) for the expanded prompt reference.
