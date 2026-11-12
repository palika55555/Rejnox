import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart';

import '../db.dart';
import '../http/api_exception.dart';
import 'trainer_validation.dart';

const _notFound = ApiException(404, 'not_found', 'Klient sa nenašiel.');

/// Cvik v pláne tak, ako ho posiela tréner.
class PlanExercise {
  const PlanExercise({
    required this.exerciseId,
    required this.sets,
    required this.reps,
    this.weightKg,
    this.note,
  });

  factory PlanExercise.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const ApiException(400, 'invalid_exercises', 'Neplatný cvik.');
    }
    final weight = json['weightKg'];
    return PlanExercise(
      exerciseId: requireUuid('${json['exerciseId']}', 'exerciseId'),
      sets: requireInt(json['sets'], 'sets', min: 1, max: 20),
      reps: requireInt(json['reps'], 'reps', min: 1, max: 1000),
      weightKg: weight == null ? null : requireWeight(weight),
      note: optionalText(json, 'note', max: 200),
    );
  }

  final String exerciseId;
  final int sets;
  final int reps;
  final double? weightKg;
  final String? note;
}

String _hashCode(String normalized) =>
    sha256.convert(utf8.encode(normalized)).toString();

Map<String, dynamic> _json(Map<String, dynamic> row) => {
  for (final e in row.entries)
    e.key: e.value is DateTime
        ? (e.value as DateTime).toIso8601String()
        : e.value,
};

class TrainerService {
  TrainerService(this._db);

  final Database _db;

  static const _clientColumns = '''
    id::text, client_name AS name, note, status::text,
    client_user_id IS NOT NULL AS "hasAccount",
    invite_expires_at AS "inviteExpiresAt", created_at AS "createdAt"
  ''';

  // ------------------------------------------------------------- tréner

  Future<List<Map<String, dynamic>>> listClients(String trainerId) =>
      _db.asUser(trainerId, (tx) async {
        final rows = await tx.execute(
          Sql.named('''
            SELECT $_clientColumns FROM trainer_clients
            WHERE trainer_id = CAST(@me AS uuid)
            ORDER BY status = 'ended', lower(client_name)
          '''),
          parameters: {'me': trainerId},
        );
        return [for (final r in rows) _json(r.toColumnMap())];
      });

  Future<Map<String, dynamic>> addClient(
    String trainerId, {
    required String name,
    String? note,
  }) => _db.asUser(trainerId, (tx) async {
    final rows = await tx.execute(
      Sql.named('''
        INSERT INTO trainer_clients (trainer_id, client_name, note)
        VALUES (CAST(@me AS uuid), @name, @note)
        RETURNING $_clientColumns
      '''),
      parameters: {'me': trainerId, 'name': name, 'note': note},
    );
    return _json(rows.first.toColumnMap());
  });

  /// Detail klienta: údaje, plány s cvikmi a posledné série.
  Future<Map<String, dynamic>> clientDetail(
    String trainerId,
    String clientId,
  ) => _db.asUser(trainerId, (tx) async {
    final client = await tx.execute(
      Sql.named('''
            SELECT $_clientColumns FROM trainer_clients
            WHERE id = CAST(@id AS uuid) AND trainer_id = CAST(@me AS uuid)
          '''),
      parameters: {'id': clientId, 'me': trainerId},
    );
    if (client.isEmpty) throw _notFound;
    return {
      ..._json(client.first.toColumnMap()),
      'workouts': await _workouts(
        tx,
        'w.trainer_client_id = CAST(@id AS uuid)',
        {'id': clientId},
      ),
      'sets': await _sets(tx, clientId),
    };
  });

  /// Vydá nový pozývací kód (platí 7 dní). Kód sa vráti len raz,
  /// v databáze je len jeho odtlačok.
  Future<Map<String, dynamic>> invite(String trainerId, String clientId) =>
      _db.asUser(trainerId, (tx) async {
        final code = newInviteCode();
        final rows = await tx.execute(
          Sql.named('''
            UPDATE trainer_clients
            SET status = 'invited', invite_token_hash = @hash,
                invite_expires_at = now() + interval '7 days'
            WHERE id = CAST(@id AS uuid) AND trainer_id = CAST(@me AS uuid)
              AND client_user_id IS NULL AND status IN ('record_only', 'invited')
            RETURNING invite_expires_at
          '''),
          parameters: {
            'hash': _hashCode(normalizeInviteCode(code)),
            'id': clientId,
            'me': trainerId,
          },
        );
        if (rows.isEmpty) {
          throw const ApiException(
            409,
            'cannot_invite',
            'Tohto klienta už pozvať nejde.',
          );
        }
        return {
          'code': code,
          'expiresAt': (rows.first[0] as DateTime).toIso8601String(),
        };
      });

  /// Ukončí spoluprácu (tréner aj klient). Tréner potom stratí prístup.
  Future<void> endLink(String userId, String linkId) =>
      _db.asUser(userId, (tx) async {
        final rows = await tx.execute(
          Sql.named('''
            UPDATE trainer_clients
            SET status = 'ended', invite_token_hash = NULL, invite_expires_at = NULL
            WHERE id = CAST(@id AS uuid) AND status <> 'ended'
            RETURNING id
          '''),
          parameters: {'id': linkId},
        );
        if (rows.isEmpty) throw _notFound;
      });

  /// Zmazať sa dá len klient bez účtu (história klienta s účtom ostáva).
  Future<void> deleteClient(
    String trainerId,
    String clientId,
  ) => _db.asUser(trainerId, (tx) async {
    final rows = await tx.execute(
      Sql.named(
        'DELETE FROM trainer_clients WHERE id = CAST(@id AS uuid) RETURNING id',
      ),
      parameters: {'id': clientId},
    );
    if (rows.isEmpty) {
      throw const ApiException(
        409,
        'cannot_delete',
        'Klienta s účtom nejde zmazať, spoluprácu môžeš len ukončiť.',
      );
    }
  });

  Future<Map<String, dynamic>> addWorkout(
    String trainerId,
    String clientId, {
    required String title,
    DateTime? scheduledOn,
    required List<PlanExercise> exercises,
  }) => _db.asUser(trainerId, (tx) async {
    final created = await tx.execute(
      Sql.named('''
        INSERT INTO workouts (trainer_client_id, title, scheduled_on, created_by)
        SELECT t.id, @title, @date, CAST(@me AS uuid) FROM trainer_clients t
        WHERE t.id = CAST(@id AS uuid) AND t.trainer_id = CAST(@me AS uuid)
          AND t.status <> 'ended'
        RETURNING id::text
      '''),
      parameters: {
        'title': title,
        'date': scheduledOn,
        'me': trainerId,
        'id': clientId,
      },
    );
    if (created.isEmpty) throw _notFound;
    final workoutId = created.first[0] as String;
    for (var i = 0; i < exercises.length; i++) {
      final e = exercises[i];
      await tx.execute(
        Sql.named('''
          INSERT INTO workout_exercises
            (workout_id, exercise_id, position, sets, reps, weight_kg, note)
          VALUES (CAST(@w AS uuid), CAST(@e AS uuid), @pos, @sets, @reps,
                  @weight, @note)
        '''),
        parameters: {
          'w': workoutId,
          'e': e.exerciseId,
          'pos': i,
          'sets': e.sets,
          'reps': e.reps,
          'weight': e.weightKg,
          'note': e.note,
        },
      );
    }
    final list = await _workouts(tx, 'w.id = CAST(@id AS uuid)', {
      'id': workoutId,
    });
    return list.single;
  });

  Future<void> deleteWorkout(
    String trainerId,
    String clientId,
    String workoutId,
  ) => _db.asUser(trainerId, (tx) async {
    final rows = await tx.execute(
      Sql.named('''
            DELETE FROM workouts
            WHERE id = CAST(@w AS uuid) AND trainer_client_id = CAST(@id AS uuid)
            RETURNING id
          '''),
      parameters: {'w': workoutId, 'id': clientId},
    );
    if (rows.isEmpty) throw _notFound;
  });

  /// Tréner zapíše sériu klientovi. ID z appky = bez duplikátov.
  Future<Map<String, dynamic>> logSet(
    String trainerId,
    String clientId, {
    required String id,
    required String exerciseId,
    required int reps,
    required double weightKg,
    DateTime? performedAt,
  }) => _db.asUser(trainerId, (tx) async {
    final rows = await tx.execute(
      Sql.named('''
        INSERT INTO set_logs
          (id, trainer_client_id, exercise_id, reps, weight_kg, performed_at, logged_by)
        SELECT CAST(@sid AS uuid), t.id, CAST(@e AS uuid), @reps, @weight,
               coalesce(@at, now()), CAST(@me AS uuid)
        FROM trainer_clients t
        WHERE t.id = CAST(@id AS uuid) AND t.trainer_id = CAST(@me AS uuid)
          AND t.status <> 'ended'
        ON CONFLICT (id) DO NOTHING
        RETURNING id
      '''),
      parameters: {
        'sid': id,
        'e': exerciseId,
        'reps': reps,
        'weight': weightKg,
        'at': performedAt,
        'me': trainerId,
        'id': clientId,
      },
    );
    if (rows.isEmpty) {
      // Buď už existuje (opakované odoslanie), alebo klient nepatrí trénerovi.
      final exists = await tx.execute(
        Sql.named(
          'SELECT 1 FROM set_logs WHERE id = CAST(@sid AS uuid) '
          'AND trainer_client_id = CAST(@id AS uuid)',
        ),
        parameters: {'sid': id, 'id': clientId},
      );
      if (exists.isEmpty) throw _notFound;
    }
    return {'id': id};
  });

  // ------------------------------------------------------------- klient

  /// Klient zadá kód od trénera.
  Future<Map<String, dynamic>> acceptInvite(String userId, String code) =>
      _db.asUser(userId, (tx) async {
        final String linkId;
        try {
          final rows = await tx.execute(
            Sql.named('SELECT accept_client_invite(@hash)::text'),
            parameters: {'hash': _hashCode(code)},
          );
          linkId = rows.first[0] as String;
        } on ServerException catch (e) {
          if (e.message.contains('invite invalid')) {
            throw const ApiException(
              404,
              'invalid_code',
              'Kód neplatí alebo už vypršal.',
            );
          }
          rethrow;
        }
        return (await _myTrainers(
          tx,
          userId,
        )).firstWhere((t) => t['linkId'] == linkId);
      });

  Future<List<Map<String, dynamic>>> myTrainers(String userId) =>
      _db.asUser(userId, (tx) => _myTrainers(tx, userId));

  /// Plány od všetkých mojich trénerov.
  Future<List<Map<String, dynamic>>> myPlans(String userId) =>
      _db.asUser(userId, (tx) async {
        return _workouts(
          tx,
          'w.trainer_client_id IN (SELECT id FROM trainer_clients '
          'WHERE client_user_id = CAST(@me AS uuid))',
          {'me': userId},
        );
      });

  // ------------------------------------------------------------- pomocné

  Future<List<Map<String, dynamic>>> _myTrainers(
    TxSession tx,
    String userId,
  ) async {
    final rows = await tx.execute(
      Sql.named('''
        SELECT t.id::text AS "linkId", p.display_name AS "trainerName",
               t.status::text AS status, t.created_at AS "createdAt"
        FROM trainer_clients t
        JOIN public_profiles p ON p.id = t.trainer_id
        WHERE t.client_user_id = CAST(@me AS uuid)
        ORDER BY t.status = 'ended', t.created_at DESC
      '''),
      parameters: {'me': userId},
    );
    return [for (final r in rows) _json(r.toColumnMap())];
  }

  Future<List<Map<String, dynamic>>> _workouts(
    TxSession tx,
    String where,
    Map<String, Object?> params,
  ) async {
    final rows = await tx.execute(
      Sql.named('''
        SELECT w.id::text, w.title, to_char(w.scheduled_on, 'YYYY-MM-DD') AS "scheduledOn",
               w.created_at AS "createdAt", p.display_name AS "trainerName",
               coalesce(json_agg(json_build_object(
                 'exerciseId', we.exercise_id, 'name', e.name,
                 'muscleGroup', e.muscle_group, 'sets', we.sets, 'reps', we.reps,
                 'weightKg', we.weight_kg::float8, 'note', we.note
               ) ORDER BY we.position) FILTER (WHERE we.id IS NOT NULL), '[]') AS exercises
        FROM workouts w
        JOIN trainer_clients t ON t.id = w.trainer_client_id
        JOIN public_profiles p ON p.id = t.trainer_id
        LEFT JOIN workout_exercises we ON we.workout_id = w.id
        LEFT JOIN exercises e ON e.id = we.exercise_id
        WHERE $where
        GROUP BY w.id, p.display_name
        ORDER BY w.scheduled_on DESC NULLS LAST, w.created_at DESC
        LIMIT 50
      '''),
      parameters: params,
    );
    return [
      for (final r in rows)
        {
          ..._json(r.toColumnMap()),
          'exercises': _decodeJson(r.toColumnMap()['exercises']),
        },
    ];
  }

  Future<List<Map<String, dynamic>>> _sets(
    TxSession tx,
    String clientId,
  ) async {
    final rows = await tx.execute(
      Sql.named('''
        SELECT s.id::text, s.exercise_id::text AS "exerciseId", e.name,
               s.reps, s.weight_kg::float8 AS "weightKg", s.performed_at AS "performedAt"
        FROM set_logs s JOIN exercises e ON e.id = s.exercise_id
        WHERE s.trainer_client_id = CAST(@id AS uuid)
        ORDER BY s.performed_at DESC
        LIMIT 100
      '''),
      parameters: {'id': clientId},
    );
    return [for (final r in rows) _json(r.toColumnMap())];
  }

  static Object? _decodeJson(Object? value) =>
      value is String ? jsonDecode(value) : value;
}
