import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'auth_interceptor.dart';

part 'dio_client.g.dart';

/// Base URL for the backend, injected at build time.
///
/// Provide it with `--dart-define=API_BASE_URL=https://api.myapp.com`
/// (or `--dart-define-from-file=env/dev.json`). Wire per-flavor values via the
/// build matrix (skill 10 for flavors, skill 21 for CI). Never hardcode a
/// production URL in source.
const String _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://api.example.com',
);

/// The single, shared, configured [Dio] client for the whole app.
///
/// Lives in `lib/core/network/` and is the only place dio is constructed.
/// Every remote data source watches this provider, so timeouts, headers, and
/// interceptors are applied uniformly. Skill 06 references this as
/// `dioProvider`; the generated name of this function provider is `dioProvider`.
///
/// Interceptor order matters:
///  1. [AuthInterceptor] runs first so the bearer token is on the request.
///  2. [LogInterceptor] runs next so it logs the *final* request.
///  3. The resilience interceptor (retry/timeout — skill 14) is added after
///     these once that stage lands.
@riverpod
Dio dio(Ref ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: _apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      // Bounds a single attempt; retry/backoff policy is skill 14.
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  dio.interceptors.addAll([
    AuthInterceptor(ref),
    // Verbose logging is for development only — gate it on a build flag or
    // strip it in release. A structured `logger`-backed interceptor is fine too.
    LogInterceptor(requestBody: true, responseBody: true),
    // TODO(skill-14): dio.interceptors.add(ref.watch(retryInterceptorProvider));
  ]);

  return dio;
}
