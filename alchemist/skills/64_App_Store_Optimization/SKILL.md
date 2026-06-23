---
name: App Store Optimization
description: Optimize the Google Play Store listing for conversion — title, subtitle, keywords, full description, short description, screenshots order, and localized store listings. Use before Play Store submission, when conversion is low, or when localizing to new markets.
when_to_use: Trigger on "optimize Play Store listing", "ASO review", "app store optimization", "improve Play Store conversion", "store listing audit", "localize store listing", or before stage 22 Deployment pushes to a production track.
---

# App Store Optimization

You optimize the Google Play Store listing to maximize **impression → visit → install** conversion. You audit the existing listing against ASO best practices, keyword strategy, screenshot hierarchy, and localization opportunity, then produce a revised listing.

House style: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md). This skill feeds [stage 22 Deployment](../22_Deployment/SKILL.md) and [stage 50 Localization_i18n](../50_Localization_i18n/SKILL.md).

---
## What this skill covers

| Listing element | Character limit | Optimization focus |
|---|---|---|
| Title | 30 chars | Primary keyword + brand |
| Short description | 80 chars | Value prop + secondary keyword |
| Full description | 4000 chars | Keyword-rich, scannable, benefit-first |
| Subtitle / developer name | Varies | Keyword reinforcement |
| Screenshots (up to 8) | — | Order, captions, localized overlays |
| Feature graphic | 1024x500 | Brand + value prop at a glance |
| Icon | 512x512 | Recognizability at tiny sizes |
| Promo video | YouTube URL | 30-60s, shows core flow |

---
## Step 1 — Read current listing + competition

1. Read the existing store listing from `fastlane/metadata/android/en-US/` (or wherever it lives in the project).
2. Identify the **primary keyword** the app is targeting (e.g., "expense tracker", "habit tracker", "workout log").
3. Pull the top 3-5 competitors for that keyword. Note their title patterns, screenshot styles, and description structure.

---
## Step 2 — Keyword strategy

The Play Store algorithm indexes keywords from: **title > short description > full description > developer name** (approximate weight order). Keywords in the title are weighted highest.

Follow [`templates/aso_checklist.md`](templates/aso_checklist.md) for the detailed checklist. Key rules:

- **Title:** `[Primary Keyword] — [Brand or Secondary Keyword]`. Never exceed 30 characters.
- **Short description:** Lead with the value proposition; include 2-3 secondary keywords naturally.
- **Full description:** Front-load keywords in the first 2-3 sentences. Repeat primary keyword 3-5x, secondary keywords 1-2x each — never stuff. Use short paragraphs (2-3 sentences), bullet lists for features, and a clear call-to-action at the end.
- **Developer name:** If flexible, include a keyword (e.g., "Acme Productivity Apps").

---
## Step 3 — Screenshot strategy

Screenshots are the #1 conversion factor after the title/icon. Order matters:

1. **Slot 1:** Core value — the #1 thing users do (not a splash screen, not a login screen).
2. **Slots 2-4:** Key features, one per screenshot, with a short caption overlay.
3. **Slots 5-7:** Differentiators — what makes this app better than competitors.
4. **Slot 8:** Social proof or review quote (once available).

Rules:
- Captions on the screenshot image itself (not just in the console), because many users never expand.
- No device frame chrome in the first 2 screenshots — it wastes pixel space.
- Light + dark variants for each screenshot (or at least the first 2).
- Localized captions for each locale (use a template with text layers, not baked-in text per locale).

---
## Step 4 — Write the optimized listing

Produce the listing for US English (en-US) first, then for any additional locales specified. Write:

### Title
`[Primary Keyword] — [Brand/Secondary]` — ≤30 chars.

### Short Description
≤80 chars. Formula: `[Action verb] + [primary benefit] + [differentiator].`

### Full Description
Structure:
```
[2-3 sentence hook with primary + secondary keywords]
[Feature section — bullet list, each starts with a benefit]
[Social proof placeholder or review pull-quote]
[Trust signals — "No ads", "Offline-first", "Privacy-respecting"]
[Call to action — "Download now and start ..."]
```

---
## Step 5 — Localization

For each target locale (>5% of addressable market OR requested by the user):

1. Translate the listing (title, short desc, full desc) — use a translation service or the project's existing localization workflow (skill 50).
2. Adapt keywords per locale — a direct translation may not be the highest-volume search term. Research the locale-specific keyword.
3. Localize screenshot captions — the screenshots stay the same, but the text overlay changes.
4. Check cultural fit — colors, imagery, hand gestures, text direction.

---
## Step 6 — Deliver

Write the updated listing files to `fastlane/metadata/android/en-US/` (and per-locale directories). The structure follows the Fastlane `supply` convention:

```
fastlane/metadata/android/
├── en-US/
│   ├── title.txt
│   ├── short_description.txt
│   ├── full_description.txt
│   └── changelogs/
│       └── default.txt        # or per-version: 1.2.3.txt
├── es-ES/
│   └── ...
└── fr-FR/
    └── ...
```

Also produce an **ASO audit summary** — listing the before/after keyword density, title changes, and screenshot order rationale — so the user can review before uploading.

---
## Cross-references

- **22 Deployment** — consumes the store listing to push to Play Console.
- **50 Localization_i18n** — provides the translation infrastructure for listing localization.
- **05 App_Preview** — the screenshots you optimize may come from here.
- **65 Changelog_Generator** — produces the "What's New" text for each release.

See the full checklist in [`templates/aso_checklist.md`](templates/aso_checklist.md).
