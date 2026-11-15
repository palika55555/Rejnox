import 'package:flutter_test/flutter_test.dart';
import 'package:rejnox/features/training/application/exercise_stats.dart';
import 'package:rejnox/features/training/domain/training_models.dart';

LoggedSet _set(
  String id,
  double kg, {
  int reps = 5,
  SyncState state = SyncState.synced,
}) => LoggedSet(
  id: id,
  exerciseId: 'drep',
  reps: reps,
  weightKg: kg,
  performedAt: DateTime(2026, 11, 15, 10),
  state: state,
);

void main() {
  test('história cviku: rekord je najvyššia váha, posledná je prvá', () {
    // Série sú zoradené od najnovšej.
    final history = ExerciseHistory.fromSets([
      _set('c', 90, reps: 8),
      _set('b', 110),
      _set('a', 100),
    ])['drep']!;

    expect(history.bestKg, 110);
    expect(history.last!.id, 'c');
  });

  test('odmietnutá séria sa do rekordu nepočíta', () {
    final history = ExerciseHistory.fromSets([
      _set('x', 300, state: SyncState.rejected),
      _set('a', 100),
    ])['drep']!;

    expect(history.bestKg, 100);
    expect(history.last!.id, 'a');
  });

  test('druh série sa uloží v telefóne, ale na server nejde', () {
    final set = LoggedSet(
      id: 'w',
      exerciseId: 'drep',
      reps: 10,
      weightKg: 60,
      performedAt: DateTime(2026, 11, 15),
      kind: SetKind.warmup,
    );

    expect(LoggedSet.fromJson(set.toJson()).kind, SetKind.warmup);
    expect(set.toApiJson().containsKey('kind'), isFalse);
    // Staré záznamy bez druhu sú pracovné série.
    final old = set.toJson()..remove('kind');
    expect(LoggedSet.fromJson(old).kind, SetKind.working);
  });

  test('formát hodín a váhy', () {
    expect(formatClock(const Duration(seconds: 65)), '1:05');
    expect(
      formatClock(const Duration(hours: 1, minutes: 2, seconds: 7)),
      '1:02:07',
    );
    expect(formatKg(100), '100');
    expect(formatKg(102.5), '102,5');
  });
}
