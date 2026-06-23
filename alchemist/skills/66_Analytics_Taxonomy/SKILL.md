---
name: analytics-taxonomy
description: Design a typed, privacy-safe analytics event taxonomy from PRD success metrics — auto-instrument screen views, user actions, business outcomes, and errors tied to Firebase Analytics and stage 23 monitoring
when_to_use: When a PRD (stage 02) defines measurable success metrics that need an analytics schema — triggers after the PRD is approved and before monitoring wiring (stage 23)
---

# 66 — Analytics Taxonomy

**Exit gate:** every PRD success metric has mapped events; key funnel instrumented; taxonomy compiles and matches analytics schema; privacy consent gating wired.

Links: [Conventions](../../references/CONVENTIONS.md) | [Pipeline](../../references/PIPELINE.md)

---

## 1. Reading PRD Success Metrics (from Stage 02)

Input is the PRD from skill `02_PRDs_and_Success_Metrics`. Extract:
- **Quantitative goals**: e.g. "onboarding completion rate > 70%"
- **Conversion milestones**: e.g. "checkout page to payment success > 45%"
- **Feature-adoption targets**: e.g. "30% of DAU use new search by week 4"
- **Error / crash bounds**: e.g. "crash-free rate > 99.5%"

For every metric, answer: *"What event(s) must fire for this to be measurable?"* Map each metric to one or more concrete events. If a metric cannot be traced to an event, flag it — either the PRD is underspecified or the product needs a custom logger.

### Example mapping

| PRD metric | Event(s) |
|---|---|
| Onboarding completion > 70% | `onboarding_step1_started`, `onboarding_step2_completed`, `onboarding_step3_completed` |
| Checkout conversion > 45% | `checkout_payment_started`, `checkout_payment_succeeded`, `checkout_payment_failed` |
| Search adoption > 30% DAU | `search_query_submitted`, `search_result_tapped` |
| Crash-free > 99.5% | `error_crash`, `error_recoverable` |

---

## 2. Event Taxonomy Design

Four categories cover all analytics needs. Every event belongs to exactly one:

| Category | Trigger | Example |
|---|---|---|
| `screen_view` | Route change (automatic via go_router observer) | `screen_checkout_payment` |
| `user_action` | Intentional tap, swipe, input (explicit `track()`) | `checkout_added_promo_code` |
| `business_outcome` | KPI-relevant state transition (Riverpod observer) | `purchase_completed`, `onboarding_finished` |
| `error_event` | Caught exception, crash (global FlutterError hook) | `error_fatal_payment_api` |

---

## 3. Event Naming Convention

Pattern: **`category_action_detail`** — snake_case, no abbreviations unless industry-standard.

| Category | Template | Example |
|---|---|---|
| screen_view | `screen_[feature]_[page]` | `screen_checkout_payment` |
| user_action | `[feature]_[action]_[target]` | `checkout_added_promo_code` |
| business_outcome | `[feature]_[milestone]_[result]` | `onboarding_step3_completed` |
| error_event | `error_[severity]_[source]` | `error_fatal_payment_api` |

Rules:
- Lowercase snake_case only.
- Limit to 40 characters (Firebase Analytics limit).
- Do not include PII or dynamic values in the event name.
- Prefer `completed` over `done`; `failed` over `error` (for business outcomes).

---

## 4. Event Properties Schema

### Required (every event)

| Property | Type | Description |
|---|---|---|
| `timestamp` | `DateTime` | UTC, client-generated |
| `session_id` | `String` | UUID regenerated per app launch |
| `user_id_hash` | `String` | SHA-256 of user ID, or anonymous installation ID |

### Category-specific

| Category | Additional Properties |
|---|---|
| screen_view | `screen_name`, `previous_screen`, `duration_ms` |
| user_action | `action`, `target`, `metadata` (Map<String, Object?>) |
| business_outcome | `outcome`, `value` (num?), `funnel_step` (String?) |
| error_event | `error_type`, `error_message`, `stack_trace_hash`, `is_fatal` |

---

## 5. Typed Event Model in Dart

Define a sealed class hierarchy so every event has compile-time property guarantees:

```dart
sealed class AnalyticsEvent {
  DateTime get timestamp;
  String get sessionId;
  String get userIdHash;
  String get name;            // event name string
  Map<String, Object> toJson(); // Firebase-compatible, omits nulls
}
```

Subtypes: `ScreenViewEvent`, `UserActionEvent`, `BusinessOutcomeEvent`, `ErrorEvent`.
Each constructor requires its category-specific fields — never a generic `Map<String, dynamic>` payload.

`toJson()` rules: flatten to `Map<String, Object>`, DateTime to ISO-8601, omit nulls, prepend category prefix.

See `templates/analytics_taxonomy.dart` for the full sealed hierarchy and `AnalyticsObserver`.

---

## 6. Key Funnel Definition

A funnel is an ordered event sequence. Define funnels centrally:

```dart
enum AnalyticsFunnel {
  onboarding(steps: ['onboarding_step1_started', 'onboarding_step2_completed',
                     'onboarding_step3_completed']),
  checkout(steps: ['checkout_payment_started', 'checkout_payment_succeeded']),
  featureAdoption(steps: ['search_query_submitted', 'search_result_tapped']),
}
```

`FunnelTracker` (in `templates/event_instrumentation.dart`) counts events per step and computes drop-off rates for stage 23 monitoring.

---

## 7. Auto-Instrumentation Patterns

### Screen views — go_router observer
Attach `AnalyticsObserver` (extends `RouteObserver<PageRoute>`) to `GoRouter.observers`. Fires `ScreenViewEvent` on route changes with screen name and previous screen.

### Business events — Riverpod listener
Use `AnalyticsRiverpodObserver` (a `ProviderObserver`). When a business-significant provider changes state (e.g. `checkoutStateProvider`), it fires a `BusinessOutcomeEvent`.

### Error events — global error boundary
Hook `PlatformDispatcher.instance.onError` and `FlutterError.onError` before `runApp()`. Both forward to `ErrorEvent` with a sanitized message and `stack_trace_hash` (first 8 hex chars of SHA-256).

### User actions — explicit tracking
User actions require explicit calls. Use the `EventTracker` mixin (in templates) so every feature widget/controller gets a scoped `track()` method.

---

## 8. AnalyticsService Abstraction

```dart
abstract class AnalyticsService {
  Future<void> logEvent(AnalyticsEvent event);
  Future<void> setUserProperty(String key, String value);
  Future<void> setUserId(String userId); // stores hash internally
}
```

Implementations: `FirebaseAnalyticsService`, `NoOpAnalyticsService`, `DelegatingAnalyticsService`.
Provided via Riverpod (`analyticsServiceProvider`). Never call directly from widgets — go through `EventTracker` or `consentGateProvider`.

---

## 9. Privacy & Consent Gating

All analytics MUST be gated behind user consent:

```dart
enum AnalyticsConsent { granted, denied, undetermined }
final consentGateProvider = StateProvider<AnalyticsConsent>(
  (ref) => AnalyticsConsent.undetermined,
);
```

Rules:
- First launch: `undetermined` — no events fire.
- Show a consent dialog before any tracking starts.
- If `denied`, `analyticsServiceProvider` returns `NoOpAnalyticsService`.
- `user_id_hash` uses SHA-256, never raw emails or PII.
- `error_message` is sanitized — remove URLs, emails, file paths before logging.

---

## 10. Testing

### Unit tests
- Every `AnalyticsEvent` subtype round-trips through `toJson()` without losing fields.
- `FunnelTracker` correctly counts steps and computes drop-off rates.
- `consentGateProvider` gates all event logging.

### Integration tests
- Test `AnalyticsService` spy verifies events fire on expected flows.
- Funnel step counts increment only on correct event names.
- No events fire when consent is `denied`.

### Pipeline
- Stage 02 PRD metrics map to taxonomy events.
- Stage 23 monitoring reads funnel data and verifies against PRD targets.

---

## 11. References

- Skill 02 — `../02_PRDs_and_Success_Metrics/SKILL.md`: input success metrics.
- Skill 23 — `../23_Monitoring/SKILL.md`: consumes funnel data and event streams.
- Conventions — `../../references/CONVENTIONS.md`: Dart 3, Riverpod 2.x, sealed types.
- Pipeline — `../../references/PIPELINE.md`: stage 02 to 66 to stage 23 flow.
