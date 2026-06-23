# Curated Package Map — common Flutter needs → recommended package(s)

A **starting point**, not a verdict. This is the engine's seed list of common
capability needs and the package(s) that usually win the recommendation rubric.
It is curated, not live.

> ⚠️ **Re-verify every pick with live #56 data before recommending.** Health,
> licenses, and maintenance change month to month. Run
> `dep_health.py --packages <name> --osv` and apply the rubric in
> [`recommendation_rubric.md`](recommendation_rubric.md). If the curated pick has
> gone stale or grown an advisory, switch to the fallback.

House stack (these needs are **already decided** — confirm, don't re-litigate):
[`../../../references/CONVENTIONS.md`](../../../references/CONVENTIONS.md).

Legend: 🏠 = house default from CONVENTIONS (use it). 🥇 = recommended pick for an
unassigned need. 🥈 = typical fallback. ⭐ = first-party / Flutter Favorite.

---

## Already chosen by the house stack (confirm, don't shop)

| Need | House default | Notes |
|---|---|---|
| State management | 🏠 `flutter_riverpod` + `riverpod_generator` / `riverpod_lint` | Testable, no `BuildContext` coupling. Reject `GetX`/`provider` as duplicates. |
| Immutable models | 🏠 `freezed` + `json_serializable` | Unions, copyWith, value equality. |
| Networking / HTTP | 🏠 `dio` (+ `retrofit` optional) | Interceptors, cancellation, error mapping. Reject second HTTP client. |
| Routing | 🏠 `go_router` ⭐ | Declarative, deep-link & Android App Links ready. |
| Local DB | 🏠 `drift` or `isar` | drift = SQL/relational; isar = fast NoSQL. Pick per data shape. |
| Key-value prefs | 🏠 `shared_preferences` ⭐ | Simple unencrypted settings. |
| Secure storage | 🏠 `flutter_secure_storage` | Keystore-backed secrets/tokens. |
| Lints | 🏠 `very_good_analysis` | Strict house lint set. |
| Codegen runner | 🏠 `build_runner` | freezed/json/riverpod generation. |
| Crash / analytics | 🏠 `sentry_flutter` **or** `firebase_crashlytics` + analytics | Observability from day one. |
| Logging | 🏠 `logger` | Never `print`. |
| Mocking (test) | 🏠 `mocktail` | Null-safe, no codegen. |
| Asset/codegen typing | 🏠 `flutter_gen` | No stringly-typed asset paths. |

---

## Unassigned needs → recommended pick + fallback (re-verify live)

| Need | 🥇 Recommend | 🥈 Fallback | One-line rationale + house-stack fit |
|---|---|---|---|
| Charts / graphs | `fl_chart` 🥇 | `syncfusion_flutter_charts` | fl_chart is pure-Dart, MIT, widely used — light & themeable; Syncfusion is far richer but check its community license terms (route to #58). Feed it data from a Riverpod provider. |
| Image picker (gallery/camera) | `image_picker` ⭐ 🥇 | `wechat_assets_picker` | First-party platform plumbing; tracks the SDK. Use `wechat_assets_picker` only if you need a custom multi-select gallery UI. Wrap behind a repository returning `Result`. |
| Permissions | `permission_handler` 🥇 | `flutter_permissions` (rarely) | De-facto standard, maintained, Android+iOS. Request inside an application-layer service, not in `build`. |
| Local notifications | `flutter_local_notifications` 🥇 | `awesome_notifications` | Mature, MIT, Android channels supported; awesome_notifications for rich/scheduled UI. Schedule via a provider-backed service. |
| Push notifications | `firebase_messaging` 🥇 | `onesignal_flutter` | FCM is the Android-native path; OneSignal if you want a managed dashboard. Token + handlers behind a notifier. |
| Date / time utils | `intl` ⭐ 🥇 | `jiffy` | First-party i18n + formatting; `jiffy` adds moment.js-style manipulation if needed. Keep formatting in presentation, not domain. |
| Forms / validation | `flutter_form_builder` + `form_builder_validators` 🥇 | `reactive_forms` | Declarative fields + ready validators; `reactive_forms` if you prefer reactive streams. Bind submit to a Riverpod controller. |
| Connectivity / offline | `connectivity_plus` ⭐ 🥇 | `internet_connection_checker_plus` | Flutter-community, Favorite; pair with a checker for real reachability (#14). Expose as a stream provider. |
| Caching network images | `cached_network_image` 🥇 | `extended_image` | Mature, MIT, disk+memory cache; extended_image adds zoom/editing. Render inside the data async state. |
| SVG rendering | `flutter_svg` 🥇 | `vector_graphics` ⭐ | flutter_svg is the standard; vector_graphics (first-party) for precompiled performance. Type assets via `flutter_gen`. |
| App icon / splash | `flutter_launcher_icons` + `flutter_native_splash` 🥇 | — | Build-time generators for adaptive icon + splash (#10). Dev dependencies only. |
| URL / deep link launch | `url_launcher` ⭐ 🥇 | — | First-party; opens URLs, tel, mailto. Deep-link routing itself stays in `go_router` (#07). |
| File system paths | `path_provider` ⭐ 🥇 | — | First-party; canonical app/temp/docs dirs. Use under `data` for DB/file storage. |
| Device / app info | `device_info_plus` + `package_info_plus` ⭐ 🥇 | — | Flutter-community Favorites; version & device facts for analytics/diagnostics (#23). |
| Biometric auth | `local_auth` ⭐ 🥇 | — | First-party fingerprint/face unlock (#13). Gate behind secure-storage-backed flow. |
| In-app purchases | `in_app_purchase` ⭐ 🥇 | `purchases_flutter` (RevenueCat) | First-party for direct store billing; RevenueCat if you want managed entitlements. Wrap in a repository returning `Result`. |
| Maps | `google_maps_flutter` ⭐ 🥇 | `flutter_map` | First-party Google Maps for Android; `flutter_map` (OSM) if you must avoid Google or its size. Note the heavy native footprint. |
| PDF view / generate | `printing` + `pdf` 🥇 | `syncfusion_flutter_pdfviewer` | `pdf`/`printing` are MIT and pure-Dart-ish for generation; Syncfusion viewer for rich viewing (check license, #58). |
| Animations (extra) | `flutter_animate` 🥇 | `lottie` | flutter_animate for declarative micro-interactions (#09); `lottie` for designer JSON animations. Keep durations in `AppTokens`. |
| WebView | `webview_flutter` ⭐ 🥇 | `flutter_inappwebview` | First-party for standard embedding; inappwebview for advanced JS-bridge/control needs. |
| Env / config | `envied` 🥇 | `flutter_dotenv` | `envied` is compile-time + obfuscatable (better for secrets, #13); dotenv for simple runtime config. Never commit secrets. |
| Internationalization | `intl` ⭐ + `flutter_localizations` 🥇 | `slang` | First-party ARB workflow; `slang` for type-safe codegen keys if you prefer. |
| Equality / value (non-model) | `equatable` 🥇 | (use `freezed`) | Lightweight `==`/`hashCode` for small value types; prefer 🏠 `freezed` for real domain models. |

---

## How to use this map in a recommendation

1. Find the need's row. If it's a 🏠 house default → confirm it's still healthy
   and recommend it; done.
2. If unassigned → take the 🥇 pick and 🥈 fallback as **candidates**, add any
   first-party peer, and run them through `dep_health.py` + the rubric.
3. If the curated 🥇 has gone stale, grown an advisory, or its license changed →
   promote the 🥈 fallback (or search pub.dev for a fresher peer) and note why.
4. Output the recommendation block from
   [`recommendation_rubric.md`](recommendation_rubric.md): one pick, one
   fallback, evidence, stack-fit, handoff to #11/#06/#32 and #58.
