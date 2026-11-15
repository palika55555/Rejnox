import '../../training/domain/training_models.dart';

double _num(Object? v) => (v as num?)?.toDouble() ?? 0;

/// Jeden týždeň v grafe objemu (začína pondelkom).
class WeekStat {
  const WeekStat({
    required this.start,
    required this.days,
    required this.sets,
    required this.volumeKg,
  });

  factory WeekStat.fromJson(Map<String, dynamic> json) => WeekStat(
    start: DateTime.parse(json['start'] as String),
    days: json['days'] as int,
    sets: json['sets'] as int,
    volumeKg: _num(json['volumeKg']),
  );

  final DateTime start;
  final int days;
  final int sets;
  final double volumeKg;
}

/// Najťažšia séria cviku v jeden deň.
class TrendPoint {
  const TrendPoint(this.day, this.kg);

  final DateTime day;
  final double kg;
}

/// Ako sa darí jednému cviku.
class ExerciseProgress {
  const ExerciseProgress({
    required this.exerciseId,
    required this.name,
    required this.group,
    required this.bestKg,
    required this.bestE1rmKg,
    required this.firstKg,
    required this.lastDay,
    required this.days,
    required this.trend,
  });

  factory ExerciseProgress.fromJson(Map<String, dynamic> json) =>
      ExerciseProgress(
        exerciseId: json['exerciseId'] as String,
        name: json['name'] as String,
        group: json['muscleGroup'] == null
            ? null
            : MuscleGroup.fromApi(json['muscleGroup']),
        bestKg: _num(json['bestKg']),
        bestE1rmKg: (json['bestE1rmKg'] as num?)?.toDouble(),
        firstKg: _num(json['firstKg']),
        lastDay: DateTime.parse(json['lastDay'] as String),
        days: json['days'] as int,
        trend: [
          for (final p in json['trend'] as List)
            TrendPoint(
              DateTime.parse((p as Map<String, dynamic>)['day'] as String),
              _num(p['kg']),
            ),
        ],
      );

  final String exerciseId;
  final String name;
  final MuscleGroup? group;
  final double bestKg;

  /// Odhad maxima na 1 opakovanie (len zo sérií do 12 opakovaní).
  final double? bestE1rmKg;

  /// Najťažšia séria v prvý deň, keď bol cvik odcvičený.
  final double firstKg;
  final DateTime lastDay;

  /// Počet dní, keď bol cvik odcvičený.
  final int days;
  final List<TrendPoint> trend;

  /// O koľko sa rekord zlepšil od prvého tréningu.
  double get gainKg => bestKg - firstKg;
}

/// Celý prehľad progresu zo servera (GET /progress).
class ProgressOverview {
  const ProgressOverview({
    required this.trainingDays,
    required this.totalSets,
    required this.totalVolumeKg,
    required this.monthDays,
    required this.monthSets,
    required this.monthVolumeKg,
    required this.prevMonthVolumeKg,
    required this.weeks,
    required this.exercises,
    required this.muscles,
  });

  factory ProgressOverview.fromJson(Map<String, dynamic> json) {
    final totals = json['totals'] as Map<String, dynamic>;
    final month = json['month'] as Map<String, dynamic>;
    return ProgressOverview(
      trainingDays: totals['trainingDays'] as int,
      totalSets: totals['sets'] as int,
      totalVolumeKg: _num(totals['volumeKg']),
      monthDays: month['days'] as int,
      monthSets: month['sets'] as int,
      monthVolumeKg: _num(month['volumeKg']),
      prevMonthVolumeKg: _num(month['prevVolumeKg']),
      weeks: [
        for (final w in json['weeks'] as List)
          WeekStat.fromJson(w as Map<String, dynamic>),
      ],
      exercises: [
        for (final e in json['exercises'] as List)
          ExerciseProgress.fromJson(e as Map<String, dynamic>),
      ],
      muscles: [
        for (final m in json['muscles'] as List)
          (
            group: MuscleGroup.fromApi(
              (m as Map<String, dynamic>)['muscleGroup'],
            ),
            sets: m['sets'] as int,
          ),
      ],
    );
  }

  final int trainingDays;
  final int totalSets;
  final double totalVolumeKg;

  /// Posledných 30 dní.
  final int monthDays;
  final int monthSets;
  final double monthVolumeKg;

  /// Objem v 30 dňoch pred tým (na porovnanie).
  final double prevMonthVolumeKg;

  /// Posledných 12 týždňov, najstarší prvý.
  final List<WeekStat> weeks;

  /// Naposledy odcvičené hore.
  final List<ExerciseProgress> exercises;

  /// Série na partiu za posledných 30 dní, najviac hore.
  final List<({MuscleGroup group, int sets})> muscles;

  bool get isEmpty => totalSets == 0;

  /// Zmena objemu oproti predošlým 30 dňom v percentách
  /// (null = nie je s čím porovnať).
  int? get monthVolumeChangePercent => prevMonthVolumeKg <= 0
      ? null
      : ((monthVolumeKg - prevMonthVolumeKg) / prevMonthVolumeKg * 100).round();
}
