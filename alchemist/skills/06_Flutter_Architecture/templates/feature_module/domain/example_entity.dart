import 'package:freezed_annotation/freezed_annotation.dart';

// The error contract lives in `lib/core/error/` and is owned by stage 15.
// import 'package:<app_name>/core/error/result.dart'; // Result, Ok, Err

part 'example_entity.freezed.dart';

/// A domain entity for the `example` feature.
///
/// Pure Dart: no Flutter, no `dio`, no JSON. The `data` layer maps its DTO to
/// this type so the rest of the app never depends on transport details
/// (see ../../../../SKILL.md — the dependency rule).
@freezed
class ExampleEntity with _$ExampleEntity {
  /// Creates an [ExampleEntity].
  const factory ExampleEntity({
    required String id,
    required String title,
    required bool isFavorite,
  }) = _ExampleEntity;

  const ExampleEntity._();
}

/// Repository contract for the `example` feature.
///
/// Defined in the domain so `application` depends only on this interface; the
/// concrete implementation lives in `data/` and is bound via a Riverpod
/// provider. Every method returns [Result] and never throws across the boundary.
abstract interface class ExampleRepository {
  /// Loads all examples.
  // Future<Result<List<ExampleEntity>>> getExamples();
  //
  // Uncomment the signature above once `Result` is imported from
  // `core/error/result.dart` (stage 15). The shape:
  //
  //   Future<Result<List<ExampleEntity>>> getExamples();
  //
  // The placeholder below keeps this file compilable before stage 15 lands.
  Future<List<ExampleEntity>> getExamples();
}
