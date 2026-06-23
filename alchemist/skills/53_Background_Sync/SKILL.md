---
name: Background Sync
description: Schedule durable periodic background work with WorkManager + Dart isolates — outbox flush, data sync, and dead-letter recovery — so the app stays consistent even when the user is not looking. Use when writes must drain offline, when data must refresh on a cadence, or when retries from #14 have been exhausted and need deferred execution.
when_to_use: Trigger on "background sync", "periodic task", "WorkManager", "offline outbox", "background fetch", "drain the outbox in the background", "schedule a sync", "workmanager setup", "isolate for background work", or when stage 14 has queued writes but the user closed the app. Pairs with #14 (Network Resilience) — #14 handles online detection and immediate retries; #53 handles periodic/deferred execution when the app is backgrounded or connectivity is not yet restored.
---

# Background Sync (#53)

The outbox from [skill 14](../14_Network_Resilience) queues writes when offline.
This skill drains them **periodically, in the background, on a Dart isolate** —
even when the app is not in the foreground. House style:
[`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).

> **Relationship to #14:** #14 owns the outbox contract, connectivity-triggered
> drain, and immediate retries. #53 owns the **periodic scheduler**, the
> **isolate execution**, the **Drift table schema**, and the **retry/dead-letter
> lifecycle**. They share the same outbox table; the `processing` status prevents
> double-drain if both fire concurrently.

---

## 1. Architecture

WorkManager schedules a periodic task (min 15 min interval) constrained to
`NetworkType.connected` + `BatteryNotLow`. On each cycle, WorkManager spawns a
Dart isolate and calls the top-level `callbackDispatcher`, which invokes
`BackgroundSyncService.processOutbox()` — reading/writing the Drift outbox table
with its own Dio client. The outbox is the single source of truth; entries are
created by the repository layer (when offline) and consumed by either #14's
connectivity-triggered drain or #53's periodic cadence.

Full implementation: [`templates/background_job.dart`](templates/background_job.dart).

---

## 2. WorkManager setup

**pubspec.yaml:** `workmanager: ^0.5.2`, `drift: ^2.x`, `sqlite3_flutter_libs: ^0.5.x`.

**Android manifest** — register under `<application>`:
```xml
<provider android:name="androidx.startup.InitializationProvider"
    android:authorities="${applicationId}.androidx-startup"
    android:exported="false" tools:node="merge" />
```

**Initialization** — call once in `main()`:
```dart
@pragma('vm:entry-point')  // required: prevents tree-shaking in release
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    switch (taskName) {
      case 'outbox-flush':
        await BackgroundSyncService.instance.processOutbox();
        return true;   // true = success; false = retry later
      default:
        return true;
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: kDebugMode);
  await BackgroundSyncService.instance.initialize();
  runApp(const MyApp());
}
```

The `@pragma('vm:entry-point')` annotation is **required** — without it,
tree-shaking strips the callback in release builds.

---

## 3. Periodic task registration

```dart
await Workmanager().registerPeriodicTask(
  'outbox-flush-1',
  'outbox-flush',
  tag: 'background-sync',
  frequency: const Duration(minutes: 15), // Android minimum
  constraints: Constraints(
    networkType: NetworkType.connected,
    requiresBatteryNotLow: true,
  ),
  backoffPolicy: BackoffPolicy.exponential,
  backoffPolicyDelay: const Duration(minutes: 1),
  existingWorkPolicy: ExistingWorkPolicy.keep,
);
```

Key decisions:
- **15 min frequency** — Android's enforced minimum.
- **`NetworkType.connected`** — don't wake the radio without transport.
- **`BatteryNotLow: true`** — user-facing work first.
- **`keep`** — don't re-register if already scheduled.
- **`exponential` backoff** — if a run fails, back off internally before retrying.

---

## 4. Outbox table (Drift)

| Column | Type | Role |
|---|---|---|
| `id` | `text` (PK) | Client-generated UUID; doubles as idempotency key |
| `operationType` | `text` | `POST`, `PUT`, `PATCH`, `DELETE` |
| `endpoint` | `text` | URL path to replay against |
| `payload` | `text` | JSON-encoded body |
| `createdAt` | `int` | Unix ms for FIFO ordering |
| `retryCount` | `int` | Current attempt (0 = never tried) |
| `maxRetries` | `int` | Hard cap (default 5) |
| `status` | `text` | `pending`, `processing`, `done`, `failed` |
| `lastError` | `text?` | Most recent error (nullable) |

Full Drift definition with DAO queries (`getPending`, `markDone`, `bumpRetry`,
`purgeDone`) is in the template.

---

## 5. Sync engine lifecycle

| Phase | Action |
|---|---|
| **Enqueue** | `INSERT` with status `pending`, retryCount 0. Called from repository when offline or after #14 exhausts its retries. |
| **Drain** | `SELECT * WHERE status IN ('pending','processing') ORDER BY createdAt ASC`. Process FIFO on the background isolate. |
| **Replay** | Set status `processing` → HTTP call with `Idempotency-Key` header → on 2xx mark `done`; on retryable failure bump retry count; on max retries mark `failed`. |
| **Backoff** | Apply full-jitter delay before the next entry in the batch. |
| **Dead-letter** | Entries with status `failed` are left for inspection; logged to Sentry/logger. A `deadLetters` getter exposes them for admin review. |

---

## 6. Retry strategy

| Parameter | Value |
|---|---|
| Algorithm | Full-jitter exponential backoff |
| Base | 1 second |
| Cap | 60 seconds |
| Formula | `min(60000, random(0, 1000 * 2^retryCount))` |
| Max attempts | 5 (per-entry, via `maxRetries` column) |
| After max | Mark `failed`, log to Sentry, expose in dead-letter queue |
| Retryable codes | 408, 429, 500, 502, 503, 504 (same as #14) |

Unlike #14's immediate in-process retries (capped at 3), these retries span
minutes to hours across periodic cycles. A `retryCount=4` entry gets ~16s of
backoff before its next attempt on the following cycle.

---

## 7. Isolate constraints

The `callbackDispatcher` runs in a fresh Dart isolate with **no shared memory**:

- No Riverpod providers, `BuildContext`, or `Theme` available.
- Dio must be constructed fresh inside the isolate.
- Drift must use `NativeDatabase` from `sqlite3_flutter_libs` (not
  platform-channel-based openers) so it works in any isolate.
- Pass the database file path via `inputData` rather than relying on
  `path_provider` (which uses platform channels).

The template constructs a standalone Dio + Drift specifically for the background
isolate.

---

## 8. Pairs with #14 (Network Resilience)

| Concern | #14 (Network Resilience) | #53 (Background Sync) |
|---|---|---|
| **Trigger** | `connectivityStatusProvider` flips online | WorkManager cadence (15+ min) |
| **Context** | UI isolate, in-process | Separate Dart isolate |
| **Outbox drain** | Yes — immediate | Yes — periodic fallback |
| **Retries** | 3 bounded, in-process | 5 deferred, across cycles |
| **Dead letter** | Marks entry for #53 | Owns the workflow |
| **App state** | Foreground | Killed or backgrounded |

Both read `status='pending' ORDER BY createdAt ASC` — the `processing` status
prevents double-processing if both fire simultaneously.

---

## 9. Testing

| Scope | Tool | Verify |
|---|---|---|
| **Unit** | `flutter_test` + `mocktail` | DAO queries return correct rows; `enqueue` sets defaults; `bumpRetry` increments; backoff math is in range |
| **Integration** | `integration_test` | Register periodic task; insert entries; trigger callback via `Workmanager().executeTask()`; verify drain |
| **WM mock** | Mock `Workmanager` | `registerPeriodicTask` called with correct params; `cancelAll()` on logout |
| **Isolate** | Unit + manual | `callbackDispatcher` imports no `dart:ui`; Dio + Drift function in the isolate |

---

## 10. Definition of done

- `workmanager` initialized with `callbackDispatcher` in `main()`.
- Periodic task registered with Connected + BatteryNotLow constraints.
- Drift outbox table with all columns from section 4; DAO with typed queries.
- `enqueue()` inserts from repository layer; `processOutbox()` drains FIFO.
- Exponential backoff with jitter; dead-letter entries logged to Sentry.
- Zero analyzer warnings under `very_good_analysis`.
- Unit tests cover OutboxDao, backoff, and enqueue; integration test covers a
  full drain cycle.

See [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md) for the
full house style, and skill [14](../14_Network_Resilience) for the outbox
contract and connectivity-triggered drain.
