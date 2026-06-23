// core/network/circuit_breaker.dart
//
// A minimal circuit breaker to stop hammering a dead/struggling endpoint.
// Owned by skill 14 (Network_Resilience).
//
// States:
//   closed    → calls flow through; consecutive failures are counted.
//   open      → calls are rejected immediately for `resetTimeout`; protects the
//               backend and fails fast instead of stacking timeouts.
//   halfOpen  → after the cooldown, one trial call is allowed; success closes
//               the breaker, failure re-opens it.
//
// Wrap ONE breaker per logical endpoint (or host) and share it across requests.
// Pair with the retry interceptor: retries handle transient blips; the breaker
// handles a sustained outage.
//
// See ../SKILL.md (circuit breaker) and ../../../references/CONVENTIONS.md §5.

import 'dart:async';

import '../error/failure.dart';
import '../error/result.dart';

/// Observable breaker states.
enum CircuitState { closed, open, halfOpen }

/// Thrown internally / surfaced as a [NetworkFailure] when the breaker rejects
/// a call because the circuit is open.
class CircuitOpenException implements Exception {
  const CircuitOpenException(this.retryAfter);

  /// How long until the breaker will next allow a trial call.
  final Duration retryAfter;

  @override
  String toString() => 'CircuitOpenException(retryAfter: $retryAfter)';
}

/// A single-endpoint circuit breaker. Not tied to dio — wrap any async fn.
class CircuitBreaker {
  CircuitBreaker({
    this.failureThreshold = 5,
    this.resetTimeout = const Duration(seconds: 30),
    DateTime Function() now = DateTime.now,
  }) : _now = now;

  /// Consecutive failures in `closed` state that trip the breaker to `open`.
  final int failureThreshold;

  /// How long the breaker stays `open` before allowing a half-open trial.
  final Duration resetTimeout;

  final DateTime Function() _now;

  CircuitState _state = CircuitState.closed;
  int _consecutiveFailures = 0;
  DateTime? _openedAt;

  CircuitState get state {
    _maybeHalfOpen();
    return _state;
  }

  /// Run [action] through the breaker.
  ///
  /// * `open` (still cooling down) → returns `Err(NetworkFailure)` WITHOUT
  ///   calling [action] (fail fast).
  /// * otherwise runs [action]; a thrown error counts as a failure and is
  ///   mapped via [mapError]. Success resets the breaker.
  Future<Result<T>> run<T>(
    Future<T> Function() action, {
    required Failure Function(Object error, StackTrace st) mapError,
  }) async {
    _maybeHalfOpen();

    if (_state == CircuitState.open) {
      return Err<T>(
        NetworkFailure(
          'Circuit open — endpoint temporarily unavailable',
          cause: CircuitOpenException(_remainingCooldown()),
        ),
      );
    }

    try {
      final value = await action();
      _onSuccess();
      return Ok<T>(value);
    } catch (error, st) {
      _onFailure();
      return Err<T>(mapError(error, st));
    }
  }

  /// Transition `open → halfOpen` once the cooldown has elapsed.
  void _maybeHalfOpen() {
    if (_state != CircuitState.open) return;
    final openedAt = _openedAt;
    if (openedAt == null) return;
    if (_now().difference(openedAt) >= resetTimeout) {
      _state = CircuitState.halfOpen;
    }
  }

  void _onSuccess() {
    _consecutiveFailures = 0;
    _state = CircuitState.closed;
    _openedAt = null;
  }

  void _onFailure() {
    // A failure during the half-open trial re-opens immediately.
    if (_state == CircuitState.halfOpen) {
      _trip();
      return;
    }
    _consecutiveFailures++;
    if (_consecutiveFailures >= failureThreshold) _trip();
  }

  void _trip() {
    _state = CircuitState.open;
    _openedAt = _now();
  }

  Duration _remainingCooldown() {
    final openedAt = _openedAt;
    if (openedAt == null) return Duration.zero;
    final elapsed = _now().difference(openedAt);
    final remaining = resetTimeout - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Force the breaker closed (e.g. after manual recovery or on app resume).
  void reset() => _onSuccess();
}
