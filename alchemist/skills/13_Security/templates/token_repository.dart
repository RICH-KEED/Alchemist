// token_repository.dart
//
// Single source of truth for auth tokens. The skill 11 auth interceptor reads
// `currentAccessToken` from here; login/logout flows write through `saveTokens`
// and `clear`. Tokens are persisted via SecureStore (Keystore-backed) — never
// SharedPreferences, never source.
//
// House style: Dart 3, Riverpod (codegen). See SKILL.md §2.

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'secure_storage.dart';

part 'token_repository.g.dart';

/// Immutable token pair handed back from auth/refresh endpoints.
class TokenPair {
  const TokenPair({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

/// Reads and writes auth tokens against Keystore-backed [SecureStore].
///
/// This is the token source for the skill 11 auth interceptor:
///   - the interceptor calls [currentAccessToken] to attach the bearer token;
///   - on refresh-token rotation it calls [saveTokens] with the new pair;
///   - on logout / refresh failure it calls [clear].
class TokenRepository {
  TokenRepository(this._store);

  final SecureStore _store;

  /// The current access token, or `null` if the user is not authenticated.
  Future<String?> get currentAccessToken => _store.readAccessToken();

  /// The current refresh token, or `null`. Used by the interceptor's refresh
  /// flow only — never sent on normal requests.
  Future<String?> get currentRefreshToken => _store.readRefreshToken();

  /// Persist a freshly issued token pair (login or rotation). On rotation the
  /// previous refresh token is overwritten and must never be reused.
  Future<void> saveTokens(TokenPair tokens) async {
    await _store.writeAccessToken(tokens.accessToken);
    await _store.writeRefreshToken(tokens.refreshToken);
  }

  /// True if an access token is present (cheap auth gate for routing guards).
  Future<bool> get hasSession async =>
      (await _store.readAccessToken()) != null;

  /// Wipe both tokens. Call on logout, refresh failure, or account switch.
  Future<void> clear() async {
    await _store.deleteAccessToken();
    await _store.deleteRefreshToken();
  }
}

/// Provides the app-wide [TokenRepository].
@Riverpod(keepAlive: true)
TokenRepository tokenRepository(TokenRepositoryRef ref) {
  return TokenRepository(ref.watch(secureStoreProvider));
}
