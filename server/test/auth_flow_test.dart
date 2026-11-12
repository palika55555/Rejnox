// Test celého toku proti skutočnej lokálnej databáze (config/.env).
// Vytvorí účet s náhodným e-mailom a na konci ho zmaže.
import 'dart:convert';
import 'dart:math';

import 'package:rejnox_server/src/app.dart';
import 'package:rejnox_server/src/auth/auth_service.dart';
import 'package:rejnox_server/src/config.dart';
import 'package:rejnox_server/src/db.dart';
import 'package:rejnox_server/src/http/rate_limiter.dart';
import 'package:rejnox_server/src/training/training_service.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late Database db;
  late Handler app;
  final email = 'test-${Random.secure().nextInt(1 << 32)}@test.local';
  const password = 'spravne-heslo-123';
  final errors = <Object>[];

  Future<(int, Map<String, dynamic>)> call(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
    String? rawBody,
  }) async {
    final response = await app(
      Request(
        method,
        Uri.parse('http://localhost$path'),
        body: rawBody ?? (body == null ? null : jsonEncode(body)),
        headers: {if (token != null) 'authorization': 'Bearer $token'},
      ),
    );
    final text = await response.readAsString();
    return (
      response.statusCode,
      text.isEmpty ? <String, dynamic>{} : jsonDecode(text) as Map<String, dynamic>,
    );
  }

  setUpAll(() {
    db = Database.connect(AppConfig.load().databaseUrl);
    app = buildApp(
      // Nižší počet kôl bcrypt, aby boli testy rýchle.
      auth: AuthService(db, bcryptRounds: 4),
      training: TrainingService(db),
      corsOrigins: const {'http://localhost:5173'},
      loginLimiter: RateLimiter(maxAttempts: 4, window: const Duration(minutes: 5)),
      onError: (e, _) => errors.add(e),
    );
  });

  tearDownAll(() async {
    // Poistka: ak test spadol uprostred, účet zmažeme aj tak.
    final (status, body) = await call(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    if (status == 200) {
      await call('DELETE', '/me', token: body['token'] as String);
    }
    await db.close();
  });

  test('registrácia, prihlásenie, odhlásenie a zmazanie účtu', () async {
    // Registrácia.
    var (status, body) = await call(
      'POST',
      '/auth/register',
      body: {'email': email, 'password': password, 'displayName': 'Test', 'role': 'trainer'},
    );
    expect(status, 201);
    final firstToken = body['token'] as String;
    expect(firstToken.length, greaterThan(40));
    expect(body['user'], containsPair('role', 'trainer'));
    expect(jsonEncode(body), isNot(contains('password')));

    // Rovnaký e-mail druhýkrát nejde (ani s inou veľkosťou písmen).
    (status, body) = await call(
      'POST',
      '/auth/register',
      body: {'email': email.toUpperCase(), 'password': password, 'displayName': 'X'},
    );
    expect(status, 409);
    expect(body['error']['code'], 'email_taken');

    // /me s tokenom a bez neho.
    (status, body) = await call('GET', '/me', token: firstToken);
    expect(status, 200);
    expect(body['email'], email);
    (status, _) = await call('GET', '/me');
    expect(status, 401);
    (status, _) = await call('GET', '/me', token: 'vymysleny-token');
    expect(status, 401);

    // Zlé heslo a neexistujúci účet vrátia rovnakú odpoveď.
    final (wrongStatus, wrongBody) = await call(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': 'zle-heslo-123'},
    );
    final (missingStatus, missingBody) = await call(
      'POST',
      '/auth/login',
      body: {'email': 'nikto-$email', 'password': password},
    );
    expect(wrongStatus, 401);
    expect(missingStatus, 401);
    expect(wrongBody, missingBody);

    // Správne prihlásenie vydá nový token.
    (status, body) = await call(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    expect(status, 200);
    final secondToken = body['token'] as String;
    expect(secondToken, isNot(firstToken));

    // Odhlásenie zruší len ten jeden token.
    (status, _) = await call('POST', '/auth/logout', token: firstToken);
    expect(status, 204);
    (status, _) = await call('GET', '/me', token: firstToken);
    expect(status, 401);
    (status, _) = await call('GET', '/me', token: secondToken);
    expect(status, 200);

    // Zmazanie účtu: token aj prihlásenie prestanú platiť.
    (status, _) = await call('DELETE', '/me', token: secondToken);
    expect(status, 204);
    (status, _) = await call('GET', '/me', token: secondToken);
    expect(status, 401);
    (status, _) = await call(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    expect(status, 401);

    expect(errors, isEmpty, reason: 'server zalogoval nečakanú chybu');
  });

  test('opakované zlé pokusy o prihlásenie sa zablokujú', () async {
    final target = 'brute-$email';
    final statuses = <int>[];
    for (var i = 0; i < 6; i++) {
      final (status, _) = await call(
        'POST',
        '/auth/login',
        body: {'email': target, 'password': 'pokus-cislo-$i'},
      );
      statuses.add(status);
    }
    expect(statuses, [401, 401, 401, 401, 429, 429]);
  });

  test('neplatné vstupy vrátia 400 a neznáma cesta 404', () async {
    var (status, body) = await call('POST', '/auth/register', rawBody: '{nie json');
    expect(status, 400);
    expect(body['error']['code'], 'invalid_json');

    (status, body) = await call(
      'POST',
      '/auth/register',
      body: {'email': email, 'password': 'kratke', 'displayName': 'Test'},
    );
    expect(status, 400);
    expect(body['error']['code'], 'invalid_password');

    (status, _) = await call('GET', '/neexistuje');
    expect(status, 404);
    expect(errors, isEmpty);
  });
}
