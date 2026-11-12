import '../../../core/theme/app_colors.dart';

/// Všetko, čo potrebuje domovská obrazovka klienta.
class HomeOverview {
  const HomeOverview({
    required this.userName,
    required this.streakDays,
    required this.weeklyGoal,
    required this.todayWorkout,
    required this.personalRecord,
    required this.ranking,
    required this.nearbyGym,
    required this.partnerRequest,
  });

  final String userName;
  final int streakDays;
  final WeeklyGoal weeklyGoal;
  final Workout? todayWorkout;
  final PersonalRecord personalRecord;
  final Ranking ranking;
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
    required this.minutes,
    required this.kcal,
    required this.exercises,
  });

  final String title;
  final String? trainerName;
  final int minutes;
  final int kcal;
  final List<Exercise> exercises;
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
  });

  final String name;
  final String shortName;
  final int sets;
  final int reps;
  final double weightKg;
  final String note;
  final Plate plate;
  final bool isPr;

  String get scheme => '$sets×$reps';
  String get weightLabel => '${_trim(weightKg)} kg';
}

class PersonalRecord {
  const PersonalRecord({
    required this.exercise,
    required this.weightKg,
    required this.monthDeltaKg,
    required this.trend,
  });

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

String _trim(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString().replaceAll('.', ',');
