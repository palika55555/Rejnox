import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';

import 'health_platform.dart';
import 'heart_rate_service.dart';

/// Typy, ktoré Rejnox z Apple Health / Health Connect číta (len čítanie).
const healthReadTypes = [
  HealthDataType.HEART_RATE,
  HealthDataType.RESTING_HEART_RATE,
  HealthDataType.HEART_RATE_VARIABILITY_SDNN, // iPhone
  HealthDataType.HEART_RATE_VARIABILITY_RMSSD, // Android
  HealthDataType.STEPS,
  HealthDataType.WEIGHT,
  HealthDataType.ACTIVE_ENERGY_BURNED,
  HealthDataType.SLEEP_ASLEEP,
  HealthDataType.SLEEP_LIGHT,
  HealthDataType.SLEEP_DEEP,
  HealthDataType.SLEEP_REM,
];

const _sleepTypes = {
  HealthDataType.SLEEP_ASLEEP,
  HealthDataType.SLEEP_LIGHT,
  HealthDataType.SLEEP_DEEP,
  HealthDataType.SLEEP_REM,
};

/// Prehľad zdravotných údajov pre sekciu Zdravie.
class HealthSummary {
  const HealthSummary({
    this.heartRate,
    this.restingBpm,
    this.steps,
    this.activeKcal,
    this.sleep,
    this.weightKg,
  });

  final HeartRateReading? heartRate;
  final double? restingBpm;
  final int? steps;
  final double? activeKcal;
  final Duration? sleep;
  final double? weightKg;

  bool get isEmpty =>
      heartRate == null &&
      restingBpm == null &&
      steps == null &&
      activeKcal == null &&
      sleep == null &&
      weightKg == null;
}

double? _num(HealthDataPoint p) => p.value is NumericHealthValue
    ? (p.value as NumericHealthValue).numericValue.toDouble()
    : null;

/// Okno poslednej noci: od 18:00 predchádzajúceho dňa do 12:00.
({DateTime from, DateTime to}) lastNight(DateTime now) {
  final noon = DateTime(now.year, now.month, now.day, 12);
  return (from: noon.subtract(const Duration(hours: 18)), to: noon);
}

/// Zostaví prehľad z bodov Apple Health (čistá funkcia, dá sa testovať).
HealthSummary summarize(
  List<HealthDataPoint> points, {
  required DateTime now,
  int? steps,
}) {
  final midnight = DateTime(now.year, now.month, now.day);

  // Najnovší tep: prednostne z hodiniek, inak akékoľvek automatické meranie.
  final heartRate =
      pickLatestWatchReading(points) ?? _latestAutomaticHeartRate(points);

  final resting =
      points.where((p) => p.type == HealthDataType.RESTING_HEART_RATE).toList()
        ..sort((a, b) => b.dateTo.compareTo(a.dateTo));

  final kcal = points
      .where(
        (p) =>
            p.type == HealthDataType.ACTIVE_ENERGY_BURNED &&
            !p.dateFrom.isBefore(midnight),
      )
      .map(_num)
      .whereType<double>()
      .fold<double>(0, (a, b) => a + b);
  final hasKcal = points.any(
    (p) => p.type == HealthDataType.ACTIVE_ENERGY_BURNED,
  );

  final weight = points.where((p) => p.type == HealthDataType.WEIGHT).toList()
    ..sort((a, b) => b.dateTo.compareTo(a.dateTo));

  final night = lastNight(now);
  final sleepMinutes = points
      .where(
        (p) =>
            _sleepTypes.contains(p.type) &&
            !p.dateFrom.isBefore(night.from) &&
            !p.dateFrom.isAfter(night.to),
      )
      .map(_num)
      .whereType<double>()
      .fold<double>(0, (a, b) => a + b);

  return HealthSummary(
    heartRate: heartRate,
    restingBpm: resting.isEmpty ? null : _num(resting.first),
    steps: steps,
    activeKcal: hasKcal ? kcal : null,
    sleep: sleepMinutes > 0 ? Duration(minutes: sleepMinutes.round()) : null,
    weightKg: weight.isEmpty ? null : _num(weight.first),
  );
}

HeartRateReading? _latestAutomaticHeartRate(List<HealthDataPoint> points) {
  final hr =
      points
          .where(
            (p) =>
                p.type == HealthDataType.HEART_RATE &&
                p.recordingMethod != RecordingMethod.manual &&
                p.value is NumericHealthValue,
          )
          .toList()
        ..sort((a, b) => b.dateTo.compareTo(a.dateTo));
  if (hr.isEmpty) return null;
  return HeartRateReading(
    bpm: _num(hr.first)!,
    measuredAt: hr.first.dateTo,
    source: hr.first.sourceName,
  );
}

/// Zdroj prehľadu zdravia. Dá sa nahradiť v testoch.
abstract interface class HealthSummarySource {
  bool get supported;
  Future<bool> requestAccess();
  Future<HealthSummary> load();
}

class AppleHealthSummary implements HealthSummarySource {
  final _health = Health();
  Future<void>? _configured;

  @override
  bool get supported => healthPlatformSupported;

  Future<void> _init() {
    if (!supported) {
      throw UnsupportedError('Zdravotné údaje sú len na iPhone a Androide.');
    }
    return _configured ??= _health.configure();
  }

  List<HealthDataType> get _types => availableTypes(_health, healthReadTypes);

  @override
  Future<bool> requestAccess() async {
    await _init();
    if (!await ensureHealthStore(_health)) return false;
    final types = _types;
    return _health.requestAuthorization(
      types,
      permissions: [for (final _ in types) HealthDataAccess.READ],
    );
  }

  @override
  Future<HealthSummary> load() async {
    await _init();
    final now = DateTime.now();
    final types = _types;
    final points = await _health.getHealthDataFromTypes(
      types: types
          .where((t) => t != HealthDataType.STEPS && t != HealthDataType.WEIGHT)
          .toList(),
      startTime: now.subtract(const Duration(days: 7)),
      endTime: now,
    );
    // Váha sa meria zriedka, posledná hodnota za 90 dní.
    final weight = types.contains(HealthDataType.WEIGHT)
        ? await _health.getHealthDataFromTypes(
            types: [HealthDataType.WEIGHT],
            startTime: now.subtract(const Duration(days: 90)),
            endTime: now,
          )
        : const <HealthDataPoint>[];
    final steps = await _health.getTotalStepsInInterval(
      DateTime(now.year, now.month, now.day),
      now,
    );
    return summarize(
      _health.removeDuplicates([...points, ...weight]),
      now: now,
      steps: steps,
    );
  }
}

final healthSummarySourceProvider = Provider<HealthSummarySource>(
  (ref) => AppleHealthSummary(),
);
