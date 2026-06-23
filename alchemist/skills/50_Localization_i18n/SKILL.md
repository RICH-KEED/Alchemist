---
name: Localization & i18n Engine
description: Extract hardcoded UI strings into ARB and wire flutter_localizations + intl with ICU plurals, RTL, and text-expansion readiness. Use when the user says "localize", "i18n", "internationalization", "translations", "ARB", "multi-language", "RTL", "right-to-left", or "support another language", or when shipping to non-English markets. Produces l10n setup, an extraction pass over lib/, ICU messages, and an RTL/overflow audit.
when_to_use: Trigger when an app needs more than one language, when hardcoded English strings must move out of widgets, or when adding RTL (Arabic/Hebrew) support. Run after the UI exists (Phase C) and before release. For the locale-switch UI state use 08 (Riverpod); for overflow/responsive layout use 17; for typed asset/string codegen alternatives note slang below.
---

# Localization & i18n Engine

You make the app speak every language it ships in — without a single user-facing string baked
into a widget. The house contract lives in
[`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md) (§4 widget hygiene: *never
hardcode strings*; §7 Definition of Done: *strings tokenized*). When this skill and that file
disagree, that file wins.

**The house stack:** Flutter's first-party **`flutter_localizations` + `intl`** with **ARB** files
and generated `AppLocalizations` (`flutter gen-l10n`). It is zero-dependency, IDE-supported, and the
default everyone knows.

> **Typed alternative — `slang`.** If a project wants compile-time-checked keys, nested namespaces,
> and no `BuildContext` to read a string, use `slang` instead of `intl`. Same ARB-like JSON, same ICU
> support, but `t.home.title` is a typed getter (a missing key is a *compile* error, not a runtime
> `null`). Pick one per project. The rest of this skill assumes `intl`; the workflow (extract → keys →
> review → RTL audit) is identical for `slang`.

**Exit gate:** *every user-facing string comes from `AppLocalizations`; `flutter analyze` clean;
RTL renders correctly; no overflow at 1.3× text expansion.*

---

## 1. Setup (intl + flutter_localizations)

`pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  intl: any            # version pinned by the Flutter SDK — let it resolve
flutter:
  generate: true       # turns on gen-l10n codegen
```

Add **`l10n.yaml`** at the project root (config — see
[`templates/l10n.yaml`](templates/l10n.yaml)): it points at `lib/l10n/` for the `.arb` files and emits
`AppLocalizations`. Put the seed file `lib/l10n/app_en.arb` (see
[`templates/app_en.arb`](templates/app_en.arb)) and run:

```bash
flutter gen-l10n          # or `flutter pub get` — codegen runs on build too
```

Wire it into `MaterialApp` (see [`templates/localization_usage.dart`](templates/localization_usage.dart)):

```dart
MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  // locale: ref.watch(localeControllerProvider),  // see §6
)
```

The generated `AppLocalizations` is **the only** way the UI reads text. Hardcoded literals in widgets
are a review failure from here on.

---

## 2. Extraction workflow (the migration pass)

Moving an existing app off hardcoded strings is a four-step loop:

1. **Find candidates.** Run
   [`scripts/extract_strings.py`](scripts/extract_strings.py) over `lib/`. It scans `lib/**/*.dart`
   for user-facing literals — `Text('…')`, `label:`/`hintText:`/`title:`/`tooltip:` arguments,
   `SnackBar`/`AppBar` titles — and emits candidate **key → value** pairs (skipping imports, `Key('…')`,
   logger/`debugPrint` calls, and URLs). `--json` emits a merge-ready map for `app_en.arb`.

   ```bash
   python3 scripts/extract_strings.py lib            # human-readable report
   python3 scripts/extract_strings.py lib --json > new_keys.json
   ```

2. **Name keys.** Use `lowerCamelCase`, scoped by feature: `cartEmptyMessage`, `loginCtaSignIn`,
   `profileGreeting`. Name by *meaning*, not by English wording (`okButton`, not `ok`) — the English
   text changes; the key shouldn't.

3. **Add to ARB** with metadata (`@key` description + placeholders). Merge the script output into
   `lib/l10n/app_en.arb`, then `flutter gen-l10n`.

4. **Replace in code.** Swap each literal for `AppLocalizations.of(context)!.<key>` (alias it:
   `final l10n = AppLocalizations.of(context)!;` at the top of `build`). Re-run the script — it should
   find nothing user-facing left.

> The script is a **finder, not an editor** — it surfaces candidates and proposes keys; a human names
> and replaces. It will have false positives (a `Text` showing a variable, debug labels); that's fine,
> skip them.

---

## 3. ICU message syntax

ARB values use ICU MessageFormat. The three you need constantly:

**Placeholders** — interpolate, and *declare* each in the `@`-metadata with a type:

```json
"greeting": "Hello, {name}!",
"@greeting": {
  "placeholders": { "name": { "type": "String" } }
}
```
→ `l10n.greeting('Sam')`

**Plurals** — never `if (n == 1)` in Dart; let ICU pick the category. Translators add the categories
their language needs (`zero`, `one`, `two`, `few`, `many`, `other`):

```json
"itemCount": "{count, plural, =0{No items} one{1 item} other{{count} items}}",
"@itemCount": { "placeholders": { "count": { "type": "int" } } }
```
→ `l10n.itemCount(3)` → "3 items"

**Select / gender** — branch on a string (e.g. grammatical gender):

```json
"invited": "{gender, select, male{He} female{She} other{They}} invited you",
"@invited": { "placeholders": { "gender": { "type": "String" } } }
```

Use `NumberFormat`/`DateFormat` from `intl` (locale-aware) for numbers, currency, and dates — never
string-format them by hand. See [`templates/app_en.arb`](templates/app_en.arb) for a full example.

---

## 4. RTL audit (Arabic, Hebrew, Persian, Urdu)

Adding an RTL locale flips the layout. Flutter mirrors automatically **only if you used
direction-aware APIs**. Audit for:

| Check | Wrong (LTR-locked) | Right (direction-aware) |
|---|---|---|
| Padding / margin | `EdgeInsets.only(left: 16)` | `EdgeInsetsDirectional.only(start: 16)` |
| Alignment | `Alignment.centerLeft` | `AlignmentDirectional.centerStart` |
| Positioned | `Positioned(left: 0)` | `PositionedDirectional(start: 0)` |
| Text alignment | `TextAlign.left` | `TextAlign.start` |
| Borders / radius | `BorderRadius.only(topLeft: …)` | `BorderRadiusDirectional.only(topStart: …)` |
| Icons (arrows, back) | fixed `Icons.arrow_back` | `Icons.arrow_back` auto-mirrors; for custom art set `matchTextDirection: true` |

- `Directionality` is provided by `MaterialApp` from the locale — don't hardcode `TextDirection.ltr`.
- Test by forcing RTL: wrap a screen in `Directionality(textDirection: TextDirection.rtl, child: …)`
  in a widget test, or run the app with the device set to Arabic.
- Directional icons (chevrons, send) should mirror; logos and brand marks should **not** — leave those
  as plain `Icons`/assets.

---

## 5. Text-expansion & overflow readiness

Translations are longer than English — German/Finnish often **+30–40%**, and pseudolocales longer
still. Before shipping:

- Never `maxLines: 1` a label that must show fully; allow wrap or use `Flexible`/`Expanded`.
- Avoid fixed-width buttons sized to the English string — let them size to content with sensible
  `min`/`max` constraints.
- Don't build sentences by **concatenation** (see anti-patterns) — word order differs per language.
- Pseudo-localize to catch truncation early: temporarily make `app_en.arb` values longer (wrap each in
  `»…«` and pad ~40%), run the app, and look for `…`/clipping. Coordinate with skill **17**
  (Responsive UI) for the overflow-handling widgets.

---

## 6. Locale switching via Riverpod

The active locale is app-lived state — a `keepAlive` Riverpod controller persisted to
`shared_preferences`. The widget watches it and feeds `MaterialApp.locale`; `null` means "follow the
device". See [`templates/localization_usage.dart`](templates/localization_usage.dart) for the full
provider. Follow CONVENTIONS §6 — the controller holds no `BuildContext`, and the switch UI calls a
method, never mutating state in `build`.

```dart
final locale = ref.watch(localeControllerProvider);   // Locale?  (null = system)
MaterialApp(locale: locale, /* delegates + supportedLocales */);
```

---

## 7. Translation management (pre-translate + human review)

ARB scales to many locales: `app_es.arb`, `app_ar.arb`, … each mirroring `app_en.arb`'s keys.

- **Machine pre-translate** new/changed keys (DeepL, Google, or an LLM) to get coverage fast — but
  **flag every machine output for human review**. A simple convention: add `"x-needs-review": true` to
  the `@key` metadata (or keep a `// MT` marker), and clear it once a human confirms. Never ship
  machine output to a user-visible market as final.
- A missing key in a locale falls back to the template (English) at runtime — acceptable temporarily,
  but track coverage so gaps are visible.
- Keep keys in sync: every locale must have the **same key set** as `app_en.arb`. CI can diff key sets
  and fail on drift.

---

## ANTI-PATTERNS — reject these in review

| Anti-pattern | Why it's wrong | Do instead |
|---|---|---|
| Concatenating translated fragments (`l10n.youHave + ' ' + count + ' ' + l10n.items`) | word order/plural rules differ per language; breaks RTL | one ICU message with placeholders/plural |
| Hardcoded `EdgeInsets.only(left:)` / `TextAlign.left` | LTR-locked; breaks in RTL | `EdgeInsetsDirectional.start` / `TextAlign.start` |
| `if (count == 1) 'item' else 'items'` in Dart | wrong for languages with `few`/`many`/`zero` | ICU `plural` with categories |
| Literal string in a widget (`Text('Submit')`) | invisible to localization; a review failure | `l10n.submit` from an ARB key |
| Naming keys after English text (`"submit": "Submit"` → later "Send") | key meaning drifts from value | name by intent (`primaryCtaLabel`) |
| Shipping machine translations unreviewed | embarrassing/incorrect wording in market | flag `x-needs-review`, human-confirm first |
| `DateTime.toString()` / manual number formatting | not locale-aware (separators, calendars) | `intl` `DateFormat`/`NumberFormat` |
| Hardcoding `TextDirection.ltr` | overrides the locale's natural direction | let `MaterialApp` set `Directionality` |

---

## What you produce

1. **Setup** — `l10n.yaml`, `pubspec` flags, `lib/l10n/app_en.arb`, wired `MaterialApp`.
2. **Extraction pass** — ran `extract_strings.py`, named keys, moved literals into ARB, replaced in code.
3. **ICU messages** — plurals/select/placeholders for every dynamic string.
4. **Locale controller** — Riverpod `keepAlive` provider + persisted choice + switch UI.
5. **RTL + expansion audit** — direction-aware widgets; no overflow at +40%.

### Exit-gate checklist

- [ ] No user-facing literal left in widgets (`extract_strings.py` finds nothing actionable).
- [ ] All dynamic text uses ICU placeholders/plural/select — no Dart-side concatenation or `if (n==1)`.
- [ ] `flutter gen-l10n` succeeds; `AppLocalizations` used app-wide; `flutter analyze` clean.
- [ ] RTL audited — direction-aware padding/align/icons; renders correctly in Arabic.
- [ ] No overflow/truncation at +40% text expansion (pseudo-loc pass).
- [ ] Every non-template locale shares the template's key set; machine output flagged for review.

Hand off to **17** (overflow widgets) and **20** (golden tests per locale + RTL).
