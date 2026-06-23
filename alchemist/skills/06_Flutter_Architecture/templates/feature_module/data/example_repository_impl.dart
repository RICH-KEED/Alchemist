import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/example_entity.dart';
import 'example_remote_data_source.dart';

// The error contract lives in `lib/core/error/` (stage 15):
//   import 'package:<app_name>/core/error/result.dart';   // Result, Ok, Err
//   import 'package:<app_name>/core/error/dio_failure.dart'; // DioException.toFailure()

part 'example_repository_impl.g.dart';

/// Concrete [ExampleRepository]: maps DTO → entity and exceptions → `Failure`.
///
/// This is the boundary where transport errors stop. Once stage 15 lands, each
/// method should `try { ... } on DioException catch (e) { return Err(e.toFailure()); }`
/// and return `Ok(value)` on success. The placeholder bodies below keep the
/// scaffold compilable until then.
final class ExampleRepositoryImpl implements ExampleRepository {
  /// Creates an [ExampleRepositoryImpl].
  const ExampleRepositoryImpl(this._remote);

  final ExampleRemoteDataSource _remote;

  @override
  Future<List<ExampleEntity>> getExamples() async {
    // Target shape once `Result` is available (stage 15):
    //
    //   try {
    //     final dtos = await _remote.fetchExamples();
    //     return Ok(dtos.map((d) => d.toEntity()).toList());
    //   } on DioException catch (e) {
    //     return Err(e.toFailure());
    //   }
    //
    // Placeholder (returns the unwrapped list to stay compilable):
    final dtos = await _remote.fetchExamples();
    return dtos.map((d) => d.toEntity()).toList();
  }
}

/// Binds the domain [ExampleRepository] interface to its implementation.
///
/// Everything downstream depends on this provider's *interface* type, so tests
/// override it with a fake via `ProviderScope(overrides: [...])`.
@riverpod
ExampleRepository exampleRepository(Ref ref) =>
    ExampleRepositoryImpl(ref.watch(exampleRemoteDataSourceProvider));
