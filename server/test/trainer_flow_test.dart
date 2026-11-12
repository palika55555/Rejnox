// Tréner a klienti proti skutočnej lokálnej databáze (config/.env).
import 'dart:convert';
import 'dart:math';

import 'package:rejnox_server/src/app.dart';
import 'package:rejnox_server/src/auth/auth_service.dart';
import 'package:rejnox_server/src/config.dart';
import 'package:rejnox_server/src/db.dart';
import 'package:rejnox_server/src/trainer/trainer_service.dart';
import 'package:rejnox_server/src/trainer/trainer_validation.dart';
import 'package:rejnox_server/src/training/training_service.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

const _squat = '00000000-0000-4000-8000-000000000001';

void main() {
  group('pozývací kód', () {
    test('má tvar XXXX-XXXX a dá sa zadať aj s malými písmenami', () {
      final code = newInviteCode(Random(1));
      expect(code, matches(RegExp(r'^[A-Z2-9]{4}-[A-Z2-9]{4}$')));
      expect(
        normalizeInviteCode(' ${code.toLowerCase()} '),
        code.replaceAll('-', ''),
      );
    });

    test('nezmysel sa odmietne', () {
      expect(() => normalizeInviteCode('ABC'), throwsA(anything));
      expect(() => normalizeInviteCode('ABCD-EFG0'), throwsA(anything));
    });
  });

  group('tréner ↔ klient', () {
    late Database db;
    late AuthService auth;
    late Handler app;
    final ids = <String>[];
    final tag = Random.secure().nextInt(1 << 32);

    Future<String> account(String name, String role) async {
      final r = await auth.register(
        email: '$name-$tag@test.local',
        password: 'heslo-na-test-1',
        displayName: name,
        role: role,
      );
      ids.add(r.user.id);
      return r.token;
    }

    Future<(int, dynamic)> call(
      String method,
      String path,
      String token, [
      Map<String, dynamic>? body,
    ]) async {
      final response = await app(
        Request(
          method,
          Uri.parse('http://localhost$path'),
          body: body == null ? null : jsonEncode(body),
          headers: {'authorization': 'Bearer $token'},
        ),
      );
      final text = await response.readAsString();
      return (response.statusCode, text.isEmpty ? null : jsonDecode(text));
    }

    setUpAll(() {
      db = Database.connect(AppConfig.load().databaseUrl);
      auth = AuthService(db, bcryptRounds: 4);
      app = buildApp(
        auth: auth,
        training: TrainingService(db),
        trainers: TrainerService(db),
        corsOrigins: const {},
      );
    });

    tearDownAll(() async {
      for (final id in ids) {
        await auth.deleteAccount(id);
      }
      await db.close();
    });

    test('celý tok: pridanie, pozvánka, plán, progres, ukončenie', () async {
      final trainer = await account('Marek', 'trainer');
      final client = await account('Jana', 'member');
      final stranger = await account('Cudzi', 'member');

      // Člen nemá prístup k trénerskej časti.
      var (status, body) = await call('GET', '/clients', client);
      expect(status, 403);

      // Klient bez appky (len záznam).
      (status, body) = await call('POST', '/clients', trainer, {
        'name': 'Jana Nováková',
        'note': 'Koleno po operácii',
      });
      expect(status, 201);
      final clientId = body['id'] as String;
      expect(body['status'], 'record_only');
      expect(body['hasAccount'], isFalse);

      // Plán a séria aj pre klienta bez účtu.
      (status, body) = await call(
        'POST',
        '/clients/$clientId/workouts',
        trainer,
        {
          'title': 'Nohy A',
          'scheduledOn': '2026-11-20',
          'exercises': [
            {'exerciseId': _squat, 'sets': 4, 'reps': 6, 'weightKg': 80},
          ],
        },
      );
      expect(status, 201);
      expect(body['exercises'][0]['name'], 'Drep s činkou');
      expect(body['exercises'][0]['weightKg'], 80.0);

      final setId =
          '11111111-2222-4333-8444-${tag.toRadixString(16).padLeft(12, '0')}';
      for (var i = 0; i < 2; i++) {
        (status, _) = await call('POST', '/clients/$clientId/sets', trainer, {
          'id': setId,
          'exerciseId': _squat,
          'reps': 6,
          'weightKg': 82.5,
        });
        expect(status, 201);
      }

      // Pozvánka.
      (status, body) = await call('POST', '/clients/$clientId/invite', trainer);
      expect(status, 201);
      final code = body['code'] as String;

      // Zlý kód nič neprezradí, správny prepojí.
      (status, body) = await call('POST', '/invites/accept', client, {
        'code': 'AAAA-BBBB',
      });
      expect(status, 404);
      (status, body) = await call('POST', '/invites/accept', client, {
        'code': code.toLowerCase(),
      });
      expect(status, 200);
      expect(body['trainerName'], 'Marek');
      final linkId = body['linkId'] as String;

      // Použitý kód už druhýkrát nefunguje.
      (status, _) = await call('POST', '/invites/accept', stranger, {
        'code': code,
      });
      expect(status, 404);

      // Klient vidí plán od trénera, cudzí nie.
      (status, body) = await call('GET', '/me/plans', client);
      expect((body['plans'] as List).single['title'], 'Nohy A');
      (status, body) = await call('GET', '/me/plans', stranger);
      expect(body['plans'], isEmpty);

      // Tréner vidí klienta ako prepojeného, s jedinou sériou (bez duplikátu).
      (status, body) = await call('GET', '/clients/$clientId', trainer);
      expect(body['status'], 'linked');
      expect(body['sets'], hasLength(1));

      // Klienta s účtom nejde zmazať.
      (status, body) = await call('DELETE', '/clients/$clientId', trainer);
      expect(status, 409);

      // Klient ukončí spoluprácu: tréner už nič nevidí ani nezapíše.
      (status, _) = await call('POST', '/me/trainers/$linkId/end', client);
      expect(status, 204);
      (status, body) = await call('GET', '/clients/$clientId', trainer);
      expect(body['status'], 'ended');
      expect(body['workouts'], isEmpty);
      expect(body['sets'], isEmpty);
      (status, _) = await call('POST', '/clients/$clientId/workouts', trainer, {
        'title': 'Po ukončení',
        'exercises': [
          {'exerciseId': _squat, 'sets': 1, 'reps': 1},
        ],
      });
      expect(status, 404);

      // Klientovi história ostáva.
      (status, body) = await call('GET', '/me/plans', client);
      expect(body['plans'], hasLength(1));
    });

    test('cudzí tréner na klienta nedosiahne', () async {
      final trainerA = await account('TrenerA', 'trainer');
      final trainerB = await account('TrenerB', 'trainer');
      var (status, body) = await call('POST', '/clients', trainerA, {
        'name': 'X',
      });
      final clientId = body['id'] as String;

      (status, _) = await call('GET', '/clients/$clientId', trainerB);
      expect(status, 404);
      (status, _) = await call('POST', '/clients/$clientId/invite', trainerB);
      expect(status, 409);
      (status, _) = await call(
        'POST',
        '/clients/$clientId/workouts',
        trainerB,
        {
          'title': 'Cudzí',
          'exercises': [
            {'exerciseId': _squat, 'sets': 1, 'reps': 1},
          ],
        },
      );
      expect(status, 404);
      (status, body) = await call('GET', '/clients', trainerB);
      expect(body['clients'], isEmpty);

      // Klienta bez účtu tréner zmazať môže.
      (status, _) = await call('DELETE', '/clients/$clientId', trainerA);
      expect(status, 204);
    });

    test('neplatné vstupy', () async {
      final trainer = await account('TrenerC', 'trainer');
      var (status, body) = await call('POST', '/clients', trainer, {
        'name': '',
      });
      expect(status, 400);
      (status, body) = await call('POST', '/clients', trainer, {'name': 'Y'});
      final id = body['id'];
      (status, body) = await call('POST', '/clients/$id/workouts', trainer, {
        'title': 'Bez cvikov',
        'exercises': [],
      });
      expect(status, 400);
      (status, _) = await call('GET', '/clients/nie-je-uuid', trainer);
      expect(status, 400);
    });
  });
}
