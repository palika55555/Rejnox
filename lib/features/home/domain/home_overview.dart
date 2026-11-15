import '../../../core/theme/app_colors.dart';
import '../../training/domain/training_models.dart' show MuscleGroup;

/// Všetko, čo potrebuje domovská obrazovka klienta (GET /home).
/// Čo ešte nemá dáta na serveri (rebríček, fitko v okolí, parťák), je null
/// a karta sa neukáže.
class HomeOverview {
  const HomeOverview({
    required this.streakDays,
    required this.weeklyGoal,
    required this.todayWorkout,
    required this.personalRecord,
    this.ranking,
    this.nearbyGym,
    this.partnerRequest,
  });

  factory HomeOverview.fromJson(Map<String, dynamic> json) {
    final goal = json['weeklyGoal'] as Map<String, dynamic>;
    final workout = json['todayWorkout'] as Map<String, dynamic>?;
    final record = json['personalRecord'] as Map<String, dynamic>?;
    return HomeOverview(
      streakDays: json['streakDays'] as int,
      weeklyGoal: WeeklyGoal(
        done: goal['done'] as int,
        total: goal['total'] as int,
      ),
      todayWorkout: workout == null ? null : Workout.fromJson(workout),
      personalRecord: record == null ? null : PersonalRecord.fromJson(record),
    );
  }

  final int streakDays;
  final WeeklyGoal weeklyGoal;
  final Workout? todayWorkout;
  final PersonalRecord? personalRecord;
  final Ranking? ranking;
  final NearbyGym? nearbyGym;
  final PartnerRequest? partnerRequest;
}

class WeeklyGoal {
  const WeeklyGoal({required this.done, required this.total})
    : assert(total > 0),
      assert(done >= 0);

  final int done;
  final int total;

  int get percent => (done / total * 100).round().clamp(0, 100);
  bool get reached => done >= total;
}

class Workout {
  const Workout({
    required this.title,
    required this.trainerName,
    required this.exercises,
    this.minutes,
    this.kcal,
  });

  /// Plán od trénera. Cviky sa farebne striedajú podľa kotúčov.
  factory Workout.fromJson(Map<String, dynamic> json) {
    final exercises = json['exercises'] as List;
    return Workout(
      title: json['title'] as String,
      trainerName: json['trainerName'] as String?,
      exercises: [
        for (var i = 0; i < exercises.length; i++)
          Exercise.fromJson(
            exercises[i] as Map<String, dynamic>,
            plate: Plate.values[i % Plate.values.length],
          ),
      ],
    );
  }

  final String title;
  final String? trainerName;
  final List<Exercise> exercises;

  /// Odhad dĺžky a kalórií, ak ho niekto zadal (server ich zatiaľ nemá).
  final int? minutes;
  final int? kcal;
}

class Exercise {
  const Exercise({
    required this.name,
    required this.shortName,
    required this.sets,
    required this.reps,
    required this.weightKg,
    required this.note,
    required this.plate,
    this.isPr = false,
    this.exerciseId,
    this.group,
  });

  factory Exercise.fromJson(Map<String, dynamic> json, {required Plate plate}) {
    final name = json['name'] as String? ?? 'Cvik';
    final sets = json['sets'] as int;
    final note = json['note'] as String?;
    return Exercise(
      name: name,
      shortName: name,
      exerciseId: json['exerciseId'] as String?,
      group: json['muscleGroup'] == null
          ? null
          : MuscleGroup.fromApi(json['muscleGroup']),
      sets: sets,
      reps: json['reps'] as int,
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      note: note == null || note.isEmpty ? '$sets ${_seriesWord(sets)}' : note,
      plate: plate,
    );
  }

  final String name;
  final String shortName;
  final String? exerciseId;
  final MuscleGroup? group;
  final int sets;
  final int reps;

  /// Null = váhu tréner nezadal (napr. vlastná váha).
  final double? weightKg;
  final String note;
  final Plate plate;
  final bool isPr;

  String get scheme => '$sets×$reps';
  String? get weightLabel => weightKg == null ? null : '${_trim(weightKg!)} kg';
}

class PersonalRecord {
  const PersonalRecord({
    required this.exercise,
    required this.weightKg,
    required this.monthDeltaKg,
    required this.trend,
  });

  factory PersonalRecord.fromJson(Map<String, dynamic> json) => PersonalRecord(
    exercise: json['exercise'] as String,
    weightKg: (json['weightKg'] as num).toDouble(),
    monthDeltaKg: (json['monthDeltaKg'] as num).toDouble(),
    trend: [for (final v in json['trend'] as List) (v as num).toDouble()],
  );

  final String exercise;
  final double weightKg;
  final double monthDeltaKg;

  /// Posledné hodnoty PR od najstaršej po najnovšiu (pre graf).
  final List<double> trend;

  String get weightLabel => _trim(weightKg);
  String get deltaLabel =>
      '${monthDeltaKg >= 0 ? '+' : ''}${_trim(monthDeltaKg)} kg tento mesiac';
}

class Ranking {
  const Ranking({
    required this.position,
    required this.region,
    required this.topPercent,
    required this.gymName,
  });

  final int position;
  final String region;
  final int topPercent;
  final String gymName;
}

class NearbyGym {
  const NearbyGym({
    required this.name,
    required this.distanceKm,
    required this.occupancyPercent,
  });

  final String name;
  final double distanceKm;
  final int occupancyPercent;

  String get distanceLabel => '${distanceKm.toStringAsFixed(1)} km';
}

class PartnerRequest {
  const PartnerRequest({
    required this.name,
    required this.when,
    required this.focus,
  });

  final String name;
  final String when;
  final String focus;
}

String _seriesWord(int n) => switch (n) {
  1 => 'séria',
  >= 2 && <= 4 => 'série',
  _ => 'sérií',
};

String _trim(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString().replaceAll('.', ',');
