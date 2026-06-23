// core/network/retry_interceptor.dart
//
// A dio Interceptor that retries failed requests with bounded, jittered
// exponential backoff. Owned by skill 14 (Network_Resilience).
//
// Design rules (see ../SKILL.md):
//   * Only retry SAFE, idempotent requests. A non-idempotent POST that may have
//     already mutated server state must NOT be replayed blindly.
//   * Retry only transient conditions: connect/receive/send timeouts, connection
//     errors, and the transient status codes 408 / 429 / 500 / 502 / 503 / 504.
//   * Honour a `Retry-After` header (seconds or HTTP-date) when present.
//   * Cap total attempts so retries are always BOUNDED — never an infinite loop.
//   * Respect caller cancellation: a cancelled request is never retried.
//
// Add to the dio client AFTER the auth interceptor and BEFORE the error-mapping
// interceptor, so a successful retry never surfaces as a Failure.
//
// See ../../../references/CONVENTIONS.md §1 (networking = dio).

import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';

/// Tunable policy for [RetryInterceptor]. Defaults are conservative and safe
/// for a typical mobile app; override per-environment as needed.
class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 300),
    this.maxDelay = const Duration(seconds: 8),
    this.retryableStatusCodes = const {408, 429, 500, 502, 503, 504},
    this.retryableMethods = const {'GET', 'HEAD', 'OPTIONS', 'PUT', 'DELETE'},
  });

  /// Total tries INCLUDING the first. `3` means 1 initial + up to 2 retries.
  final int maxAttempts;

  /// First backoff delay; doubles each attempt before jitter.
  final Duration baseDelay;

  /// Upper bound for a single backoff delay (caps exponential growth).
  final Duration maxDelay;

  /// HTTP status codes considered transient and worth retrying.
  final Set<int> retryableStatusCodes;

  /// Idempotent methods that are safe to replay. POST/PATCH are excluded by
  /// default — opt a specific request in via `extra['retryable'] == true` only
  /// when you KNOW it is idempotent (e.g. guarded by an idempotency key).
  final Set<String> retryableMethods;
}

/// Per-request opt-in/out flags read from `RequestOptions.extra`.
class RetryExtras {
  /// Force a request to be retryable even if its method isn't idempotent by
  /// default — use only with a server-side idempotency key.
  static const optIn = 'retryable';

  /// Force-disable retries for a specific request.
  static const optOut = 'noRetry';

  /// Internal: the attempt counter we thread through `extra`.
  static const attempt = 'retryAttempt';
}

/// Retries transient dio failures with exponential backoff + full jitter.
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required Dio dio,
    this.policy = const RetryPolicy(),
    Random? random,
  })  : _dio = dio,
        _random = random ?? Random();

  final Dio _dio;
  final RetryPolicy policy;
  final Random _random;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final attempt = (request.extra[RetryExtras.attempt] as int?) ?? 0;

    if (!_shouldRetry(err, attempt)) {
      return handler.next(err); // give up — let the error mapper classify it.
    }

    final delay = _delayFor(err, attempt);
    try {
      await Future<void>.delayed(delay);
    } on Object {
      return handler.next(err);
    }

    // Thread the incremented attempt count and replay the request.
    final nextOptions = request.copyWith(
      extra: {...request.extra, RetryExtras.attempt: attempt + 1},
    );

    try {
      final response = await _dio.fetch<dynamic>(nextOptions);
      return handler.resolve(response); // retry succeeded.
    } on DioException catch (e) {
      return handler.next(e); // re-enters onError; bounded by maxAttempts.
    }
  }

  /// True when the failure is transient AND we have retries left AND the
  /// request is safe to replay AND it wasn't cancelled.
  bool _shouldRetry(DioException err, int attempt) {
    if (attempt >= policy.maxAttempts - 1) return false;
    if (err.type == DioExceptionType.cancel) return false;

    final request = err.requestOptions;
    if (request.extra[RetryExtras.optOut] == true) return false;

    if (!_isMethodRetryable(request)) return false;

    return switch (err.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError =>
        true,
      DioExceptionType.badResponse => policy.retryableStatusCodes
          .contains(err.response?.statusCode),
      _ => false,
    };
  }

  bool _isMethodRetryable(RequestOptions request) {
    if (request.extra[RetryExtras.optIn] == true) return true;
    return policy.retryableMethods.contains(request.method.toUpperCase());
  }

  /// Backoff delay for [attempt] (0-based). Prefers an explicit `Retry-After`
  /// header (429/503); otherwise exponential backoff with full jitter:
  ///   delay = random(0, min(maxDelay, baseDelay * 2^attempt))
  Duration _delayFor(DioException err, int attempt) {
    final retryAfter = _retryAfter(err.response);
    if (retryAfter != null) {
      return retryAfter > policy.maxDelay ? policy.maxDelay : retryAfter;
    }

    final exp = policy.baseDelay.inMilliseconds * pow(2, attempt).toInt();
    final capped = min(exp, policy.maxDelay.inMilliseconds);
    final jittered = _random.nextInt(capped + 1); // full jitter
    return Duration(milliseconds: jittered);
  }

  /// Parse a `Retry-After` header: delta-seconds or an HTTP-date.
  Duration? _retryAfter(Response<dynamic>? response) {
    final raw = response?.headers.value('retry-after');
    if (raw == null) return null;

    final seconds = int.tryParse(raw.trim());
    if (seconds != null) return Duration(seconds: seconds);

    final date = HttpDate.tryParse(raw);
    if (date != null) {
      final delta = date.difference(DateTime.now());
      return delta.isNegative ? Duration.zero : delta;
    }
    return null;
  }
}

/// Minimal, dependency-free HTTP-date parsing (RFC 7231 IMF-fixdate is the only
/// form servers must emit). Returns `null` on anything it can't parse.
class HttpDate {
  HttpDate._();

  static DateTime? tryParse(String value) {
    try {
      // `dart:io` ships HttpDate.parse, but core/network stays io-light; fall
      // back to DateTime for the common ISO/RFC overlap, else give up.
      return DateTime.tryParse(value)?.toUtc();
    } on Object {
      return null;
    }
  }
}
