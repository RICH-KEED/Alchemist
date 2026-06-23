// core/error/error_mapper.dart
//
// The ONE place that turns low-level exceptions into typed [Failure]s.
// Call it in the data layer (data sources / repository impls) — see
// `runCatchingAsync` in result.dart, which takes this as `mapError`.
//
// Keep this exhaustive-ish: anything unrecognised becomes UnknownFailure so a
// raw exception never escapes the boundary.
//
// See ../../references/CONVENTIONS.md §5.

import 'dart:async';

import 'package:dio/dio.dart';

import 'failure.dart';

/// Map any [error] (with its [st]) to a typed [Failure].
///
/// Order matters: most specific first, broad fallback last.
Failure mapError(Object error, StackTrace st) {
  return switch (error) {
    // Already typed — pass it straight through (idempotent).
    final Failure f => f,
    final DioException e => _mapDio(e, st),
    final TimeoutException _ => TimeoutFailure(
        'The operation timed out.',
        cause: error,
        stackTrace: st,
      ),
    final FormatException e => ValidationFailure(
        'Received malformed data: ${e.message}',
        cause: error,
        stackTrace: st,
      ),
    // dart:io SocketException etc. are matched by name to avoid importing
    // dart:io into shared code that may run on web.
    _ when error.runtimeType.toString() == 'SocketException' =>
      NetworkFailure(
        'No internet connection.',
        cause: error,
        stackTrace: st,
      ),
    _ => UnknownFailure(
        'Something went wrong.',
        code: error.runtimeType.toString(),
        cause: error,
        stackTrace: st,
      ),
  };
}

Failure _mapDio(DioException e, StackTrace st) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return TimeoutFailure(
        'The request timed out. Check your connection and try again.',
        cause: e,
        stackTrace: st,
      );

    case DioExceptionType.connectionError:
      return NetworkFailure(
        'Could not reach the server.',
        cause: e,
        stackTrace: st,
      );

    case DioExceptionType.cancel:
      // A cancelled request is rarely user-visible; classify as unknown so a
      // caller that *does* surface it has a generic, safe message.
      return UnknownFailure(
        'The request was cancelled.',
        code: 'dio_cancel',
        cause: e,
        stackTrace: st,
      );

    case DioExceptionType.badCertificate:
      return NetworkFailure(
        'Could not establish a secure connection.',
        cause: e,
        stackTrace: st,
      );

    case DioExceptionType.badResponse:
      return _mapStatus(e, st);

    case DioExceptionType.unknown:
      return _mapStatus(e, st);
  }
}

/// Map an HTTP status code to the most precise [Failure].
Failure _mapStatus(DioException e, StackTrace st) {
  final status = e.response?.statusCode;
  switch (status) {
    case 400:
    case 422:
      return ValidationFailure(
        _serverMessage(e) ?? 'The submitted data was rejected.',
        fieldErrors: _fieldErrors(e),
        cause: e,
        stackTrace: st,
      );
    case 401:
    case 403:
      return UnauthorizedFailure(
        _serverMessage(e) ?? 'You are not authorized to do that.',
        statusCode: status,
        cause: e,
        stackTrace: st,
      );
    case 404:
      return NotFoundFailure(
        _serverMessage(e) ?? 'We could not find what you were looking for.',
        cause: e,
        stackTrace: st,
      );
    case null:
      return NetworkFailure(
        'Network request failed.',
        cause: e,
        stackTrace: st,
      );
    default:
      return NetworkFailure(
        _serverMessage(e) ?? 'Server error (HTTP $status).',
        statusCode: status,
        cause: e,
        stackTrace: st,
      );
  }
}

/// Best-effort extraction of a `{"message": "..."}` style error body.
String? _serverMessage(DioException e) {
  final data = e.response?.data;
  if (data is Map) {
    final msg = data['message'] ?? data['error'] ?? data['detail'];
    if (msg is String && msg.isNotEmpty) return msg;
  }
  return null;
}

/// Best-effort extraction of a `{"errors": {"field": "msg"}}` style map.
Map<String, String> _fieldErrors(DioException e) {
  final data = e.response?.data;
  if (data is Map && data['errors'] is Map) {
    return (data['errors'] as Map).map(
      (key, value) => MapEntry('$key', '$value'),
    );
  }
  return const {};
}
