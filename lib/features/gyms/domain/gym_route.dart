import 'gym.dart';

/// Ako sa k fitku dostať: autom alebo pešo.
enum TravelMode {
  car('Auto', 'routed-car'),
  foot('Pešo', 'routed-foot');

  const TravelMode(this.label, this.profile);

  final String label;

  /// Názov profilu na smerovacom serveri OSRM.
  final String profile;
}

/// Trasa od polohy používateľa k fitku.
class GymRoute {
  const GymRoute({
    required this.points,
    required this.distanceKm,
    required this.duration,
  });

  final List<GeoPoint> points;
  final double distanceKm;
  final Duration duration;

  /// Prečíta odpoveď OSRM `/route` s `geometries=geojson`.
  /// Vráti null, keď server trasu nenašiel alebo poslal nezmysel.
  static GymRoute? fromOsrm(Object? json) {
    if (json is! Map || json['code'] != 'Ok') return null;
    final routes = json['routes'];
    if (routes is! List || routes.isEmpty) return null;
    final route = routes.first;
    if (route is! Map) return null;
    final distance = route['distance'];
    final seconds = route['duration'];
    final geometry = route['geometry'];
    if (distance is! num || seconds is! num || geometry is! Map) return null;
    final coordinates = geometry['coordinates'];
    if (coordinates is! List) return null;
    final points = <GeoPoint>[];
    for (final c in coordinates) {
      if (c is! List || c.length < 2) return null;
      final (lng, lat) = (c[0], c[1]);
      if (lng is! num || lat is! num) return null;
      if (lat.abs() > 90 || lng.abs() > 180) return null;
      points.add(GeoPoint(lat.toDouble(), lng.toDouble()));
    }
    if (points.length < 2) return null;
    return GymRoute(
      points: List.unmodifiable(points),
      distanceKm: distance / 1000,
      duration: Duration(seconds: seconds.round()),
    );
  }
}

/// „8 min“, „1 h 05 min“.
String formatTravelTime(Duration duration) {
  final minutes = (duration.inSeconds / 60).ceil().clamp(1, 1 << 30);
  if (minutes < 60) return '$minutes min';
  final rest = (minutes % 60).toString().padLeft(2, '0');
  return '${minutes ~/ 60} h $rest min';
}
