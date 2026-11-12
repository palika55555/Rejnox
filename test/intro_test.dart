import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rejnox/core/theme/app_theme.dart';
import 'package:rejnox/features/auth/data/auth_repository.dart';
import 'package:rejnox/features/auth/domain/auth_models.dart';
import 'package:rejnox/features/auth/presentation/auth_controller.dart';
import 'package:rejnox/features/auth/presentation/celebration_state.dart';
import 'package:rejnox/features/intro/celebration_overlay.dart';
import 'package:rejnox/features/intro/intro_animation.dart';

const _jana = AuthUser(
  id: 'u1',
  email: 'jana@test.sk',
  displayName: 'Jana Nová',
  role: UserRole.member,
);

class _Tokens implements TokenStore {
  _Tokens([this.token, this.user]);

  String? token;
  AuthUser? user;

  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String token) async => this.token = token;
  @override
  Future<AuthUser?> readUser() async => user;
  @override
  Future<void> writeUser(AuthUser user) async => this.user = user;
  @override
  Future<void> clear() async => token = user = null;
}

class _Repo implements AuthRepository {
  @override
  Future<AuthUser> me(String token) async => _jana;
  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async => const AuthSession(token: 't', user: _jana);
  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) async => const AuthSession(token: 't', user: _jana);
  @override
  Future<void> logout(String token) async {}
}

Widget _app(Widget child, {bool reduced = false}) => MaterialApp(
  theme: AppTheme.dark(webFonts: false),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
      child: Scaffold(body: child),
    ),
  ),
);

void main() {
  group('úvodná animácia', () {
    testWidgets('prebehne a sama skončí', (tester) async {
      var done = false;
      await tester.pumpWidget(_app(IntroAnimation(onDone: () => done = true)));
      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.text('REJNOX'), findsOneWidget);
      expect(find.text('Lepší pohyb, zdravší ty.'), findsOneWidget);
      expect(done, isFalse);

      await tester.pump(const Duration(milliseconds: 800));
      expect(done, isTrue);
    });

    testWidgets('ťuknutie ju preskočí', (tester) async {
      var done = false;
      await tester.pumpWidget(_app(IntroAnimation(onDone: () => done = true)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byType(IntroAnimation));
      expect(done, isTrue);
    });

    testWidgets('pri vypnutých animáciách sa vynechá', (tester) async {
      await tester.pumpWidget(
        _app(const IntroGate(child: Text('appka')), reduced: true),
      );
      expect(find.byType(IntroAnimation), findsNothing);
      expect(find.text('appka'), findsOneWidget);
    });

    testWidgets('IntroGate po skončení ukáže appku', (tester) async {
      await tester.pumpWidget(_app(const IntroGate(child: Text('appka'))));
      expect(find.byType(IntroAnimation), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(IntroAnimation), findsNothing);
    });
  });

  group('oslava po prihlásení', () {
    testWidgets('pozdrav, vibrácia a koniec', (tester) async {
      final haptics = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String);
          }
          return null;
        },
      );
      var done = false;
      await tester.pumpWidget(
        _app(
          CelebrationOverlay(
            celebration: const Celebration(
              firstName: 'Jana',
              registered: false,
            ),
            onDone: () => done = true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1000));
      expect(haptics, isEmpty);
      await tester.pump(const Duration(milliseconds: 100));
      expect(haptics, ['HapticFeedbackType.heavyImpact']);

      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.text('Ahoj, Jana'), findsOneWidget);
      expect(find.text('Ideme na to.'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 800));
      expect(done, isTrue);
    });

    testWidgets('po registrácii iný nadpis, ťuknutie preskočí', (tester) async {
      var done = false;
      await tester.pumpWidget(
        _app(
          CelebrationOverlay(
            celebration: const Celebration(firstName: 'Jana', registered: true),
            onDone: () => done = true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 2000));
      expect(find.text('Vitaj v Rejnoxe, Jana'), findsOneWidget);
      await tester.tap(find.byType(CelebrationOverlay));
      expect(done, isTrue);
    });

    testWidgets('pri vypnutých animáciách len krátko', (tester) async {
      var done = false;
      await tester.pumpWidget(
        _app(
          CelebrationOverlay(
            celebration: const Celebration(
              firstName: 'Jana',
              registered: false,
            ),
            onDone: () => done = true,
          ),
          reduced: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Ahoj, Jana'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      expect(done, isTrue);
    });
  });

  group('kedy sa oslava spustí', () {
    Future<ProviderContainer> container(_Tokens tokens) async {
      final c = ProviderContainer(
        overrides: [
          tokenStoreProvider.overrideWithValue(tokens),
          authRepositoryProvider.overrideWithValue(_Repo()),
        ],
      );
      c.listen(authControllerProvider, (_, _) {});
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      return c;
    }

    test('po prihlásení áno, s krstným menom', () async {
      final c = await container(_Tokens());
      await c
          .read(authControllerProvider.notifier)
          .login(email: 'jana@test.sk', password: 'x');
      final cel = c.read(celebrationProvider);
      expect(cel?.title, 'Ahoj, Jana');
      c.dispose();
    });

    test('po registrácii s pozdravom pre nováčika', () async {
      final c = await container(_Tokens());
      await c
          .read(authControllerProvider.notifier)
          .register(
            email: 'jana@test.sk',
            password: 'heslo-123',
            displayName: 'Jana Nová',
            role: UserRole.member,
          );
      expect(c.read(celebrationProvider)?.title, 'Vitaj v Rejnoxe, Jana');
      c.dispose();
    });

    test('pri obnovení uloženej relácie nie', () async {
      final c = await container(_Tokens('t', _jana));
      expect(c.read(authControllerProvider), isA<SignedIn>());
      expect(c.read(celebrationProvider), isNull);
      c.dispose();
    });
  });
}
