import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'example_dto.dart';
import 'example_remote_data_source.dart';

// The error contract is owned by skill 15 in `lib/core/error/`. In a real app,
// delete the placeholder section at the bottom of this file and import:
//
//   import 'package:<app>/core/error/result.dart';        // Result, Ok, Err
//   import 'package:<app>/core/error/error_mapper.dart';  // mapErrorToFailure
//
// The domain repository interface lives in the feature's `domain/` layer:
//
//   import 'package:<app>/features/todo/domain/todo_repository.dart';

part 'example_repository_impl.g.dart';

/// Concrete [TodoRepository]: the boundary where transport errors stop.
///
/// Every method calls the data source inside `try/catch`, maps any exception to
/// a `Failure` via skill 15's `mapErrorToFailure`, maps the DTO to its domain
/// entity with `toEntity()`, and returns `Result<T>` — never throwing across
/// the layer line (skill 06's dependency rule, CONVENTIONS §5).
final class TodoRepositoryImpl implements TodoRepository {
  /// Creates a [TodoRepositoryImpl].
  const TodoRepositoryImpl(this._remote);

  final TodoRemoteDataSource _remote;

  @override
  Future<Result<List<TodoEntity>>> getTodos() async {
    try {
      final dtos = await _remote.fetchTodos();
      return Ok(dtos.map((d) => d.toEntity()).toList());
    } on DioException catch (e, st) {
      return Err(mapErrorToFailure(e, st));
    } on Object catch (e, st) {
      return Err(mapErrorToFailure(e, st));
    }
  }

  @override
  Future<Result<TodoEntity>> getTodo(String id) async {
    try {
      final dto = await _remote.fetchTodo(id);
      return Ok(dto.toEntity());
    } on DioException catch (e, st) {
      return Err(mapErrorToFailure(e, st));
    } on Object catch (e, st) {
      return Err(mapErrorToFailure(e, st));
    }
  }
}

/// Binds the domain [TodoRepository] interface to its implementation.
///
/// Everything downstream depends on this provider's *interface* type, so tests
/// override it (or `dioProvider`) with a fake via `ProviderScope(overrides:)`.
@riverpod
TodoRepository todoRepository(Ref ref) =>
    TodoRepositoryImpl(ref.watch(todoRemoteDataSourceProvider));

// ---------------------------------------------------------------------------
// PLACEHOLDERS — owned by skill 15 (core/error) and the feature's domain layer.
// Delete this section and import the real types once those stages land. They
// are inlined here only so this template compiles and demonstrates the flow.
// ---------------------------------------------------------------------------

/// Domain contract for the `todo` feature (normally in `domain/`).
abstract interface class TodoRepository {
  /// Loads all todos.
  Future<Result<List<TodoEntity>>> getTodos();

  /// Loads a single todo by id.
  Future<Result<TodoEntity>> getTodo(String id);
}

/// Outcome wrapper — see CONVENTIONS §5. Owned by skill 15.
sealed class Result<T> {
  const Result();
}

/// Success carrying a [value].
final class Ok<T> extends Result<T> {
  /// Creates an [Ok].
  const Ok(this.value);

  /// The successful value.
  final T value;
}

/// Failure carrying a typed [failure].
final class Err<T> extends Result<T> {
  /// Creates an [Err].
  const Err(this.failure);

  /// The mapped failure.
  final Failure failure;
}

/// Typed failure base — owned by skill 15.
sealed class Failure {
  /// Creates a [Failure].
  const Failure(this.message);

  /// Human-readable message.
  final String message;
}

/// Fallback failure used by the placeholder mapper below.
final class UnknownFailure extends Failure {
  /// Creates an [UnknownFailure].
  const UnknownFailure(super.message);
}

/// Placeholder for skill 15's `mapErrorToFailure`.
///
/// The real mapper translates `DioException` types into the right `Failure`
/// (timeout → `TimeoutFailure`, 401 → `UnauthorizedFailure`,
/// 404 → `NotFoundFailure`, no connection → `NetworkFailure`, …).
Failure mapErrorToFailure(Object error, StackTrace stackTrace) =>
    UnknownFailure(error.toString());
