import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../coaching/domain/coaching_models.dart';
import '../domain/training_models.dart';
import 'workout_log_controller.dart';

typedef PlanProgress = ({int done, int total, PlanItem? next});

/// Prebiehajúci tréning vrátane pôvodného poradia a parametrov plánu.
class ActiveWorkout {
  const ActiveWorkout({
    required this.title,
    required this.startedAt,
    this.plan = const [],
  });

  factory ActiveWorkout.fromJson(Map<String, dynamic> json) => ActiveWorkout(
    title: json['title'] as String,
    startedAt: DateTime.parse(json['startedAt'] as String).toLocal(),
    plan: [
      for (final item in json['plan'] as List? ?? const [])
        PlanItem.fromJson(item as Map<String, dynamic>),
    ],
  );

  final String title;
  final DateTime startedAt;
  final List<PlanItem> plan;

  /// Série zapísané od začiatku tréningu (najnovšie hore).
  List<LoggedSet> setsFrom(List<LoggedSet> all) => [
    for (final s in all)
      if (!s.performedAt.isBefore(startedAt) && s.state != SyncState.rejected)
        s,
  ];

  /// Série, ktoré patria do plánu. Opakovaný cvik sa plní v poradí plánu.
  PlanProgress progressFrom(Iterable<LoggedSet> all) {
    if (plan.isEmpty) return (done: 0, total: 0, next: null);
    final remaining = <String, int>{};
    for (final set in all) {
      if (set.kind == SetKind.warmup ||
          set.state == SyncState.rejected ||
          set.performedAt.isBefore(startedAt)) {
        continue;
      }
      remaining.update(set.exerciseId, (count) => count + 1, ifAbsent: () => 1);
    }
    var done = 0;
    var total = 0;
    PlanItem? next;
    for (final item in plan) {
      final available = remaining[item.exerciseId] ?? 0;
      final credited = available.clamp(0, item.sets);
      remaining[item.exerciseId] = available - credited;
      done += credited;
      total += item.sets;
      if (credited < item.sets) next ??= item;
    }
    return (done: done, total: total, next: next);
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'startedAt': startedAt.toUtc().toIso8601String(),
    if (plan.isNotEmpty) 'plan': [for (final item in plan) item.toJson()],
  };
}

/// Súhrn ukončeného tréningu.
class FinishedWorkout {
  const FinishedWorkout({
    required this.title,
    required this.startedAt,
    required this.duration,
    required this.sets,
    required this.exercises,
    required this.volumeKg,
  });

  factory FinishedWorkout.fromJson(Map<String, dynamic> json) =>
      FinishedWorkout(
        title: json['title'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String).toLocal(),
        duration: Duration(seconds: json['seconds'] as int),
        sets: json['sets'] as int,
        exercises: json['exercises'] as int,
        volumeKg: (json['volumeKg'] as num).toDouble(),
      );

  /// Spočíta súhrn zo sérií tréningu.
  factory FinishedWorkout.summarize(
    ActiveWorkout workout,
    List<LoggedSet> allSets, {
    required DateTime now,
  }) {
    final sets = workout.setsFrom(allSets);
    return FinishedWorkout(
      title: workout.title,
      startedAt: workout.startedAt,
      duration: now.difference(workout.startedAt),
      sets: sets.length,
      exercises: {for (final s in sets) s.exerciseId}.length,
      volumeKg: sets.fold(0.0, (v, s) => v + s.volumeKg),
    );
  }

  final String title;
  final DateTime startedAt;
  final Duration duration;
  final int sets;
  final int exercises;
  final double volumeKg;

  bool isOn(DateTime day) =>
      startedAt.year == day.year &&
      startedAt.month == day.month &&
      startedAt.day == day.day;

  Map<String, dynamic> toJson() => {
    'title': title,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'seconds': duration.inSeconds,
    'sets': sets,
    'exercises': exercises,
    'volumeKg': volumeKg,
  };
}

class WorkoutSessionState {
  const WorkoutSessionState({this.active, this.lastFinished});

  final ActiveWorkout? active;
  final FinishedWorkout? lastFinished;
}

/// Začiatok a koniec tréningu. Drží sa v telefóne, takže prežije aj
/// zatvorenie appky uprostred tréningu.
class WorkoutSessionController extends Notifier<WorkoutSessionState> {
  static const freeTitle = 'Voľný tréning';

  String? _userId;

  String _activeKey(String userId) => 'workout_active_$userId';
  String _finishedKey(String userId) => 'workout_finished_$userId';

  @override
  WorkoutSessionState build() {
    final auth = ref.watch(authControllerProvider);
    _userId = auth is SignedIn ? auth.user.id : null;
    final userId = _userId;
    if (userId != null) _load(userId);
    return const WorkoutSessionState();
  }

  Future<void> _load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    ActiveWorkout? active;
    FinishedWorkout? finished;
    try {
      final a = prefs.getString(_activeKey(userId));
      final f = prefs.getString(_finishedKey(userId));
      if (a != null) {
        active = ActiveWorkout.fromJson(jsonDecode(a) as Map<String, dynamic>);
      }
      if (f != null) {
        finished = FinishedWorkout.fromJson(
          jsonDecode(f) as Map<String, dynamic>,
        );
      }
    } on FormatException {
      // Poškodený záznam: radšej začať odznova než spadnúť.
    }
    if (!ref.mounted || _userId != userId) return;
    // Medzitým mohol používateľ tréning už začať – ten má prednosť.
    state = WorkoutSessionState(
      active: state.active ?? active,
      lastFinished: state.lastFinished ?? finished,
    );
  }

  /// Začne tréning, ak ešte nebeží. [startedAt] je pre testy.
  Future<void> start({
    String title = freeTitle,
    DateTime? startedAt,
    List<PlanItem> plan = const [],
  }) async {
    final userId = _userId;
    if (userId == null || state.active != null) return;
    final active = ActiveWorkout(
      title: title,
      startedAt: startedAt ?? DateTime.now(),
      plan: List.unmodifiable(plan),
    );
    state = WorkoutSessionState(
      active: active,
      lastFinished: state.lastFinished,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeKey(userId), jsonEncode(active.toJson()));
  }

  /// Ukončí tréning. Bez jedinej série sa nič neuloží (tréning sa zahodí).
  Future<FinishedWorkout?> finish() async {
    final userId = _userId;
    final active = state.active;
    if (userId == null || active == null) return null;
    final summary = FinishedWorkout.summarize(
      active,
      ref.read(workoutLogProvider).sets,
      now: DateTime.now(),
    );
    final saved = summary.sets > 0 ? summary : null;
    state = WorkoutSessionState(lastFinished: saved ?? state.lastFinished);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeKey(userId));
    if (saved != null) {
      await prefs.setString(_finishedKey(userId), jsonEncode(saved.toJson()));
    }
    return saved;
  }
}

final workoutSessionProvider =
    NotifierProvider<WorkoutSessionController, WorkoutSessionState>(
      WorkoutSessionController.new,
    );
