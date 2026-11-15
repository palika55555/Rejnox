import 'package:flutter_test/flutter_test.dart';
import 'package:rejnox/features/coaching/domain/coaching_models.dart';
import 'package:rejnox/features/training/application/workout_session.dart';
import 'package:rejnox/features/training/domain/training_models.dart';

LoggedSet _set(
  String id,
  DateTime at, {
  String exercise = 'drep',
  SyncState state = SyncState.synced,
  SetKind kind = SetKind.working,
}) => LoggedSet(
  id: id,
  exerciseId: exercise,
  reps: 5,
  weightKg: 100,
  performedAt: at,
  state: state,
  kind: kind,
);

void main() {
  final start = DateTime(2026, 11, 15, 17);
  final workout = ActiveWorkout(title: 'Nohy', startedAt: start);

  test('do tréningu patria len série od jeho začiatku', () {
    final sets = workout.setsFrom([
      _set('po', start.add(const Duration(minutes: 5))),
      _set(
        'odmietnutá',
        start.add(const Duration(minutes: 6)),
        state: SyncState.rejected,
      ),
      _set('pred', start.subtract(const Duration(hours: 3))),
    ]);

    expect(sets.map((s) => s.id), ['po']);
  });

  test('súhrn ukončeného tréningu', () {
    final summary = FinishedWorkout.summarize(workout, [
      _set('a', start.add(const Duration(minutes: 10)), exercise: 'bench'),
      _set('b', start.add(const Duration(minutes: 4))),
      _set('c', start.add(const Duration(minutes: 2))),
    ], now: start.add(const Duration(minutes: 52)));

    expect(summary.duration, const Duration(minutes: 52));
    expect(summary.sets, 3);
    expect(summary.exercises, 2);
    expect(summary.volumeKg, 1500);
    expect(summary.isOn(DateTime(2026, 11, 15, 23)), isTrue);
    expect(summary.isOn(DateTime(2026, 11, 16)), isFalse);
  });

  test('obnovený plán nepočíta rozcvičku, cudzie ani odmietnuté série', () {
    final planned = ActiveWorkout(
      title: 'Nohy',
      startedAt: start,
      plan: const [
        PlanItem(
          exerciseId: 'drep',
          name: 'Drep',
          group: MuscleGroup.legs,
          sets: 1,
          reps: 5,
        ),
        PlanItem(
          exerciseId: 'drep',
          name: 'Drep',
          group: MuscleGroup.legs,
          sets: 2,
          reps: 8,
        ),
      ],
    );
    final active = ActiveWorkout.fromJson(planned.toJson());
    final progress = active.progressFrom([
      _set('working', start, state: SyncState.pending),
      _set('warmup', start, kind: SetKind.warmup),
      _set('rejected', start, state: SyncState.rejected),
      _set('other', start, exercise: 'bench'),
      _set('prior', start.subtract(const Duration(seconds: 1))),
    ]);
    expect(progress.done, 1);
    expect(progress.total, 3);
    expect(progress.next?.reps, 8);
  });

  test('tréning prežije uloženie a načítanie', () {
    final restored = ActiveWorkout.fromJson(workout.toJson());
    expect(restored.title, 'Nohy');
    expect(restored.startedAt, start);
    expect(restored.plan, isEmpty);

    final summary = FinishedWorkout.summarize(workout, const [], now: start);
    final back = FinishedWorkout.fromJson(summary.toJson());
    expect(back.title, 'Nohy');
    expect(back.sets, 0);
  });
}
