// Data source tests — stage 12 (API Testing).
//
// Verifies the data source skill 11 produced:
//   * issues the expected HTTP method / path / query params
//   * parses real JSON fixtures into DTOs with every field populated
//
// Approach: mocktail mock of `Dio`, returning a `Response` built from a fixture.
// No socket is ever opened.
//
// Place at: test/features/articles/data/article_remote_data_source_test.dart
//
// --- Assumed skill-11 shapes (adjust imports to your project) -------------
// import 'package:my_app/features/articles/data/article_dto.dart';
// import 'package:my_app/features/articles/data/article_remote_data_source.dart';
//
// Reference implementations shown here so the test compiles standalone. In a
// real project DELETE these and import the production code instead.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Stand-in production code (normally imported from lib/). Mirrors skill 11.
// ---------------------------------------------------------------------------

/// DTO matching `fixtures/example_item.json` / each item of `example_list.json`.
class ArticleDto {
  const ArticleDto({
    required this.id,
    required this.title,
    required this.summary,
    required this.author,
    required this.tags,
    required this.publishedAt,
    required this.readTimeMinutes,
    required this.isPremium,
  });

  factory ArticleDto.fromJson(Map<String, dynamic> json) => ArticleDto(
        id: json['id'] as String,
        title: json['title'] as String,
        summary: json['summary'] as String,
        author: json['author'] as String,
        tags: (json['tags'] as List<dynamic>).cast<String>(),
        publishedAt: DateTime.parse(json['published_at'] as String),
        readTimeMinutes: json['read_time_minutes'] as int,
        isPremium: json['is_premium'] as bool,
      );

  final String id;
  final String title;
  final String summary;
  final String author;
  final List<String> tags;
  final DateTime publishedAt;
  final int readTimeMinutes;
  final bool isPremium;
}

/// Remote data source. Throws DioException on transport errors (mapped to
/// Failure later by the repository — see repository_test.dart).
class ArticleRemoteDataSource {
  ArticleRemoteDataSource(this._dio);
  final Dio _dio;

  Future<List<ArticleDto>> fetchArticles({int page = 1}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/articles',
      queryParameters: {'page': page},
    );
    final items = (res.data!['items'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    return items.map(ArticleDto.fromJson).toList();
  }

  Future<ArticleDto> fetchArticle(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/articles/$id');
    return ArticleDto.fromJson(res.data!);
  }
}

// ---------------------------------------------------------------------------
// Test helper (normally test/helpers/fixture_reader.dart — see template).
// ---------------------------------------------------------------------------
String readFixture(String path) =>
    File('test/fixtures/$path').readAsStringSync();

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------
class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late ArticleRemoteDataSource dataSource;

  setUp(() {
    dio = MockDio();
    dataSource = ArticleRemoteDataSource(dio);
  });

  // Build a 200 Response from a fixture file.
  Response<Map<String, dynamic>> okResponse(String fixture, String path) =>
      Response<Map<String, dynamic>>(
        data: jsonDecode(readFixture(fixture)) as Map<String, dynamic>,
        statusCode: 200,
        requestOptions: RequestOptions(path: path),
      );

  group('fetchArticles', () {
    test('issues GET /articles with the page query param', () async {
      when(() => dio.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer(
        (_) async => okResponse('articles/example_list.json', '/articles'),
      );

      await dataSource.fetchArticles(page: 3);

      // Request shape is pinned: a renamed path or dropped query breaks this.
      verify(() => dio.get<Map<String, dynamic>>(
            '/articles',
            queryParameters: {'page': 3},
          )).called(1);
    });

    test('parses the list fixture into fully-populated DTOs', () async {
      when(() => dio.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer(
        (_) async => okResponse('articles/example_list.json', '/articles'),
      );

      final result = await dataSource.fetchArticles();

      expect(result, hasLength(2));
      final first = result.first;
      expect(first.id, 'a1b2c3');
      expect(first.title, 'Flutter 3 ships impeller by default');
      expect(first.author, 'Jane Doe');
      expect(first.tags, contains('flutter'));
      expect(first.publishedAt, DateTime.utc(2026, 5, 12, 9, 30));
      expect(first.readTimeMinutes, 4);
      expect(first.isPremium, isFalse);
    });
  });

  group('fetchArticle', () {
    test('issues GET /articles/:id and parses the item fixture', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => okResponse('articles/example_item.json', '/articles/a1b2c3'),
      );

      final dto = await dataSource.fetchArticle('a1b2c3');

      verify(() => dio.get<Map<String, dynamic>>('/articles/a1b2c3')).called(1);
      expect(dto.id, 'a1b2c3');
      expect(dto.isPremium, isFalse);
    });
  });
}
