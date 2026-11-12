import 'dart:math';

import 'package:flutter/material.dart';

/// Jedno meranie tepu.
class HrSample {
  const HrSample(this.at, this.bpm);

  final DateTime at;
  final double bpm;
}

/// História tepu za zvolené obdobie + doplnkové údaje.
class HeartRateHistory {
  const HeartRateHistory({required this.samples, this.hrvMs, this.restingBpm});

  /// Zoradené od najstaršieho.
  final List<HrSample> samples;
  final double? hrvMs;
  final double? restingBpm;

  HrSample? get latest => samples.isEmpty ? null : samples.last;
}

class HrStats {
  const HrStats({required this.min, required this.avg, required this.max});

  final double min;
  final double avg;
  final double max;
}

HrStats? heartRateStats(List<HrSample> samples) {
  if (samples.isEmpty) return null;
  var lo = double.infinity, hi = 0.0, sum = 0.0;
  for (final s in samples) {
    lo = min(lo, s.bpm);
    hi = max(hi, s.bpm);
    sum += s.bpm;
  }
  return HrStats(min: lo, avg: sum / samples.length, max: hi);
}

enum HrZone {
  max('Maximálna', '90–100 %', Color(0xFFFF4D6A), 0.9),
  high('Vysoká', '80–90 %', Color(0xFFFF8A3D), 0.8),
  aerobic('Aeróbna', '70–80 %', Color(0xFFFFC542), 0.7),
  fatBurn('Spaľovanie tukov', '60–70 %', Color(0xFF2BD9B0), 0.6),
  rest('Pokojová', '< 60 %', Color(0xFF4D8BFF), 0);

  const HrZone(this.label, this.range, this.color, this.fromFraction);

  final String label;
  final String range;
  final Color color;
  final double fromFraction;

  static HrZone of(double bpm, double maxHr) {
    final f = bpm / maxHr;
    return values.firstWhere((z) => f >= z.fromFraction);
  }
}

/// Predvolený maximálny tep, kým nepoznáme vek (vzorec 220 − vek pre ~30 r.).
const defaultMaxHr = 190.0;

/// Čas strávený v jednotlivých zónach. Každé meranie platí do ďalšieho,
/// najviac však [cap] (medzery bez meraní sa nezapočítajú).
Map<HrZone, Duration> zoneDurations(
  List<HrSample> samples, {
  double maxHr = defaultMaxHr,
  Duration cap = const Duration(minutes: 10),
}) {
  final result = {for (final z in HrZone.values) z: Duration.zero};
  for (var i = 0; i < samples.length; i++) {
    final next = i + 1 < samples.length ? samples[i + 1].at : null;
    var span = next == null
        ? const Duration(minutes: 1)
        : next.difference(samples[i].at);
    if (span > cap) span = cap;
    if (span.isNegative) continue;
    final zone = HrZone.of(samples[i].bpm, maxHr);
    result[zone] = result[zone]! + span;
  }
  return result;
}

/// Štítok merania do zoznamu „Posledné merania“.
String measurementTag(HrSample s, {double? restingBpm}) {
  final rest = restingBpm ?? 65;
  if (s.bpm >= max(100, rest + 35)) return 'Tréning';
  if (s.at.hour >= 5 && s.at.hour < 9 && s.bpm <= rest + 10) {
    return 'Po prebudení';
  }
  return 'Pokoj';
}

/// Priemer tepu po dňoch (pre Trendy), zoradené od najstaršieho dňa.
List<HrSample> dailyAverages(List<HrSample> samples) {
  final byDay = <DateTime, List<double>>{};
  for (final s in samples) {
    final day = DateTime(s.at.year, s.at.month, s.at.day);
    (byDay[day] ??= []).add(s.bpm);
  }
  final days = byDay.keys.toList()..sort();
  return [
    for (final d in days)
      HrSample(d, byDay[d]!.reduce((a, b) => a + b) / byDay[d]!.length),
  ];
}

/// Ukážková história pre web (náhľad dizajnu), nie skutočné údaje.
HeartRateHistory demoHistory(DateTime now, Duration window) {
  final rnd = Random(7);
  final samples = <HrSample>[];
  final start = now.subtract(window);
  final step = window.inHours <= 24
      ? const Duration(minutes: 10)
      : const Duration(minutes: 60);
  for (var t = start; t.isBefore(now); t = t.add(step)) {
    final h = t.hour + t.minute / 60;
    var bpm = 62 + 10 * sin((h - 6) / 24 * 2 * pi) + rnd.nextDouble() * 8;
    if (h > 6.5 && h < 9) bpm -= 4;
    if (h > 17 && h < 18.2) bpm = 105 + rnd.nextDouble() * 35; // tréning
    if (h < 6) bpm = 54 + rnd.nextDouble() * 6; // spánok
    samples.add(HrSample(t, bpm));
  }
  return HeartRateHistory(samples: samples, hrvMs: 62, restingBpm: 58);
}
