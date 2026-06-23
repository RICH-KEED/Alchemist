import 'package:freezed_annotation/freezed_annotation.dart';

// The domain entity is pure Dart and lives in the feature's `domain/` layer.
// import 'package:<app>/features/todo/domain/todo_entity.dart';

part 'example_dto.freezed.dart';
part 'example_dto.g.dart';

/// Wire model for the `todo` feature.
///
/// Lives in `data/` and is the *only* place that knows about JSON. The remote
/// data source returns these; the repository maps them to the domain entity via
/// [toEntity] (the domain never sees this type — skill 06's dependency rule).
@freezed
class TodoDto with _$TodoDto {
  /// Creates a [TodoDto].
  const factory TodoDto({
    required String id,
    required String title,
    @JsonKey(name: 'is_completed') @Default(false) bool isCompleted,
  }) = _TodoDto;

  const TodoDto._();

  /// Deserializes a [TodoDto] from a decoded JSON map.
  factory TodoDto.fromJson(Map<String, dynamic> json) =>
      _$TodoDtoFromJson(json);

  /// Maps this transport DTO to its pure domain entity.
  ///
  /// Replace the placeholder return with the real domain type once the
  /// feature's `domain/todo_entity.dart` exists:
  ///
  ///   TodoEntity toEntity() =>
  ///       TodoEntity(id: id, title: title, isCompleted: isCompleted);
  TodoEntity toEntity() =>
      TodoEntity(id: id, title: title, isCompleted: isCompleted);
}

/// Placeholder domain entity so this template compiles standalone.
///
/// In a real feature this lives in `domain/todo_entity.dart` (a `freezed`
/// entity) and this file imports it instead of declaring it.
class TodoEntity {
  /// Creates a [TodoEntity].
  const TodoEntity({
    required this.id,
    required this.title,
    required this.isCompleted,
  });

  /// Stable identifier.
  final String id;

  /// Human-readable title.
  final String title;

  /// Whether the todo is done.
  final bool isCompleted;
}
