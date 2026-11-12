// Mapa fitiek a hodnotenia proti skutočnej lokálnej databáze (config/.env).
import 'dart:convert';
import 'dart:math';

import 'package:postgres/postgres.dart';
import 'package:rejnox_server/src/app.dart';
import 'package:rejnox_server/src/auth/auth_service.dart';
import 'package:rejnox_server/src/config.dart';
import 'package:rejnox_server/src/db.dart';
import 'package:rejnox_server/src/gyms/gym_service.dart';
import 'package:rejnox_server/src/trainer/trainer_service.dart';
import 'package:rejnox_server/src/training/training_service.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late Database db;
  late Handler app;
  late AuthService auth;
  late ({String id, String token}) anna;
  late ({String id, String token}) boris;
  late String gymId;

  Future<({String id, String token})> register(String name) async {
    final result = await auth.register(
      email: '$name-${Random.secure().nextInt(1 << 32)}@test.local',
      password: 'heslo-na-test-1',
      displayName: name,
      role: 'member',
    );
    return (id: result.user.id, token: result.token);
  }

  Future<(int, Map<String, dynamic>)> call(
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final response = await app(
      Request(
        method,
        Uri.parse('http://localhost$path'),
        body: body == null ? null : jsonEncode(body),
        headers: {if (token != null) 'authorization': 'Bearer $token'},
      ),
    );
    final text = await response.readAsString();
    return (
      response.statusCode,
      text.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(text) as Map<String, dynamic>,
    );
  }

  setUpAll(() async {
    db = Database.connect(AppConfig.load().databaseUrl);
    auth = AuthService(db, bcryptRounds: 4);
    app = buildApp(
      auth: auth,
      training: TrainingService(db),
      trainers: TrainerService(db),
      gyms: GymService(db),
      corsOrigins: const {},
    );
    anna = await register('anna');
    boris = await register('boris');
    // Testovacie fitko pridá Anna (smie pridávať, mazať len svoje).
    gymId = await db.asUser(anna.id, (tx) async {
      final rows = await tx.execute(
        Sql.named('''
          INSERT INTO gyms (name, city, lat, lng, created_by, opening_hours, tags)
          VALUES ('Test Gym', 'Nitra', 48.3, 18.08, CAST(@me AS uuid),
                  'Nonstop', '{"Kardio","Sauna"}')
          RETURNING id::text
        '''),
        parameters: {'me': anna.id},
      );
      return rows.first[0] as String;
    });
  });

  tearDownAll(() async {
    await db.asUser(anna.id, (tx) async {
      await tx.execute(
        Sql.named('DELETE FROM gyms WHERE id = CAST(@id AS uuid)'),
        parameters: {'id': gymId},
      );
    });
    await auth.deleteAccount(anna.id);
    await auth.deleteAccount(boris.id);
    await db.close();
  });

  test('bez prihlásenia fitká nevydá', () async {
    final (status, _) = await call('GET', '/gyms');
    expect(status, 401);
  });

  test('zoznam obsahuje fitko s detailmi a prázdnym hodnotením', () async {
    final (status, body) = await call('GET', '/gyms', token: anna.token);
    expect(status, 200);
    final gym = (body['gyms'] as List).cast<Map<String, dynamic>>().firstWhere(
      (g) => g['id'] == gymId,
    );
    expect(gym['name'], 'Test Gym');
    expect(gym['lat'], 48.3);
    expect(gym['openingHours'], 'Nonstop');
    expect(gym['tags'], ['Kardio', 'Sauna']);
    expect(gym['rating'], {
      'stars': [0, 0, 0, 0, 0],
    });
    expect(gym['myStars'], isNull);
  });

  test('hodnotenie: súhrn vidia všetci, „moje“ len autor', () async {
    var (status, body) = await call(
      'PUT',
      '/gyms/$gymId/review',
      token: anna.token,
      body: {'stars': 5},
    );
    expect(status, 200);
    expect(body['myStars'], 5);

    (status, body) = await call(
      'PUT',
      '/gyms/$gymId/review',
      token: boris.token,
      body: {'stars': 3},
    );
    expect(body['rating'], {
      'stars': [0, 0, 1, 0, 1],
    });
    expect(body['myStars'], 3);

    // Anna zmení názor – nepribudne druhé hodnotenie, len sa prepíše.
    (status, body) = await call(
      'PUT',
      '/gyms/$gymId/review',
      token: anna.token,
      body: {'stars': 4},
    );
    expect(body['rating'], {
      'stars': [0, 0, 1, 1, 0],
    });

    // Boris svoje hodnotenie zmaže.
    (status, body) = await call(
      'DELETE',
      '/gyms/$gymId/review',
      token: boris.token,
    );
    expect(status, 200);
    expect(body['myStars'], isNull);
    expect(body['rating'], {
      'stars': [0, 0, 0, 1, 0],
    });
  });

  test('cudzie hodnotenia sa nedajú čítať priamo', () async {
    final visible = await db.asUser(boris.id, (tx) async {
      final rows = await tx.execute('SELECT count(*)::int FROM gym_reviews');
      return rows.first[0] as int;
    });
    expect(visible, 0); // Boris svoje zmazal, Annine nevidí.
  });

  test('neplatné hodnotenie a neznáme fitko', () async {
    var (status, body) = await call(
      'PUT',
      '/gyms/$gymId/review',
      token: anna.token,
      body: {'stars': 6},
    );
    expect(status, 400);

    (status, body) = await call(
      'PUT',
      '/gyms/00000000-0000-4000-8000-0000000000ff/review',
      token: anna.token,
      body: {'stars': 4},
    );
    expect(status, 404);
    expect((body['error'] as Map)['code'], 'gym_not_found');

    (status, _) = await call('GET', '/gyms/nie-je-uuid', token: anna.token);
    expect(status, 400);
  });

  test('priveľa hodnotení za minútu server odmietne', () async {
    final limited = buildApp(
      auth: auth,
      training: TrainingService(db),
      trainers: TrainerService(db),
      gyms: GymService(db),
      corsOrigins: const {},
    );
    var lastStatus = 0;
    for (var i = 0; i < 31; i++) {
      final response = await limited(
        Request(
          'PUT',
          Uri.parse('http://localhost/gyms/$gymId/review'),
          body: jsonEncode({'stars': 1 + i % 5}),
          headers: {'authorization': 'Bearer ${boris.token}'},
        ),
      );
      lastStatus = response.statusCode;
    }
    expect(lastStatus, 429);
  });
}
