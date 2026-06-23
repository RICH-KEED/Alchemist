---
name: Network Resilience
description: Make a Flutter app robust to bad networks — bounded retries with exponential backoff + jitter, sane timeouts, connectivity detection, offline caching, write queues, and a circuit breaker. Use when the app must survive slow/flaky/offline networks or 5xx servers, when adding retry/timeout logic to the dio client, or at pipeline stage 14.
when_to_use: Trigger on "handle offline", "add retries", "the app breaks on bad wifi", "requests hang forever", "cache for offline", "stop hammering the server", "circuit breaker", or when stage 14 of the pipeline runs. For raw client/repository wiring use skill 11; for typed errors use skill 15; for loading/offline UI use skill 16.
---

# Network Resilience

You make the app **degrade gracefully** when the network misbehaves. The exit
gate for this stage: *the app degrades gracefully offline, and retries are
bounded*. Everything here sits in `core/network/` and feeds the dio client from
[skill 11](../11_Backend_Integration), returns typed errors from
[skill 15](../15_Error_Handling), and surfaces state through the UI patterns in
[skill 16](../16_Loading_States).

Follow the house style in [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md):
Dart 3, Riverpod, dio; errors as `Result<T>` / `Failure` from `core/error/`.

## The four failure modes (and the response to each)

| Failure mode | What the user sees without us | Our response |
|---|---|---|
| **Slow** (high latency, stalled socket) | Infinite spinner | **Timeouts** (connect/receive/send) + cancellation so a call can't hang forever |
| **Flaky** (intermittent drops, transient 5xx) | Random errors | **Bounded retries** with exponential backoff + jitter on *safe* requests only |
| **Offline** (no transport) | Crash / blank screen | **Connectivity awareness** + **cache-then-network** reads + **outbox** for writes |
| **Server struggling** (sustained 5xx/timeouts) | Stacked retries pile load onto a dying backend | **Circuit breaker**: fail fast while it recovers |

These compose: a flaky request retries a couple of times; if it keeps failing
the breaker opens; reads still serve from cache; writes queue in the outbox; the
UI shows an offline banner. No spinner runs forever.

## Retry policy — the rules

Retries are the most dangerous tool here. Get the policy right:

- **Only retry idempotent requests.** `GET`/`HEAD`/`OPTIONS`/`PUT`/`DELETE` are
  safe to replay. **Never auto-retry `POST`/`PATCH`** unless it carries a
  server-side **idempotency key** (then opt it in explicitly).
- **Only retry transient conditions:** connection/timeout errors, and status
  **408, 429, 500, 502, 503, 504**. A `400`/`401`/`404`/`422` will fail again —
  retrying just wastes time and battery.
- **Respect `Retry-After`** on `429`/`503` (delta-seconds or HTTP-date). Honour
  the server's pacing before falling back to computed backoff.
- **Exponential backoff with jitter.** `delay = random(0, min(maxDelay,
  base · 2^attempt))`. Full jitter prevents a thundering herd of clients
  retrying in lockstep.
- **Bound everything.** A hard `maxAttempts` (default 3 = 1 try + 2 retries).
  Retries must terminate — never loop until success.

Implementation: [`templates/retry_interceptor.dart`](templates/retry_interceptor.dart),
a dio `Interceptor` you register **after** auth and **before** the error mapper.

## Timeouts and cancellation

A request with no time budget is a latent infinite spinner. Set all three on the
dio `BaseOptions` (skill 11 owns the client; these are its resilience defaults):

```dart
BaseOptions(
  connectTimeout: const Duration(seconds: 10), // TCP/TLS handshake
  sendTimeout: const Duration(seconds: 10),    // uploading the request body
  receiveTimeout: const Duration(seconds: 20), // streaming the response
);
```

- Pass a `CancelToken` for any request tied to a screen; cancel it in the
  notifier's `dispose`/`onDispose` so navigating away aborts in-flight work.
- A cancelled request is **never** retried (the interceptor checks this).

## Connectivity awareness

[`templates/connectivity_service.dart`](templates/connectivity_service.dart)
wraps **`connectivity_plus`** in `@riverpod` providers:

- `connectivityStatusProvider` — a `Stream<ConnectivityStatus>` (online/offline).
- `isOnlineProvider` — a boolean view, optimistic on cold start.

```yaml
# pubspec.yaml
dependencies:
  connectivity_plus: ^6.0.0
```

> **Transport ≠ reachability.** `connectivity_plus` reports wifi/mobile/none, not
> whether your backend answers. A captive portal reads as "online". Use it as a
> fast hint to *skip* doomed calls and show a banner; the retry interceptor and
> circuit breaker remain the source of truth for actual success.

## Offline strategy — reads and writes

**Reads: cache-then-network (stale-while-revalidate).**
[`templates/cache_policy.dart`](templates/cache_policy.dart) provides
`Future<Result<T>> cached<T>(...)` over a `CacheStore<T>` interface (defined
there; back the impl with `drift`/`isar` per CONVENTIONS §1):

- `cacheFirst`: fresh cache → return instantly; stale/miss → fetch, write
  through, return; on network failure → serve stale cache if present.
- `networkFirst`: revalidate first; fall back to cache (even stale) when offline.

This is what makes the app *usable* offline: the last-known-good data is always
on screen, and a refresh quietly happens when connectivity returns.

**Writes: an outbox/queue.** Don't lose a user's action because they were in a
tunnel. Persist mutations to a durable queue and drain it when back online:

```dart
// Sketch — back the queue with the project DB; replay is idempotent.
class OutboxEntry {
  final String id;          // client-generated; doubles as idempotency key
  final String endpoint;    // where to replay
  final Map<String, dynamic> body;
  final DateTime queuedAt;
}

// On connectivity regained (watch connectivityStatusProvider), drain in order:
//   for each entry → send with its idempotency key → on Ok remove it.
// Replays are safe because the server dedupes on the idempotency key.
```

Queue writes optimistically (update local state now, sync later), tag each entry
with a client-generated id used as the idempotency key, and drain FIFO when
`connectivityStatusProvider` flips to online.

## Circuit breaker

When an endpoint is *down* (not just blipping), retrying every request stacks
timeouts onto a dying server and freezes the UI.
[`templates/circuit_breaker.dart`](templates/circuit_breaker.dart) is a minimal
**closed → open → half-open** breaker, one per endpoint/host:

- **closed:** calls flow; count consecutive failures.
- **open:** after `failureThreshold` failures, reject calls instantly for
  `resetTimeout` (fail fast, return `NetworkFailure`).
- **half-open:** after cooldown, allow one trial — success closes it, failure
  re-opens it.

Retries handle transient blips; the breaker handles sustained outages. Use both.

## Surfacing offline state in the UI (ties to skill 16)

Resilience is invisible unless the UI reflects it:

- Watch `connectivityStatusProvider` at the app shell; show a dismissible
  **offline banner** when offline.
- When serving stale cache, badge it ("Showing saved data") so users know it may
  be out of date — see skill 16's empty/error/stale states.
- Disable or queue actions that need the network; never leave a button spinning.
- On reconnect, auto-refresh visible data and drain the outbox.

## Anti-patterns (do not ship these)

- **Retrying non-idempotent writes** — a replayed `POST` double-charges /
  double-posts. Idempotency key or no retry.
- **Unbounded retries** — "keep trying until it works" hammers the server and
  drains the battery. Always cap attempts.
- **Retrying client errors** — `4xx` (except 408/429) won't change on replay.
- **No timeouts** — a stalled socket becomes a permanent spinner.
- **Infinite spinner offline** — detect offline and render a real offline state.
- **Retrying in lockstep** — no jitter ⇒ thundering herd when the server recovers.
- **Trusting connectivity_plus as truth** — it's a hint, not a reachability check.

## Definition of done (stage 14 gate)

- All requests have connect/receive/send timeouts and cancellation wired.
- Retry interceptor registered; only idempotent/transient requests retry,
  bounded by `maxAttempts`, with jittered backoff and `Retry-After` honoured.
- `connectivityStatusProvider` drives an offline banner in the app shell.
- Key reads go through `cached<T>(...)`; the app shows last-known-good data
  offline. Writes queue in an outbox and drain on reconnect.
- A circuit breaker guards at least the primary backend host.
- Verified manually: airplane-mode the device → app stays usable, no infinite
  spinners, no uncaught errors; restore network → data refreshes and queue drains.

See [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md) for the
full house style, and skills [11](../11_Backend_Integration) /
[15](../15_Error_Handling) / [16](../16_Loading_States) for the surrounding
contracts.
