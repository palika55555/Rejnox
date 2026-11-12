import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/api/api_client.dart';
import '../domain/auth_models.dart';

abstract interface class AuthRepository {
  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  });

  Future<AuthSession> login({required String email, required String password});

  Future<AuthUser> me(String token);

  Future<void> logout(String token);
}

class HttpAuthRepository implements AuthRepository {
  const HttpAuthRepository(this._api);

  final ApiClient _api;

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) async => AuthSession.fromJson(
    await _api.send(
      'POST',
      '/auth/register',
      body: {
        'email': email,
        'password': password,
        'displayName': displayName,
        'role': role.apiValue,
      },
    ),
  );

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async => AuthSession.fromJson(
    await _api.send(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
    ),
  );

  @override
  Future<AuthUser> me(String token) async =>
      AuthUser.fromJson(await _api.send('GET', '/me', token: token));

  @override
  Future<void> logout(String token) =>
      _api.send('POST', '/auth/logout', token: token);
}

/// Kde je uložený prihlasovací token medzi spusteniami appky.
abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String token);

  /// Posledný známy profil, aby appka fungovala aj pri štarte bez internetu.
  Future<AuthUser?> readUser();
  Future<void> writeUser(AuthUser user);

  /// Zmaže token aj profil.
  Future<void> clear();
}

/// Šifrované úložisko zariadenia (Keychain na iOS, Keystore na Androide).
class SecureTokenStore implements TokenStore {
  const SecureTokenStore();

  static const _storage = FlutterSecureStorage();
  static const _key = 'rejnox_session_token';
  static const _userKey = 'rejnox_session_user';

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<AuthUser?> readUser() async {
    final raw = await _storage.read(key: _userKey);
    if (raw == null) return null;
    try {
      return AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> writeUser(AuthUser user) =>
      _storage.write(key: _userKey, value: jsonEncode(user.toJson()));

  @override
  Future<void> clear() async {
    await _storage.delete(key: _key);
    await _storage.delete(key: _userKey);
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => HttpAuthRepository(ref.watch(apiClientProvider)),
);

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => const SecureTokenStore(),
);
