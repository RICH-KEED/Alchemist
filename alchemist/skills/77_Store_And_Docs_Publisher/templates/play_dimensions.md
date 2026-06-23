# Play Store Image Dimension Spec

Every asset has exact pixel dimensions and a max file size. Play Console rejects anything outside these bounds. All images MUST be 24-bit PNG (or JPEG, with alpha only on the icon).

| Asset | Dimensions (px) | Max file size | Format | Aspect ratio | Notes |
|---|---|---|---|---|---|
| App icon | 512×512 | 1 MB | PNG 32-bit | 1:1 | Alpha channel required for adaptive icon mask |
| Feature graphic | 1024×500 | 1 MB | PNG or JPEG (no alpha) | ~2:1 | Header image at top of listing. Safe area: center 600px. |
| Phone screenshot | min 320 px wide, min 384 px tall | 8 MB each | PNG or JPEG (no alpha) | Between 16:9 and 9:16 | 2–8 required. MUST be real app screenshots (Play policy). |
| Tablet 7-inch screenshot | min 320 px wide | 8 MB each | PNG or JPEG | Between 16:9 and 9:16 | Optional, 2–8. Use skill 17 responsive layout. |
| Tablet 10-inch screenshot | min 320 px wide | 8 MB each | PNG or JPEG | Between 16:9 and 9:16 | Optional, 2–8. Different layout ratio than 7-inch. |
| TV banner | 1280×720 | — | PNG or JPEG | 16:9 | Android TV only. |
| Wear OS screenshot | min 320 px wide | — | PNG or JPEG | 1:1 | Wear OS only. Round crop applied by Play. |
| Daydream 360° (legacy) | 4096×4096 | — | JPEG | 1:1 | Very rarely used; skip. |
| Promo video | YouTube URL | — | — | 16:9 | Optional. Must be YouTube. Shows below feature graphic. |

## Screenshot best practices

Per Play policy and conversion science:
1. **Real UI only, no device frame.** Play applies its own shadow frame. Adding a redundant frame in the image can get rejected.
2. **Remove the status bar.** Clean screenshots show 100% app content. Use `SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [])` or crop in post.
3. **Each screenshot sells one feature.** Don't show the same screen twice. Each image tells one value-prop story with a caption overlay (optional but effective for conversion).
4. **Localize the overlay text.** If you add caption overlays to screenshots, they need ARB keys from skill 50 for every locale your listing supports.
5. **Light theme screenshots** perform slightly better in Play experiments, unless your app is exclusively dark-themed.

## Feature graphic composition

```
+--------------------------------------------------+
|  [1024 px wide]                                  |
|                                                  |  ^
|  BACKGROUND: ColorScheme.primary or gradient     |  |
|                                                  |  |
|               APP NAME (display type)             | 500 px
|             one-line tagline below               |  |
|                                                  |  |
|                                [screenshot®]     |
+--------------------------------------------------+
                                                ^
                                         safe zone
                                     (center ~600px)
```

- Background: `seedColor` solid or a 2-stop gradient from `primary` → `primaryContainer`.
- App name: `fontSize 48`, `onPrimary`, display weight, centered.
- Tagline (optional): `fontSize 18`, `onPrimary` at 80% opacity.
- Left-aligned text variant: app name + tagline left, screenshot inset 40% width right. Either layout works. Test both.
- Safe zone: keep critical content (name, tagline) in the center 600px — sides may be cropped on different Play layouts.

## Device frames (screenshot approach)

If using Method B or C with a device frame (NOT Play policy, but they look good in A/B tests for feature graphics):
- Use the free Material Design device-frame SVGs from Google's marketing kit.
- Frame the screenshot at its native resolution before resizing to Play dimensions.
- Remove the frame for the actual Play screenshots (Play applies its own shadow).
