import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'example_dto.dart';

// The shared dio client lives in `lib/core/network/dio_client.dart` (this skill).
// import 'package:<app>/core/network/dio_client.dart'; // dioProvider

part 'example_remote_data_source.g.dart';

/// Talks to the network for the `todo` feature.
///
/// Returns [TodoDto]s and **lets `DioException`s propagate** — it does not
/// catch. The repository implementation is the boundary that maps those
/// exceptions to a `Failure` (skill 15); see `example_repository_impl.dart`.
class TodoRemoteDataSource {
  /// Creates a [TodoRemoteDataSource] from the shared, configured [Dio] client.
  const TodoRemoteDataSource(this._dio);

  final Dio _dio;

  /// GET `/todos` — fetches the full list.
  Future<List<TodoDto>> fetchTodos() async {
    final response = await _dio.get<List<dynamic>>('/todos');
    final data = response.data ?? const <dynamic>[];
    return data
        .cast<Map<String, dynamic>>()
        .map(TodoDto.fromJson)
        .toList();
  }

  /// GET `/todos/{id}` — fetches a single todo by id.
  Future<TodoDto> fetchTodo(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/todos/$id');
    final data = response.data;
    if (data == null) {
      // An empty body where one was expected is a transport problem; surface it
      // as a DioException so the repository maps it like any other failure.
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        error: 'Empty body for /todos/$id',
      );
    }
    return TodoDto.fromJson(data);
  }
}

/// Provides the [TodoRemoteDataSource], wired to the shared `dioProvider`.
@riverpod
TodoRemoteDataSource todoRemoteDataSource(Ref ref) {
  // Once core/network/dio_client.dart is in place:
  //   return TodoRemoteDataSource(ref.watch(dioProvider));
  return TodoRemoteDataSource(ref.watch(dioProvider));
}
