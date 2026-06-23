// secure_storage.dart
//
// Keystore-backed secure storage wrapper. All tokens and secrets go through this
// type — never SharedPreferences, never a plaintext db column, never source.
//
// House style: Dart 3, Riverpod (codegen), flutter_secure_storage.
// See ../../../references/CONVENTIONS.md and SKILL.md §1.
//
// pubspec:
//   flutter_secure_storage: ^9.x
//   riverpod_annotation / riverpod_generator (codegen)
//
// On Android, `encryptedSharedPreferences: true` routes values into the
// Keystore-backed EncryptedSharedPreferences (AES-GCM, hardware-backed key
// where the device supports it) instead of legacy plaintext prefs.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'secure_storage.g.dart';

/// Canonical key names. Keep them centralized so nothing in the app reaches for
/// raw strings — typed methods below are the only public surface.
class _Keys {
  const _Keys._();
  static const accessToken = 'auth.access_token';
  static const refreshToken = 'auth.refresh_token';
}

/// Keystore-backed secure storage for tokens and secrets.
///
/// Wraps [FlutterSecureStorage] with typed methods so callers depend on intent
/// (`writeAccessToken`) rather than string keys, and so tests can override
/// [secureStoreProvider] with a fake.
class SecureStore {
  SecureStore(this._storage);

  final FlutterSecureStorage _storage;

  // --- Access token ---------------------------------------------------------

  Future<void> writeAccessToken(String token) =>
      _storage.write(key: _Keys.accessToken, value: token);

  Future<String?> readAccessToken() =>
      _storage.read(key: _Keys.accessToken);

  Future<void> deleteAccessToken() =>
      _storage.delete(key: _Keys.accessToken);

  // --- Refresh token --------------------------------------------------------

  Future<void> writeRefreshToken(String token) =>
      _storage.write(key: _Keys.refreshToken, value: token);

  Future<String?> readRefreshToken() =>
      _storage.read(key: _Keys.refreshToken);

  Future<void> deleteRefreshToken() =>
      _storage.delete(key: _Keys.refreshToken);

  // --- Generic typed secret (use sparingly; prefer named methods) -----------

  Future<void> writeSecret(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<String?> readSecret(String key) => _storage.read(key: key);

  Future<void> deleteSecret(String key) => _storage.delete(key: key);

  // --- Lifecycle ------------------------------------------------------------

  /// Wipe everything. Call on logout, account switch, or detected compromise.
  Future<void> wipe() => _storage.deleteAll();
}

/// Provides the app-wide [SecureStore]. Override in tests with a fake.
@Riverpod(keepAlive: true)
SecureStore secureStore(SecureStoreRef ref) {
  const storage = FlutterSecureStorage(
    // Keystore-backed EncryptedSharedPreferences on Android.
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    // iOS/macOS: device-only so secrets never sync to iCloud Keychain.
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );
  return SecureStore(storage);
}
