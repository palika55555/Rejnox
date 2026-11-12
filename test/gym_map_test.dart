import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rejnox/core/theme/app_theme.dart';
import 'package:rejnox/features/gyms/application/user_location.dart';
import 'package:rejnox/features/gyms/data/gym_repository.dart';
import 'package:rejnox/features/gyms/domain/gym.dart';
import 'package:rejnox/features/gyms/presentation/globe_projection.dart';
import 'package:rejnox/features/gyms/presentation/gym_map_screen.dart';
import 'package:rejnox/features/gyms/presentation/map_style.dart';

import 'fakes.dart';

const _nitra = GeoPoint(48.3069, 18.0864);
const _bratislava = GeoPoint(48.1486, 17.1077);

Gym _gym(String id, String name, GeoPoint at) =>
    Gym(id: id, name: name, city: 'Mesto', location: at);

Future<void> _pump(
  WidgetTester tester,
  FakeLocationSource location, {
  FakeGymRepository? repository,
}) async {
  tester.view.physicalSize = const Size(390, 760);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      // Bez automatického opakovania – test riadi „Skúsiť znova“ sám.
      retry: (_, _) => null,
      overrides: [
        locationSourceProvider.overrideWithValue(location),
        mapTilesEnabledProvider.overrideWithValue(false),
        gymSessionTokenProvider.overrideWithValue('t'),
        gymRepositoryProvider.overrideWithValue(
          repository ??
              FakeGymRepository([
                _gym('far', 'Tokio Gym', const GeoPoint(35.68, 139.65)),
                _gym('ba', 'Bratislava Gym', _bratislava),
                _gym('nr', 'Nitra Gym', const GeoPoint(48.31, 18.09)),
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
}

void main() {
  group('vzdialenosti', () {
    test('Nitra – Bratislava je asi 75 km', () {
      expect(_nitra.distanceKmTo(_bratislava), closeTo(75, 3));
    });

    test('najbližšie fitká sú zoradené od najbližšieho', () {
      final result = nearestGyms([
        _gym('ba', 'BA', _bratislava),
        _gym('nr', 'NR', _nitra),
      ], const GeoPoint(48.30, 18.08));
      expect(result.map((r) => r.gym.id), ['nr', 'ba']);
      expect(
        nearestGyms(result.map((r) => r.gym), _nitra, limit: 1),
        hasLength(1),
      );
    });

    test('formát vzdialenosti', () {
      expect(formatDistance(0.843), '840 m');
      expect(formatDistance(1.26), '1,3 km');
      expect(formatDistance(38.4), '38 km');
      expect(formatDistance(8412), '8 412 km');
    });
  });

  group('zemeguľa', () {
    final frame = GlobeFrame(
      center: const Offset(100, 100),
      radius: 100,
      lat: 0,
      lng: 0,
    );

    test('stred pohľadu je v strede kruhu', () {
      expect(frame.toScreen(const GeoPoint(0, 0)), const Offset(100, 100));
    });

    test('sever je hore, východ vpravo', () {
      final north = frame.toScreen(const GeoPoint(45, 0))!;
      final east = frame.toScreen(const GeoPoint(0, 45))!;
      expect(north.dy, lessThan(100));
      expect(east.dx, greaterThan(100));
    });

    test('odvrátená strana nie je vidieť', () {
      expect(frame.toScreen(const GeoPoint(0, 180)), isNull);
    });

    test('otočenie ide najkratšou cestou cez dátumovú hranicu', () {
      expect(shortestLngDelta(170, -170), 20);
      expect(shortestLngDelta(-170, 170), -20);
      expect(normalizeLng(190), -170);
    });

    test('Mercator: rovník je v strede, sever hore', () {
      expect(mercatorY(0), closeTo(0.5, 1e-9));
      expect(mercatorY(60), lessThan(0.5));
    });
  });

  group('hľadanie', () {
    final gyms = [
      _gym('ke', 'Východ Fitness', const GeoPoint(48.7, 21.2)),
      _gym('ba', 'Danube Club', _bratislava),
    ];

    test('nájde bez diakritiky aj podľa mesta', () {
      expect(searchGyms(gyms, 'vychod').map((g) => g.id), ['ke']);
      expect(searchGyms(gyms, '  ').length, 2);
      expect(searchGyms(gyms, 'mesto').length, 2);
      expect(searchGyms(gyms, 'praha'), isEmpty);
    });

    test('mestá s počtom fitiek od najväčšieho', () {
      final cities = gymCities([
        _gym('a', 'A', _nitra).copyWithCity('Nitra'),
        _gym('b', 'B', _nitra).copyWithCity('Nitra'),
        _gym('c', 'C', _bratislava).copyWithCity('Bratislava'),
      ]);
      expect(cities.map((c) => (c.city, c.count)), [
        ('Nitra', 2),
        ('Bratislava', 1),
      ]);
    });
  });

  group('obrazovka mapy', () {
    Future<void> openMode(WidgetTester tester, String label) async {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    testWidgets('začína zemeguľou s počtom fitiek', (tester) async {
      await _pump(tester, FakeLocationSource());

      expect(
        find.bySemanticsLabel(RegExp('Zemeguľa s fitkami')),
        findsOneWidget,
      );
      // Odznak pri zemeguli aj karta mesta (všetky tri sú v „Mesto“).
      expect(find.text('3 fitká'), findsNWidgets(2));
      expect(find.text('v 1 meste'), findsOneWidget);
    });

    testWidgets('zoznam je zoradený od najbližšieho a dá sa hľadať', (
      tester,
    ) async {
      await _pump(tester, FakeLocationSource());
      await openMode(tester, 'Zoznam');

      final nitra = tester.getTopLeft(find.text('Nitra Gym'));
      final bratislava = tester.getTopLeft(find.text('Bratislava Gym'));
      expect(nitra.dy, lessThan(bratislava.dy));
      expect(find.textContaining('km'), findsWidgets);

      await tester.enterText(find.byType(TextField), 'tokio');
      await tester.pumpAndSettle();
      expect(find.text('Tokio Gym'), findsOneWidget);
      expect(find.text('Nitra Gym'), findsNothing);
    });

    testWidgets('mapa ukáže najbližšie fitko', (tester) async {
      await _pump(tester, FakeLocationSource());
      await openMode(tester, 'Mapa');

      expect(find.text('NAJBLIŽŠIE FITKO'), findsOneWidget);
      expect(find.text('Nitra Gym'), findsWidgets);
    });

    testWidgets('bez povolenia polohy ponúkne povolenie znova', (tester) async {
      final location = FakeLocationSource(
        const LocationUnavailable(LocationIssue.denied),
      );
      await _pump(tester, location);
      await openMode(tester, 'Zoznam');

      expect(find.textContaining('Bez povolenia polohy'), findsOneWidget);
      expect(find.textContaining(' km'), findsNothing);

      location.result = const LocationFound(_nitra);
      await tester.tap(find.text('Povoliť'));
      await tester.pumpAndSettle();

      expect(location.calls, 2);
      expect(find.textContaining('Bez povolenia polohy'), findsNothing);
      expect(find.textContaining(' km'), findsWidgets);
    });

    testWidgets('keď server neodpovedá, ponúkne Skúsiť znova', (tester) async {
      final repository = FakeGymRepository([_gym('nr', 'Nitra Gym', _nitra)])
        ..fail = true;
      await _pump(tester, FakeLocationSource(), repository: repository);

      expect(
        find.textContaining('Fitká sa nepodarilo načítať'),
        findsOneWidget,
      );

      repository.fail = false;
      await tester.tap(find.text('Skúsiť znova'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Fitká sa nepodarilo načítať'), findsNothing);
      expect(find.text('1 fitko'), findsWidgets);
    });

    testWidgets('zakázanú polohu otvorí v nastaveniach', (tester) async {
      final location = FakeLocationSource(
        const LocationUnavailable(LocationIssue.deniedForever),
      );
      await _pump(tester, location);

      await tester.tap(find.text('Nastavenia'));
      await tester.pumpAndSettle();

      expect(location.opened, [LocationIssue.deniedForever]);
    });
  });
}

extension on Gym {
  Gym copyWithCity(String city) =>
      Gym(id: id, name: name, city: city, location: location);
}
