# Data Safety Mapping — Flutter SDKs & Permissions → Play Data Types

This is the **knowledge table** the skill reasons from. Each row is a *default* (a prior) — verify
against the SDK's docs and your actual usage before declaring. Columns:

- **Data type** — the Google Play Data Safety category.
- **Collected** — leaves the device (your server *or* an SDK's server).
- **Shared** — sent to a *third party* (an ad/attribution network counts).
- **Purpose** — Play's fixed purpose list.
- **Apple type** — the matching `NSPrivacyCollectedDataType*` for the iOS manifest.

> "Collected" is the load-bearing question. On-device-only processing is **not** collected. A
> permission grants *capability*, not collection — resolve "does it leave the device?" per app.

---

## 1. SDK families → data types

| SDK family | Example packages | Typically collects | Play data type(s) | Collected | Shared | Purpose | Apple type |
|---|---|---|---|---|---|---|---|
| Analytics | `firebase_analytics`, `amplitude_flutter`, `mixpanel_flutter`, `posthog_flutter`, `segment` | events, screen views, device/OS, app interactions, sometimes ad ID | App activity; Device or other IDs | Yes | Usually no (your backend) | Analytics | `…ProductInteraction`, `…DeviceID` |
| Crash / diagnostics | `firebase_crashlytics`, `sentry_flutter` | crash logs, stack traces, device model, OS, breadcrumbs | App info & performance (Crash logs, Diagnostics) | Yes | No | App functionality, Analytics | `…CrashData`, `…PerformanceData` |
| Performance | `firebase_performance` | trace timings, network metrics, device/OS | App info & performance | Yes | No | Analytics, App functionality | `…PerformanceData` |
| Ads / attribution | `google_mobile_ads`, `applovin_max`, `appsflyer_sdk`, `facebook_app_events`, `unity_ads` | advertising ID, device IDs, approx location, usage for targeting | Device or other IDs; Location (approx); App activity | Yes | **Yes (shared)** | Advertising/marketing, Analytics | `…DeviceID`, `…CoarseLocation`, `…AdvertisingData` |
| Auth / identity | `firebase_auth`, `google_sign_in`, `sign_in_with_apple`, `supabase_flutter` | email, name, user ID, sometimes phone/photo | Personal info (Email, Name, User IDs) | Yes | No (your auth) | Account management, App functionality | `…EmailAddress`, `…Name`, `…UserID` |
| Location | `geolocator`, `location`, `google_maps_flutter`, `flutter_map` | precise and/or approximate location | Location (Precise and/or Approximate) | If sent off-device | Depends | App functionality | `…PreciseLocation`, `…CoarseLocation` |
| Messaging / push | `firebase_messaging`, `onesignal_flutter` | device push token, device ID, app activity | Device or other IDs; App activity | Yes | No (or vendor) | App functionality, Developer comms | `…DeviceID` |
| Payments | `in_app_purchase`, `flutter_stripe`, `purchases_flutter` (RevenueCat) | purchase history, partial payment info (processor holds PAN) | Financial info (Purchase history, Payment info) | Yes | Processor | App functionality, Account management | `…PaymentInfo`, `…PurchaseHistory` |
| Media / files | `image_picker`, `camera`, `file_picker` | photos/videos, files (only if uploaded/shared) | Photos & videos; Files & docs | Only if uploaded | No | App functionality | `…Photos`, `…OtherUserContent` |
| Contacts | `contacts_service`, `flutter_contacts` | contact names, numbers, emails | Contacts | Only if uploaded | Depends | App functionality | `…Contacts` |
| Health / sensors | `health`, `sensors_plus` | health & fitness, device sensor data | Health and fitness | If sent off-device | No | App functionality | `…HealthData`, `…FitnessData` |
| Storage utilities | `shared_preferences`, `path_provider`, `sqflite`, `hive`, `flutter_secure_storage` | none collected — on-device only | (none) | No | No | — | — (but trigger Apple required-reason APIs, see §3) |
| Device info | `device_info_plus`, `package_info_plus` | device model, OS version, app version | Device or other IDs (if sent) | If sent | No | Analytics | `…DeviceID` |

> Packages not in this table → **list under "review manually"**, look up the vendor's data
> practices, and add a row. Never silently assume "no collection" for an unknown SDK.

---

## 2. Android permissions → implied data type

A permission means the app *can* access something. Declare it collected **only if** the data leaves
the device or is fed to an SDK. Resolve the "Collected off-device?" question per app.

| Permission | Implied data type | Play data type | Resolve: collected off-device? |
|---|---|---|---|
| `ACCESS_FINE_LOCATION` | precise location | Location (Precise) | Sent to backend/maps/ads SDK? |
| `ACCESS_COARSE_LOCATION` | approximate location | Location (Approximate) | Same |
| `ACCESS_BACKGROUND_LOCATION` | location while backgrounded | Location | Strong scrutiny — must justify |
| `CAMERA` | photos/videos | Photos and videos | Uploaded, or local capture only? |
| `RECORD_AUDIO` | audio / voice | Audio (Voice or sound recordings) | Sent off-device? |
| `READ_CONTACTS` | contacts | Contacts | Uploaded/synced? |
| `READ_EXTERNAL_STORAGE` / `READ_MEDIA_*` | files, photos | Files & docs; Photos | Uploaded? |
| `READ_PHONE_STATE` | phone number, device IDs | Phone number; Device IDs | Rarely needed — justify |
| `BODY_SENSORS` / health | health & fitness | Health and fitness | Sent off-device? |
| `BLUETOOTH_CONNECT` | nearby devices | (context-specific) | What is read & sent? |
| `POST_NOTIFICATIONS` | (capability only) | — | No data type by itself |
| `INTERNET` | (capability only) | — | Enables all collection above |
| `AD_ID` (`com.google.android.gms.permission.AD_ID`) | advertising ID | Device or other IDs | Yes if ads SDK present |

> Android 13+ requires declaring the `AD_ID` permission if you use the advertising ID; its presence
> is a strong signal of ads/tracking and should flip the iOS manifest's `NSPrivacyTracking` to true.

---

## 3. Apple required-reason APIs triggered by common Flutter plugins

For `PrivacyInfo.xcprivacy` → `NSPrivacyAccessedAPITypes`. Declare the category **and** an approved
reason code (see the manifest example for the literal strings).

| Plugin(s) | API category | Typical approved reason |
|---|---|---|
| `shared_preferences` | `NSPrivacyAccessedAPICategoryUserDefaults` | `CA92.1` (access info from same app) |
| `path_provider`, `sqflite`, `hive` | `NSPrivacyAccessedAPICategoryFileTimestamp` | `C617.1` / `DDA9.1` |
| `device_info_plus`, `package_info_plus` | `NSPrivacyAccessedAPICategorySystemBootTime` | `35F9.1` |
| disk-space checks, file pickers | `NSPrivacyAccessedAPICategoryDiskSpace` | `E174.1` / `85F4.1` |
| keyboard-aware UI | `NSPrivacyAccessedAPICategoryActiveKeyboards` | `54BD.1` |

Missing a required-reason declaration is a **hard App Store rejection** (enforced since 2024).

---

## 4. Filled answer table (one row per declared data type)

Fill this from the scanner output + your own data-flow grep. This is the artifact a human verifies.

| Data type | Source (SDK / permission / your code) | Collected | Shared | Purpose(s) | Optional? | Encrypted in transit | Deletion path | Confidence |
|---|---|---|---|---|---|---|---|---|
| _e.g._ App activity | `firebase_analytics` | Yes | No | Analytics | Consent-gated (#23) | Yes (TLS, #13) | Account delete | Detected |
| _e.g._ Device or other IDs | `google_mobile_ads`, `AD_ID` perm | Yes | **Yes** | Advertising | No | Yes | n/a | Detected |
| _e.g._ Email address | `firebase_auth` | Yes | No | Account management | Required | Yes | Account delete | Detected |
| _… add a row per detected type …_ | | | | | | | | |

**Confidence** = `Detected` (in inputs) · `Assumed` (SDK default, usage unconfirmed) · `Review`
(unknown SDK / custom flow). Resolve every `Review` before filing.

See the skill body for how each column maps to the Play Console form.
