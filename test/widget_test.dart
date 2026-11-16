import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rejnox/core/api/api_client.dart';
import 'package:rejnox/core/router/app_router.dart';
import 'package:rejnox/features/body/domain/body_measurements.dart';
import 'package:rejnox/features/coaching/data/coaching_api.dart';
import 'package:rejnox/features/coaching/domain/coaching_models.dart';
import 'package:rejnox/features/gyms/application/user_location.dart';
import 'package:rejnox/features/gyms/data/gym_repository.dart';
import 'package:rejnox/features/gyms/presentation/map_style.dart';
import 'package:rejnox/features/training/domain/training_models.dart';
import 'package:rejnox/features/auth/data/auth_repository.dart';
import 'package:rejnox/features/auth/domain/auth_models.dart';
import 'package:rejnox/features/auth/presentation/auth_controller.dart';
import 'package:rejnox/core/theme/app_colors.dart';
import 'package:rejnox/features/home/data/home_repository.dart';
import 'package:rejnox/features/home/domain/home_overview.dart';
import 'package:rejnox/features/home/presentation/widgets/dashboard_sections.dart';
import 'package:rejnox/features/progress/data/progress_repository.dart';
import 'package:rejnox/features/reminders/reminder_service.dart';
import 'package:rejnox/features/training/application/workout_log_controller.dart';
import 'package:rejnox/features/training/data/set_storage.dart';
import 'package:rejnox/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';
import 'package:rejnox/features/training/application/rest_alerts.dart';

const _pavol = AuthUser(
  id: 'u1',
  email: 'pavol@test.sk',
  displayName: 'Pavol Novák',
  role: UserRole.member,
);

class _MemoryTokenStore implements TokenStore {
  _MemoryTokenStore([this.token]);

  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String token) async => this.token = token;

  AuthUser? user;

  @override
  Future<AuthUser?> readUser() async => user;

  @override
  Future<void> writeUser(AuthUser user) async => this.user = user;

  @override
  Future<void> clear() async {
    token = null;
    user = null;
  }
}

/// Falošný server: platný je len token "ok" a heslo "spravne-heslo".
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.user = _pavol});

  final AuthUser user;
  final loggedOut = <String>[];
  Object? meError;

  @override
  Future<AuthUser> me(String token) async {
    if (meError != null) throw meError!;
    if (token != 'ok') {
      throw const ApiError(401, 'unauthorized', 'Prihlás sa, prosím.');
    }
    return user;
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    if (password != 'spravne-heslo') {
      throw const ApiError(
        401,
        'invalid_credentials',
        'Nesprávny e-mail alebo heslo.',
      );
    }
    return const AuthSession(token: 'ok', user: _pavol);
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) async => AuthSession(
    token: 'ok',
    user: AuthUser(
      id: 'u2',
      email: email,
      displayName: displayName,
      role: role,
    ),
  );

  @override
  Future<void> logout(String token) async => loggedOut.add(token);
}

class _OfflinePlansApi extends FakeCoachingApi {
  @override
  Future<List<Plan>> myPlans(String token) async =>
      throw const ApiError.network();
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required _MemoryTokenStore tokens,
  _FakeAuthRepository? repository,
  FakeTrainingApi? trainingApi,
  FakeCoachingApi? coachingApi,
  FakeHomeRepository? home,
  FakeProgressRepository? progress,
  Map<String, Object> preferences = const {},
  MemorySetStore? setStore,
}) async {
  SharedPreferences.setMockInitialValues(preferences);
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(tokens),
        authRepositoryProvider.overrideWithValue(
          repository ?? _FakeAuthRepository(),
        ),
        localSetStoreProvider.overrideWithValue(setStore ?? MemorySetStore()),
        trainingApiProvider.overrideWithValue(
          trainingApi ?? (FakeTrainingApi()..online = true),
        ),
        connectivityProvider.overrideWithValue(const Stream<bool>.empty()),
        reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
        restAlertsProvider.overrideWithValue(lastRestAlerts = FakeRestAlerts()),
        coachingApiProvider.overrideWithValue(coachingApi ?? FakeCoachingApi()),
        locationSourceProvider.overrideWithValue(FakeLocationSource()),
        mapTilesEnabledProvider.overrideWithValue(false),
        gymRepositoryProvider.overrideWithValue(FakeGymRepository(const [])),
        homeRepositoryProvider.overrideWithValue(home ?? FakeHomeRepository()),
        progressRepositoryProvider.overrideWithValue(
          progress ?? FakeProgressRepository(),
        ),
      ],
      child: const RejnoxApp(webFonts: false),
    ),
  );
  await tester.pumpAndSettle();
}

/// Z úvodnej obrazovky otvorí prihlasovací formulár.
Future<void> _openLogin(WidgetTester tester) async {
  expect(find.text('VITAJ SPÄŤ'), findsNothing);
  await tester.tap(find.text('Prihlásiť sa'));
  await tester.pumpAndSettle();
  expect(find.text('VITAJ SPÄŤ'), findsOneWidget);
}

/// Profil je v menu „Viac“ v spodnej lište.
Future<void> _openProfile(WidgetTester tester) async {
  await tester.tap(find.text('Viac'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Profil'));
}

Future<void> _pumpSignedIn(WidgetTester tester) =>
    _pumpApp(tester, tokens: _MemoryTokenStore('ok'));

/// Odpočty pauzy z posledného spusteného testu.
late FakeRestAlerts lastRestAlerts;

void main() {
  group('WeeklyGoal', () {
    test('počíta percentá', () {
      expect(const WeeklyGoal(done: 4, total: 5).percent, 80);
      expect(const WeeklyGoal(done: 0, total: 5).percent, 0);
    });

    test('percentá nepresiahnu 100', () {
      const goal = WeeklyGoal(done: 7, total: 5);
      expect(goal.percent, 100);
      expect(goal.reached, isTrue);
    });
  });

  group('presmerovanie podľa prihlásenia', () {
    const signedIn = SignedIn(user: _pavol, token: 'ok');

    test('pri štarte čaká na úvodnej obrazovke', () {
      expect(authRedirect(const AuthRestoring(), '/home'), '/splash');
      expect(authRedirect(const AuthRestoring(), '/splash'), isNull);
    });

    test('neprihlásený sa dostane len na úvod, prihlásenie a registráciu', () {
      expect(authRedirect(const SignedOut(), '/home'), '/welcome');
      expect(authRedirect(const SignedOut(), '/profile'), '/welcome');
      expect(authRedirect(const SignedOut(), '/welcome'), isNull);
      expect(authRedirect(const SignedOut(), '/login'), isNull);
      expect(authRedirect(const SignedOut(), '/register'), isNull);
    });

    test('prihlásený ide z prihlásenia rovno domov', () {
      expect(authRedirect(signedIn, '/login'), '/home');
      expect(authRedirect(signedIn, '/welcome'), '/home');
      expect(authRedirect(signedIn, '/splash'), '/home');
      expect(authRedirect(signedIn, '/map'), isNull);
    });
  });

  testWidgets('domovská obrazovka ukáže dnešný tréning', (tester) async {
    await _pumpSignedIn(tester);

    expect(find.text('Ahoj, Pavol'), findsOneWidget);
    expect(find.text('NOHY & ZADOK'), findsOneWidget);
    expect(find.text('5 cvikov · 17 sérií · asi 55 min'), findsOneWidget);
    expect(find.text('4 z 5 tréningov'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
    // Nálož na tyči ukazuje prvý cvik s činkou.
    expect(find.text('Drep s činkou · 4 × 6'), findsOneWidget);
    // Bez zadanej váhy sa ukáže len schéma.
    expect(find.text('3×10'), findsOneWidget);
    expect(find.text('4×6 · 120 kg'), findsOneWidget);
    expect(find.textContaining('140'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard uprednostňuje aktívne sekcie a zapíše váhu', (
    tester,
  ) async {
    await _pumpSignedIn(tester);

    for (final title in [
      'TENTO TÝŽDEŇ',
      'TELO',
      'VÝKON',
      'S TRÉNEROM',
      'Pripravujeme',
    ]) {
      await tester.scrollUntilVisible(find.text(title), 200);
      expect(find.text(title), findsOneWidget);
    }

    await tester.scrollUntilVisible(find.text('Zapíš si váhu'), -200);
    await tester.tap(find.text('Zapíš si váhu'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '82,4');
    await tester.tap(find.text('Uložiť'));
    await tester.pumpAndSettle();

    expect(find.text('Zapíš si váhu'), findsNothing);
    expect(find.text('Váha · dnes'), findsOneWidget);
    expect(find.textContaining('82,4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rýchle váženie odmietne NaN a uloží desatinnú čiarku', (
    tester,
  ) async {
    await _pumpSignedIn(tester);
    await tester.scrollUntilVisible(find.text('Zapísať váhu'), 150);
    await tester.tap(find.text('Zapísať váhu'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'NaN');
    await tester.tap(find.text('Uložiť'));
    await tester.pumpAndSettle();
    expect(find.text('Zadaj váhu 20 až 400 kg.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '80,5');
    await tester.tap(find.text('Uložiť'));
    await tester.pumpAndSettle();
    expect(find.text('Váha · dnes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('prehľad sa zmestí na úzky displej aj pri väčšom písme', (
    tester,
  ) async {
    await _pumpSignedIn(tester);
    tester.view.physicalSize = const Size(320, 740);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Pripravujeme'), 200);
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(1200, 900);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('nový účet bez dát: prázdne karty namiesto vymyslených čísel', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      tokens: _MemoryTokenStore('ok'),
      home: FakeHomeRepository(FakeHomeRepository.empty),
    );

    expect(find.text('0 z 3 tréningov'), findsOneWidget);
    expect(find.text('ODDYCH'), findsOneWidget);
    expect(find.text('Na dnes nemáš naplánovaný tréning'), findsOneWidget);
    expect(find.text('Zatiaľ bez rekordu'), findsOneWidget);
    expect(find.text('Rebríček'), findsNothing);

    await tester.tap(find.text('Voľný tréning'));
    await tester.pumpAndSettle();
    expect(find.text('TRÉNING'), findsOneWidget);
  });

  test('prehľad sa načíta z odpovede servera', () {
    final overview = HomeOverview.fromJson({
      'streakDays': 2,
      'weeklyGoal': {'done': 1, 'total': 3},
      'todayWorkout': {
        'title': 'Nohy',
        'trainerName': 'Marek',
        'exercises': [
          {'name': 'Drep', 'sets': 4, 'reps': 6, 'weightKg': 100, 'note': null},
          {'name': 'Výpady', 'sets': 1, 'reps': 10, 'weightKg': null},
        ],
      },
      'personalRecord': {
        'exercise': 'Drep',
        'weightKg': 105.5,
        'monthDeltaKg': 0,
        'trend': [100, 105.5],
      },
    });

    final workout = overview.todayWorkout!;
    expect(workout.exercises.map((e) => e.plate), [Plate.red, Plate.blue]);
    expect(workout.exercises[0].note, '4 série');
    expect(workout.exercises[0].weightLabel, '100 kg');
    expect(workout.exercises[1].weightLabel, isNull);
    expect(workout.exercises[1].note, '1 séria');
    expect(overview.personalRecord!.weightLabel, '105,5');
    expect(overview.ranking, isNull);
  });

  testWidgets('spodná navigácia otvorí komunitu a z nej správy', (
    tester,
  ) async {
    await _pumpSignedIn(tester);

    await tester.tap(find.text('Komunita'));
    await tester.pumpAndSettle();
    expect(find.text('KOMUNITA'), findsOneWidget);

    await tester.tap(find.byTooltip('Správy'));
    await tester.pumpAndSettle();
    expect(find.text('SPRÁVY'), findsOneWidget);
  });

  testWidgets('menu Viac otvorí mapu', (tester) async {
    await _pumpSignedIn(tester);

    await tester.tap(find.text('Viac'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mapa fitiek'));
    await tester.pumpAndSettle();

    expect(find.text('MAPA FITIEK'), findsOneWidget);
  });

  testWidgets('tréning z prehľadu predvyplní cviky a po sériách postúpi', (
    tester,
  ) async {
    await _pumpSignedIn(tester);
    await tester.tap(find.text('Začať tréning'));
    await tester.pumpAndSettle();
    expect(find.text('TRÉNING'), findsOneWidget);
    expect(find.text('Plán · 0 z 13 sérií'), findsOneWidget);
    final squat = find.text('Zapísať sériu · 6 × 120 kg');
    expect(squat, findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await tester.ensureVisible(squat);
      await tester.tap(squat);
      await tester.pumpAndSettle();
    }
    expect(find.text('Plán · 4 z 13 sérií'), findsOneWidget);
    expect(find.text('Rumunský mŕtvy ťah'), findsOneWidget);
    expect(find.text('Zapísať sériu · 8 × 90 kg'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bez uloženého tokenu sa ukáže úvod s tlačidlami', (
    tester,
  ) async {
    await _pumpApp(tester, tokens: _MemoryTokenStore());

    expect(find.text('Začať'), findsOneWidget);
    expect(find.text('Prihlásiť sa'), findsOneWidget);
    expect(find.text('Ahoj, Pavol'), findsNothing);
  });

  testWidgets('neplatný uložený token sa zahodí', (tester) async {
    final tokens = _MemoryTokenStore('stary-token');
    await _pumpApp(tester, tokens: tokens);

    expect(find.text('Začať'), findsOneWidget);
    expect(tokens.token, isNull);
  });

  testWidgets('výpadok servera pri štarte token nezmaže', (tester) async {
    final tokens = _MemoryTokenStore('ok');
    final repository = _FakeAuthRepository()
      ..meError = const ApiError.network();
    await _pumpApp(tester, tokens: tokens, repository: repository);

    expect(find.text('Začať'), findsOneWidget);
    expect(tokens.token, 'ok');
  });

  testWidgets('bez internetu so zapamätaným profilom ostane prihlásený', (
    tester,
  ) async {
    final tokens = _MemoryTokenStore('ok')..user = _pavol;
    final repository = _FakeAuthRepository()
      ..meError = const ApiError.network();
    await _pumpApp(tester, tokens: tokens, repository: repository);

    expect(find.text('Ahoj, Pavol'), findsOneWidget);
    expect(tokens.token, 'ok');
  });

  testWidgets('neplatný token zmaže aj zapamätaný profil', (tester) async {
    final tokens = _MemoryTokenStore('stary-token')..user = _pavol;
    await _pumpApp(tester, tokens: tokens);

    expect(find.text('Začať'), findsOneWidget);
    expect(tokens.token, isNull);
    expect(tokens.user, isNull);
  });

  testWidgets('zlé heslo ukáže chybu, správne prihlási', (tester) async {
    final tokens = _MemoryTokenStore();
    await _pumpApp(tester, tokens: tokens);
    await _openLogin(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'pavol@test.sk');
    await tester.enterText(fields.at(1), 'zle-heslo');
    await tester.tap(find.text('Prihlásiť sa'));
    await tester.pumpAndSettle();
    expect(find.text('Nesprávny e-mail alebo heslo.'), findsOneWidget);
    expect(tokens.token, isNull);

    await tester.enterText(fields.at(1), 'spravne-heslo');
    await tester.tap(find.text('Prihlásiť sa'));
    await tester.pumpAndSettle();
    expect(find.text('Ahoj, Pavol'), findsOneWidget);
    expect(tokens.token, 'ok');
  });

  testWidgets('formulár nepustí neplatný e-mail', (tester) async {
    await _pumpApp(tester, tokens: _MemoryTokenStore());
    await _openLogin(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'bez-zavinaca');
    await tester.tap(find.text('Prihlásiť sa'));
    await tester.pumpAndSettle();

    expect(find.text('Zadaj platný e-mail.'), findsOneWidget);
    expect(find.text('Zadaj heslo.'), findsOneWidget);
  });

  testWidgets('registrácia trénera', (tester) async {
    await _pumpApp(tester, tokens: _MemoryTokenStore());

    await tester.tap(find.text('Začať'));
    await tester.pumpAndSettle();
    expect(find.text('VYTVOR SI ÚČET'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Marek Kováč');
    await tester.enterText(fields.at(1), 'marek@test.sk');
    await tester.enterText(fields.at(2), 'kratke');
    await tester.tap(find.text('Som tréner'));
    await tester.tap(find.text('Vytvoriť účet'));
    await tester.pumpAndSettle();
    expect(find.text('Heslo musí mať 8 až 72 znakov.'), findsOneWidget);

    await tester.enterText(fields.at(2), 'dlhe-heslo-123');
    await tester.tap(find.text('Vytvoriť účet'));
    await tester.pumpAndSettle();
    expect(find.text('Ahoj, Marek'), findsOneWidget);

    await _openProfile(tester);
    await tester.pumpAndSettle();
    expect(find.text('TRÉNER'), findsOneWidget);
  });

  testWidgets('srdce na karte zdravia pulzuje a vie zostať statické', (
    tester,
  ) async {
    Widget dashboard({required bool reduceMotion}) => ProviderScope(
      child: MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: const Scaffold(body: DashboardActions()),
          ),
        ),
      ),
    );
    final pulse = find.ancestor(
      of: find.byIcon(Icons.favorite_rounded),
      matching: find.byType(ScaleTransition),
    );
    double scale() => tester.widget<ScaleTransition>(pulse).scale.value;
    await tester.pumpWidget(dashboard(reduceMotion: false));
    await tester.pump(const Duration(milliseconds: 110));
    expect(scale(), greaterThan(1.2));
    await tester.pump(const Duration(milliseconds: 600));
    expect(scale(), 1);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 110));
    expect(scale(), greaterThan(1.2));
    await tester.pumpWidget(dashboard(reduceMotion: true));
    await tester.pump(const Duration(seconds: 4));
    expect(scale(), 1);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('Profil otvorí informácie o Rejnoxe a zdroji mapy', (
    tester,
  ) async {
    await _pumpSignedIn(tester);
    await _openProfile(tester);
    await tester.pumpAndSettle();
    final about = find.text('O aplikácii');
    await tester.ensureVisible(about);
    await tester.pumpAndSettle();
    await tester.tap(about);
    await tester.pumpAndSettle();
    expect(find.text('O APLIKÁCII'), findsOneWidget);
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
    await tester.tap(find.byTooltip('Späť'));
    await tester.pumpAndSettle();
    expect(find.text('PROFIL'), findsOneWidget);
  });

  testWidgets('odhlásenie v profile vráti na prihlásenie', (tester) async {
    final tokens = _MemoryTokenStore('ok');
    final repository = _FakeAuthRepository();
    await _pumpApp(tester, tokens: tokens, repository: repository);

    await _openProfile(tester);
    await tester.pumpAndSettle();
    expect(find.text('PAVOL NOVÁK'), findsOneWidget);

    await tester.ensureVisible(find.text('Odhlásiť sa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Odhlásiť sa'));
    await tester.pumpAndSettle();

    expect(find.text('Začať'), findsOneWidget);
    expect(tokens.token, isNull);
    expect(repository.loggedOut, ['ok']);
  });

  testWidgets('zápis série online: uloží sa a odošle', (tester) async {
    final api = FakeTrainingApi()..online = true;
    await _pumpApp(tester, tokens: _MemoryTokenStore('ok'), trainingApi: api);

    await tester.tap(find.text('Tréning'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Zapísať sériu'));
    await tester.pumpAndSettle();

    expect(find.text('8 × 20 kg'), findsOneWidget);
    expect(find.text('Všetko uložené'), findsOneWidget);
    expect(api.received, hasLength(1));
  });

  testWidgets('zápis série bez internetu: čaká v telefóne', (tester) async {
    final api = FakeTrainingApi();
    await _pumpApp(tester, tokens: _MemoryTokenStore('ok'), trainingApi: api);

    await tester.tap(find.text('Tréning'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '5');
    await tester.enterText(find.byType(TextFormField).at(1), '102,5');
    await tester.tap(find.textContaining('Zapísať sériu'));
    await tester.pumpAndSettle();

    expect(find.text('5 × 102,5 kg'), findsOneWidget);
    expect(find.text('Offline · čaká 1'), findsOneWidget);
    expect(find.textContaining('bezpečne uložené v telefóne'), findsOneWidget);
  });

  testWidgets('rýchle voľby menia váhu, po zápise beží pauza', (tester) async {
    await _pumpSignedIn(tester);

    await tester.tap(find.text('Tréning'));
    await tester.pumpAndSettle();
    expect(find.text('Zapísať sériu · 8 × 20 kg'), findsOneWidget);

    await tester.tap(find.text('+5 kg'));
    await tester.pump();
    expect(find.text('Zapísať sériu · 8 × 25 kg'), findsOneWidget);

    await tester.tap(find.byTooltip('Rozcvička'));
    await tester.tap(find.textContaining('Zapísať sériu'));
    await tester.pumpAndSettle();

    expect(find.text('8 × 25 kg'), findsOneWidget);
    expect(find.text('Rozcvička'), findsWidgets);
    expect(find.text('PAUZA'), findsOneWidget);
    expect(find.text('Minule 8 × 25 kg'), findsOneWidget);
    // Odpočet beží aj mimo appky (zamknutá obrazovka).
    expect(lastRestAlerts.end, isNotNull);

    await tester.tap(find.byTooltip('Preskočiť pauzu'));
    await tester.pump();
    expect(find.text('PAUZA'), findsNothing);
    expect(lastRestAlerts.end, isNull);
  });

  testWidgets('prebiehajúci tréning je vidieť na Dnes a dá sa ukončiť', (
    tester,
  ) async {
    await _pumpSignedIn(tester);

    await tester.tap(find.text('Tréning'));
    await tester.pumpAndSettle();
    expect(find.text('Začať tréning'), findsOneWidget);

    await tester.tap(find.textContaining('Zapísať sériu'));
    await tester.pumpAndSettle();
    expect(find.text('Ukončiť tréning'), findsOneWidget);

    await tester.tap(find.text('Dnes'));
    await tester.pumpAndSettle();
    expect(find.text('PREBIEHA TRÉNING'), findsOneWidget);
    expect(find.text('VOĽNÝ TRÉNING'), findsOneWidget);
    expect(find.textContaining('1 séria · 160 kg'), findsOneWidget);
    // Pásik nad lištou aj tlačidlo v karte.
    expect(find.text('Pokračovať'), findsNWidgets(2));

    await tester.tap(find.text('Ukončiť tréning'));
    await tester.pumpAndSettle();
    expect(find.text('UKONČIŤ TRÉNING?'), findsOneWidget);

    await tester.tap(find.text('Ukončiť a uložiť'));
    await tester.pumpAndSettle();

    expect(find.text('HOTOVO NA DNES'), findsOneWidget);
    expect(find.text('Pokračovať'), findsNothing);
    expect(find.textContaining('Tréning uložený'), findsOneWidget);
  });

  testWidgets('výber cviku filtruje partie a vyberie cvik', (tester) async {
    await _pumpSignedIn(tester);

    await tester.tap(find.text('Tréning'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.unfold_more_rounded));
    await tester.pumpAndSettle();
    expect(find.text('VYBER CVIK'), findsOneWidget);

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('group-chest')),
      find.byType(ListView).first,
      const Offset(-120, 0),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('group-chest')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('group-chest')));
    await tester.pumpAndSettle();
    expect(find.text('Bench press'), findsOneWidget);
    expect(find.text('Zhyby'), findsNothing);

    await tester.tap(find.text('Bench press'));
    await tester.pumpAndSettle();
    expect(find.text('VYBER CVIK'), findsNothing);
    expect(find.text('Bench press'), findsOneWidget);
  });

  testWidgets('neplatné opakovania sa nezapíšu', (tester) async {
    await _pumpSignedIn(tester);

    await tester.tap(find.text('Tréning'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '0');
    await tester.tap(find.textContaining('Zapísať sériu'));
    await tester.pumpAndSettle();

    expect(find.text('Zadaj 1 až 1000.'), findsOneWidget);
    expect(find.textContaining('Zatiaľ žiadne série'), findsOneWidget);
  });

  group('menu Viac a progres', () {
    testWidgets('menu ukáže časti, ktoré sa do lišty nezmestili', (
      tester,
    ) async {
      await _pumpSignedIn(tester);
      expect(find.text('Profil'), findsNothing);

      await tester.tap(find.text('Viac'));
      await tester.pumpAndSettle();
      expect(find.text('VIAC'), findsOneWidget);
      for (final label in ['Profil', 'Progres', 'Tep srdca', 'O aplikácii']) {
        expect(find.text(label), findsOneWidget);
      }
      // Mapa je v menu, v lište sú namiesto nej Správy.
      expect(find.text('Mapa fitiek'), findsOneWidget);
    });

    testWidgets('progres ukáže mesiac, týždne, rekordy a detail cviku', (
      tester,
    ) async {
      await _pumpSignedIn(tester);
      await tester.tap(find.text('Viac'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Progres'));
      await tester.pumpAndSettle();

      expect(find.text('PROGRES'), findsOneWidget);
      expect(find.text('16,4 t'), findsOneWidget);
      expect(find.text('+17 %'), findsOneWidget);
      expect(find.text('OBJEM PO TÝŽDŇOCH'), findsOneWidget);

      final squat = find.text('Drep s činkou');
      await tester.ensureVisible(squat);
      await tester.pumpAndSettle();
      expect(find.text('rekord 120 kg  +20 kg'), findsOneWidget);
      await tester.tap(squat);
      await tester.pumpAndSettle();
      expect(find.text('DREP S ČINKOU'), findsOneWidget);
      expect(find.text('138,5 kg'), findsOneWidget);
      expect(find.text('+20 kg'), findsOneWidget);
    });

    testWidgets('telo: na postave sa zapíše pás a ukáže sa pri ňom', (
      tester,
    ) async {
      await _pumpSignedIn(tester);
      await tester.tap(find.text('Viac'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Telo a rozmery'));
      await tester.pumpAndSettle();

      expect(find.text('TELO'), findsOneWidget);
      expect(find.text('+ zapísať'), findsNWidgets(BodyPart.values.length));

      await tester.tap(find.text('Pás'));
      await tester.pumpAndSettle();
      expect(find.text('PÁS'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '5');
      await tester.tap(find.text('Uložiť'));
      await tester.pumpAndSettle();
      expect(find.text('Zadaj 40 až 200 cm.'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), '82,5');
      await tester.tap(find.text('Uložiť'));
      await tester.pumpAndSettle();
      expect(find.text('82,5 cm'), findsOneWidget);
      expect(find.text('+ zapísať'), findsNWidgets(BodyPart.values.length - 1));
      expect(find.text('ZMENA ZA 30 DNÍ'), findsOneWidget);
    });

    testWidgets('bez sérií progres ponúkne začať', (tester) async {
      await _pumpApp(
        tester,
        tokens: _MemoryTokenStore('ok'),
        progress: FakeProgressRepository(FakeProgressRepository.emptyJson),
      );
      await tester.tap(find.text('Viac'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Progres'));
      await tester.pumpAndSettle();
      expect(find.text('Zatiaľ bez progresu'), findsOneWidget);
    });
  });

  testWidgets('v profile je pripomienka, na webe vysvetlenie', (tester) async {
    await _pumpSignedIn(tester);

    await _openProfile(tester);
    await tester.pumpAndSettle();

    expect(find.text('Pripomienka tréningu'), findsOneWidget);
    expect(find.textContaining('fungujú v mobilnej appke'), findsOneWidget);
  });

  group('tréner a klienti', () {
    const marek = AuthUser(
      id: 't1',
      email: 'marek@test.sk',
      displayName: 'Marek Tréner',
      role: UserRole.trainer,
    );

    Future<FakeCoachingApi> pumpTrainer(WidgetTester tester) async {
      final api = FakeCoachingApi();
      await _pumpApp(
        tester,
        tokens: _MemoryTokenStore('ok'),
        repository: _FakeAuthRepository(user: marek),
        coachingApi: api,
      );
      return api;
    }

    testWidgets('tréner má v menu Klientov namiesto Mapy', (tester) async {
      await pumpTrainer(tester);
      expect(find.text('Klienti'), findsOneWidget);
      expect(find.text('Mapa'), findsNothing);
    });

    testWidgets('člen má v lište Správy a Komunitu, nie Klientov', (
      tester,
    ) async {
      await _pumpSignedIn(tester);
      expect(find.text('Správy'), findsWidgets);
      expect(find.text('Komunita'), findsOneWidget);
      expect(find.text('Klienti'), findsNothing);
    });

    testWidgets('spodná lišta otvorí správy', (tester) async {
      await _pumpSignedIn(tester);
      await tester.tap(find.text('Správy').last);
      await tester.pumpAndSettle();
      expect(find.text('SPRÁVY'), findsOneWidget);
    });

    testWidgets('pridanie klienta a pozvánka s kódom', (tester) async {
      final api = await pumpTrainer(tester);

      await tester.tap(find.text('Klienti'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Zatiaľ nemáš klientov'), findsOneWidget);

      await tester.tap(find.text('Pridať'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Jana Nová');
      await tester.tap(find.text('Pridať klienta'));
      await tester.pumpAndSettle();

      expect(api.clientsList.single.name, 'Jana Nová');
      expect(find.text('JANA NOVÁ'), findsOneWidget);
      expect(find.text('Bez appky'), findsOneWidget);

      await tester.tap(find.text('Pozvať do appky'));
      await tester.pumpAndSettle();
      expect(find.text('K7QM-4XPA'), findsOneWidget);
    });

    testWidgets('klient zadá kód: zlý odmietne, správny prepojí', (
      tester,
    ) async {
      final api = FakeCoachingApi();
      await _pumpApp(tester, tokens: _MemoryTokenStore('ok'), coachingApi: api);

      await _openProfile(tester);
      await tester.pumpAndSettle();
      expect(find.textContaining('Zatiaľ nemáš trénera'), findsOneWidget);

      await tester.tap(find.text('Mám kód od trénera'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'AAAA-BBBB');
      await tester.tap(find.text('Prepojiť'));
      await tester.pumpAndSettle();
      expect(find.text('Kód neplatí alebo už vypršal.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'k7qm-4xpa');
      await tester.tap(find.text('Prepojiť'));
      await tester.pumpAndSettle();
      expect(find.text('Marek'), findsOneWidget);
      expect(api.trainers, hasLength(1));
    });

    testWidgets('offline plán z karty Tréning pokračuje po reštarte', (
      tester,
    ) async {
      const plan = Plan(
        id: 'p1',
        title: 'Nohy A',
        trainerName: 'Marek',
        items: [
          PlanItem(
            exerciseId: '00000000-0000-4000-8000-000000000001',
            name: 'Drep s činkou',
            group: MuscleGroup.legs,
            sets: 1,
            reps: 6,
            weightKg: 80,
          ),
          PlanItem(
            exerciseId: '00000000-0000-4000-8000-000000000009',
            name: 'Bulharské výpady',
            group: MuscleGroup.legs,
            sets: 2,
            reps: 10,
          ),
        ],
      );
      final store = MemorySetStore();
      Future<void> openTraining(Map<String, Object> preferences) async {
        await _pumpApp(
          tester,
          tokens: _MemoryTokenStore('ok'),
          coachingApi: _OfflinePlansApi(),
          trainingApi: FakeTrainingApi(),
          setStore: store,
          preferences: preferences,
        );
        await tester.tap(find.text('Tréning'));
        await tester.pumpAndSettle();
      }

      await openTraining({
        'rejnox_plans_v1_u1': jsonEncode([plan.toJson()]),
      });
      expect(find.text('NOHY A'), findsOneWidget);
      expect(find.text('uložené v telefóne'), findsOneWidget);
      final start = find.text('Cvičiť podľa plánu');
      await tester.ensureVisible(start);
      await tester.pumpAndSettle();
      await tester.tap(start);
      await tester.pumpAndSettle();
      final logSet = find.text('Zapísať sériu · 6 × 80 kg');
      expect(logSet, findsOneWidget);
      expect(find.text('Plán · 0 z 3 sérií'), findsOneWidget);
      await tester.tap(logSet);
      await tester.pumpAndSettle();
      expect(store.data[_pavol.id]?.single.state, SyncState.pending);
      final prefs = await SharedPreferences.getInstance();
      final saved = {for (final key in prefs.getKeys()) key: prefs.get(key)!};
      await tester.pumpWidget(const SizedBox.shrink());
      await openTraining(saved);
      expect(find.text('Plán · 1 z 3 sérií'), findsOneWidget);
      expect(find.text('Zapísať sériu · 10 × 0 kg'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
