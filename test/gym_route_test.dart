import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rejnox/core/theme/app_theme.dart';
import 'package:rejnox/features/gyms/application/gym_actions.dart';
import 'package:rejnox/features/gyms/application/user_location.dart';
import 'package:rejnox/features/gyms/data/gym_repository.dart';
import 'package:rejnox/features/gyms/data/route_source.dart';
import 'package:rejnox/features/gyms/domain/gym.dart';
import 'package:rejnox/features/gyms/domain/gym_route.dart';
import 'package:rejnox/features/gyms/presentation/gym_map_screen.dart';
import 'package:rejnox/features/gyms/presentation/map_style.dart';

import 'fakes.dart';

class _FakeRouteSource implements RouteSource {
  final modes = <TravelMode>[];
  bool fail = false;

  @override
  Future<GymRoute?> route(GeoPoint from, GeoPoint to, TravelMode mode) async {
    modes.add(mode);
    if (fail) throw Exception('offline');
    return GymRoute(
      points: [from, to],
      distanceKm: mode == TravelMode.car ? 2.4 : 1.8,
      duration: Duration(minutes: mode == TravelMode.car ? 7 : 23),
    );
  }
}

Map<String, Object?> _osrm({String code = 'Ok'}) => {
  'code': code,
  'routes': [
    {
      'distance': 2412.5,
      'duration': 431.0,
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          [18.08, 48.30],
          [18.085, 48.305],
          [18.09, 48.31],
        ],
      },
    },
  ],
};

Future<(_FakeRouteSource, FakeExternalActions)> _pump(
  WidgetTester tester, {
  UserLocation location = const LocationFound(GeoPoint(48.3, 18.08)),
}) async {
  tester.view.physicalSize = const Size(390, 760);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final routes = _FakeRouteSource();
  final external = FakeExternalActions();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        locationSourceProvider.overrideWithValue(FakeLocationSource(location)),
        mapTilesEnabledProvider.overrideWithValue(false),
        gymSessionTokenProvider.overrideWithValue('t'),
        routeSourceProvider.overrideWithValue(routes),
        externalActionsProvider.overrideWithValue(external),
        gymRepositoryProvider.overrideWithValue(
          FakeGymRepository([
            const Gym(
              id: 'nr',
              name: 'Nitra Gym',
              city: 'Nitra',
              location: GeoPoint(48.31, 18.09),
            ),
          ]),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(webFonts: false),
        home: const Scaffold(body: GymMapScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Mapa'));
  await tester.pumpAndSettle();
  return (routes, external);
}

void main() {
  group('trasa z OSRM', () {
    test('prečíta body, vzdialenosť a čas', () {
      final route = GymRoute.fromOsrm(_osrm())!;
      expect(route.points, hasLength(3));
      expect(route.points.first.lat, 48.30);
      expect(route.points.first.lng, 18.08);
      expect(route.distanceKm, closeTo(2.41, 0.01));
      expect(route.duration, const Duration(seconds: 431));
    });

    test('bez trasy alebo s nezmyslom vráti null', () {
      expect(GymRoute.fromOsrm(_osrm(code: 'NoRoute')), isNull);
      expect(GymRoute.fromOsrm(null), isNull);
      expect(GymRoute.fromOsrm({'code': 'Ok', 'routes': []}), isNull);
      final broken = _osrm();
      ((broken['routes']! as List).first as Map)['geometry'] = {
        'coordinates': [
          [18.0, 120.0],
          [18.1, 48.0],
        ],
      };
      expect(GymRoute.fromOsrm(broken), isNull);
    });

    test('formát času cesty', () {
      expect(formatTravelTime(const Duration(seconds: 20)), '1 min');
      expect(formatTravelTime(const Duration(seconds: 431)), '8 min');
      expect(formatTravelTime(const Duration(minutes: 65)), '1 h 05 min');
    });
  });

  group('navigácia na mape', () {
    final navButton = find.byTooltip('Trasa k fitku');

    testWidgets('ukáže trasu autom a prepne na pešo', (tester) async {
      final (routes, _) = await _pump(tester);

      await tester.tap(navButton);
      await tester.pumpAndSettle();
      expect(find.text('2,4 km · 7 min'), findsOneWidget);
      expect(routes.modes, [TravelMode.car]);

      await tester.tap(find.text('Pešo'));
      await tester.pumpAndSettle();
      expect(find.text('1,8 km · 23 min'), findsOneWidget);
      expect(routes.modes, [TravelMode.car, TravelMode.foot]);

      await tester.tap(find.byTooltip('Zrušiť trasu'));
      await tester.pumpAndSettle();
      expect(find.textContaining('min'), findsNothing);
      expect(navButton, findsOneWidget);
    });

    testWidgets('druhé ťuknutie spustí navigáciu v Mapách', (tester) async {
      final (_, external) = await _pump(tester);

      await tester.tap(navButton);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Spustiť navigáciu'));
      await tester.pumpAndSettle();

      expect(external.opened, hasLength(1));
      expect(external.opened.single.toString(), contains('48.31'));
    });

    testWidgets('bez siete ukáže chybu', (tester) async {
      final (routes, _) = await _pump(tester);
      routes.fail = true;

      await tester.tap(navButton);
      await tester.pumpAndSettle();
      expect(find.textContaining('Skontroluj pripojenie'), findsOneWidget);
    });
  });
}
