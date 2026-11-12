import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rejnox/core/theme/app_theme.dart';
import 'package:rejnox/features/gyms/application/gym_actions.dart';
import 'package:rejnox/features/gyms/application/user_location.dart';
import 'package:rejnox/features/gyms/data/gym_repository.dart';
import 'package:rejnox/features/gyms/domain/gym.dart';
import 'package:rejnox/features/gyms/presentation/gym_detail_screen.dart';
import 'package:rejnox/features/gyms/presentation/gym_map_screen.dart';
import 'package:rejnox/features/gyms/presentation/map_style.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

const _gym = Gym(
  id: 'g1',
  name: 'Gym Fit Nitra',
  city: 'Nitra',
  location: GeoPoint(48.3076, 18.0845),
  openingHours: 'Nonstop',
  tags: ['Silový tréning', 'Kardio'],
  rating: GymRating(stars: [3, 2, 9, 41, 112]),
);

const _bare = Gym(
  id: 'g2',
  name: 'Nové fitko',
  city: 'Žilina',
  location: GeoPoint(49.22, 18.74),
);

Future<FakeExternalActions> _pump(
  WidgetTester tester, {
  String location = '/gym/g1',
  FakeGymRepository? repository,
}) async {
  repository ??= FakeGymRepository([_gym, _bare]);
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final actions = FakeExternalActions();
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/map',
        builder: (_, _) => const Scaffold(body: GymMapScreen()),
      ),
      GoRoute(
        path: '/gym/:id',
        builder: (_, state) =>
            GymDetailScreen(gymId: state.pathParameters['id']!),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gymRepositoryProvider.overrideWithValue(repository),
        gymSessionTokenProvider.overrideWithValue('t'),
        locationSourceProvider.overrideWithValue(FakeLocationSource()),
        mapTilesEnabledProvider.overrideWithValue(false),
        externalActionsProvider.overrideWithValue(actions),
      ],
      child: MaterialApp.router(
        theme: AppTheme.dark(webFonts: false),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return actions;
}

void main() {
  group('hodnotenie', () {
    const rating = GymRating(stars: [3, 2, 9, 41, 112]);

    test('priemer, počet a podiely', () {
      expect(rating.count, 167);
      expect(rating.averageLabel, '4,5');
      expect(rating.share(5), closeTo(112 / 167, 1e-9));
    });

    test('skloňovanie recenzií', () {
      String label(int n) => GymRating(stars: [0, 0, 0, 0, n]).countLabel;
      expect(label(1), '1 recenzia');
      expect(label(3), '3 recenzie');
      expect(label(5), '5 recenzií');
    });
  });

  test('navigácia: na iPhone Apple Mapy, inde Google Mapy', () {
    expect(
      navigationUrl(_gym, platform: TargetPlatform.iOS).host,
      'maps.apple.com',
    );
    final google = navigationUrl(_gym, platform: TargetPlatform.android);
    expect(google.host, 'www.google.com');
    expect(google.queryParameters['destination'], '48.3076,18.0845');
  });

  testWidgets('detail ukáže hodnotenie, hodiny a zameranie', (tester) async {
    await _pump(tester);

    expect(find.text('Gym Fit Nitra'), findsOneWidget);
    expect(find.text('4,5 (167 recenzií)'), findsOneWidget);
    expect(find.text('Otvorené nonstop'), findsOneWidget);
    expect(find.text('Silový tréning  •  Kardio'), findsOneWidget);
    expect(find.text('Hodnotenie'), findsOneWidget);
    // Fitko bez webu nemá tlačidlo Web.
    expect(find.text('Web'), findsNothing);
  });

  testWidgets('Navigovať otvorí mapy, Zdieľať pošle odkaz', (tester) async {
    final actions = await _pump(tester);

    await tester.tap(find.text('Navigovať'));
    await tester.pumpAndSettle();
    expect(
      actions.opened.single.queryParameters['destination'],
      '48.3076,18.0845',
    );

    await tester.tap(find.text('Zdieľať'));
    await tester.pumpAndSettle();
    expect(actions.shared.single, contains('Gym Fit Nitra'));
  });

  testWidgets('keď sa mapy neotvoria, povie to', (tester) async {
    final actions = await _pump(tester);
    actions.canOpen = false;

    await tester.tap(find.text('Navigovať'));
    await tester.pumpAndSettle();

    expect(find.text('Odkaz sa nepodarilo otvoriť.'), findsOneWidget);
  });

  testWidgets('Uložiť si fitko zapamätá v telefóne', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Uložiť'));
    await tester.pumpAndSettle();

    expect(find.text('Uložené'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('favorite_gyms'), ['g1']);

    await tester.tap(find.byTooltip('Odobrať z uložených'));
    await tester.pumpAndSettle();
    expect(find.text('Uložiť'), findsOneWidget);
  });

  testWidgets('fitko bez údajov ukáže, že hodnotenia chýbajú', (tester) async {
    await _pump(tester, location: '/gym/g2');

    expect(find.text('Zatiaľ bez hodnotení'), findsOneWidget);
    expect(find.text('Toto fitko zatiaľ nikto nehodnotil.'), findsOneWidget);
  });

  testWidgets('neznáme fitko', (tester) async {
    await _pump(tester, location: '/gym/nie');
    expect(find.text('Toto fitko sme nenašli.'), findsOneWidget);
  });

  testWidgets('zo zoznamu sa otvorí detail a Späť vráti na mapu', (
    tester,
  ) async {
    await _pump(tester, location: '/map');

    await tester.tap(find.text('Zoznam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nové fitko'));
    await tester.pumpAndSettle();
    expect(find.text('Zatiaľ bez hodnotení'), findsOneWidget);

    await tester.tap(find.byTooltip('Späť'));
    await tester.pumpAndSettle();
    expect(find.text('MAPA FITIEK'), findsOneWidget);
  });

  testWidgets('hodnotenie hviezdičkami sa uloží a ďalším ťuknutím zruší', (
    tester,
  ) async {
    final repository = FakeGymRepository([_gym, _bare]);
    await _pump(tester, repository: repository);
    expect(find.text('Ohodnoť fitko'), findsOneWidget);

    await tester.tap(find.byTooltip('4 z 5'));
    await tester.pumpAndSettle();
    expect(repository.ratings['g1'], 4);
    expect(find.text('Tvoje hodnotenie'), findsOneWidget);
    expect(find.textContaining('168 recenzií'), findsWidgets);

    await tester.tap(find.byTooltip('4 z 5'));
    await tester.pumpAndSettle();
    expect(repository.ratings['g1'], isNull);
    expect(find.text('Ohodnoť fitko'), findsOneWidget);
    expect(find.textContaining('167 recenzií'), findsWidgets);
  });

  testWidgets('bez internetu hodnotenie povie, čo sa stalo', (tester) async {
    final repository = FakeGymRepository([_gym, _bare]);
    await _pump(tester, repository: repository);
    repository.fail = true;

    await tester.tap(find.byTooltip('5 z 5'));
    await tester.pumpAndSettle();

    expect(
      find.text('Server je nedostupný. Skontroluj pripojenie.'),
      findsOneWidget,
    );
    expect(find.text('Ohodnoť fitko'), findsOneWidget);
  });

  test('fitko zo servera', () {
    final gym = Gym.fromJson({
      'id': 'a',
      'name': 'X',
      'city': 'Nitra',
      'address': null,
      'lat': 48,
      'lng': 18.5,
      'openingHours': 'Nonstop',
      'tags': ['Kardio'],
      'website': 'javascript:alert(1)',
      'photoUrls': [],
      'rating': {
        'stars': [0, 0, 1, 0, 2],
      },
      'myStars': 5,
    });
    expect(gym.location, const GeoPoint(48, 18.5));
    expect(gym.tags, ['Kardio']);
    expect(gym.website, isNull); // len https odkazy
    expect(gym.rating!.count, 3);
    expect(gym.myStars, 5);
  });
}
