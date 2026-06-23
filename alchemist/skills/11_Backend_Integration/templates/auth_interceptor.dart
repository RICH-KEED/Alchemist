import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

// The token source is backed by secure storage (skill 13). It lives behind a
// tiny interface so the interceptor stays testable and never reaches into
// storage details directly:
//
//   import 'package:<app>/core/network/auth_token_source.dart';
//
// Skill 13 owns the concrete `SecureStorageTokenSource` (reads/writes the
// access + refresh tokens via `flutter_secure_storage`) and exposes a
// `tokenSourceProvider`. Until then, this interface keeps the scaffold compilable.

/// Supplies the current access token (and triggers refresh) for the
/// [AuthInterceptor]. Implemented over secure storage by skill 13.
abstract interface class AuthTokenSource {
  /// The current access token, or `null` if the user is signed out.
  Future<String?> accessToken();

  /// Attempts to refresh the access token after a 401.
  ///
  /// Returns the new access token on success, or `null` if refresh failed
  /// (caller should then surface an unauthorized error). The real
  /// implementation — call the refresh endpoint, persist the new tokens — is
  /// owned by skill 13.
  Future<String?> refresh();
}

/// Provides the [AuthTokenSource]. Bound to secure storage by skill 13.
@riverpod
AuthTokenSource authTokenSource(Ref ref) {
  // TODO(skill-13): return SecureStorageTokenSource(ref.watch(secureStorageProvider));
  throw UnimplementedError('Bound by skill 13 (secure storage).');
}

/// Attaches `Authorization: Bearer <token>` to outgoing requests and leaves a
/// 401 refresh seam.
///
/// Kept deliberately cheap: read the token, set the header, continue. No
/// business logic. The token is sourced from secure storage (skill 13) via
/// [AuthTokenSource]; the refresh flow itself is skill 13's responsibility.
class AuthInterceptor extends Interceptor {
  /// Creates an [AuthInterceptor]. Holds [Ref] so it can read the token source
  /// lazily (the interceptor outlives any single request).
  AuthInterceptor(this._ref);

  final Ref _ref;

  AuthTokenSource get _tokens => _ref.read(authTokenSourceProvider);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokens.accessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // 401 hook: ask the token source to refresh, then replay the request once.
    // The actual refresh-token exchange is owned by skill 13 — this is only the
    // seam. By default (no refresh available) we pass the error through so the
    // repository maps it to an `UnauthorizedFailure` (skill 15).
    if (err.response?.statusCode == 401 && !_isRetry(err.requestOptions)) {
      final newToken = await _tokens.refresh();
      if (newToken != null && newToken.isNotEmpty) {
        final retried = await _replay(err.requestOptions, newToken);
        return handler.resolve(retried);
      }
    }
    handler.next(err);
  }

  bool _isRetry(RequestOptions options) =>
      options.extra['__auth_retried__'] == true;

  Future<Response<dynamic>> _replay(RequestOptions options, String token) {
    final retryOptions = options
      ..headers['Authorization'] = 'Bearer $token'
      ..extra['__auth_retried__'] = true;
    // Uses a bare Dio so we don't re-enter this interceptor chain; in practice
    // skill 13 may inject the shared client here.
    return Dio().fetch<dynamic>(retryOptions);
  }
}
