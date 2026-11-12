import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rejnox/core/api/api_client.dart';
import 'package:rejnox/core/router/app_router.dart';
import 'package:rejnox/features/auth/data/auth_repository.dart';
import 'package:rejnox/features/auth/domain/auth_models.dart';
import 'package:rejnox/features/auth/presentation/auth_controller.dart';
import 'package:rejnox/features/home/domain/home_overview.dart';
import 'package:rejnox/features/reminders/reminder_service.dart';
import 'package:rejnox/features/training/application/workout_log_controller.dart';
import 'package:rejnox/features/training/data/set_storage.dart';
import 'package:rejnox/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

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
  final loggedOut = <String>[];
  Object? meError;

  @override
  Future<AuthUser> me(String token) async {
    if (meError != null) throw meError!;
    if (token != 'ok') {
      throw const ApiError(401, 'unauthorized', 'Prihlás sa, prosím.');
    }
    return _pavol;
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

Future<void> _pumpApp(
  WidgetTester tester, {
  required _MemoryTokenStore tokens,
  _FakeAuthRepository? repository,
  FakeTrainingApi? trainingApi,
}) async {
  SharedPreferences.setMockInitialValues({});
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
        localSetStoreProvider.overrideWithValue(MemorySetStore()),
        trainingApiProvider.overrideWithValue(
          trainingApi ?? (FakeTrainingApi()..online = true),
        ),
        connectivityProvider.overrideWithValue(const Stream<bool>.empty()),
        reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
      ],
      child: const RejnoxApp(webFonts: false),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpSignedIn(WidgetTester tester) =>
    _pumpApp(tester, tokens: _MemoryTokenStore('ok'));

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

    test('neprihlásený sa dostane len na prihlásenie a registráciu', () {
      expect(authRedirect(const SignedOut(), '/home'), '/login');
      expect(authRedirect(const SignedOut(), '/profile'), '/login');
      expect(authRedirect(const SignedOut(), '/login'), isNull);
      expect(authRedirect(const SignedOut(), '/register'), isNull);
    });

    test('prihlásený ide z prihlásenia rovno domov', () {
      expect(authRedirect(signedIn, '/login'), '/home');
      expect(authRedirect(signedIn, '/splash'), '/home');
      expect(authRedirect(signedIn, '/map'), isNull);
    });
  });

  testWidgets('domovská obrazovka ukáže dnešný tréning', (tester) async {
    await _pumpSignedIn(tester);

    expect(find.text('Pavol'), findsOneWidget);
    expect(find.text('NOHY & ZADOK'), findsOneWidget);
    expect(find.text('4 z 5 tréningov'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
    expect(find.text('+2 cviky'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('prepínač Dnes / Týždeň / Rekordy mení obsah', (tester) async {
    await _pumpSignedIn(tester);

    await tester.tap(find.text('Rekordy'));
    await tester.pumpAndSettle();

    expect(find.text('NOHY & ZADOK'), findsNothing);
    expect(find.textContaining('osobné rekordy'), findsOneWidget);
  });

  testWidgets('spodná navigácia otvorí mapu', (tester) async {
    await _pumpSignedIn(tester);

    await tester.tap(find.text('Mapa'));
    await tester.pumpAndSettle();

    expect(find.text('MAPA FITIEK'), findsOneWidget);
  });

  testWidgets('Začať tréning otvorí kartu Tréning', (tester) async {
    await _pumpSignedIn(tester);

    await tester.tap(find.text('Začať tréning'));
    await tester.pumpAndSettle();

    expect(find.text('TRÉNING'), findsOneWidget);
  });

  testWidgets('bez uloženého tokenu sa ukáže prihlásenie', (tester) async {
    await _pumpApp(tester, tokens: _MemoryTokenStore());

    expect(find.text('VITAJ SPÄŤ'), findsOneWidget);
    expect(find.text('Pavol'), findsNothing);
  });

  testWidgets('neplatný uložený token sa zahodí', (tester) async {
    final tokens = _MemoryTokenStore('stary-token');
    await _pumpApp(tester, tokens: tokens);

    expect(find.text('VITAJ SPÄŤ'), findsOneWidget);
    expect(tokens.token, isNull);
  });

  testWidgets('výpadok servera pri štarte token nezmaže', (tester) async {
    final tokens = _MemoryTokenStore('ok');
    final repository = _FakeAuthRepository()
      ..meError = const ApiError.network();
    await _pumpApp(tester, tokens: tokens, repository: repository);

    expect(find.text('VITAJ SPÄŤ'), findsOneWidget);
    expect(tokens.token, 'ok');
  });

  testWidgets('bez internetu so zapamätaným profilom ostane prihlásený', (
    tester,
  ) async {
    final tokens = _MemoryTokenStore('ok')..user = _pavol;
    final repository = _FakeAuthRepository()
      ..meError = const ApiError.network();
    await _pumpApp(tester, tokens: tokens, repository: repository);

    expect(find.text('Pavol'), findsOneWidget);
    expect(tokens.token, 'ok');
  });

  testWidgets('neplatný token zmaže aj zapamätaný profil', (tester) async {
    final tokens = _MemoryTokenStore('stary-token')..user = _pavol;
    await _pumpApp(tester, tokens: tokens);

    expect(find.text('VITAJ SPÄŤ'), findsOneWidget);
    expect(tokens.token, isNull);
    expect(tokens.user, isNull);
  });

  testWidgets('zlé heslo ukáže chybu, správne prihlási', (tester) async {
    final tokens = _MemoryTokenStore();
    await _pumpApp(tester, tokens: tokens);

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
    expect(find.text('Pavol'), findsOneWidget);
    expect(tokens.token, 'ok');
  });

  testWidgets('formulár nepustí neplatný e-mail', (tester) async {
    await _pumpApp(tester, tokens: _MemoryTokenStore());

    await tester.enterText(find.byType(TextFormField).at(0), 'bez-zavinaca');
    await tester.tap(find.text('Prihlásiť sa'));
    await tester.pumpAndSettle();

    expect(find.text('Zadaj platný e-mail.'), findsOneWidget);
    expect(find.text('Zadaj heslo.'), findsOneWidget);
  });

  testWidgets('registrácia trénera', (tester) async {
    await _pumpApp(tester, tokens: _MemoryTokenStore());

    await tester.tap(find.text('Nemám účet. Zaregistrovať sa'));
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
    expect(find.text('Marek'), findsOneWidget);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('TRÉNER'), findsOneWidget);
  });

  testWidgets('odhlásenie v profile vráti na prihlásenie', (tester) async {
    final tokens = _MemoryTokenStore('ok');
    final repository = _FakeAuthRepository();
    await _pumpApp(tester, tokens: tokens, repository: repository);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Pavol Novák'), findsOneWidget);

    await tester.tap(find.text('Odhlásiť sa'));
    await tester.pumpAndSettle();

    expect(find.text('VITAJ SPÄŤ'), findsOneWidget);
    expect(tokens.token, isNull);
    expect(repository.loggedOut, ['ok']);
  });

  testWidgets('zápis série online: uloží sa a odošle', (tester) async {
    final api = FakeTrainingApi()..online = true;
    await _pumpApp(tester, tokens: _MemoryTokenStore('ok'), trainingApi: api);

    await tester.tap(find.text('Tréning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zapísať sériu'));
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
    await tester.tap(find.text('Zapísať sériu'));
    await tester.pumpAndSettle();

    expect(find.text('5 × 102,5 kg'), findsOneWidget);
    expect(find.text('Offline · čaká 1'), findsOneWidget);
    expect(find.textContaining('bezpečne uložené v telefóne'), findsOneWidget);
  });

  testWidgets('neplatné opakovania sa nezapíšu', (tester) async {
    await _pumpSignedIn(tester);

    await tester.tap(find.text('Tréning'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '0');
    await tester.tap(find.text('Zapísať sériu'));
    await tester.pumpAndSettle();

    expect(find.text('Zadaj 1 až 1000.'), findsOneWidget);
    expect(find.textContaining('Zatiaľ žiadne série'), findsOneWidget);
  });

  testWidgets('v profile je pripomienka, na webe vysvetlenie', (tester) async {
    await _pumpSignedIn(tester);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();

    expect(find.text('Pripomienka tréningu'), findsOneWidget);
    expect(find.textContaining('fungujú v mobilnej appke'), findsOneWidget);
  });
}
