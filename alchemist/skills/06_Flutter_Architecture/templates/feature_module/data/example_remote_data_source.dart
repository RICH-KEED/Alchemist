import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'example_dto.dart';

// The shared dio client lives in `lib/core/network/` (stage 11).
// import 'package:<app_name>/core/network/dio_provider.dart'; // dioProvider

part 'example_remote_data_source.g.dart';

/// Talks to the network for the `example` feature.
///
/// Returns [ExampleDto]s and lets `DioException`s propagate — the
/// repository implementation is responsible for mapping them to `Failure`
/// (see `example_repository_impl.dart`).
class ExampleRemoteDataSource {
  /// Creates an [ExampleRemoteDataSource] from a configured [Dio] client.
  const ExampleRemoteDataSource(this._dio);

  final Dio _dio;

  /// Fetches the raw example list from the API.
  Future<List<ExampleDto>> fetchExamples() async {
    final response = await _dio.get<List<dynamic>>('/examples');
    final data = response.data ?? const <dynamic>[];
    return data
        .cast<Map<String, dynamic>>()
        .map(ExampleDto.fromJson)
        .toList();
  }
}

/// Provides the [ExampleRemoteDataSource], wired to the shared dio client.
@riverpod
ExampleRemoteDataSource exampleRemoteDataSource(Ref ref) {
  // TODO(stage-11): use `ref.watch(dioProvider)` once core/network exists.
  // final dio = ref.watch(dioProvider);
  final dio = Dio(); // placeholder client; replaced by the shared one.
  return ExampleRemoteDataSource(dio);
}
