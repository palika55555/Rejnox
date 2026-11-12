import 'dart:math' as math;
import 'dart:ui';

import '../domain/gym.dart';

/// Ortografická projekcia zemegule: pohľad z vesmíru na bod (lat, lng).
class GlobeFrame {
  GlobeFrame({
    required this.center,
    required this.radius,
    required double lat,
    required double lng,
  }) : _sinLat0 = math.sin(lat * _rad),
       _cosLat0 = math.cos(lat * _rad),
       _lng0 = lng;

  static const _rad = math.pi / 180;

  final Offset center;
  final double radius;
  final double _sinLat0;
  final double _cosLat0;
  final double _lng0;

  /// Súradnice na jednotkovej guli. `z < 0` = odvrátená strana.
  ({double x, double y, double z}) unit(double lat, double lng) {
    final phi = lat * _rad;
    final dLambda = (lng - _lng0) * _rad;
    final cosPhi = math.cos(phi);
    final sinPhi = math.sin(phi);
    final cosD = math.cos(dLambda);
    return (
      x: cosPhi * math.sin(dLambda),
      y: _cosLat0 * sinPhi - _sinLat0 * cosPhi * cosD,
      z: _sinLat0 * sinPhi + _cosLat0 * cosPhi * cosD,
    );
  }

  Offset screenOf(double x, double y) =>
      Offset(center.dx + radius * x, center.dy - radius * y);

  /// Poloha bodu na obrazovke alebo null, ak je na odvrátenej strane.
  Offset? toScreen(GeoPoint point) {
    final u = unit(point.lat, point.lng);
    return u.z < 0 ? null : screenOf(u.x, u.y);
  }
}

/// Zemepisnú dĺžku prevedie do rozsahu −180…180.
double normalizeLng(double lng) => (lng + 180) % 360 - 180;

/// Najkratšie otočenie z [from] na [to] v stupňoch (cez dátumovú hranicu).
double shortestLngDelta(double from, double to) => normalizeLng(to - from);

/// Webová Mercatorova súradnica Y (0 = sever, 1 = juh) pre dlaždice mapy.
double mercatorY(double lat) {
  final phi = lat.clamp(-85.0511, 85.0511) * math.pi / 180;
  return (1 - math.log(math.tan(phi) + 1 / math.cos(phi)) / math.pi) / 2;
}
