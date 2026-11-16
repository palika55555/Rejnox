import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rejnox/core/theme/app_theme.dart';
import 'package:rejnox/features/auth/domain/auth_models.dart';
import 'package:rejnox/features/auth/presentation/auth_controller.dart';
import 'package:rejnox/features/community/data/community_api.dart';
import 'package:rejnox/features/community/domain/community_models.dart';
import 'package:rejnox/features/community/presentation/community_screen.dart';
import 'package:rejnox/features/home/domain/home_overview.dart';

class _SignedIn extends AuthController {
  @override
  AuthState build() => const SignedIn(
    user: AuthUser(
      id: 'u1',
      email: 'a@test.sk',
      displayName: 'Anna',
      role: UserRole.member,
    ),
    token: 'ok',
  );
}

/// Komunita v pamäti: len to, čo testy potrebujú.
class _FakeCommunityApi extends Fake implements CommunityApi {
  final stored = <CommunityPost>[];
  var board = const Leaderboard(optedIn: false, entries: []);
  var challengeList = <Challenge>[];

  @override
  Future<List<CommunityPost>> posts(String token, {DateTime? before}) async =>
      List.of(stored);

  @override
  Future<CommunityPost> createPost(String token, String body) async {
    final post = CommunityPost(
      id: 'p${stored.length + 1}',
      authorName: 'Anna',
      body: body,
      createdAt: DateTime.now(),
      likes: 0,
      comments: 0,
      likedByMe: false,
      mine: true,
    );
    stored.insert(0, post);
    return post;
  }

  @override
  Future<CommunityPost> setLike(String token, String postId, bool liked) async {
    final i = stored.indexWhere((p) => p.id == postId);
    final p = stored[i];
    stored[i] = p.copyWith(likedByMe: liked, likes: p.likes + (liked ? 1 : -1));
    return stored[i];
  }

  @override
  Future<List<Challenge>> challenges(String token) async => challengeList;

  @override
  Future<Leaderboard> leaderboard(String token) async => board;

  @override
  Future<Leaderboard> setLeaderboardOptIn(String token, bool enabled) async =>
      board = Leaderboard(
        optedIn: enabled,
        entries: [
          const LeaderboardEntry(name: 'Peter', city: null, days: 5, me: false),
          const LeaderboardEntry(name: 'Zuza', city: null, days: 4, me: false),
          LeaderboardEntry(name: 'Anna', city: 'Nitra', days: 3, me: enabled),
          const LeaderboardEntry(name: 'Ivo', city: null, days: 1, me: false),
        ],
      );
}

Future<_FakeCommunityApi> _pump(
  WidgetTester tester, [
  _FakeCommunityApi? api,
]) async {
  final fake = api ?? _FakeCommunityApi();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_SignedIn.new),
        communityApiProvider.overrideWithValue(fake),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(webFonts: false),
        home: const Scaffold(body: CommunityScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

Future<void> _openSection(WidgetTester tester, String label) async {
  await tester.dragUntilVisible(
    find.text(label),
    find.byType(ListView).first,
    const Offset(-150, 0),
  );
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('bez príspevkov ukáže prázdny stav, nie vymyslené dáta', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Zatiaľ nič…'), findsOneWidget);
    expect(find.textContaining('Zatiaľ tu nie sú žiadne príspevky'), findsOne);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nový príspevok sa uloží na server a ukáže sa vo feede', (
    tester,
  ) async {
    final api = await _pump(tester);

    await tester.tap(find.text('Nový príspevok'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Nový rekord v drepe');
    await tester.tap(find.text('Zdieľať'));
    await tester.pumpAndSettle();

    expect(api.stored.single.body, 'Nový rekord v drepe');
    expect(find.text('Nový rekord v drepe'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pumpAndSettle();
    expect(api.stored.single.likes, 1);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });

  testWidgets('rebríček sa ukáže až so súhlasom a zvýrazní ma', (tester) async {
    await _pump(tester);
    await _openSection(tester, 'Rebríčky');

    expect(find.text('Ukázať ma v rebríčku'), findsOneWidget);
    expect(find.textContaining('ešte nikto z rebríčka'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('Peter'), findsOneWidget);
    expect(find.text('Anna (ty)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('výzva ukazuje môj skutočný pokrok', (tester) async {
    final api = _FakeCommunityApi()
      ..challengeList = [
        Challenge(
          id: 'c1',
          title: '12 tréningov v novembri',
          description: null,
          goalDays: 12,
          startsOn: DateTime(2026, 11),
          endsOn: DateTime(2026, 11, 30),
          members: 3,
          joined: true,
          mine: false,
          myDays: 4,
        ),
      ];
    await _pump(tester, api);
    await _openSection(tester, 'Výzvy');

    expect(find.text('12 tréningov v novembri'), findsOneWidget);
    expect(find.text('4 z 12 dní s tréningom'), findsOneWidget);
  });

  test('domov načíta rebríček a parťáka zo servera', () {
    final home = HomeOverview.fromJson({
      'streakDays': 2,
      'weeklyGoal': {'done': 1, 'total': 3},
      'todayWorkout': null,
      'personalRecord': null,
      'ranking': {'position': 2, 'total': 9, 'days': 4},
      'partnerRequest': {
        'id': 's1',
        'hostName': 'Tomáš',
        'startsAt': '2026-11-20T17:00:00.000Z',
        'focus': 'Nohy',
        'place': 'Fitko Nivy',
      },
    });

    expect(home.ranking?.position, 2);
    expect(home.partnerRequest?.name, 'Tomáš');
    expect(home.partnerRequest?.place, 'Fitko Nivy');
  });
}
