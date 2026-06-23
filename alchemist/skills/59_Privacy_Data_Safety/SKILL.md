---
name: Privacy Manifest & Play Data-Safety Generator
description: Scan a Flutter/Android app's SDKs, permissions, and data flows to auto-draft the Google Play Data Safety form, the iOS privacy manifest (PrivacyInfo.xcprivacy), and a privacy-policy starting draft — so store submissions aren't rejected for wrong or missing data declarations. Use when prepping a Play/App Store release, filling the Data Safety form, adding a required iOS privacy manifest, or writing a first privacy policy.
when_to_use: Trigger on "fill the Data Safety form", "data safety declaration", "privacy manifest", "PrivacyInfo.xcprivacy", "required reason API", "draft a privacy policy", "what data does my app collect", "store rejected my privacy answers", or stage 24's privacy line item. Advisory only — a human verifies and signs every declaration. For consent wiring see #23, for secret storage see #13, for the launch gate see #24.
---

# Privacy Manifest & Play Data-Safety Generator

You draft three **store-submission privacy artifacts** from what the app actually contains:

1. **Google Play Data Safety** answers (the form in Play Console → App content → Data safety).
2. The **iOS privacy manifest** (`PrivacyInfo.xcprivacy`) — required-reason APIs + tracking + collected data types.
3. A **privacy-policy starting draft** the team finishes and hosts at a live URL.

Method: enumerate dependencies + Android permissions + observable data flows → map each to the
**data types** it plausibly collects → translate those into the **Play data categories** (collected
vs shared, purpose, optional, encryption-in-transit, deletion) and the **Apple privacy nutrition
labels / required-reason API** entries → assemble a policy from the same facts. House style:
[`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).

> **Advisory, not authoritative.** You produce a **draft to verify**, never a filed declaration.
> The SDK→data-type knowledge is a prior, not ground truth — a vendor may collect more or less than
> the default, and your own code may collect things no SDK reveals. **A human confirms every line
> against real behavior before submitting.** Over-declaring wastes nothing; under-declaring gets the
> app rejected or pulled. When unsure, flag it for review — don't guess silently.

**Where this sits:** the privacy line items of stage **#24 (Production Readiness)** depend on this
draft. It must stay consistent with **#23 (Monitoring)** — what analytics/crash SDKs are wired and
what consent gates them — and with **#13 (Security)** — encryption in transit/at rest is a Data
Safety answer. If #23 says "analytics gated on consent", this skill must declare that, not contradict it.

---

## First actions when invoked

1. **Locate the inputs.** `pubspec.yaml` (declared SDKs), `android/app/src/main/AndroidManifest.xml`
   (permissions + any `<meta-data>` SDK keys), and — if present — `ios/Runner/Info.plist` (usage
   strings) and the monitoring layer from #23 (`lib/core/monitoring/`).
2. **Run the scanner** (below) to enumerate data-collecting SDKs + permissions and their likely Play
   categories. Treat its output as a **starting hypothesis**, not a verdict.
3. **Read your own data flows.** The scanner sees declared deps; it cannot see custom forms, a
   backend you POST to, or a `userId` you attach. Grep the app for collection you wrote yourself
   (sign-up forms, location reads, file pickers, contact access, payment fields).
4. **Map → declare → draft** using the templates, then hand the human a verification checklist.

## The SDK → data-type knowledge approach

Each common SDK has a **default data-practice profile** — what category of data it typically
collects when wired the normal way. The lookup lives in
[`templates/data_safety_mapping.md`](templates/data_safety_mapping.md); the script encodes the same
table. Reason by **SDK family**, because vendors in a family behave alike:

| Family | Examples | Typically collects | Play data type |
|---|---|---|---|
| **Analytics** | `firebase_analytics`, `amplitude`, `mixpanel`, `posthog` | usage events, screen views, device/OS, app interactions, sometimes an advertising ID | App activity, Device IDs |
| **Crash / perf** | `firebase_crashlytics`, `sentry_flutter`, `firebase_performance` | crash logs, diagnostics, device model, OS, stack traces (may contain breadcrumbs) | App info & performance, Diagnostics |
| **Ads / attribution** | `google_mobile_ads`, `applovin`, `appsflyer`, `facebook_app_events` | advertising ID, device IDs, approximate location, usage for ad targeting | Device IDs, Location, **shared** + advertising purpose |
| **Auth / identity** | `firebase_auth`, `google_sign_in`, `sign_in_with_apple` | email, name, user IDs, sometimes phone | Personal info (email, name, user IDs) |
| **Location** | `geolocator`, `location`, `google_maps_flutter` | precise or approximate location | Location |
| **Messaging / push** | `firebase_messaging`, `onesignal` | device push token, device ID, app activity | Device IDs, App activity |
| **Payments** | `in_app_purchase`, `stripe`, `flutter_stripe` | purchase history, partial payment info (processor handles PAN) | Financial info, Purchase history |
| **Media / storage** | `image_picker`, `file_picker`, `camera`, `contacts_service` | photos/videos, files, contacts (only if uploaded/shared off-device) | Photos/Videos, Files, Contacts |

**Permissions are a second, independent signal.** A permission proves *capability*, not collection —
`ACCESS_FINE_LOCATION` means the app *can* read precise location; you declare it as collected only if
it **leaves the device** or is sent to an SDK. The mapping table lists each common permission's
implied data type and the "collected vs on-device-only" question to resolve.

## Mapping to Google Play Data Safety

For every data type the inputs surface, answer the form's columns honestly:

- **Collected?** Does the data leave the device (sent to your server or any SDK's server)? On-device-only
  processing is **not** "collected".
- **Shared?** Does it go to a *third party* (an ads/attribution SDK sharing with its network counts as
  sharing). Analytics to your own backend is collected-not-shared; an ad SDK is usually shared.
- **Purpose** — pick from Play's fixed list: App functionality, Analytics, Developer communications,
  Advertising/marketing, Fraud prevention, Personalization, Account management. One data type can have
  several.
- **Optional vs required** — can the user use the app without providing it? Optional if it's behind a
  prompt the user can decline (e.g. location only after they tap "find nearby").
- **Encrypted in transit** — true if all collection uses HTTPS/TLS (it must — #13 enforces no cleartext).
- **User can request deletion** — does the app expose a delete-my-data path? Ties to your account
  deletion flow; Play also requires an account-deletion URL if the app has accounts.

Record each decision in [`templates/data_safety_mapping.md`](templates/data_safety_mapping.md)'s answer
table so the human can diff it against the SDK defaults and against reality.

## Mapping to the Apple privacy manifest

`PrivacyInfo.xcprivacy` (template [`templates/PrivacyInfo.xcprivacy.example`](templates/PrivacyInfo.xcprivacy.example))
has four required-by-Apple keys:

- **`NSPrivacyTracking`** — `true` only if the app tracks (links user/device data to third-party data
  for ads, or shares a device ID with a data broker/ad network). Ads/attribution SDKs flip this to true.
- **`NSPrivacyTrackingDomains`** — every domain that does tracking; the app must show ATT before
  reaching them. List the ad/attribution SDK endpoints.
- **`NSPrivacyCollectedDataTypes`** — the Apple nutrition-label equivalents of your Play data types
  (`NSPrivacyCollectedDataTypeEmailAddress`, `…DeviceID`, `…CrashData`, `…PreciseLocation`, etc.),
  each with linked/tracking flags and purposes.
- **`NSPrivacyAccessedAPITypes`** — **required-reason APIs**. If the app (or an SDK) calls
  `UserDefaults`, file-timestamp, system-boot-time, disk-space, or active-keyboard APIs, you must
  declare the API category **and** an approved reason code. Many Flutter plugins (`shared_preferences`,
  `path_provider`, `sqflite`, `package_info_plus`, `device_info_plus`) hit these — the template lists
  the common category→reason pairs. Missing this is a **hard App Store rejection** since 2024.

> Flutter apps still ship an iOS privacy manifest even when Android is the lead platform, because the
> same SDKs are used. Each third-party SDK on Apple's "commonly used" list should also ship *its own*
> manifest; you declare what *your* code triggers and verify the SDKs include theirs.

## Drafting the privacy policy

From the same enumerated facts, fill [`templates/privacy_policy_template.md`](templates/privacy_policy_template.md):
what you collect, why, who you share with (name the SDK vendors), retention, the user's rights
(access/delete/opt-out), children's-data stance, and contact. **Every "we collect X" line must trace
to a declared data type** — the policy, the Data Safety form, and the manifest are three views of one
truth and **must agree**. A reviewer who finds the policy admitting something the form omits will
reject the app.

## Keeping it truthful (the cardinal rule)

- **Declare what the code does, not what the marketing says.** If `firebase_analytics` is in pubspec
  and initialized, you collect usage + device data — declare it even if "we don't really use it".
- **Consent changes "collected", not the SDK list.** If analytics is gated behind opt-in (#23),
  declare the data type but note collection is optional/consent-based. The SDK present ≠ unconditional
  collection, but a present-and-default-on SDK *is* collection.
- **Three artifacts, one set of facts.** Policy ⊇ Data Safety ⊇ manifest must be consistent. Diff them.
- **Re-run on every dependency change.** Adding an ad SDK changes all three artifacts and may flip
  `NSPrivacyTracking` to true. Wire this into the pre-release checklist (#24).

## Running the scanner

```bash
python "${CLAUDE_SKILL_DIR}/scripts/scan_data_collection.py" .            # table for the project root
python "${CLAUDE_SKILL_DIR}/scripts/scan_data_collection.py" . --json     # machine-readable
python "${CLAUDE_SKILL_DIR}/scripts/scan_data_collection.py" \
    --pubspec pubspec.yaml --manifest android/app/src/main/AndroidManifest.xml
```

It reads `pubspec.yaml` + `AndroidManifest.xml`, matches each SDK and permission against the built-in
knowledge table, and lists detected data-collecting SDKs/permissions with their likely Play data
categories, collected/shared guesses, and whether they imply tracking. **Stdlib only, no network.**
`--json` emits the structured findings to feed the templates. Unknown SDKs are listed under "review
manually" — they are not silently dropped.

## Output discipline

- Map from **evidence** (a line in pubspec, a permission in the manifest, a flow you grepped) — cite it.
- Separate **detected** (in the inputs) from **assumed** (the SDK default) from **needs human review**.
- Lead the hand-off with the **verification checklist**: every declared line for a human to confirm
  or correct before filing. You draft; the human signs and submits.
- Keep all three artifacts in sync and route encryption/consent questions to #13/#23.

See the SDK→data table in [`templates/data_safety_mapping.md`](templates/data_safety_mapping.md),
the manifest in [`templates/PrivacyInfo.xcprivacy.example`](templates/PrivacyInfo.xcprivacy.example),
and the policy in [`templates/privacy_policy_template.md`](templates/privacy_policy_template.md).
