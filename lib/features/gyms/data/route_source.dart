import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../domain/gym.dart';
import '../domain/gym_route.dart';

/// Hľadá trasu medzi dvoma bodmi (v testoch sa nahradí).
abstract interface class RouteSource {
  /// Vráti null, keď sa trasa nedá nájsť. Pri chybe siete hodí výnimku.
  Future<GymRoute?> route(GeoPoint from, GeoPoint to, TravelMode mode);
}

/// Bezplatný smerovací server FOSSGIS nad OpenStreetMap
/// (ten istý používa openstreetmap.org). Žiadny kľúč netreba.
class OsrmRouteSource implements RouteSource {
  OsrmRouteSource({http.Client? client}) : _client = client ?? http.Client();

  static const _host = 'routing.openstreetmap.de';
  static const _timeout = Duration(seconds: 12);

  final http.Client _client;

  @override
  Future<GymRoute?> route(GeoPoint from, GeoPoint to, TravelMode mode) async {
    final path =
        '/${mode.profile}/route/v1/driving/'
        '${from.lng},${from.lat};${to.lng},${to.lat}';
    final url = Uri.https(_host, path, {
      'overview': 'full',
      'geometries': 'geojson',
    });
    final response = await _client.get(url).timeout(_timeout);
    if (response.statusCode == 400) return null;
    if (response.statusCode != 200) {
      throw http.ClientException('Trasa: HTTP ${response.statusCode}', url);
    }
    return GymRoute.fromOsrm(jsonDecode(response.body));
  }
}

final routeSourceProvider = Provider<RouteSource>((ref) => OsrmRouteSource());
