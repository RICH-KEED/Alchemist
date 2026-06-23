// Repository tests — stage 12 (API Testing).
//
// Verifies the repository skill 11 produced:
//   * happy path: DTO -> domain entity, returns Ok(entity)
//   * every error path: data source throws DioException of each kind, repo maps
//     it (via skill 15's error mapper) to the correct Failure inside Err
//
// Approach: mocktail mock of the data source; drive each branch by stubbing it
// to throw the matching DioException. The error->Failure mapping itself lives
// in skill 15 — here we PROVE it is wired correctly, one test per branch.
//
// Place at: test/features/articles/data/article_repository_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Stand-in production code (normally imported from lib/). Mirrors skills 5/11/15.
// In a real project DELETE these and import the production types.
// ---------------------------------------------------------------------------

// --- Result / Failure (CONVENTIONS §5, owned by skill 15) ------------------
sealed class Result<T> {
  const Result();
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}

sealed class Failure {
  const Failure(this.message);
  final String message;
}

final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Network error']);
}

final class TimeoutFailure extends Failure {
  const TimeoutFailure([super.message = 'Request timed out']);
}

final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'Unauthorized']);
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Not found']);
}

final class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Unknown error']);
}

// --- DTO + domain entity (skill 11) ----------------------------------------
class ArticleDto {
  const ArticleDto({required this.id, required this.title, required this.author});
  final String id;
  final String title;
  final String author;

  Article toDomain() => Article(id: id, title: title, author: author);
}

class Article {
  const Article({required this.id, required this.title, required this.author});
  final String id;
  final String title;
  final String author;
}

// --- Error mapper (skill 15): DioException -> Failure -----------------------
Failure mapDioError(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const TimeoutFailure();
    case DioExceptionType.connectionError:
      return const NetworkFailure();
    case DioExceptionType.badResponse:
      final code = e.response?.statusCode;
      return switch (code) {
        401 => const UnauthorizedFailure(),
        404 => const NotFoundFailure(),
        _ => const NetworkFailure(),
      };
    case DioExceptionType.cancel:
    case DioExceptionType.badCertificate:
    case DioExceptionType.unknown:
      return const UnknownFailure();
  }
}

// --- Data source (skill 11) ------------------------------------------------
abstract class ArticleRemoteDataSource {
  Future<ArticleDto> fetchArticle(String id);
}

// --- Repository under test (skill 11) --------------------------------------
class ArticleRepository {
  ArticleRepository(this._remote);
  final ArticleRemoteDataSource _remote;

  Future<Result<Article>> getArticle(String id) async {
    try {
      final dto = await _remote.fetchArticle(id);
      return Ok(dto.toDomain());
    } on DioException catch (e) {
      return Err(mapDioError(e));
    } catch (_) {
      return const Err(UnknownFailure());
    }
  }
}

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------
class MockArticleRemoteDataSource extends Mock
    implements ArticleRemoteDataSource {}

DioException _dioError(
  DioExceptionType type, {
  int? statusCode,
}) {
  final options = RequestOptions(path: '/articles/a1b2c3');
  return DioException(
    requestOptions: options,
    type: type,
    response: statusCode == null
        ? null
        : Response<dynamic>(requestOptions: options, statusCode: statusCode),
  );
}

void main() {
  late MockArticleRemoteDataSource remote;
  late ArticleRepository repository;

  setUp(() {
    remote = MockArticleRemoteDataSource();
    repository = ArticleRepository(remote);
  });

  group('getArticle — happy path', () {
    test('maps DTO to domain entity and returns Ok', () async {
      when(() => remote.fetchArticle('a1b2c3')).thenAnswer(
        (_) async => const ArticleDto(
          id: 'a1b2c3',
          title: 'Flutter 3 ships impeller by default',
          author: 'Jane Doe',
        ),
      );

      final result = await repository.getArticle('a1b2c3');

      expect(result, isA<Ok<Article>>());
      final entity = (result as Ok<Article>).value;
      expect(entity.id, 'a1b2c3');
      expect(entity.title, 'Flutter 3 ships impeller by default');
      expect(entity.author, 'Jane Doe');
    });
  });

  group('getArticle — error mapping (one per DioException branch)', () {
    // (thrown DioException, expected Failure type) — exhaustive, not spot-check.
    final cases = <String, ({DioException error, Type failure})>{
      'connectionTimeout -> TimeoutFailure': (
        error: _dioError(DioExceptionType.connectionTimeout),
        failure: TimeoutFailure,
      ),
      'receiveTimeout -> TimeoutFailure': (
        error: _dioError(DioExceptionType.receiveTimeout),
        failure: TimeoutFailure,
      ),
      'connectionError -> NetworkFailure': (
        error: _dioError(DioExceptionType.connectionError),
        failure: NetworkFailure,
      ),
      'badResponse 401 -> UnauthorizedFailure': (
        error: _dioError(DioExceptionType.badResponse, statusCode: 401),
        failure: UnauthorizedFailure,
      ),
      'badResponse 404 -> NotFoundFailure': (
        error: _dioError(DioExceptionType.badResponse, statusCode: 404),
        failure: NotFoundFailure,
      ),
      'badResponse 500 -> NetworkFailure': (
        error: _dioError(DioExceptionType.badResponse, statusCode: 500),
        failure: NetworkFailure,
      ),
    };

    cases.forEach((name, c) {
      test(name, () async {
        when(() => remote.fetchArticle(any())).thenThrow(c.error);

        final result = await repository.getArticle('a1b2c3');

        expect(result, isA<Err<Article>>());
        expect((result as Err<Article>).failure.runtimeType, c.failure);
      });
    });

    test('non-Dio exception (e.g. bad JSON) -> UnknownFailure', () async {
      when(() => remote.fetchArticle(any()))
          .thenThrow(const FormatException('bad json'));

      final result = await repository.getArticle('a1b2c3');

      expect(result, isA<Err<Article>>());
      expect((result as Err<Article>).failure, isA<UnknownFailure>());
    });
  });
}
