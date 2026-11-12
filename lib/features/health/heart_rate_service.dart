import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';

import 'health_platform.dart';
import 'heart_rate_stats.dart';

class HeartRateReading {
  const HeartRateReading({
    required this.bpm,
    required this.measuredAt,
    required this.source,
  });

  final double bpm;
  final DateTime measuredAt;
  final String source;
}

/// Zdroj srdcového tepu. Dá sa nahradiť v testoch.
abstract interface class HeartRateSource {
  /// Apple Health je len na iPhone.
  bool get supported;

  /// Vypýta povolenie len na čítanie tepu.
  Future<bool> requestPermission();

  /// Najnovšie meranie z Apple Watch za posledných 24 hodín.
  Future<HeartRateReading?> latest();

  /// Merania tepu za posledné [window] + HRV a pokojový tep.
  Future<HeartRateHistory> history(Duration window);
}

/// Typy pre obrazovku tepu (len čítanie).
const heartRateReadTypes = [
  HealthDataType.HEART_RATE,
  HealthDataType.RESTING_HEART_RATE,
  HealthDataType.HEART_RATE_VARIABILITY_SDNN, // iPhone
  HealthDataType.HEART_RATE_VARIABILITY_RMSSD, // Android
];

double? _value(HealthDataPoint p) => p.value is NumericHealthValue
    ? (p.value as NumericHealthValue).numericValue.toDouble()
    : null;

/// Z bodov Apple Health zostaví históriu tepu (čistá funkcia).
HeartRateHistory buildHistory(List<HealthDataPoint> points, DateTime from) {
  final samples = <HrSample>[];
  HealthDataPoint? hrv, resting;
  for (final p in points) {
    final v = _value(p);
    if (v == null) continue;
    switch (p.type) {
      case HealthDataType.HEART_RATE
          when p.recordingMethod != RecordingMethod.manual &&
              !p.dateTo.isBefore(from):
        samples.add(HrSample(p.dateTo, v));
      case HealthDataType.HEART_RATE_VARIABILITY_SDNN ||
              HealthDataType.HEART_RATE_VARIABILITY_RMSSD
          when hrv == null || p.dateTo.isAfter(hrv.dateTo):
        hrv = p;
      case HealthDataType.RESTING_HEART_RATE
          when resting == null || p.dateTo.isAfter(resting.dateTo):
        resting = p;
      default:
        break;
    }
  }
  samples.sort((a, b) => a.at.compareTo(b.at));
  return HeartRateHistory(
    samples: samples,
    hrvMs: hrv == null ? null : _value(hrv),
    restingBpm: resting == null ? null : _value(resting),
  );
}

/// Vyberie najnovšie automatické meranie tepu z Apple Watch.
///
/// Pozor: `sourceName` a `sourceDeviceId` nie sú spoľahlivá identifikácia
/// zariadenia, filter môže niektoré platné merania vynechať. Spoľahlivé
/// rozlíšenie Apple Watch by vyžadovalo natívny HealthKit dotaz (HKDevice).
HeartRateReading? pickLatestWatchReading(List<HealthDataPoint> points) {
  final watch = points.where((p) {
    final source = p.sourceName.toLowerCase();
    final device = p.sourceDeviceId.toLowerCase();
    return p.type == HealthDataType.HEART_RATE &&
        p.recordingMethod != RecordingMethod.manual &&
        p.value is NumericHealthValue &&
        (source.contains('watch') || device.contains('watch'));
  }).toList();
  if (watch.isEmpty) return null;

  watch.sort((a, b) => b.dateTo.compareTo(a.dateTo));
  final latest = watch.first;
  return HeartRateReading(
    bpm: (latest.value as NumericHealthValue).numericValue.toDouble(),
    measuredAt: latest.dateTo,
    source: latest.sourceName,
  );
}

class AppleHealthHeartRate implements HeartRateSource {
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

  List<HealthDataType> get _types =>
      availableTypes(_health, heartRateReadTypes);

  @override
  Future<bool> requestPermission() async {
    await _init();
    if (!await ensureHealthStore(_health)) return false;
    final types = _types;
    return _health.requestAuthorization(
      types,
      permissions: [for (final _ in types) HealthDataAccess.READ],
    );
  }

  @override
  Future<HeartRateHistory> history(Duration window) async {
    await _init();
    final now = DateTime.now();
    final from = now.subtract(window);
    // HRV a pokojový tep stačí z posledného týždňa.
    final extraFrom = window < const Duration(days: 7)
        ? now.subtract(const Duration(days: 7))
        : from;
    final points = await _health.getHealthDataFromTypes(
      types: _types,
      startTime: extraFrom,
      endTime: now,
    );
    return buildHistory(_health.removeDuplicates(points), from);
  }

  @override
  Future<HeartRateReading?> latest() async {
    await _init();
    final now = DateTime.now();
    final points = await _health.getHealthDataFromTypes(
      types: [HealthDataType.HEART_RATE],
      startTime: now.subtract(const Duration(hours: 24)),
      endTime: now,
    );
    return pickLatestWatchReading(_health.removeDuplicates(points));
  }
}

final heartRateSourceProvider = Provider<HeartRateSource>(
  (ref) => AppleHealthHeartRate(),
);
