import 'package:health/health.dart';

/// Hodinky a náramky, ktoré zapisujú do Apple Health / Health Connect.
/// Rozpoznávajú sa podľa názvu zdroja, ID appky (bundle / package) alebo
/// ID zariadenia. Prvá zhoda vyhráva, preto sú konkrétne značky pred
/// všeobecným „watch“.
const _wearables = <(String, List<String>)>[
  ('Garmin', ['garmin', 'connectmobile']),
  ('Fitbit', ['fitbit']),
  ('Samsung Galaxy Watch', ['samsung', 'shealth', 'galaxy watch']),
  ('Polar', ['polar']),
  ('Whoop', ['whoop']),
  ('Oura', ['oura']),
  ('Amazfit', ['amazfit', 'zepp', 'huami']),
  ('Huawei', ['huawei']),
  ('Xiaomi', ['xiaomi', 'mi fitness', 'mi band', 'com.mi.health']),
  ('Withings', ['withings']),
  ('Coros', ['coros']),
  ('Suunto', ['suunto']),
  ('Wahoo', ['wahoo']),
  ('Pixel Watch', ['pixel watch']),
  ('Wear OS', ['google.android.apps.fitness', 'wear os', 'wearos']),
  ('Apple Watch', ['apple watch', 'watch']),
];

/// Názov hodiniek, z ktorých bod pochádza, alebo null (telefón, ručný zápis).
String? wearableName(HealthDataPoint p) {
  if (p.recordingMethod == RecordingMethod.manual) return null;
  final haystack = '${p.sourceName} ${p.sourceId} ${p.sourceDeviceId}'
      .toLowerCase();
  for (final (name, keys) in _wearables) {
    if (keys.any(haystack.contains)) return name;
  }
  return null;
}

bool isWearable(HealthDataPoint p) => wearableName(p) != null;
