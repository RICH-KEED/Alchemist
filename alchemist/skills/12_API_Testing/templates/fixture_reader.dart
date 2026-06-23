// Test helper: load the raw contents of a JSON fixture from test/fixtures/.
//
// Usage in a test:
//   final json = jsonDecode(readFixture('articles/example_list.json'))
//       as Map<String, dynamic>;
//
// Fixtures live under `test/fixtures/`. This reader uses plain file IO (relative
// to the package root, where `flutter test` runs), so no asset registration in
// pubspec.yaml is needed.
//
// Place this file at: test/helpers/fixture_reader.dart
import 'dart:convert';
import 'dart:io';

/// Returns the UTF-8 text of the fixture at `test/fixtures/<path>`.
///
/// Throws a [StateError] with a helpful message if the file is missing, so a
/// typo'd fixture name fails loudly instead of yielding a confusing null.
String readFixture(String path) {
  final file = File('test/fixtures/$path');
  if (!file.existsSync()) {
    throw StateError(
      'Fixture not found: ${file.path}. '
      'Create it under test/fixtures/ (a real, scrubbed backend response).',
    );
  }
  return file.readAsStringSync();
}

/// Convenience: read a fixture and decode it as a JSON object.
Map<String, dynamic> readJsonFixture(String path) =>
    jsonDecode(readFixture(path)) as Map<String, dynamic>;

/// Convenience: read a fixture and decode it as a JSON array.
List<dynamic> readJsonArrayFixture(String path) =>
    jsonDecode(readFixture(path)) as List<dynamic>;
