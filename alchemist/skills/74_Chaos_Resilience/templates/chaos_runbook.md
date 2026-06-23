# Chaos Resilience — Execution Runbook

Concrete commands and step-by-step execution for every chaos scenario. The scenario catalog is in [`chaos_scenarios.md`](chaos_scenarios.md) — this file is the **how**, not the **what**. Read the catalog first to understand each scenario's expectations, then use this runbook to execute.

---

## Prerequisites

Before any scenario: ensure `adb` is on your PATH and a device/emulator is connected.

```bash
adb devices
# Expect: List of devices attached
# <serial>    device   (or emulator-5554)
```

Set a shell variable for the package name (adjust per project):
```bash
PKG=com.example.yourapp
```

---

## Dio Fault Interceptor (central injection tool)

The most precise way to inject network failures is a **debug-only Dio interceptor** that reads fault flags from the environment. Register it **after** auth and **before** the error mapper in your Dio setup.

Drop this file into `lib/core/network/fault_interceptor.dart` (debug-only, never shipped in release):

```dart
// lib/core/network/fault_interceptor.dart
// DEBUG ONLY — conditionally import in dio setup.
// Reads fault flags from environment variables or a debug drawer.

import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class FaultFlags {
  final int? delayMs;         // inject per-request latency
  final int? statusCode;      // override response status
  final bool? dropConnection;  // simulate mid-flight socket drop
  final String? corruptBody;  // if non-null, replace response body with this string
  final String? pathContains; // only apply to requests whose path contains this

  const FaultFlags({
    this.delayMs,
    this.statusCode,
    this.dropConnection,
    this.corruptBody,
    this.pathContains,
  });

  factory FaultFlags.fromEnv() {
    // Set these from a debug drawer or env — never hardcode.
    // Example env vars (for adb shell setprop or Flutter --dart-define):
    //   FAULT_DELAY_MS=3000
    //   FAULT_STATUS=503
    //   FAULT_DROP=true
    //   FAULT_CORRUPT=1
    //   FAULT_PATH=/products
    const env = String.fromEnvironment;
    return FaultFlags(
      delayMs: int.tryParse(env('FAULT_DELAY_MS', '0')),
      statusCode: int.tryParse(env('FAULT_STATUS', '0')),
      dropConnection: env('FAULT_DROP', 'false') == 'true',
      corruptBody: (env('FAULT_CORRUPT', '0') == '1') ? '{broken' : null,
      pathContains: env('FAULT_PATH', ''),
    );
  }

  bool get active =>
      (delayMs != null && delayMs! > 0) ||
      (statusCode != null && statusCode! > 0) ||
      dropConnection == true ||
      corruptBody != null;

  bool matches(String path) {
    if (pathContains == null || pathContains!.isEmpty) return true;
    return path.contains(pathContains!);
  }

  @override
  String toString() => 'FaultFlags(delay=$delayMs, status=$statusCode, '
      'drop=$dropConnection, corrupt=$corruptBody, path=$pathContains)';
}

class FaultInterceptor extends Interceptor {
  final FaultFlags flags;
  final Random _random = Random();

  FaultInterceptor(this.flags);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!flags.active || !flags.matches(options.path)) {
      return handler.next(options);
    }

    // Simulate dropped connection — reject with connection error
    if (flags.dropConnection == true) {
      return handler.reject(DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: const OSError('Connection reset by peer', 104),
        message: 'Simulated connection drop',
      ));
    }

    // Inject latency
    if (flags.delayMs != null && flags.delayMs! > 0) {
      final delay = Duration(milliseconds: flags.delayMs!);
      if (flags.statusCode != null && flags.statusCode! > 0) {
        // Delay then return synthetic response
        Future.delayed(delay).then((_) {
          handler.resolve(_syntheticResponse(options));
        });
        return;
      }
      // Just delay, pass through
      Future.delayed(delay).then((_) => handler.next(options));
      return;
    }

    // Override status (no delay)
    if (flags.statusCode != null && flags.statusCode! > 0) {
      return handler.resolve(_syntheticResponse(options));
    }

    handler.next(options);
  }

  Response _syntheticResponse(RequestOptions options) {
    return Response(
      requestOptions: options,
      statusCode: flags.statusCode!,
      statusMessage: _statusMessage(flags.statusCode!),
      data: flags.corruptBody ?? {'error': 'Injected fault'},
    );
  }

  String _statusMessage(int code) => switch (code) {
    401 => 'Unauthorized',
    429 => 'Too Many Requests',
    500 => 'Internal Server Error',
    503 => 'Service Unavailable',
    _ => 'Fault Injected',
  };
}
```

**Register it (debug only):**

```dart
// In your Dio setup (lib/core/network/dio_client.dart or equivalent):
if (kDebugMode) {
  dio.interceptors.add(FaultInterceptor(FaultFlags.fromEnv()));
}
```

**Usage — set flags before launch:**

```bash
# Launch with fault flags:
flutter run --dart-define=FAULT_DELAY_MS=3000 --dart-define=FAULT_PATH=/products

# Launch with status override:
flutter run --dart-define=FAULT_STATUS=503 --dart-define=FAULT_PATH=/api

# Launch with connection drop:
flutter run --dart-define=FAULT_DROP=true

# Launch with corrupt JSON:
flutter run --dart-define=FAULT_CORRUPT=1
```

> **Hot restart note:** `--dart-define` values are baked at launch time. To change flags, hot restart (not hot reload). A debug drawer that writes to `SharedPreferences` and is read by `FaultFlags` is a superior UX for repeated testing.

---

## Network failures

### N1 — No connectivity

**Setup:** App open on a data-loading screen (list, feed, search results).

**Inject:**
```bash
adb shell cmd connectivity airplane-mode enable
```

**Wait:** 3 seconds for the connectivity listener to fire (skill 14 `connectivityStatusProvider`).

**Check:**
- [ ] Offline banner or `MaterialBanner` appears at app shell.
- [ ] Cached data is displayed (not a blank screen).
- [ ] Retry button or pull-to-refresh is available.
- [ ] No crash, no raw exception.

**Recover:**
```bash
adb shell cmd connectivity airplane-mode disable
```
Tap retry / pull-to-refresh — data refreshes. App returns to normal.

---

### N2 — High latency (slow API)

**Setup:** Screen that loads a list or image grid.

**Inject — Option A (Dio interceptor, preferred):**
```bash
flutter run --dart-define=FAULT_DELAY_MS=3000
```

**Inject — Option B (emulator throttle):**
1. Open Emulator Extended Controls (three-dot menu).
2. Cellular → Network type: **EDGE**.
3. Or CLI (if supported): `adb emu network speed edge`.

**Check:**
- [ ] Skeleton/shimmer appears (not blank).
- [ ] No ANR dialog (if ANR appears: main-thread networking).
- [ ] After timeout (default 10s receive), screen transitions from skeleton to error state.
- [ ] Error state shows `TimeoutFailure` UX with "Request timed out" + retry.
- [ ] Timeout value is reasonable (set in skill 14 on `BaseOptions`).

**Recover:**
Hot restart without fault flag, or restore emulator to LTE. Retry succeeds.

---

### N3 — Mid-request drop

**Setup:** Initiate a data-loading request (pull-to-refresh or navigate to a list screen).

**Inject:** While the loading skeleton is visible:
```bash
adb shell cmd connectivity airplane-mode enable
```

**Check:**
- [ ] Request does NOT hang forever — timeout fires or socket error surfaces.
- [ ] Error state replaces loading state (not both at once).
- [ ] Error message is `NetworkFailure` UX (not raw `SocketException` or `DioException`).
- [ ] Retry button present.

**Recover:**
```bash
adb shell cmd connectivity airplane-mode disable
```
Tap retry — request succeeds.

**Alt injection (Dio interceptor):**
```bash
flutter run --dart-define=FAULT_DROP=true --dart-define=FAULT_PATH=/api
```

---

### N4 — DNS failure / invalid host

**Setup:** App has a configurable base URL (env var / debug menu).

**Inject:**
Change the base URL to a non-existent host:
```
https://api.nonexistent-host.invalid.example.com
```

**Check:**
- [ ] `NetworkFailure` UX shown (not raw `SocketException: Failed host lookup`).
- [ ] Retry button available.
- [ ] No crash.

**Recover:** Restore correct base URL in the app config.

---

### N5 — Server 503 (Service Unavailable)

**Inject (Dio fault interceptor):**
```bash
flutter run --dart-define=FAULT_STATUS=503 --dart-define=FAULT_PATH=/api
```

**Check:**
- [ ] Error state with retry.
- [ ] If `Retry-After` header is simulated in the interceptor response, the retry delay is honored.
- [ ] Circuit breaker opens after `failureThreshold` consecutive failures (skill 14). Verify by triggering N5 5+ times and checking that subsequent requests fail instantly (not after timeout).
- [ ] User-facing message is appropriate ("Service temporarily unavailable"), not "HTTP 503".

**Recover:** Hot restart without fault flag. Retry succeeds.

---

### N6 — Server 401 (Unauthorized)

**Inject (Dio fault interceptor):**
```bash
flutter run --dart-define=FAULT_STATUS=401
```

**Check:**
- [ ] User is redirected to login screen.
- [ ] Session tokens are cleared from secure storage.
- [ ] No stale authenticated data is visible behind the redirect.
- [ ] 401 is NOT retried (skill 14 — 401 is a definitive failure, not transient).
- [ ] Error is logged (observability hook).

**Recover:** Log in again. Normal operation resumes.

---

### N7 — Server 429 (Rate Limited)

**Inject (Dio fault interceptor):**
```bash
flutter run --dart-define=FAULT_STATUS=429
```

For `Retry-After` testing, modify the interceptor to include the header:
```dart
// In _syntheticResponse, add for 429:
headers: Headers.fromMap({'Retry-After': ['30']}),
```

**Check:**
- [ ] Backoff respects `Retry-After` value (waits ~30s).
- [ ] User sees "Too many requests" or rate-limit UX.
- [ ] No tight retry loop (not hammering the server).
- [ ] Retry is jittered (skill 14 — no lockstep).

**Recover:** Hot restart without fault flag.

---

### N8 — Connection refused (server down)

**Inject:**
Stop the backend server entirely. Or point the base URL to `localhost:9999` (where nothing listens).

**Check:**
- [ ] `connectTimeout` fires (default 10s — should not hang longer).
- [ ] `NetworkFailure` UX with retry.
- [ ] No raw `ConnectionRefused` text.
- [ ] No ANR.

**Recover:** Start server / restore URL. Tap retry — succeeds.

---

## Permission failures

### P1 — Camera permission denied

**Inject:**
```bash
# Revoke before test:
adb shell pm revoke $PKG android.permission.CAMERA

# Also revoke "never ask again" state if set:
adb shell pm revoke $PKG android.permission.CAMERA
```

**Procedure:** Launch app, navigate to camera feature (scan, photo, AR).

**Check:**
- [ ] Camera-dependent feature shows explanation UI (not crash, not blank camera preview).
- [ ] "Open Settings" button present and launches system settings.
- [ ] Remaining app features function normally.
- [ ] No unhandled permission exception in logs.

**Recover:**
```bash
adb shell pm grant $PKG android.permission.CAMERA
```
Return to app; camera feature works.

---

### P2 — Location permission denied

**Inject:**
```bash
adb shell pm revoke $PKG android.permission.ACCESS_FINE_LOCATION
adb shell pm revoke $PKG android.permission.ACCESS_COARSE_LOCATION
```

**Check:**
- [ ] Location-dependent features degrade gracefully (manual input fallback, defaults, approximate IP location).
- [ ] Explanation for why location is needed (not just "Permission denied").
- [ ] No crash.
- [ ] No hang waiting for a location that will never arrive.

**Recover:**
```bash
adb shell pm grant $PKG android.permission.ACCESS_FINE_LOCATION
```

---

### P3 — Notification permission denied (Android 13+)

**Inject:**
```bash
adb shell pm revoke $PKG android.permission.POST_NOTIFICATIONS
```

**Check:**
- [ ] In-app fallback (badge, banner, in-app notification center) considered.
- [ ] No crash on FCM token registration.
- [ ] App does not repeatedly re-prompt after denial.

**Recover:**
```bash
adb shell pm grant $PKG android.permission.POST_NOTIFICATIONS
```

---

## Resource failures

### R1 — Low memory

**Setup:** Screen with many images (gallery, product grid, profile list).

**Inject (emulator):** Launch emulator with restricted RAM.
```bash
emulator -avd <avd_name> -memory 256
```

Or on Google Play emulator images, use the AVD Manager → Edit → Advanced → RAM: 256MB.

**Procedure:**
1. Open 3-4 image-heavy screens.
2. Scroll rapidly through a long image list.
3. Open and close the app several times.

**Check:**
- [ ] Image caches are trimmed (images may reload on scroll-back — acceptable).
- [ ] No `OutOfMemoryError` crash.
- [ ] Scrolling remains responsive (may be choppy under pressure — acceptable).

**Recover:** N/A — GC recovers when memory frees. Restart emulator if OOM occurred.

> Emulator OOM behavior differs from Android `lmkd` (Low Memory Killer Daemon). A physical device test is the definitive result.

---

### R2 — Disk full

**Setup:** App is about to write to local storage (cache, offline sync, download).

**Inject:**
```bash
# Check current free space:
adb shell df -h /data

# Fill storage (adjust count M based on free space — leave ~5MB):
adb shell dd if=/dev/zero of=/data/local/tmp/chaos_filler bs=1M count=500

# Verify near-full:
adb shell df -h /data
```

**Procedure:** Trigger a write operation in the app (save preference, download file, offline sync).

**Check:**
- [ ] Write failure is caught and mapped to a `Failure` (e.g., `CacheFailure`).
- [ ] User is notified if the operation was user-initiated.
- [ ] App does NOT crash.
- [ ] Existing cached data remains readable.

**Recover:**
```bash
adb shell rm /data/local/tmp/chaos_filler
```
Retry the write — succeeds.

---

## System failures

### S1 — Clock skew (past)

**Prerequisite:** Requires `adb root` (not available on Google Play emulator images — use a non-Play AVD or physical rooted device).

**Inject:**
```bash
# Disable auto time:
adb shell settings put global auto_time 0

# Set to 1 year ago (June 23, 2025):
adb shell date -s "202506230900.00"
```

**Alternative (emulator Extended Controls):**
Emulator → three-dot menu → Date & Time → set to 1 year in the past.

**Check:**
- [ ] SSL/TLS certificate validation errors are caught and mapped (not raw `HandshakeException`).
- [ ] If JWT tokens are used: expiry/nbf is handled gracefully (not an infinite refresh loop).
- [ ] User sees an appropriate error message.
- [ ] No crash.

**Recover:**
```bash
adb shell settings put global auto_time 1
```
App recovers after restart or re-login.

---

### S2 — Process death

**Setup:** App is in the foreground on a screen with form input (partially filled), or deep inside a multi-step flow.

**Inject:**
```bash
adb shell am kill $PKG
```

The app disappears immediately (process is killed, not just backgrounded).

**Recover:** Tap the app icon in the launcher to relaunch.

**Check:**
- [ ] App launches to a working screen (not a crash loop, not stuck on splash).
- [ ] Not a blank white screen.
- [ ] Saved preferences, auth tokens, and cached data survive the kill.
- [ ] **Bonus:** Unsaved form state is restored, or the user is warned it was lost.
- [ ] **Minimum:** App is functional; user can navigate.

---

### S3 — Background to foreground

**Setup:** App is on a data-displaying screen (list, feed, profile).

**Inject:**
1. Press the Home button (app backgrounds).
2. Wait **5 minutes** (real clock time).
3. Open the app from the launcher or recent-apps switcher.

**Check:**
- [ ] App displays cached data immediately, OR refreshes within a reasonable time.
- [ ] No blank/white screen on resume.
- [ ] No crash.
- [ ] No duplicate data from re-running initial load logic.
- [ ] Pull-to-refresh still works and fetches fresh data.

---

### S4 — Rotation during loading

**Setup:** Start a data-loading request (pull-to-refresh or navigate to a screen that triggers a network call).

**Inject:** While the loading skeleton is visible:
1. Rotate to landscape.
2. Wait 2 seconds.
3. Rotate back to portrait.

**Check:**
- [ ] The in-flight request is NOT cancelled or restarted (one network call, not two).
- [ ] Loading skeleton remains visible through rotations.
- [ ] When the response arrives, data renders correctly in the current orientation.
- [ ] No crash.
- [ ] No "duplicate GlobalKey" errors in the debug console.

**Verify no duplicate requests:**
```bash
# In another terminal, watch network calls:
adb logcat | grep -i "dio\|okhttp\|http"
```
Only one request to the endpoint should appear.

---

### S5 — Rapid navigation

**Setup:** App has 4-5 bottom-nav destinations or drawer items. Start on home.

**Inject:** Tap 5 navigation destinations as fast as you can (sub-second intervals).

**Check:**
- [ ] Navigation settles on the LAST tapped destination (not stuck mid-transition).
- [ ] No multiple screens stacked or overlapping.
- [ ] No race-condition crash.
- [ ] No "duplicate GlobalKey" errors.
- [ ] System Back button navigates normally (does not unwind through all 5 taps).

**Alt injection (screen push/pop):** Rapidly push and pop a detail screen 5 times.

**Check:**
- [ ] Screen stack correct (one instance, not 5).
- [ ] No `setState()` called after dispose errors.
- [ ] Memory usage stable (no leak from abandoned route objects).

---

## Execution log template

Copy this into the project chaos report (`docs/chaos/chaos_report.md`):

```markdown
# Chaos Resilience Report — <App Name>

Date: YYYY-MM-DD
Tester: <name>
Device/Emulator: <model>, Android <version>, RAM <MB>
App version: <versionCode> (<versionName>)
Commit: <sha>

---

## Results

| # | Scenario | Screen | Result | Observed behavior | Recovery | Notes |
|---|---|---|---|---|---|---|
| N1 | No connectivity | | | | | |
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
| S3 | Background→foreground | | | | | |
| S4 | Rotation during load | | | | | |
| S5 | Rapid navigation | | | | | |

## Summary

- **Passed:** X/18
- **Failed:** Y (crashes or data loss)
- **Partial:** Z (no crash, poor UX — infinite spinner / raw error / blank screen / no recovery)
- **Skipped:** W (feature not applicable or tooling unavailable — reason documented)

## Verdict

[ ] RESILIENT — 100% pass, 0 crashes. Ready for stage 24 gate.
[ ] HARDEN NEEDED — failures above require fixes. Retest after resolution.

## Failing scenario details

(N/A if all pass — otherwise list each failing scenario, observed behavior, root cause, fix location, and skill reference.)
```

---

## Result codes

| Code | Meaning |
|---|---|
| **PASS** | Graceful degradation per skill 14/15/16 contracts; recovery works. |
| **FAIL** | Crash, raw exception, data loss, or security breach (stale auth data). |
| **PARTIAL** | No crash, but: infinite spinner / blank screen / no recovery path / raw error text shown to user / no retry on a retryable failure. |
| **SKIP** | Feature not applicable (no camera, no JWT, no disk writes) — reason documented. |

---

## Quick-reference: adb commands cheat sheet

```bash
# Connectivity
adb shell cmd connectivity airplane-mode enable
adb shell cmd connectivity airplane-mode disable
adb shell svc wifi disable
adb shell svc wifi enable
adb shell svc data disable
adb shell svc data enable

# Process management
adb shell am kill <package>               # kill process
adb shell am force-stop <package>          # force-stop (clears back stack)
adb shell am start -n <package>/<activity> # launch app
adb shell dumpsys meminfo <package>        # memory usage

# Permissions
adb shell pm list permissions -g -d        # list dangerous permissions
adb shell pm revoke <pkg> <permission>
adb shell pm grant <pkg> <permission>

# Storage
adb shell df -h /data                      # check free space
adb shell dd if=/dev/zero of=/data/local/tmp/filler bs=1M count=N  # fill
adb shell rm /data/local/tmp/filler        # free

# Clock (requires root)
adb root
adb shell settings put global auto_time 0
adb shell date -s "202506230900.00"
adb shell settings put global auto_time 1   # restore

# Logging
adb logcat -s flutter,stderr,AndroidRuntime
adb logcat | grep -i "dio\|retrofit\|okhttp"
```

---

## Dio fault interceptor quick reference

| Flag | Value | Effect |
|---|---|---|
| `FAULT_DELAY_MS` | milliseconds (e.g. `3000`) | Delay every matched request by N ms |
| `FAULT_STATUS` | HTTP status (e.g. `503`) | Return synthetic response with this status |
| `FAULT_DROP` | `true` | Reject request with `connectionError` (simulate socket drop) |
| `FAULT_CORRUPT` | `1` | Replace response body with `{broken` (simulate malformed JSON) |
| `FAULT_PATH` | path substring (e.g. `/products`) | Only apply faults to matching requests |

Combine flags for compound scenarios:
```bash
# 3s delay + 503 status on /api endpoints:
flutter run --dart-define=FAULT_DELAY_MS=3000 \
            --dart-define=FAULT_STATUS=503 \
            --dart-define=FAULT_PATH=/api
```
