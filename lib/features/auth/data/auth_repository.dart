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
  Future<void> clear();
}

/// Šifrované úložisko zariadenia (Keychain na iOS, Keystore na Androide).
class SecureTokenStore implements TokenStore {
  const SecureTokenStore();

  static const _storage = FlutterSecureStorage();
  static const _key = 'rejnox_session_token';

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => HttpAuthRepository(ref.watch(apiClientProvider)),
);

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => const SecureTokenStore(),
);
