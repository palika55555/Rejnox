import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rejnox/core/theme/app_theme.dart';
import 'package:rejnox/features/gyms/application/gym_actions.dart';
import 'package:rejnox/features/gyms/application/gym_photo_picker.dart';
import 'package:rejnox/features/gyms/application/user_location.dart';
import 'package:rejnox/features/gyms/data/gym_repository.dart';
import 'package:rejnox/features/gyms/domain/gym.dart';
import 'package:rejnox/features/gyms/presentation/gym_detail_screen.dart';
import 'package:rejnox/features/gyms/presentation/gym_form_screen.dart';
import 'package:rejnox/features/gyms/presentation/gym_map_screen.dart';
import 'package:rejnox/features/gyms/presentation/map_style.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

const _foreign = Gym(
  id: 'g1',
  name: 'Gym Fit Nitra',
  city: 'Nitra',
  location: GeoPoint(48.3076, 18.0845),
  prices: [
    GymPrice(
      id: 'c-old',
      kind: GymPriceKind.membership,
      title: 'Jednorazový vstup',
      priceCents: 600,
    ),
  ],
);

const _mine = Gym(
  id: 'g2',
  name: 'Moje fitko',
  city: 'Žilina',
  location: GeoPoint(49.22, 18.74),
  mine: true,
);

Future<void> _pump(
  WidgetTester tester, {
  required String location,
  required FakeGymRepository repository,
  FakeGymPhotoPicker? picker,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/map',
        builder: (_, _) => const Scaffold(body: GymMapScreen()),
      ),
      GoRoute(
        path: '/gym/new',
        builder: (_, state) => GymFormScreen(
          initialLocation: geoPointFromQuery(state.uri.queryParameters),
        ),
      ),
      GoRoute(
        path: '/gym/:id/edit',
        builder: (_, state) =>
            GymFormScreen(gymId: state.pathParameters['id']!),
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
        externalActionsProvider.overrideWithValue(FakeExternalActions()),
        gymPhotoPickerProvider.overrideWithValue(
          picker ?? FakeGymPhotoPicker(),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.dark(webFonts: false),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _field(String label) =>
    find.widgetWithText(TextFormField, label, skipOffstage: false);

void main() {
  group('údaje od používateľov', () {
    test('cena zadaná textom', () {
      expect(parsePriceCents('39'), 3900);
      expect(parsePriceCents('4,50 €'), 450);
      expect(parsePriceCents(' 12.9 '), 1290);
      expect(parsePriceCents(''), isNull);
      expect(parsePriceCents('-5'), isNull);
      expect(parsePriceCents('1,999'), isNull);
    });

    test('popis ceny', () {
      const price = GymPrice(
        id: 'c',
        kind: GymPriceKind.product,
        title: 'Proteín',
        priceCents: 350,
      );
      expect(price.priceLabel, '3,50 €');
    });

    test('poloha z odkazu', () {
      expect(
        geoPointFromQuery({'lat': '48.1', 'lng': '17.1'}),
        const GeoPoint(48.1, 17.1),
      );
      expect(geoPointFromQuery({'lat': '95', 'lng': '17'}), isNull);
      expect(geoPointFromQuery({'lat': 'NaN', 'lng': '17'}), isNull);
      expect(geoPointFromQuery({}), isNull);
    });

    test('fitko zo servera s fotkami, cenníkom a autorom', () {
      final gym = Gym.fromJson({
        'id': 'g',
        'name': 'Gym',
        'city': 'Nitra',
        'lat': 48.3,
        'lng': 18.1,
        'mine': true,
        'photos': [
          {'id': 'p1', 'mine': false},
        ],
        'prices': [
          {
            'id': 'c1',
            'kind': 'product',
            'title': 'Voda',
            'priceCents': 120,
            'currency': 'EUR',
            'period': null,
            'mine': true,
          },
        ],
      });
      expect(gym.mine, isTrue);
      expect(gym.photos.single.id, 'p1');
      expect(gym.prices.single.kind, GymPriceKind.product);
      expect(gym.prices.single.mine, isTrue);
      expect(gymPhotoUrl(gym.photos.single), endsWith('/gym-photos/p1'));
    });
  });

  testWidgets('z mapy sa otvorí formulár nového fitka', (tester) async {
    await _pump(
      tester,
      location: '/map',
      repository: FakeGymRepository([_foreign]),
    );

    await tester.tap(find.byTooltip('Pridať fitko'));
    await tester.pumpAndSettle();

    expect(find.text('NOVÉ FITKO'), findsOneWidget);
    expect(find.text('Ťukni na mapu tam, kde je fitko.'), findsOneWidget);
  });

  testWidgets('bez polohy a názvu sa fitko neuloží', (tester) async {
    final repository = FakeGymRepository([_foreign]);
    await _pump(tester, location: '/gym/new', repository: repository);

    await tester.tap(find.text('Pridať fitko na mapu'));
    await tester.pumpAndSettle();

    expect(find.text('Zadaj názov.'), findsOneWidget);
    expect(find.text('Zadaj mesto.'), findsOneWidget);
    expect(repository.gyms, hasLength(1));
  });

  testWidgets('nové fitko sa uloží a otvorí sa jeho detail', (tester) async {
    final repository = FakeGymRepository([_foreign]);
    await _pump(
      tester,
      location: '/gym/new?lat=48.15&lng=17.11',
      repository: repository,
    );

    await tester.enterText(_field('Názov fitka'), 'Iron Gym');
    await tester.enterText(_field('Mesto'), 'Bratislava');
    await tester.enterText(_field('Otváracie hodiny (nepovinné)'), 'Nonstop');
    await tester.tap(find.widgetWithText(FilterChip, 'Sauna'));
    await tester.tap(find.text('Pridať fitko na mapu'));
    await tester.pumpAndSettle();

    final created = repository.gyms.last;
    expect(created.name, 'Iron Gym');
    expect(created.location, const GeoPoint(48.15, 17.11));
    expect(created.tags, ['Sauna']);
    expect(find.text('Iron Gym'), findsOneWidget);
    expect(find.text('Otvorené nonstop'), findsOneWidget);
    // Autor môže svoje fitko upraviť.
    expect(find.byTooltip('Upraviť fitko'), findsOneWidget);
  });

  testWidgets('cudzie fitko sa upraviť nedá', (tester) async {
    await _pump(
      tester,
      location: '/gym/g1',
      repository: FakeGymRepository([_foreign]),
    );
    expect(find.byTooltip('Upraviť fitko'), findsNothing);
    expect(find.byTooltip('Zmazať fitko'), findsNothing);
  });

  testWidgets('úprava vlastného fitka', (tester) async {
    final repository = FakeGymRepository([_foreign, _mine]);
    await _pump(tester, location: '/gym/g2', repository: repository);

    await tester.tap(find.byTooltip('Upraviť fitko'));
    await tester.pumpAndSettle();
    expect(find.text('UPRAVIŤ FITKO'), findsOneWidget);

    await tester.enterText(_field('Názov fitka'), 'Moje fitko 2');
    await tester.tap(find.text('Uložiť zmeny'));
    await tester.pumpAndSettle();

    expect(repository.gyms.last.name, 'Moje fitko 2');
    expect(find.text('Moje fitko 2'), findsOneWidget);
  });

  testWidgets('zmazanie vlastného fitka sa pýta a vráti na mapu', (
    tester,
  ) async {
    final repository = FakeGymRepository([_foreign, _mine]);
    await _pump(tester, location: '/gym/g2', repository: repository);

    await tester.tap(find.byTooltip('Zmazať fitko'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nechať'));
    await tester.pumpAndSettle();
    expect(repository.gyms, hasLength(2));

    await tester.tap(find.byTooltip('Zmazať fitko'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zmazať'));
    await tester.pumpAndSettle();

    expect(repository.gyms.map((g) => g.id), ['g1']);
    expect(find.text('MAPA FITIEK'), findsOneWidget);
  });

  testWidgets('cenník: pridanie a zmazanie vlastnej ceny', (tester) async {
    final repository = FakeGymRepository([_foreign]);
    await _pump(tester, location: '/gym/g1', repository: repository);

    expect(find.text('Jednorazový vstup'), findsOneWidget);
    expect(find.text('6,00 €'), findsOneWidget);
    // Cudziu cenu zmazať nemôžem.
    expect(find.byTooltip('Zmazať moju cenu'), findsNothing);

    await tester.ensureVisible(find.text('Pridať cenu'));
    await tester.tap(find.text('Pridať cenu'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Názov'), 'Mesačná permanentka');
    await tester.enterText(_field('Cena'), '39,90');
    await tester.enterText(_field('Obdobie (nepovinné)'), 'mesiac');
    await tester.tap(find.text('Pridať do cenníka'));
    await tester.pumpAndSettle();

    expect(find.text('39,90 €'), findsOneWidget);
    expect(repository.gyms.single.prices.last.priceCents, 3990);

    await tester.tap(find.byTooltip('Zmazať moju cenu'));
    await tester.pumpAndSettle();
    expect(find.text('39,90 €'), findsNothing);
  });

  testWidgets('neplatná cena sa neuloží', (tester) async {
    final repository = FakeGymRepository([_foreign]);
    await _pump(tester, location: '/gym/g1', repository: repository);

    await tester.ensureVisible(find.text('Pridať cenu'));
    await tester.tap(find.text('Pridať cenu'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Názov'), 'Vstup');
    await tester.enterText(_field('Cena'), 'zadarmo');
    await tester.tap(find.text('Pridať do cenníka'));
    await tester.pumpAndSettle();

    expect(find.text('Napr. 39 alebo 4,50'), findsOneWidget);
    expect(repository.gyms.single.prices, hasLength(1));
  });

  testWidgets('fotka z galérie sa nahrá k fitku', (tester) async {
    final repository = FakeGymRepository([_foreign]);
    await _pump(tester, location: '/gym/g1', repository: repository);

    await tester.tap(find.text('Pridať fotku'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vybrať z galérie'));
    await tester.pumpAndSettle();

    expect(repository.uploads.single, [0xff, 0xd8, 0xff, 0xe0]);
    expect(repository.gyms.single.photos.single.mine, isTrue);
    expect(find.text('Fotka je pridaná. Ďakujeme!'), findsOneWidget);
    expect(find.bySemanticsLabel('Fotka 1 z 1'), findsOneWidget);
  });

  testWidgets('keď sa fotka nedá načítať, povie to', (tester) async {
    final repository = FakeGymRepository([_foreign]);
    await _pump(
      tester,
      location: '/gym/g1',
      repository: repository,
      picker: FakeGymPhotoPicker()..fail = true,
    );

    await tester.tap(find.text('Pridať fotku'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Odfotiť'));
    await tester.pumpAndSettle();

    expect(
      find.text('Fotku sa nepodarilo načítať. Skontroluj povolenia.'),
      findsOneWidget,
    );
    expect(repository.uploads, isEmpty);
  });
}
