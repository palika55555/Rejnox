import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rejnox/core/api/api_client.dart';
import 'package:rejnox/features/auth/domain/auth_models.dart';
import 'package:rejnox/features/auth/presentation/auth_controller.dart';
import 'package:rejnox/features/chat/application/chat_providers.dart';
import 'package:rejnox/features/chat/data/chat_api.dart';
import 'package:rejnox/features/chat/domain/chat_models.dart';
import 'package:rejnox/features/chat/presentation/chat_screen.dart';
import 'package:rejnox/features/chat/presentation/chat_widgets.dart';
import 'package:rejnox/features/notifications/notification_models.dart';
import 'package:rejnox/features/notifications/notifications_api.dart';
import 'package:rejnox/features/notifications/notifications_controller.dart';
import 'package:rejnox/features/notifications/phone_alerts.dart';

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

ChatMessage _msg(String id, String body, {bool mine = false, int minute = 0}) {
  final at = DateTime.utc(2026, 11, 15, 10, minute);
  return ChatMessage(
    id: id,
    body: body,
    sentAt: at.toLocal(),
    rawSentAt: at.toIso8601String(),
    mine: mine,
  );
}

class FakeChatApi implements ChatApi {
  final messagesByLink = <String, List<ChatMessage>>{};
  final sent = <String>[];
  final afterCursors = <String?>[];
  Object? sendError;

  @override
  Future<List<ChatThread>> threads(String token) async => [
    const ChatThread(
      linkId: 'l1',
      name: 'Tréner Tomáš',
      withTrainer: true,
      canSend: true,
      unread: 0,
    ),
  ];

  @override
  Future<List<ChatMessage>> messages(
    String token,
    String linkId, {
    String? after,
  }) async {
    afterCursors.add(after);
    final all = messagesByLink[linkId] ?? const [];
    if (after == null) return all;
    return [
      for (final m in all)
        if (m.rawSentAt!.compareTo(after) > 0) m,
    ];
  }

  @override
  Future<ChatMessage> send(String token, String linkId, String body) async {
    if (sendError != null) throw sendError!;
    sent.add(body);
    final m = _msg('s${sent.length}', body, mine: true, minute: 30);
    messagesByLink[linkId] = [...?messagesByLink[linkId], m];
    return m;
  }
}

class FakeNotificationsApi implements NotificationsApi {
  NotificationFeed next = const NotificationFeed();
  final readIds = <String?>[];
  final deleted = <String>[];

  @override
  Future<NotificationFeed> feed(String token) async => next;

  @override
  Future<void> markRead(String token, {String? id}) async => readIds.add(id);

  @override
  Future<void> delete(String token, String id) async => deleted.add(id);
}

class FakePhoneAlerts implements PhoneAlerts {
  final shown = <String>[];
  int permissionRequests = 0;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    String? body,
    bool message = false,
  }) async => shown.add(title);
}

AppNotification _note(String id, {bool read = false}) => AppNotification(
  id: id,
  kind: 'plan',
  title: 'Nový plán od trénera',
  body: 'Tomáš: Nohy',
  linkId: 'l1',
  createdAt: DateTime(2026, 11, 15),
  read: read,
);

void main() {
  group('pomocné', () {
    test('čas správy: dnes hodiny, inak dátum', () {
      final now = DateTime(2026, 11, 15, 18);
      expect(shortTime(DateTime(2026, 11, 15, 9, 5), now: now), '9:05');
      expect(shortTime(DateTime(2026, 11, 14, 9, 5), now: now), '14. 11.');
    });

    test('konverzácia zo servera', () {
      final t = ChatThread.fromJson({
        'linkId': 'l1',
        'name': 'Klient Peter',
        'otherRole': 'client',
        'canSend': false,
        'unread': 3,
        'lastMessage': {
          'body': 'Ahoj',
          'sentAt': '2026-11-15T10:00:00.123456+00:00',
          'mine': true,
        },
      });
      expect(t.withTrainer, isFalse);
      expect(t.canSend, isFalse);
      expect(t.unread, 3);
      expect(t.lastMessage!.body, 'Ahoj');
      expect(t.lastMessage!.mine, isTrue);
    });
  });

  group('chat', () {
    late FakeChatApi api;
    late ProviderContainer container;

    setUp(() {
      api = FakeChatApi()
        ..messagesByLink['l1'] = [
          _msg('m1', 'Ahoj', minute: 1),
          _msg('m2', 'Zajtra nohy', minute: 2),
        ];
      container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(_SignedIn.new),
          chatApiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);
    });

    test(
      'odoslaná správa je v zozname raz, aj po priebežnom načítaní',
      () async {
        final sub = container.listen(chatProvider('l1'), (_, _) {});
        addTearDown(sub.close);
        await container.read(chatProvider('l1').future);

        await container.read(chatProvider('l1').notifier).send('  Super  ');
        await container.read(chatProvider('l1').notifier).refresh();

        final bodies = [
          for (final m in container.read(chatProvider('l1')).value!) m.body,
        ];
        expect(bodies, ['Ahoj', 'Zajtra nohy', 'Super']);
        expect(api.sent, ['Super']);
        // Priebežné načítanie sa pýta len na novšie ako posledná správa.
        expect(api.afterCursors.last, isNotNull);
      },
    );

    test('pri chybe sa neodoslaná správa zo zoznamu odoberie', () async {
      final sub = container.listen(chatProvider('l1'), (_, _) {});
      addTearDown(sub.close);
      await container.read(chatProvider('l1').future);
      api.sendError = const ApiError(
        409,
        'chat_closed',
        'Spolupráca skončila, písať už nejde.',
      );

      await expectLater(
        container.read(chatProvider('l1').notifier).send('Haló'),
        throwsA(isA<ApiError>()),
      );
      expect(container.read(chatProvider('l1')).value, hasLength(2));
    });

    testWidgets('obrazovka ukáže správy a pošle novú', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(_SignedIn.new),
            chatApiProvider.overrideWithValue(api),
          ],
          child: const MaterialApp(
            home: ChatScreen(linkId: 'l1', name: 'Tréner Tomáš'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('TRÉNER TOMÁŠ'), findsOneWidget);
      expect(find.text('Zajtra nohy'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Môžem o 18:00?');
      await tester.pump();
      await tester.tap(find.byTooltip('Odoslať'));
      await tester.pumpAndSettle();

      expect(api.sent, ['Môžem o 18:00?']);
      expect(find.text('Môžem o 18:00?'), findsOneWidget);
      // Zrušiť priebežné načítanie spolu s obrazovkou.
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('upozornenia', () {
    testWidgets('načítajú sa po prihlásení, dajú sa prečítať a zmazať', (
      tester,
    ) async {
      final api = FakeNotificationsApi()
        ..next = NotificationFeed(
          notifications: [_note('n1'), _note('n2', read: true)],
          unread: 1,
          unreadMessages: 2,
        );
      final alerts = FakePhoneAlerts();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(_SignedIn.new),
          notificationsApiProvider.overrideWithValue(api),
          phoneAlertsProvider.overrideWithValue(alerts),
        ],
      );
      addTearDown(container.dispose);

      final feed = await container.read(notificationsProvider.future);
      expect(feed.unread, 1);
      expect(feed.unreadMessages, 2);
      expect(alerts.permissionRequests, 1);
      // Prvé načítanie nič nehlási, to sú staré veci.
      expect(alerts.shown, isEmpty);

      await container.read(notificationsProvider.notifier).markRead('n1');
      expect(container.read(notificationsProvider).value!.unread, 0);
      expect(api.readIds, ['n1']);

      await container.read(notificationsProvider.notifier).delete('n2');
      expect(
        container
            .read(notificationsProvider)
            .value!
            .notifications
            .map((n) => n.id),
        ['n1'],
      );
      expect(api.deleted, ['n2']);

      await container.read(notificationsProvider.notifier).markAllRead();
      expect(api.readIds.last, isNull);
      // Zastaví priebežné načítanie ešte pred kontrolou časovačov.
      container.dispose();
    });
  });
}
