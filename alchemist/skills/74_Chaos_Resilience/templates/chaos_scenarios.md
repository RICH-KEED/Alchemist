# Chaos Scenarios — Full Catalog

Every scenario below maps to the contracts in skills 14 (Network Resilience), 15 (Error Handling), and 16 (Loading States). A scenario **passes** when the app handles the injected failure gracefully — no crash, no raw exception text, no infinite spinner, a clear user-facing message, and a recovery path. A scenario **fails** when the app crashes, hangs, shows raw errors, or cannot recover.

---

## Network failures (N1–N8)

### N1 — No connectivity

| Attribute | Value |
|---|---|
| **What you inject** | Airplane mode: `adb shell cmd connectivity airplane-mode enable` or device quick-settings |
| **Precondition** | App is on any screen that loads remote data (list, detail, feed) |
| **Expected graceful behavior** | Offline banner appears at app shell; last-known-good cached data is displayed (not a blank screen); "You're offline" indicator; retry / pull-to-refresh is available but surfaces the offline state clearly |
| **Contract validated** | 14 (connectivity awareness — `connectivityStatusProvider` drives banner; cache-then-network reads return stale cache), 16 (loaded data stays visible — does not collapse to error) |
| **Severity if it fails** | **HIGH** — offline is the most common real-world failure. A crash here means every subway/tunnel/elevator user loses the app. |

### N2 — High latency / slow API

| Attribute | Value |
|---|---|
| **What you inject** | Emulator throttle: EDGE (400ms latency, 128kbps) — OR — Dio fault interceptor: 2000–5000ms per-request delay |
| **Precondition** | App loads a data screen (product list, feed, profile) |
| **Expected graceful behavior** | Skeleton/shimmer shown during loading; after `receiveTimeout` fires, screen transitions to error state with `TimeoutFailure` UX ("Request timed out"); retry button present; no ANR dialog; no infinite spinner |
| **Contract validated** | 14 (receive timeout fires, request is cancelled), 15 (`TimeoutFailure` mapped by `mapError`), 16 (skeleton → error transition, retry affordance) |
| **Severity if it fails** | **HIGH** — users on slow connections (developing markets, rural, tunnels) will see a permanent spinner and uninstall. |

### N3 — Network drops mid-request

| Attribute | Value |
|---|---|
| **What you inject** | Start a request (navigate to a data screen), then immediately enable airplane mode before the response arrives |
| **Precondition** | App initiates a network request (not yet cached) |
| **Expected graceful behavior** | Request fails with `NetworkFailure`; error state appears with retry button; no crash; no stale spinner left spinning; the socket error is caught and mapped — raw `SocketException` never reaches the UI |
| **Contract validated** | 14 (retry interceptor handles `connectionError`), 15 (`SocketException` → `NetworkFailure` mapping), 16 (error state renders with retry) |
| **Severity if it fails** | **CRITICAL** — a mid-request drop causing a crash is a hard production blocker. |

### N4 — DNS failure / invalid host

| Attribute | Value |
|---|---|
| **What you inject** | Point app at a non-existent host (e.g. `api.nonexistent.local`) via an environment toggle, or use Charles/mitmproxy to reject DNS resolution |
| **Precondition** | App makes its first request to the configured host |
| **Expected graceful behavior** | `NetworkFailure` UX with a user-friendly message; **not** raw `SocketException: Failed host lookup`; retry button available; no crash |
| **Contract validated** | 15 (`SocketException` → `NetworkFailure` via `mapError`) |
| **Severity if it fails** | **MEDIUM** — rare in production but indicates the error-mapping layer is incomplete. |

### N5 — Server 503 (Service Unavailable)

| Attribute | Value |
|---|---|
| **What you inject** | Dio fault interceptor returns HTTP 503 with optional `Retry-After: 30` header |
| **Precondition** | App requests any endpoint |
| **Expected graceful behavior** | Retry interceptor respects `Retry-After` header (waits 30s before retry, or surfaces immediately with the delay noted); error state shows "Service temporarily unavailable — Retry"; circuit breaker opens after consecutive 503 failures (fail-fast, no more requests to that host for `resetTimeout` duration) |
| **Contract validated** | 14 (retry policy — 503 is transient, retries with backoff; `Retry-After` honored; circuit breaker opens), 16 (error state with retry) |
| **Severity if it fails** | **HIGH** — without circuit breaker, a 503 storm causes cascading timeouts across every request in the app. |

### N6 — Server 401 (Unauthorized)

| Attribute | Value |
|---|---|
| **What you inject** | Dio fault interceptor returns HTTP 401 |
| **Precondition** | App is authenticated and requests a protected resource |
| **Expected graceful behavior** | `UnauthorizedFailure` mapped; session tokens cleared; user redirected to login screen; **no stale authenticated data leaked on screen**; error logged for observability |
| **Contract validated** | 15 (`UnauthorizedFailure` mapping and redirection), 14 (401 is NOT retried — it is a definitive failure) |
| **Severity if it fails** | **CRITICAL** — if 401 crashes or silently fails, users are locked out with no path back in. If stale data persists after session expiry, it is a security concern. |

### N7 — Server 429 (Rate Limited)

| Attribute | Value |
|---|---|
| **What you inject** | Dio fault interceptor returns HTTP 429 with `Retry-After: 30` |
| **Precondition** | App makes a burst of requests (e.g. pull-to-refresh on a paginated list, fast search typing) |
| **Expected graceful behavior** | Retry interceptor reads `Retry-After` and backs off; user sees "Too many requests — please wait" or equivalent; no crash; no tight retry loop hammering the server |
| **Contract validated** | 14 (`Retry-After` honored on 429; backoff jitter prevents herd), 15 (429 status mapped to appropriate `Failure`) |
| **Severity if it fails** | **MEDIUM** — without honoring `Retry-After`, a rate-limited client becomes a DDoS participant. |

### N8 — Connection refused (server down)

| Attribute | Value |
|---|---|
| **What you inject** | Stop the backend server entirely (or block its port via `adb shell iptables`) |
| **Precondition** | App requests any endpoint |
| **Expected graceful behavior** | `connectTimeout` fires (not hanging forever); `NetworkFailure` UX with retry; no crash; no ANR |
| **Contract validated** | 14 (connect timeout), 15 (error mapping), 16 (error state) |
| **Severity if it fails** | **HIGH** — a dead backend should never deadlock the app. |

---

## Permission failures (P1–P3)

### P1 — Camera permission denied

| Attribute | Value |
|---|---|
| **What you inject** | Deny camera permission at system prompt; or pre-revoke via `adb shell pm revoke <package> android.permission.CAMERA` |
| **Precondition** | App attempts to open the camera (scan barcode, take photo, AR feature) |
| **Expected graceful behavior** | Camera surface renders a disabled state with explanation ("Camera access is needed to scan barcodes"); "Open Settings" button that launches `app_settings`; no crash; no black camera preview |
| **Contract validated** | 16 (empty/disabled state with CTA), 15 (permission denial caught — no unhandled platform exception) |
| **Severity if it fails** | **MEDIUM** — users deny camera frequently. A crash on denial is a Play Store rejection risk. |

### P2 — Location permission denied

| Attribute | Value |
|---|---|
| **What you inject** | Deny location permission at system prompt; or `adb shell pm revoke <package> android.permission.ACCESS_FINE_LOCATION` |
| **Precondition** | App requests location (map, nearby search, geotag) |
| **Expected graceful behavior** | Feature degrades — map centers on default location, "Set location manually" fallback, or approximate location via IP; clear explanation of why location is useful; no crash; no hang waiting for a location that will never arrive |
| **Contract validated** | 16 (degraded state), 15 (permission denial caught) |
| **Severity if it fails** | **MEDIUM** — location is the most commonly denied sensitive permission. |

### P3 — Notification permission denied

| Attribute | Value |
|---|---|
| **What you inject** | Deny notification permission at system prompt (Android 13+); or `adb shell pm revoke <package> android.permission.POST_NOTIFICATIONS` |
| **Precondition** | App registers for push notifications / requests notification permission |
| **Expected graceful behavior** | Token registration succeeds or fails gracefully; no crash on token fetch; in-app notification fallback considered (but not required — OS-level denial is acceptable); the app does not repeatedly prompt after denial |
| **Contract validated** | 15 (error boundary — platform exception does not crash app) |
| **Severity if it fails** | **LOW** — cosmetic, but a crash here is noisy in crash reporting dashboards. |

---

## Resource failures (R1–R2)

### R1 — Low memory

| Attribute | Value |
|---|---|
| **What you inject** | Emulator configured with 256MB RAM; open many large images or heavy screens in the app |
| **Precondition** | App is running, multiple screens visited, image-heavy content loaded |
| **Expected graceful behavior** | Image caches evict; no OutOfMemoryError crash; degraded visual quality (lower-res images) acceptable; scrolling remains responsive |
| **Contract validated** | Architecture (cache eviction discipline), 16 (degraded rendering — skeleton or placeholder for evicted images) |
| **Severity if it fails** | **MEDIUM** — low-memory devices (Android Go, budget phones) are a large segment. But emulator OOM behavior differs from real `lmkd`. |

### R2 — Disk full

| Attribute | Value |
|---|---|
| **What you inject** | Fill emulator storage: `adb shell dd if=/dev/zero of=/data/local/tmp/filler bs=1M count=<N>` leaving ~5MB free |
| **Precondition** | App attempts to write to cache or local DB |
| **Expected graceful behavior** | Write failures caught; `CacheFailure` / `UnknownFailure` UX shown; app stays alive (no crash); cached data may be stale/missing — that is acceptable |
| **Contract validated** | 15 (`CacheFailure` mapping, error boundary), 14 (outbox write failure handled gracefully) |
| **Severity if it fails** | **LOW** — rare, but a crash-on-disk-full in a DB-heavy app loses user data trust. |

---

## System failures (S1–S5)

### S1 — Clock skew

| Attribute | Value |
|---|---|
| **What you inject** | `adb shell settings put global auto_time 0` + `adb shell date -s "202506230900.00"` (set to 1 year in the past). Requires `adb root`. |
| **Precondition** | App performs an authenticated request (JWT, token verification) |
| **Expected graceful behavior** | SSL certificate errors caught and mapped (not a raw `HandshakeException`); JWT "not yet valid" or "expired" handled gracefully via `UnauthorizedFailure` or appropriate mapped error; no silent auth failure that leaves the user confused |
| **Contract validated** | 15 (`mapError` catches SSL/TLS exceptions and maps to `NetworkFailure` or `UnknownFailure`), 14 (retry does not loop on definitive TLS failures) |
| **Severity if it fails** | **HIGH** — clock skew (user-set or device-reset) is real-world common; SSL failures crashing the app is a production incident. |

### S2 — Process death (killed isolate)

| Attribute | Value |
|---|---|
| **What you inject** | `adb shell am kill <package-name>` while the app is in the foreground, then relaunch from the launcher |
| **Precondition** | App is on a data-entry screen (form partially filled, or navigating a flow) |
| **Expected graceful behavior** | On relaunch: app boots to a working screen (not a crash loop); saved preferences, auth tokens, and cached data persist; **minimum:** app is functional, user can navigate. **Bonus:** unsaved form state restored or user warned. |
| **Contract validated** | Architecture (state preservation — preferences/cache survive process death), 15 (relaunch error boundary — no crash loop) |
| **Severity if it fails** | **CRITICAL** — Android kills background processes aggressively. If the app cannot survive process death, users lose their session constantly. |

### S3 — Background to foreground

| Attribute | Value |
|---|---|
| **What you inject** | Press Home to background the app, wait 5 minutes, then tap the app icon to resume |
| **Precondition** | App was displaying data (list, detail, or form) |
| **Expected graceful behavior** | App refreshes stale data (or shows timestamp of last load); no blank white screen; no crash; no duplicate data from re-running initial load logic |
| **Contract validated** | 16 (state restoration — `AsyncValueView` handles data already present), 14 (connectivity listener resumes and re-fetches) |
| **Severity if it fails** | **HIGH** — background→foreground is a constant user behavior. A blank screen on resume is a top uninstall driver. |

### S4 — Rotation during loading

| Attribute | Value |
|---|---|
| **What you inject** | Navigate to a data screen, immediately rotate the device while the request is in flight (skeleton visible) |
| **Precondition** | A network request is in-flight (not yet complete) |
| **Expected graceful behavior** | The request survives the configuration change; no duplicate request is fired; the skeleton remains visible and transitions to data/error when the original request completes; no crash |
| **Contract validated** | 08 (provider scoping — provider must NOT be scoped to widget lifecycle; must survive config change), 16 (loading state preserved across rotation) |
| **Severity if it fails** | **MEDIUM** — rotation is a normal user action. Duplicate requests waste bandwidth and can cause inconsistent state. |

### S5 — Rapid navigation

| Attribute | Value |
|---|---|
| **What you inject** | Tap 5 bottom-nav items rapidly in sequence, or rapidly push/pop screens |
| **Precondition** | App has multiple navigation destinations |
| **Expected graceful behavior** | No race conditions; no multiple screens stacked incorrectly; no `setState()` called after dispose; no crash; the final destination renders correctly |
| **Contract validated** | Architecture (navigation guards, cancel tokens for in-flight requests on navigate-away), 08 (dispose timing) |
| **Severity if it fails** | **MEDIUM** — rapid navigation happens when users explore or tap impatiently. A crash here is a bad first impression. |

---

## Severity legend

| Severity | Meaning | Action |
|---|---|---|
| **CRITICAL** | App crashes or loses user data | Must fix before production |
| **HIGH** | Common real-world scenario; poor UX degrades trust | Fix before production unless explicitly waived |
| **MEDIUM** | Uncommon or recoverable; indicates incomplete wiring | Fix in next iteration |
| **LOW** | Cosmetic or extremely rare | Acknowledge, track as tech debt |

---

## Contract coverage matrix

This table confirms every scenario exercises at least one skill contract.

| Scenario | Skill 14 | Skill 15 | Skill 16 | Skill 08 | Architecture |
|---|---|---|---|---|---|
| N1 — No connectivity | x |  | x |  |  |
| N2 — High latency | x | x | x |  |  |
| N3 — Mid-request drop | x | x | x |  |  |
| N4 — DNS failure |  | x |  |  |  |
| N5 — Server 503 | x |  | x |  |  |
| N6 — Server 401 | x | x |  |  |  |
| N7 — Server 429 | x |  |  |  |  |
| N8 — Connection refused | x | x | x |  |  |
| P1 — Camera denied |  | x | x |  |  |
| P2 — Location denied |  | x | x |  |  |
| P3 — Notifications denied |  | x |  |  |  |
| R1 — Low memory |  |  | x |  | x |
| R2 — Disk full | x | x |  |  |  |
| S1 — Clock skew | x | x |  |  |  |
| S2 — Process death |  | x |  |  | x |
| S3 — Background → foreground | x |  | x |  |  |
| S4 — Rotation during load |  |  | x | x |  |
| S5 — Rapid navigation |  |  | x | x | x |

---

## Results recording sheet (copy into project chaos report)

| # | Scenario | Screen tested | Result | Observed | Recovery | Notes |
|---|---|---|---|---|---|---|
| N1 | No connectivity | | PASS / FAIL / PARTIAL | | | |
| N2 | High latency | | | | | |
| N3 | Mid-request drop | | | | | |
| N4 | DNS failure | | | | | |
| N5 | Server 503 | | | | | |
| N6 | Server 401 | | | | | |
| N7 | Server 429 | | | | | |
| N8 | Connection refused | | | | | |
| P1 | Camera denied | | | | | |
| P2 | Location denied | | | | | |
| P3 | Notifications denied | | | | | |
| R1 | Low memory | | | | | |
| R2 | Disk full | | | | | |
| S1 | Clock skew | | | | | |
| S2 | Process death | | | | | |
| S3 | Background → foreground | | | | | |
| S4 | Rotation during load | | | | | |
| S5 | Rapid navigation | | | | | |

**Pass rate:** X/18 passed, Y partial, Z failed — VERDICT: RESILIENT / HARDEN NEEDED
