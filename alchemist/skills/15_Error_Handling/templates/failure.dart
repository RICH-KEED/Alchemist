// core/error/failure.dart
//
// The canonical typed-error hierarchy for the whole app. Owned by skill 15.
// Low-level exceptions (DioException, FormatException, …) are mapped to one of
// these in the data layer (see error_mapper.dart) so that no raw exception
// ever crosses a layer boundary.
//
// See ../../references/CONVENTIONS.md §5 (Result & error contract).

/// Base type for everything that can go wrong. Sealed so the UI can switch
/// exhaustively. Every failure carries a developer-facing [message]; most also
/// carry the originating [cause] (kept for logging/crash reports, NOT shown to
/// users) and an optional [code].
sealed class Failure {
  const Failure(this.message, {this.cause, this.stackTrace});

  /// Developer-facing description. For user-facing copy, use the
  /// `failure_x.dart` extension — never surface this string directly.
  final String message;

  /// The original error this failure was mapped from, if any. Forwarded to the
  /// crash reporter (skill 23); never displayed to the user.
  final Object? cause;

  /// Stack trace captured at the mapping site, for logs / crash reports.
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType($message)';
}

/// Connectivity / transport problems: no internet, DNS failure, connection
/// refused, socket reset, or a non-success HTTP response with no better match.
final class NetworkFailure extends Failure {
  const NetworkFailure(
    super.message, {
    this.statusCode,
    super.cause,
    super.stackTrace,
  });

  /// HTTP status code when the failure came from a response, else `null`.
  final int? statusCode;
}

/// The operation exceeded its time budget (connect/send/receive timeout).
final class TimeoutFailure extends Failure {
  const TimeoutFailure(super.message, {super.cause, super.stackTrace});
}

/// Authentication / authorization rejected the request (401 / 403). The UI
/// should typically route the user to re-authenticate.
final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure(
    super.message, {
    this.statusCode,
    super.cause,
    super.stackTrace,
  });

  /// 401 or 403, when known.
  final int? statusCode;
}

/// The requested resource does not exist (404).
final class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message, {super.cause, super.stackTrace});
}

/// Input failed validation, either locally or per the server (422 / 400).
/// [fieldErrors] maps a field name to its first error, for inline UI display.
final class ValidationFailure extends Failure {
  const ValidationFailure(
    super.message, {
    this.fieldErrors = const {},
    super.cause,
    super.stackTrace,
  });

  /// Field name → human-readable error, e.g. `{'email': 'Already in use'}`.
  final Map<String, String> fieldErrors;
}

/// A local cache / persistence read or write failed, or a cache miss occurred
/// where a value was required.
final class CacheFailure extends Failure {
  const CacheFailure(super.message, {super.cause, super.stackTrace});
}

/// The catch-all. Anything the mapper could not classify lands here so the
/// hierarchy stays exhaustive and nothing escapes untyped.
final class UnknownFailure extends Failure {
  const UnknownFailure(
    super.message, {
    this.code,
    super.cause,
    super.stackTrace,
  });

  /// Optional machine code for diagnostics / grouping in the crash reporter.
  final String? code;
}
