// Zápis sérií proti skutočnej lokálnej databáze (config/.env).
import 'dart:convert';
import 'dart:math';

import 'package:postgres/postgres.dart';
import 'package:rejnox_server/src/app.dart';
import 'package:rejnox_server/src/auth/auth_service.dart';
import 'package:rejnox_server/src/config.dart';
import 'package:rejnox_server/src/db.dart';
import 'package:rejnox_server/src/http/api_exception.dart';
import 'package:rejnox_server/src/training/training_service.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

const _squat = '00000000-0000-4000-8000-000000000001';

String _uuid() {
  final r = Random.secure();
  String hex(int n) =>
      List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
  return '${hex(8)}-${hex(4)}-4${hex(3)}-8${hex(3)}-${hex(12)}';
}

void main() {
  group('parseSets', () {
    final now = DateTime.utc(2026, 11, 12, 12);

    Map<String, dynamic> set(Map<String, dynamic> overrides) => {
      'id': '11111111-1111-4111-8111-111111111111',
      'exerciseId': _squat,
      'reps': 5,
      'weightKg': 100,
      'performedAt': '2026-11-12T10:00:00Z',
      ...overrides,
    };

    test('platná séria prejde', () {
      final (valid, rejected) = parseSets({
        'sets': [set({})],
      }, now: now);
      expect(valid.single.reps, 5);
      expect(valid.single.weightKg, 100.0);
      expect(rejected, isEmpty);
    });

    test('chybné hodnoty sa odmietnu s dôvodom, nie celá dávka', () {
      final (valid, rejected) = parseSets({
        'sets': [
          set({'id': '22222222-2222-4222-8222-222222222222', 'reps': 0}),
          set({'id': '33333333-3333-4333-8333-333333333333', 'weightKg': -5}),
          set({
            'id': '44444444-4444-4444-8444-444444444444',
            'performedAt': '2030-01-01T00:00:00Z',
          }),
          set({}),
        ],
      }, now: now);
      expect(valid, hasLength(1));
      expect(rejected, {
        '22222222-2222-4222-8222-222222222222': 'invalid_reps',
        '33333333-3333-4333-8333-333333333333': 'invalid_weight',
        '44444444-4444-4444-8444-444444444444': 'invalid_time',
      });
    });

    test('príliš veľká dávka sa odmietne celá', () {
      expect(
        () => parseSets({
          'sets': List.generate(maxSetsPerSync + 1, (_) => set({})),
        }, now: now),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 413)),
      );
    });
  });

  group('POST /sets/sync', () {
    late Database db;
    late Handler app;
    late AuthService auth;
    final email = 'sets-${Random.secure().nextInt(1 << 32)}@test.local';
    late String token;
    late String userId;

    Future<(int, Map<String, dynamic>)> sync(
      List<Map<String, dynamic>> sets, {
      String? withToken,
    }) async {
      final response = await app(
        Request(
          'POST',
          Uri.parse('http://localhost/sets/sync'),
          body: jsonEncode({'sets': sets}),
          headers: {
            if ((withToken ?? token).isNotEmpty)
              'authorization': 'Bearer ${withToken ?? token}',
          },
        ),
      );
      return (
        response.statusCode,
        jsonDecode(await response.readAsString()) as Map<String, dynamic>,
      );
    }

    Future<int> countSets() => db.asUser(userId, (tx) async {
      final rows = await tx.execute(
        Sql.named(
          'SELECT count(*)::int FROM set_logs WHERE user_id = CAST(@u AS uuid)',
        ),
        parameters: {'u': userId},
      );
      return rows.first[0] as int;
    });

    setUpAll(() async {
      db = Database.connect(AppConfig.load().databaseUrl);
      auth = AuthService(db, bcryptRounds: 4);
      app = buildApp(
        auth: auth,
        training: TrainingService(db),
        corsOrigins: const {},
      );
      final result = await auth.register(
        email: email,
        password: 'heslo-na-test-1',
        displayName: 'Série',
        role: 'member',
      );
      token = result.token;
      userId = result.user.id;
    });

    tearDownAll(() async {
      await auth.deleteAccount(userId);
      await db.close();
    });

    test('opakované odoslanie tej istej série ju nezdvojí', () async {
      final set = {
        'id': _uuid(),
        'exerciseId': _squat,
        'reps': 5,
        'weightKg': 102.5,
        'performedAt': DateTime.now().toUtc().toIso8601String(),
      };

      var (status, body) = await sync([set]);
      expect(status, 200);
      expect(body['accepted'], [set['id']]);

      (status, body) = await sync([set]);
      expect(status, 200);
      expect(body['accepted'], [set['id']]);
      expect(await countSets(), 1);
    });

    test('neznámy cvik sa odmietne', () async {
      final id = _uuid();
      final (status, body) = await sync([
        {
          'id': id,
          'exerciseId': _uuid(),
          'reps': 5,
          'weightKg': 50,
          'performedAt': DateTime.now().toUtc().toIso8601String(),
        },
      ]);
      expect(status, 200);
      expect(body['accepted'], isEmpty);
      expect(body['rejected'], [
        {'id': id, 'reason': 'unknown_exercise'},
      ]);
    });

    test('bez prihlásenia nič', () async {
      final (status, _) = await sync([], withToken: '');
      expect(status, 401);
    });

    test('katalóg cvikov', () async {
      final response = await app(
        Request(
          'GET',
          Uri.parse('http://localhost/exercises'),
          headers: {'authorization': 'Bearer $token'},
        ),
      );
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      final ids = [for (final e in body['exercises'] as List) e['id']];
      expect(ids, contains(_squat));
      expect(ids.length, greaterThanOrEqualTo(12));
    });
  });
}
