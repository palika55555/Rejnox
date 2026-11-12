import 'package:postgres/postgres.dart';

import '../db.dart';
import '../http/api_exception.dart';

final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

const maxSetsPerSync = 200;

/// Jedna odcvičená séria tak, ako ju posiela appka.
class SetInput {
  const SetInput({
    required this.id,
    required this.exerciseId,
    required this.reps,
    required this.weightKg,
    required this.performedAt,
  });

  final String id;
  final String exerciseId;
  final int reps;
  final double weightKg;
  final DateTime performedAt;
}

/// Výsledok synchronizácie: prijaté ID (aj tie, čo už na serveri boli)
/// a odmietnuté ID s dôvodom, aby ich appka prestala posielať.
class SyncResult {
  const SyncResult(this.accepted, this.rejected);

  final List<String> accepted;
  final Map<String, String> rejected;

  Map<String, dynamic> toJson() => {
    'accepted': accepted,
    'rejected': [
      for (final e in rejected.entries) {'id': e.key, 'reason': e.value},
    ],
  };
}

/// Rozparsuje telo požiadavky. Chybné položky nevyhodia celú dávku,
/// len sa označia ako odmietnuté.
(List<SetInput>, Map<String, String>) parseSets(
  Map<String, dynamic> body, {
  DateTime? now,
}) {
  final raw = body['sets'];
  if (raw is! List) {
    throw const ApiException(400, 'invalid_sets', 'Chýba zoznam sérií.');
  }
  if (raw.length > maxSetsPerSync) {
    throw const ApiException(
      413,
      'too_many_sets',
      'Naraz sa dá poslať najviac $maxSetsPerSync sérií.',
    );
  }
  final current = (now ?? DateTime.now()).toUtc();
  final valid = <SetInput>[];
  final rejected = <String, String>{};
  for (final item in raw) {
    if (item is! Map) continue;
    final id = item['id'];
    if (id is! String || !_uuidPattern.hasMatch(id)) continue;

    final exerciseId = item['exerciseId'];
    final reps = item['reps'];
    final weight = item['weightKg'];
    final performedAt = item['performedAt'] is String
        ? DateTime.tryParse(item['performedAt'] as String)
        : null;

    String? reason;
    if (exerciseId is! String || !_uuidPattern.hasMatch(exerciseId)) {
      reason = 'invalid_exercise';
    } else if (reps is! int || reps < 1 || reps > 1000) {
      reason = 'invalid_reps';
    } else if (weight is! num || weight < 0 || weight > 1000) {
      reason = 'invalid_weight';
    } else if (performedAt == null ||
        performedAt.isAfter(current.add(const Duration(days: 1))) ||
        performedAt.isBefore(current.subtract(const Duration(days: 366)))) {
      reason = 'invalid_time';
    }
    if (reason != null) {
      rejected[id] = reason;
      continue;
    }
    valid.add(
      SetInput(
        id: id,
        exerciseId: exerciseId as String,
        reps: reps as int,
        weightKg: (weight as num).toDouble(),
        performedAt: performedAt!.toUtc(),
      ),
    );
  }
  return (valid, rejected);
}

class TrainingService {
  TrainingService(this._db);

  final Database _db;

  Future<List<Map<String, dynamic>>> exercises(String userId) =>
      _db.asUser(userId, (tx) async {
        final rows = await tx.execute(
          'SELECT id::text, name, muscle_group FROM exercises ORDER BY name',
        );
        return [
          for (final r in rows) {'id': r[0], 'name': r[1], 'muscleGroup': r[2]},
        ];
      });

  /// Uloží série. Opakované poslanie tej istej série nič nezdvojí.
  Future<SyncResult> syncSets(
    String userId,
    List<SetInput> sets,
    Map<String, String> rejected,
  ) => _db.asUser(userId, (tx) async {
    final accepted = <String>[];
    if (sets.isEmpty) return SyncResult(accepted, rejected);

    final known = await tx.execute(
      Sql.named(
        'SELECT id::text FROM exercises WHERE id = ANY(CAST(@ids AS uuid[]))',
      ),
      parameters: {'ids': sets.map((s) => s.exerciseId).toSet().toList()},
    );
    final knownIds = {for (final r in known) r[0] as String};

    for (final s in sets) {
      if (!knownIds.contains(s.exerciseId)) {
        rejected[s.id] = 'unknown_exercise';
        continue;
      }
      await tx.execute(
        Sql.named('''
          INSERT INTO set_logs
            (id, user_id, exercise_id, reps, weight_kg, performed_at, logged_by)
          VALUES (CAST(@id AS uuid), CAST(@user AS uuid), CAST(@exercise AS uuid),
                  @reps, @weight, @at, CAST(@user AS uuid))
          ON CONFLICT (id) DO NOTHING
        '''),
        parameters: {
          'id': s.id,
          'user': userId,
          'exercise': s.exerciseId,
          'reps': s.reps,
          'weight': s.weightKg,
          'at': s.performedAt,
        },
      );
      accepted.add(s.id);
    }
    return SyncResult(accepted, rejected);
  });
}
