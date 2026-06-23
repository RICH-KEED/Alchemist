---
name: Chaos Resilience
description: Inject failures deliberately — network loss, slow API (high latency), denied permissions, low memory, clock skew, killed isolate/process — and assert the app degrades gracefully per the contracts from skills 14/15/16. Use to harden resilience before production, audit the resilience stack, or gate stage 24 Production_Readiness.
when_to_use: Trigger on "chaos test", "resilience audit", "inject failures", "test offline", "graceful degradation", "break the app deliberately", "pre-production hardening", or when stage 24 demands a resilience gate. Only run after skills 14, 15, and 16 have been applied — chaos testing without the resilience infrastructure is wasted.
---

# Chaos Resilience

You inject **realistic failure scenarios** into a running Flutter app and assert that it degrades **gracefully** — no crashes, no data loss, clear user feedback, and recovery when the failure is removed. This skill audits against the contracts defined by [skill 14 Network_Resilience](../14_Network_Resilience/SKILL.md), [skill 15 Error_Handling](../15_Error_Handling/SKILL.md), and [skill 16 Loading_States](../16_Loading_States/SKILL.md).

House style: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md). This is the resilience gate before [stage 24 Production_Readiness](../24_Production_Readiness/SKILL.md).

**Done when:** every scenario in `templates/chaos_scenarios.md` is executed and passes — the app never crashes, every failure surfaces a mapped error with a recovery path, and the app recovers without a restart.

---

## The chaos philosophy

Conventional testing asks: "Does the app work under normal conditions?" That proves the **happy path**. It tells you nothing about what happens when the world is not happy.

Chaos testing asks the harder question: **"Does the app fail well?"**

Five principles:

1. **Test the failure paths deliberately, not the happy path under load.** You are not stress-testing — you are breaking specific things one at a time and watching the response. A thousand successful requests under throttled bandwidth proves nothing if the thousand-and-first crashes the app because you never tested what a dropped connection looks like.
2. **One failure at a time.** Inject one variable (network down, clock skewed, permission denied), observe, record, recover. Compound failures are a separate exercise.
3. **The contract defines pass/fail, not your intuition.** Skills 14/15/16 define exactly what the app must do when each failure occurs. If the app does what the contracts say — even if the UX is imperfect — it passes. If it violates the contract (crash, raw exception, infinite spinner, no recovery path), it fails.
4. **Real adversity only.** Synthetic `throw Exception()` in tests is not chaos testing. You must inject failures into a **running** app — at the transport level (network), OS level (permissions, memory), or process level (kill adb). The test harness `chaos_runbook.md` spells out the concrete commands.
5. **Recovery is part of the test.** A scenario is not "passed" until the app recovers to a working state after the failure is removed. Surviving the failure and then being stuck is a partial fail.

---

## Pre-flight: confirm the resilience stack exists

Before injecting anything, verify the app has these three contracts wired. If any is missing, stop — you already know it will crash.

| Skill | Must-have artifact | Quick check |
|---|---|---|
| **14 — Network Resilience** | Retry interceptor, timeouts on dio `BaseOptions`, connectivity provider, at least one cache-then-network read path | Airplane-mode the device on a data screen — if it crashes instantly, the stack is not wired |
| **15 — Error Handling** | `Result<T>` / `Failure` at `core/error/`, `mapError()` in data sources, `runZonedGuarded` + `FlutterError.onError` in `main.dart` | Trigger a `NotFoundFailure` — if a raw exception text appears, mapping is missing |
| **16 — Loading States** | `AsyncValueView` on every data surface, skeleton/shimmer for loading, empty-state widget with CTA, error-state wired to skill 15 UX | Pull-to-refresh offline — if a blank screen appears, the four-state law is broken |

If these three checks pass, proceed.

---

## The scenario table (summary)

The full catalog lives in [`templates/chaos_scenarios.md`](templates/chaos_scenarios.md). Here is the signal-to-noise summary:

| # | Scenario | What you inject | Expected graceful behavior | Contract validated |
|---|---|---|---|---|
| N1 | No connectivity | Airplane mode | Offline banner; cache data shown; retry button; no crash | 14 (connectivity awareness, cache-then-network) |
| N2 | High latency (slow API) | Emulator throttle: 2000ms delay | Skeleton shown; timeout fires; `TimeoutFailure` UX with retry; no ANR | 14 (timeouts), 16 (loading → error transition) |
| N3 | Mid-request drop | Start request, cut network before response | Request fails with `NetworkFailure`; retry button; no crash; no stale spinner | 14 (retry interceptor), 15 (error mapping), 16 (error state) |
| N4 | DNS failure | Invalid host / block DNS | `NetworkFailure` UX; **not** raw `SocketException`; retry available | 15 (exception mapping) |
| N5 | Server 5xx | Interceptor returning 503 | Error state; retry honors `Retry-After`; circuit breaker opens after threshold | 14 (retry policy, circuit breaker) |
| N6 | Server 401 | Interceptor returning 401 | Redirect to login; session cleared; no stale data leaked | 15 (UnauthorizedFailure mapping) |
| N7 | Server 429 | Interceptor returning 429 with `Retry-After: 30` | Backoff respects header; user sees "too many requests" UX | 14 (Retry-After honoring) |
| N8 | Connection refused | Stop backend server | Timeout (not infinite spinner); `NetworkFailure` UX | 14 (timeouts), 15 (mapping) |
| P1 | Camera denied | Deny at system prompt | Feature disabled with explanation; "Open Settings" affordance; no crash | 16 (empty/error state with CTA) |
| P2 | Location denied | Deny at system prompt | Degraded experience; manual fallback; clear why limited | 16 (degraded state) |
| P3 | Notifications denied | Deny at system prompt | In-app fallback; no crash on token registration | 15 (error boundary) |
| R1 | Low memory | Emulator 256MB heap limit | Caches trimmed; no OOM; degraded images acceptable | Architecture (cache eviction) |
| R2 | Disk full | Fill emulator storage | Write failures caught; `CacheFailure` UX; app stays alive | 15 (CacheFailure), 14 (offline writes) |
| S1 | Clock skew | Set device clock back 1 year | SSL errors caught and mapped; JWT expiry handled; no silent auth failure | 15 (UnknownFailure mapping) |
| S2 | Process death | `adb shell am kill <pkg>` | State restored on relaunch; unsaved-data warning if applicable | Architecture (state preservation) |
| S3 | Background → foreground | Background app 5 min, resume | Stale data refreshed; no blank screen; no crash | 16 (state restoration) |
| S4 | Rotation during load | Rotate while request in-flight | Request survives config change; no duplicate; state preserved | 08 (provider scoping) + 16 |
| S5 | Rapid navigation | Tap 5 nav items quickly | No race conditions; no stacked screens; no crash | Architecture (navigation guards) |

---

## Injection methods (how to break things)

The full execution commands are in [`templates/chaos_runbook.md`](templates/chaos_runbook.md). Here are the methods:

### Network-level injection

| Method | Tool | When to use |
|---|---|---|
| **Airplane mode** | Device quick-settings / `adb shell cmd connectivity airplane-mode enable` | No connectivity, mid-request drop |
| **Network throttling** | Android Emulator Extended Controls → Cellular → Network type / Signal strength | High latency, slow bandwidth |
| **Block specific host** | `adb shell cmd connectivity airplane-mode enable` after app loads (temporary) — or use a Charles Proxy / mitmproxy map-remote to return errors | DNS failure, 5xx, connection refused |
| **Dio interceptor fault injection** | Register a `FaultInterceptor` in the debug build only — it reads flags (env / shared_prefs / debug drawer) and injects delays, status codes, or socket errors per-request | Precise per-endpoint 500/401/429/Timeout injection without network tooling |

The **Dio fault interceptor** is the most precise tool. Register it **after** auth and **before** the error mapper:

```dart
// In debug builds only:
if (kDebugMode) {
  dio.interceptors.add(FaultInterceptor(
    flags: FaultFlags.fromEnv(), // FAULT_DELAY_MS=3000 FAULT_STATUS=503 FAULT_DROP=true
  ));
}
```

The `FaultInterceptor` template is in [`templates/chaos_runbook.md`](templates/chaos_runbook.md). It can:
- **Delay** a response by N ms (simulate latency).
- **Drop** the connection mid-flight (throw `DioException.connectionError`).
- **Override** the status code (return 500/503/429/401 regardless of real response).
- **Corrupt** the response body (inject malformed JSON to test parsing error mapping).

### Permission injection

- **Android:** Revoke via Settings → Apps → [your app] → Permissions → Deny, or via `adb shell pm revoke <package> <permission>`.
- **Flutter:** The `permission_handler` package surfaces denied/permanently-denied states. Verify the app reads these before attempting the protected action.

### System-level injection

| Failure | Injection command |
|---|---|
| **Process death** | `adb shell am kill <package-name>` — then relaunch from launcher |
| **Clock skew** | `adb shell settings put global auto_time 0` then `adb shell date -s "202506230900.00"` (set to past) — **requires root or `adb root`** |
| **Low memory** | Emulator: set RAM to 256MB in AVD config, then open many large images in the app |
| **Disk full** | `adb shell dd if=/dev/zero of=/data/local/tmp/filler bs=1M count=<N>` (fill storage; adjust count to leave ~5MB free) |

### Process-death resilience (state preservation)

When process death is injected, the app must restart. The test is whether the user returns to a **meaningful** state — not necessarily the exact screen, but not a blank app either. The minimum bar:
- Saved preferences, auth tokens, and cached data survive (they are persisted).
- On relaunch, the app boots to a non-error screen.
- **Bonus:** deep-link restoration via go_router state preservation.

---

## Interpreting results

After running all scenarios, triage:

| Symptom | Root cause | Fix in |
|---|---|---|
| App crashes to home screen | Missing `runZonedGuarded` or `PlatformDispatcher.onError` | Skill 15 — global boundary |
| Red error box with stack trace | `FlutterError.onError` not wired; release `ErrorWidget.builder` not installed | Skill 15 — `app_error_boundary.dart` |
| Raw `SocketException` / `DioException` text visible | `mapError()` not called at the data boundary | Skill 15 — `error_mapper.dart` |
| Infinite spinner | No timeout on dio; no connectivity observer; no error state on that surface | Skill 14 (timeouts) or skill 16 (error state) |
| Blank/white screen | Missing empty or error state in `AsyncValueView` | Skill 16 — four-state law |
| "Something went wrong" with no action | `failure_x.dart` missing a `FailureUx` mapping for that `Failure` subtype | Skill 15 — `failure_x.dart` |
| Retry button does nothing | `onRetry` callback not wired to `ref.invalidate(provider)` | Skill 16 — error state wiring |
| Data disappears on rotate | Provider scoped to widget lifespan instead of app / auto-dispose off | Skill 08 — provider scoping |
| Duplicate requests on resume | Controller not using `skipLoadingOnRefresh`; stale refresh logic | Skill 16 — pull-to-refresh |
| App stays broken after network restored | Connectivity listener not triggering re-fetch; cache not invalidated | Skill 14 — `connectivityStatusProvider` listener |

---

## Worked example — high-latency product list

**Scenario N2: Slow API (2000ms latency)**

1. **Precondition:** App is on the product list screen. Data loads from `GET /products` normally in ~200ms.
2. **Inject:** Set the fault interceptor delay to 2000ms for the `/products` endpoint. Alternatively, emulator throttle to EDGE (400ms latency, 128kbps).
3. **Observe:**
   - T=0: App shows list skeleton (skill 16 loading state). **Pass.**
   - T=10s: Dio `receiveTimeout` fires. Interceptor maps to `TimeoutFailure`. **Pass** (skill 14 timeout contract).
   - T=10s: Screen transitions from skeleton to error state with "Request timed out — Retry" and a retry button. **Pass** (skill 16 error state; skill 15 `TimeoutFailure` UX).
   - No crash, no ANR dialog, no raw exception text. **Pass.**
4. **Recover:** Remove the delay flag. Tap "Retry". List loads normally in ~200ms. **Pass.**
5. **Record:** `N2 — PASS — Timeout at 10s, graceful error, retry recovers.`

**Failing variant:** If the skeleton spun forever and never showed an error, the fix is:
- Skill 14: ensure `receiveTimeout: Duration(seconds: 10)` is set on dio `BaseOptions`.
- Skill 16: ensure the product list uses `AsyncValueView` which maps error state.
- Skill 15: ensure `mapError()` catches `DioExceptionType.receiveTimeout` → `TimeoutFailure`.

---

## Output (what you produce)

1. **`templates/chaos_scenarios.md`** — the full scenario catalog (every scenario with inject method, expected behavior, contract validated, severity if it fails). Copy into the project's `docs/chaos/` or equivalent.
2. **`templates/chaos_runbook.md`** — step-by-step execution commands for each scenario (adb commands, dio interceptor flags, permission CLI, emulator settings).
3. **A chaos report** (per project, not a template) — a markdown table per scenario recording PASS/FAIL/PARTIAL, observed behavior, recovery, and notes. Template inline in this skill.

---

## Limitations

- Clock skew testing on an emulator requires `adb root` (unavailable on Google Play images). Use a non-Play AVD image, a physical rooted device, or skip with a note.
- Memory pressure testing is approximate on an emulator — the Linux kernel's OOM killer behaves differently than Android's `lmkd`. Physical device results are more reliable.
- Not every scenario can be automated. Dio fault injection can be scripted via a debug drawer toggle; process death requires adb manual commands. This skill defines the manual process; automation is a future concern (link here if a chaos framework emerges).
- Skipping scenarios is acceptable **if documented with a reason** — never silently skip.

---

## Cross-references

- **14 Network_Resilience** — offline, retry, timeout, circuit-breaker contract
- **15 Error_Handling** — `Failure`/`Result`, `mapError`, global boundary contract
- **16 Loading_States** — `AsyncValueView`, skeleton, empty/error state contract
- **08 Riverpod** — provider scoping (survives rotation / process death, or not)
- **24 Production_Readiness** — the production gate; chaos report is a required input

Full scenario catalog: [`templates/chaos_scenarios.md`](templates/chaos_scenarios.md).
Execution commands: [`templates/chaos_runbook.md`](templates/chaos_runbook.md).
House style: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).
