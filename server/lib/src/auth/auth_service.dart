import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:bcrypt/bcrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart';

import '../db.dart';
import '../http/api_exception.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
  });

  final String id;
  final String email;
  final String displayName;
  final String role;

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'role': role,
  };
}

class AuthResult {
  const AuthResult(this.token, this.user);

  final String token;
  final AuthUser user;

  Map<String, dynamic> toJson() => {'token': token, 'user': user.toJson()};
}

const _invalidCredentials = ApiException(
  401,
  'invalid_credentials',
  'Nesprávny e-mail alebo heslo.',
);

// bcrypt je výpočtovo náročný, preto beží mimo hlavného vlákna. Funkcie sú
// na najvyššej úrovni, aby sa do izolátu neposielal celý AuthService.
Future<String> _hashPassword(String password, int rounds) => Isolate.run(
  () => BCrypt.hashpw(password, BCrypt.gensalt(logRounds: rounds)),
);

Future<bool> _checkPassword(String password, String hash) =>
    Isolate.run(() => BCrypt.checkpw(password, hash));

class AuthService {
  AuthService(
    this._db, {
    this.sessionTtl = const Duration(days: 30),
    this.bcryptRounds = 10,
  });

  final Database _db;
  final Duration sessionTtl;
  final int bcryptRounds;
  final _random = Random.secure();

  /// Hash, proti ktorému sa overuje heslo neexistujúceho účtu, aby prihlásenie
  /// trvalo rovnako dlho, či účet existuje alebo nie.
  late final Future<String> _dummyHash = _hash('rejnox-dummy-password');

  Future<AuthResult> register({
    required String email,
    required String password,
    required String displayName,
    required String role,
  }) async {
    final passwordHash = await _hash(password);
    try {
      return await _db.transaction((tx) async {
        final idRow = await tx.execute('SELECT gen_random_uuid()::text');
        final id = idRow.first[0] as String;
        await Database.actAs(tx, id);
        await tx.execute(
          Sql.named('''
            INSERT INTO users (id, email, password_hash, display_name, role)
            VALUES (CAST(@id AS uuid), CAST(@email AS citext), @hash, @name,
                    CAST(@role AS user_role))
          '''),
          parameters: {
            'id': id,
            'email': email,
            'hash': passwordHash,
            'name': displayName,
            'role': role,
          },
        );
        final token = await _createSession(tx, id);
        return AuthResult(
          token,
          AuthUser(id: id, email: email, displayName: displayName, role: role),
        );
      });
    } on ServerException catch (e) {
      if (e.code == '23505') {
        throw const ApiException(
          409,
          'email_taken',
          'Účet s týmto e-mailom už existuje.',
        );
      }
      rethrow;
    }
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final found = await _db.transaction(
      (tx) => tx.execute(
        Sql.named('''
          SELECT id::text, password_hash
          FROM auth_find_user(CAST(@email AS citext))
        '''),
        parameters: {'email': email},
      ),
    );
    final storedHash = found.isEmpty
        ? await _dummyHash
        : found.first[1] as String;
    final matches = await _checkPassword(password, storedHash);
    if (found.isEmpty || !matches) throw _invalidCredentials;

    final id = found.first[0] as String;
    return _db.asUser(id, (tx) async {
      final user = await _loadUser(tx, id);
      if (user == null) throw _invalidCredentials;
      return AuthResult(await _createSession(tx, id), user);
    });
  }

  /// Používateľ, ktorému patrí platný token, inak null.
  Future<AuthUser?> userForToken(String token) => _db.transaction((tx) async {
    final id = await _sessionUserId(tx, token);
    if (id == null) return null;
    await Database.actAs(tx, id);
    return _loadUser(tx, id);
  });

  Future<void> logout(String token) => _db.transaction((tx) async {
    final id = await _sessionUserId(tx, token);
    if (id == null) return;
    await Database.actAs(tx, id);
    await tx.execute(
      Sql.named('DELETE FROM sessions WHERE token_hash = @hash'),
      parameters: {'hash': _tokenHash(token)},
    );
  });

  /// Zmaže účet aj všetky jeho údaje.
  Future<void> deleteAccount(String userId) => _db.asUser(
    userId,
    (tx) => tx.execute(
      Sql.named('DELETE FROM users WHERE id = CAST(@id AS uuid)'),
      parameters: {'id': userId},
    ),
  );

  Future<String> _hash(String password) =>
      _hashPassword(password, bcryptRounds);

  static String _tokenHash(String token) =>
      sha256.convert(utf8.encode(token)).toString();

  Future<String?> _sessionUserId(TxSession tx, String token) async {
    final rows = await tx.execute(
      Sql.named('SELECT auth_session_user(@hash)::text'),
      parameters: {'hash': _tokenHash(token)},
    );
    return rows.first[0] as String?;
  }

  Future<String> _createSession(TxSession tx, String userId) async {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    final token = base64Url.encode(bytes).replaceAll('=', '');
    await tx.execute(
      Sql.named('''
        INSERT INTO sessions (token_hash, user_id, expires_at)
        VALUES (@hash, CAST(@id AS uuid), now() + make_interval(secs => @ttl))
      '''),
      parameters: {
        'hash': _tokenHash(token),
        'id': userId,
        'ttl': sessionTtl.inSeconds.toDouble(),
      },
    );
    return token;
  }

  Future<AuthUser?> _loadUser(TxSession tx, String id) async {
    final rows = await tx.execute(
      Sql.named('''
        SELECT email::text, display_name, role::text
        FROM users WHERE id = CAST(@id AS uuid)
      '''),
      parameters: {'id': id},
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return AuthUser(
      id: id,
      email: row[0] as String,
      displayName: row[1] as String,
      role: row[2] as String,
    );
  }
}
