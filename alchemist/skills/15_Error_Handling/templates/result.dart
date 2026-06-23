// core/error/result.dart
//
// The canonical Result<T> type for the whole app. Owned by skill 15.
// Every repository / use-case returns Result<T> (or Future<Result<T>>) and
// NEVER throws across a layer boundary. The UI pattern-matches on it.
//
// See ../../references/CONVENTIONS.md §5 (Result & error contract).

import 'failure.dart';

/// A success-or-failure value. Use [Ok] for a value, [Err] for a [Failure].
///
/// ```dart
/// final result = await repo.fetchUser(id);
/// switch (result) {
///   case Ok(:final value):
///     print('got $value');
///   case Err(:final failure):
///     print('failed: ${failure.message}');
/// }
/// ```
sealed class Result<T> {
  const Result();

  /// Wrap a value as a successful result.
  const factory Result.ok(T value) = Ok<T>;

  /// Wrap a [Failure] as a failed result.
  const factory Result.err(Failure failure) = Err<T>;

  /// `true` when this is an [Ok].
  bool get isOk => this is Ok<T>;

  /// `true` when this is an [Err].
  bool get isErr => this is Err<T>;
}

/// The success case, carrying a [value].
final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Ok<T> && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Ok($value)';
}

/// The failure case, carrying a typed [failure].
final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Err<T> && other.failure == failure);

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'Err($failure)';
}

/// Ergonomic helpers. These keep call sites free of manual `switch`es when a
/// simple transform / collapse is all that is needed.
extension ResultX<T> on Result<T> {
  /// Collapse both cases into a single value of type [R].
  R fold<R>(R Function(T value) onOk, R Function(Failure failure) onErr) =>
      switch (this) {
        Ok<T>(:final value) => onOk(value),
        Err<T>(:final failure) => onErr(failure),
      };

  /// Exhaustive callback form of [fold]. Reads well at call sites that care
  /// about both branches but do not need to return a value.
  R when<R>({
    required R Function(T value) ok,
    required R Function(Failure failure) err,
  }) =>
      fold(ok, err);

  /// Transform the success value, preserving any failure.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
        Ok<T>(:final value) => Ok<R>(transform(value)),
        Err<T>(:final failure) => Err<R>(failure),
      };

  /// Chain another fallible operation onto the success value.
  Result<R> flatMap<R>(Result<R> Function(T value) transform) =>
      switch (this) {
        Ok<T>(:final value) => transform(value),
        Err<T>(:final failure) => Err<R>(failure),
      };

  /// Transform the failure, preserving any success value.
  Result<T> mapErr(Failure Function(Failure failure) transform) =>
      switch (this) {
        Ok<T>() => this,
        Err<T>(:final failure) => Err<T>(transform(failure)),
      };

  /// The success value, or `null` if this is an [Err].
  T? get valueOrNull => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>() => null,
      };

  /// The failure, or `null` if this is an [Ok].
  Failure? get failureOrNull => switch (this) {
        Ok<T>() => null,
        Err<T>(:final failure) => failure,
      };

  /// The success value, or [fallback] if this is an [Err].
  T getOrElse(T Function(Failure failure) fallback) => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>(:final failure) => fallback(failure),
      };
}

/// Lift a possibly-throwing synchronous computation into a [Result].
/// Pass a `mapError` (e.g. the project's `mapError`) to type the failure.
Result<T> runCatching<T>(
  T Function() body, {
  required Failure Function(Object error, StackTrace st) mapError,
}) {
  try {
    return Ok(body());
  } catch (error, st) {
    return Err(mapError(error, st));
  }
}

/// Async variant of [runCatching].
Future<Result<T>> runCatchingAsync<T>(
  Future<T> Function() body, {
  required Failure Function(Object error, StackTrace st) mapError,
}) async {
  try {
    return Ok(await body());
  } catch (error, st) {
    return Err(mapError(error, st));
  }
}
