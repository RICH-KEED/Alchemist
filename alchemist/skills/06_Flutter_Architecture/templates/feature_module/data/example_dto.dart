import 'package:freezed_annotation/freezed_annotation.dart';

import '../domain/example_entity.dart';

part 'example_dto.freezed.dart';
part 'example_dto.g.dart';

/// Wire model for the `example` feature.
///
/// Lives in `data/` and is the *only* place that knows about JSON. It maps to
/// the domain [ExampleEntity] via [toEntity]; the domain never sees this type.
@freezed
class ExampleDto with _$ExampleDto {
  /// Creates an [ExampleDto].
  const factory ExampleDto({
    required String id,
    required String title,
    @JsonKey(name: 'is_favorite') @Default(false) bool isFavorite,
  }) = _ExampleDto;

  const ExampleDto._();

  /// Deserializes an [ExampleDto] from JSON.
  factory ExampleDto.fromJson(Map<String, dynamic> json) =>
      _$ExampleDtoFromJson(json);

  /// Maps this transport DTO to its pure domain entity.
  ExampleEntity toEntity() => ExampleEntity(
        id: id,
        title: title,
        isFavorite: isFavorite,
      );
}
