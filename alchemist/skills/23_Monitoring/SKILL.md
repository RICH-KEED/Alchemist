---
name: Monitoring
description: Wire production observability into a Flutter app — crash reporting, analytics, performance, and structured logging. Use when adding Sentry/Crashlytics, instrumenting PRD success metrics, capturing frame/trace metrics, or routing logs to breadcrumbs. Pipeline stage 23; completes the crash hooks skills 15/06 left as TODO.
when_to_use: Trigger on "add crash reporting", "wire Sentry", "Crashlytics", "track analytics events", "screen views", "performance monitoring", "set up logging", "why aren't crashes showing in the dashboard", or any request to make production behavior visible. For the global error *contract* defer to skill 15; for consent/privacy policy depth defer to skill 24; for obfuscation/symbol upload mechanics tie to skill 22.
---

# Monitoring (Stage 23 — Ship & Operate)

Stage 23 of [the pipeline](../../references/PIPELINE.md). Make production behavior
**visible**: crashes, key events, performance, and logs all flowing to a dashboard
you actually watch. House style: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md) §1.

You finish what earlier stages stubbed: skill 15 / skill 06 left `// TODO(skill-23)`
markers in the three global error hooks — you fill them. Analytics events come from
the **PRD §7 success metrics** (skill 02). Logging ties to security redaction (skill 13);
symbol upload ties to deployment (skill 22); consent ties to production readiness (skill 24).

**Exit gate:** crashes **and** events are visible in the dashboard (real device, release build).

---

## The four pillars (and where each lives)

| Pillar | Package | Installs at | Reads from |
|---|---|---|---|
| Crash reporting | `sentry_flutter` (or `firebase_crashlytics`) | `lib/core/monitoring/crash_reporting.dart` | error hooks (15/06) |
| Analytics | vendor SDK behind `AnalyticsService` | `lib/core/monitoring/analytics.dart` | PRD §7 metrics (02) |
| Performance | `sentry` traces / `firebase_performance` | wrapped in crash init | key user flows |
| Logging | `logger` | `lib/core/monitoring/app_logger.dart` | everywhere (no PII — 13) |

Copy the four templates into `lib/core/monitoring/`:

| Template | Path | Role |
|---|---|---|
| `crash_reporting.dart` | `core/monitoring/crash_reporting.dart` | `initCrashReporting()` + `runAppGuarded()` |
| `analytics.dart` | `core/monitoring/analytics.dart` | `AnalyticsService` interface, providers, typed events |
| `app_logger.dart` | `core/monitoring/app_logger.dart` | configured `logger` wrapper + breadcrumb route |

---

## 1. Choosing a backend: Sentry vs Firebase Crashlytics

Pick one crash backend. Both satisfy the gate; the tradeoff is breadth vs. depth.

| | **Sentry** (our default) | **Firebase Crashlytics** |
|---|---|---|
| One SDK covers | crashes **+ performance + breadcrumbs + (optional) replay** | crashes only; add `firebase_performance` + `firebase_analytics` separately |
| Backend | self-host or SaaS; not tied to Google | Firebase project required |
| Performance | distributed traces, custom spans, slow/frozen frames | screen rendering + custom traces |
| Releases | first-class release health (crash-free sessions/users) | crash-free users; Play integration |
| Cost | event-quota based | free |
| Best when | you want one tool for crashes + perf + logs, vendor-neutral | you already live in Firebase (Analytics, Remote Config, Auth) |

**Default to Sentry** because it unifies crashes, performance, and breadcrumbs in one
init and stays vendor-neutral. **Choose Crashlytics** if the app already uses Firebase —
then pair it with `firebase_analytics` and `firebase_performance`. The templates show
Sentry as primary with a Crashlytics swap-in note; analytics is abstracted (§3) so the
vendor is swappable either way.

---

## 2. Wiring crash reporting into the global hooks (the skill 15/06 TODOs)

Skill 15 defined three nets and skill 06's `main.dart` left them as `// TODO(skill-23)`.
You now forward each to the crash reporter. The whole app boots **inside the reporter's
own zone** so async errors are captured — use `runAppGuarded` from the template instead
of a hand-rolled `runZonedGuarded`.

```dart
// lib/main.dart — replaces the stubbed bootstrap from skill 06
import 'core/monitoring/crash_reporting.dart';

Future<void> main() => runAppGuarded(
      () => const ProviderScope(child: App()),
    );
```

`initCrashReporting()` (called by `runAppGuarded`) sets all three hooks:

- **`FlutterError.onError`** — synchronous framework errors (build/layout/paint).
  In release, forward to the reporter; in debug, still `presentError` so you see the red box.
- **`PlatformDispatcher.instance.onError`** — uncaught async / platform-channel errors.
  Forward, then `return true` (handled). Never `return true` *silently* (skill 15 anti-pattern).
- **`runZonedGuarded`** — the outermost catch-all wrapping `runApp`; zone errors are fatal.

With Sentry, `SentryFlutter.init(... appRunner: () => runApp(...))` installs the framework
hook for you; you still set `PlatformDispatcher.onError` and keep the guarded zone. The
template shows exactly which lines Sentry owns vs. which you set by hand.

> Skill 15's `mapError`/`Failure` still runs first at the data boundary. The crash hooks
> are the **last** net for things that escape `Result` — not a replacement for it.

### Uploading obfuscation symbols / mapping (ties to skill 22)

Release builds are obfuscated (skill 13 `--obfuscate --split-debug-info`), so dashboard
stack traces are garbage until you upload the symbols produced at build time:

- **Sentry:** upload Dart debug-info + native symbols via `sentry_dart_plugin`
  (`flutter packages pub run sentry_dart_plugin`) or the CLI, keyed by release+dist.
- **Crashlytics:** upload the Android mapping (`uploadCrashlyticsMappingFile` / Gradle
  plugin) and NDK symbols.

This step belongs in the **stage 22 release job** (CI), keyed to the same version/build
number you set the reporter's `release`/`dist` to — otherwise symbolication can't match.

---

## 3. Analytics — a swappable abstraction over the PRD metrics

**Never call a vendor SDK directly from a widget.** Define an `AnalyticsService`
interface (template `analytics.dart`) so the vendor is one provider override away, and
so debug never pollutes the dashboard.

```dart
abstract interface class AnalyticsService {
  Future<void> logScreenView(String screenName);
  Future<void> logEvent(String name, {Map<String, Object?> params});
  Future<void> setUserId(String? id);            // null on sign-out
  Future<void> setConsent({required bool enabled});
}
```

Implementations:
- **`NoopAnalytics`** — used in **debug** and before consent; logs to `logger` only.
- **`SentryAnalytics` / `FirebaseAnalyticsService`** — the real vendor (thin sketch in template).

The provider picks the impl by build mode + consent, so you wire it once:

```dart
final svc = ref.read(analyticsServiceProvider);
await svc.logEvent(AppEvent.runLogged, params: {'distance_m': 4200});
```

**Events come from PRD §7, not from vibes.** Each "How measured → stage 23" row in the PRD
metrics table becomes one typed event constant. Define them in **one place** (`AppEvent`)
so they're greppable and renames are compile-safe:

| PRD metric (§7) | Typed event | Where fired |
|---|---|---|
| Activation ("aha") | `AppEvent.activated` | controller, on first core action |
| Task success (core loop) | `AppEvent.coreLoopCompleted` | success path of the loop |
| Engagement (key action) | `AppEvent.<keyAction>` | the action's controller |
| Screen views | `logScreenView` | router observer (skill 07) |

Fire **screen views** automatically from a `go_router` `NavigatorObserver` (skill 07);
fire **key events** from controllers in `application/` — not from `build`. Keep params
typed and minimal.

### Consent & data minimization (privacy — ties to skill 24)

- **Opt-in by default off** where the platform/PRD requires it. Gate analytics *and*
  non-essential crash data behind `setConsent(enabled: true)`; `NoopAnalytics` until then.
- **Minimize**: log event *names* and coarse, non-identifying params. No emails, no exact
  location, no free-text the user typed. Never send a `userId` that is itself PII —
  use an opaque app id.
- Respect deletion: `setUserId(null)` and a consent-revoke path that stops collection.
  Skill 24 owns the privacy-policy / data-safety form; this skill must match what it declares.

---

## 4. Performance monitoring

Instrument **the flows the PRD cares about**, not everything.

- **Key flows as transactions/traces.** Wrap a flow (app start → first frame, search →
  results, checkout) in a Sentry transaction (`Sentry.startTransaction`) or a Firebase
  custom trace; add spans for sub-steps (network, parse, render). This is how you find
  *which* step is slow, not just that the screen is.
- **Frame metrics.** Enable slow/frozen-frame reporting (`enableAutoPerformanceTracing`).
  Janky builds surface as frame drops tied to a screen — complements skill 09's 60fps gate.
- **Sample.** Set `tracesSampleRate` < 1.0 in production (e.g. 0.2) to control volume/cost;
  keep 1.0 in staging.
- **App start.** Both backends measure cold/warm start automatically once initialized
  before `runApp` — which `runAppGuarded` ensures.

---

## 5. Structured logging with `logger`

`app_logger.dart` exposes a single configured `AppLog` wrapper around the `logger` package.
Use it everywhere instead of `print`/`debugPrint` (CONVENTIONS §1 forbids `print`).

- **Levels:** `trace` / `debug` (dev only) · `info` (lifecycle, key events) · `warning`
  (handled degradations) · `error` (a `Failure` was produced) · `fatal` (about to crash).
- **Release filter:** in release, drop `trace`/`debug` — only `info`+ ship. Debug shows all
  with a pretty printer; release uses a terse, parse-friendly printer.
- **No PII / no secrets (ties to skill 13).** Never log tokens, passwords, full request
  bodies, emails, or precise location. Route values through a `redact()` helper; when in
  doubt, log an id or a count, not the value.
- **Logs → breadcrumbs.** `warning`+ logs are forwarded to the crash reporter as
  **breadcrumbs** so a crash arrives with the trail that led to it. The template wires this
  via a `logger` output that calls `Sentry.addBreadcrumb` (or `Crashlytics.log`).

Skill 15's contract — "every `Failure` is logged exactly once with its cause/stackTrace" —
is satisfied here: log at `error` where the `Failure` is created, and that single line also
becomes the crash breadcrumb.

---

## Release vs debug behavior (don't spam the dashboard)

| | Debug | Release |
|---|---|---|
| Crash reporter | **disabled** (or DSN empty) — keep the red error box | enabled, real DSN |
| Analytics impl | `NoopAnalytics` (logs only) | real vendor, **after consent** |
| Log levels | all, pretty printer | `info`+, terse printer |
| Trace sample rate | 1.0 (local) | sampled (e.g. 0.2) |

Branch on `kReleaseMode` (and a build-time DSN/flavor). A debug session must never create
events in the production project — it makes the dashboard untrustworthy and the gate meaningless.

---

## Anti-patterns (reject in review)

- **Vendor SDK in a widget** — go through `AnalyticsService`; widgets don't know the vendor.
- **Logging PII/secrets** — tokens, emails, bodies, precise location. Redact or drop.
- **`print` / `debugPrint` for app logging** — use `AppLog`.
- **Reporting from debug** — pollutes the dashboard; gate on `kReleaseMode`.
- **Crashes without symbols** — uploading mapping/debug-info (skill 22) is part of *done*,
  not optional; unsymbolicated traces fail the spirit of the gate.
- **Swallowing in the global hook** — forward *then* `return true`; never silent (skill 15).
- **Analytics events invented ad-hoc** — every event traces to a PRD §7 metric.
- **Collecting before consent** — gate analytics + non-essential crash data on `setConsent`.

---

## Exit gate checklist

- [ ] One crash backend chosen (Sentry default) and initialized **before** `runApp`.
- [ ] All three hooks forward to the reporter via `runAppGuarded` — skill 15/06 TODOs gone.
- [ ] A test crash from a **release build on a real device** appears in the dashboard,
      **symbolicated** (mapping/debug-info uploaded in the stage 22 job).
- [ ] `AnalyticsService` interface + provider; debug uses `NoopAnalytics`.
- [ ] Every PRD §7 metric maps to a typed `AppEvent`; screen views fire from the router.
- [ ] Performance: key flows traced; slow/frozen frames + app-start visible; release sampled.
- [ ] `AppLog` is the only log path; `info`+ in release; `warning`+ become breadcrumbs.
- [ ] Consent gate present; no PII/secrets in any payload (logs, events, breadcrumbs).
- [ ] Debug never writes to the production project.

See the stage→artifact→gate map in [`../../references/PIPELINE.md`](../../references/PIPELINE.md).
