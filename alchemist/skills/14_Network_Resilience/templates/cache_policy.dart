// core/network/cache_policy.dart
//
// A small, generic cache-then-network helper implementing stale-while-revalidate
// over an injected cache store. Owned by skill 14 (Network_Resilience).
//
// The store INTERFACE lives here; the concrete implementation belongs to the app
// (back it with `drift`/`isar` per CONVENTIONS §1). Keeping the interface in
// core/ means repositories depend on the abstraction, not the DB.
//
// See ../../../references/CONVENTIONS.md §5 (Result contract) and ../SKILL.md
// (offline strategy).

import '../error/failure.dart';
import '../error/result.dart';

/// A persisted cache entry plus the metadata needed to reason about freshness.
class CacheEntry<T> {
  const CacheEntry({required this.value, required this.storedAt});

  final T value;
  final DateTime storedAt;

  /// True when the entry is older than [maxAge] and should be revalidated.
  bool isStale(Duration maxAge) =>
      DateTime.now().difference(storedAt) > maxAge;
}

/// Read/write contract for a typed cache. Implement against the project DB.
/// Keys are caller-defined (e.g. `'user:42'`, `'feed:home'`).
abstract interface class CacheStore<T> {
  /// Returns the cached entry for [key], or `null` on a miss.
  Future<CacheEntry<T>?> read(String key);

  /// Persists [value] under [key], stamping `storedAt = now`.
  Future<void> write(String key, T value);

  /// Removes [key] from the cache (e.g. on logout or invalidation).
  Future<void> remove(String key);
}

/// How a [cached] call should balance freshness against availability.
enum CacheStrategy {
  /// Serve fresh cache if within [CachePolicy.maxAge]; otherwise hit the
  /// network. On network failure, fall back to stale cache when available.
  cacheFirst,

  /// Always revalidate from the network; serve cache only as an offline
  /// fallback. Use for data that must be as fresh as possible.
  networkFirst,
}

/// Tunables for a single [cached] call.
class CachePolicy {
  const CachePolicy({
    this.maxAge = const Duration(minutes: 5),
    this.strategy = CacheStrategy.cacheFirst,
  });

  /// Cache younger than this is considered fresh.
  final Duration maxAge;

  final CacheStrategy strategy;
}

/// Cache-then-network read with stale-while-revalidate semantics.
///
/// * `cacheFirst`: fresh cache → return it. Stale/miss → fetch; on success
///   write-through and return; on failure, return stale cache if present, else
///   the failure.
/// * `networkFirst`: fetch first; on success write-through and return; on
///   failure, return cache (even if stale) if present, else the failure.
///
/// [fetch] is the network call (typically a repository method returning a
/// mapped domain value as `Result<T>`). [store] persists across launches.
///
/// ```dart
/// final user = await cached<User>(
///   key: 'user:$id',
///   store: userCacheStore,
///   fetch: () => _api.fetchUser(id),
///   policy: const CachePolicy(maxAge: Duration(minutes: 10)),
/// );
/// ```
Future<Result<T>> cached<T>({
  required String key,
  required CacheStore<T> store,
  required Future<Result<T>> Function() fetch,
  CachePolicy policy = const CachePolicy(),
}) async {
  final CacheEntry<T>? entry;
  try {
    entry = await store.read(key);
  } on Object catch (e, st) {
    // A broken cache must never break the read — degrade to network-only.
    return _fetchAndStore(key: key, store: store, fetch: fetch) //
        .catchError((Object _) => Err<T>(CacheFailure('cache read failed',
            cause: e, stackTrace: st)));
  }

  final hasFresh = entry != null && !entry.isStale(policy.maxAge);

  if (policy.strategy == CacheStrategy.cacheFirst && hasFresh) {
    return Ok<T>(entry.value);
  }

  final networkResult = await _fetchAndStore(
    key: key,
    store: store,
    fetch: fetch,
  );

  // On a network failure, fall back to whatever cache we have (stale included).
  if (networkResult.isErr && entry != null) {
    return Ok<T>(entry.value);
  }
  return networkResult;
}

/// Run [fetch]; on success, write-through to [store]. Cache write failures are
/// swallowed (logged by the caller) so they never mask a good network value.
Future<Result<T>> _fetchAndStore<T>({
  required String key,
  required CacheStore<T> store,
  required Future<Result<T>> Function() fetch,
}) async {
  final result = await fetch();
  return switch (result) {
    Ok<T>(:final value) => await _writeThrough(store, key, value),
    Err<T>() => result,
  };
}

Future<Result<T>> _writeThrough<T>(
  CacheStore<T> store,
  String key,
  T value,
) async {
  try {
    await store.write(key, value);
  } on Object {
    // Non-fatal: the network value is still valid even if persistence failed.
  }
  return Ok<T>(value);
}
