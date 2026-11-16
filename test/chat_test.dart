import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rejnox/core/api/api_client.dart';
import 'package:rejnox/features/auth/domain/auth_models.dart';
import 'package:rejnox/features/auth/presentation/auth_controller.dart';
import 'package:rejnox/features/chat/application/chat_actions.dart';
import 'package:rejnox/features/chat/application/chat_providers.dart';
import 'package:rejnox/features/chat/data/chat_api.dart';
import 'package:rejnox/features/chat/domain/chat_models.dart';
import 'package:rejnox/features/chat/presentation/chat_screen.dart';
import 'package:rejnox/features/chat/presentation/chat_widgets.dart';
import 'package:rejnox/features/chat/presentation/chats_screen.dart';
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

String _iso(int minute, [int second = 0]) =>
    DateTime.utc(2026, 11, 15, 10, minute, second).toIso8601String();

ChatMessage _msg(
  String id,
  String body, {
  bool mine = false,
  int minute = 0,
  String sender = 'Tomáš',
  MessageKind kind = MessageKind.text,
  List<Reaction> reactions = const [],
  bool edited = false,
  int updatedMinute = -1,
}) => ChatMessage.fromJson({
  'id': id,
  'kind': kind.name,
  'body': body,
  'sentAt': _iso(minute),
  'updatedAt': _iso(updatedMinute < 0 ? minute : updatedMinute),
  'mine': mine,
  'senderId': mine ? 'u1' : 'u-$sender',
  'senderName': mine ? 'Anna' : sender,
  'edited': edited,
  'reactions': [
    for (final r in reactions)
      {'emoji': r.emoji, 'count': r.count, 'mine': r.mine},
  ],
});

Conversation _conv(
  String id,
  String title, {
  bool group = false,
  int unread = 0,
}) => Conversation.fromJson({
  'id': id,
  'kind': group ? 'group' : 'link',
  'title': title,
  'otherRole': 'trainer',
  'canSend': true,
  'muted': false,
  'unread': unread,
  'memberCount': group ? 3 : 2,
  'myRole': 'member',
});

/// Server v pamäti: správy podľa konverzácie, ?since= vráti zmenené.
class FakeChatApi implements ChatApi {
  final messagesByConv = <String, List<ChatMessage>>{};
  final conversationsList = <Conversation>[];
  final sent = <String>[];
  final sinceCursors = <String?>[];
  final replies = <String?>[];
  final reactions = <String?>[];
  Map<String, DateTime> readBy = const {};
  Object? sendError;

  @override
  Future<List<Conversation>> conversations(String token) async =>
      conversationsList;

  @override
  Future<MessagePage> messages(
    String token,
    String conversationId, {
    String? before,
    String? since,
  }) async {
    sinceCursors.add(since);
    final all = messagesByConv[conversationId] ?? const [];
    return MessagePage(
      canSend: true,
      readBy: readBy,
      messages: since == null
          ? all
          : [
              for (final m in all)
                if (DateTime.parse(
                  m.rawUpdatedAt!,
                ).isAfter(DateTime.parse(since)))
                  m,
            ],
    );
  }

  @override
  Future<ChatMessage> send(
    String token,
    String conversationId,
    String body, {
    String? replyTo,
  }) async {
    if (sendError != null) throw sendError!;
    sent.add(body);
    replies.add(replyTo);
    final m = _msg('s${sent.length}', body, mine: true, minute: 30);
    messagesByConv[conversationId] = [...?messagesByConv[conversationId], m];
    return m;
  }

  @override
  Future<ChatMessage> react(
    String token,
    String messageId,
    String? emoji,
  ) async {
    reactions.add(emoji);
    return _msg(
      messageId,
      'Zajtra nohy',
      minute: 2,
      reactions: [
        if (emoji != null) Reaction(emoji: emoji, count: 1, mine: true),
      ],
    );
  }

  @override
  Future<void> typing(String token, String conversationId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
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
    test('čas správy a nadpis dňa', () {
      final now = DateTime(2026, 11, 15, 18);
      expect(shortTime(DateTime(2026, 11, 15, 9, 5), now: now), '9:05');
      expect(shortTime(DateTime(2026, 11, 14, 9, 5), now: now), '14. 11.');
      expect(dayLabel(DateTime(2026, 11, 15, 1), now: now), 'Dnes');
      expect(dayLabel(DateTime(2026, 11, 14, 23), now: now), 'Včera');
      expect(dayLabel(DateTime(2025, 3, 2), now: now), '2. 3. 2025');
    });

    test('konverzácia zo servera', () {
      final c = Conversation.fromJson({
        'id': 'c1',
        'kind': 'group',
        'title': 'Ranný beh',
        'canSend': true,
        'muted': true,
        'unread': 3,
        'memberCount': 5,
        'myRole': 'admin',
        'lastMessage': {
          'kind': 'image',
          'body': null,
          'sentAt': '2026-11-15T10:00:00.123456+00:00',
          'mine': false,
          'senderName': 'Jana',
          'deleted': false,
        },
      });
      expect(c.isGroup, isTrue);
      expect(c.isAdmin, isTrue);
      expect(c.muted, isTrue);
      expect(c.subtitle, 'Skupina · 5 členov');
      expect(c.lastMessage!.preview, '📷 Fotka');
    });

    test('stránka správ: odpoveď, reakcie, kto píše a kto čítal', () {
      final page = MessagePage.fromJson({
        'canSend': false,
        'typing': ['Jana'],
        'readBy': [
          {'userId': 'u2', 'lastReadAt': _iso(5)},
        ],
        'messages': [
          {
            'id': 'm1',
            'kind': 'text',
            'body': 'Áno',
            'sentAt': _iso(1),
            'updatedAt': _iso(1),
            'mine': true,
            'replyTo': {
              'id': 'm0',
              'kind': 'text',
              'body': null,
              'senderName': 'Jana',
              'deleted': true,
            },
            'reactions': [
              {'emoji': '🔥', 'count': 2, 'mine': false},
            ],
          },
        ],
      });
      expect(page.canSend, isFalse);
      expect(page.typing, ['Jana']);
      expect(page.readBy.keys, ['u2']);
      final m = page.messages.single;
      expect(m.replyTo!.preview, 'Správa bola odstránená');
      expect(m.reactions.single.count, 2);
    });

    test('spojenie správ: zmenená nahradí pôvodnú, poradie podľa času', () {
      final merged = mergeMessages(
        [_msg('a', 'prvá', minute: 1), _msg('b', 'druhá', minute: 2)],
        [
          _msg('b', 'druhá (upravená)', minute: 2, edited: true),
          _msg('c', 'tretia', minute: 3),
        ],
      );
      expect(merged.map((m) => m.body), ['prvá', 'druhá (upravená)', 'tretia']);
      expect(merged[1].edited, isTrue);
    });

    test('„Videné“ je pri mojej poslednej správe, ktorú prečítali všetci', () {
      final room = ChatRoom(
        canSend: true,
        messages: [
          _msg('a', 'moja 1', mine: true, minute: 1),
          _msg('b', 'moja 2', mine: true, minute: 6),
        ],
        readBy: {'u2': DateTime.parse(_iso(5))},
      );
      // Druhú ešte nikto nečítal → nič „Videné“ (posledná moja je nová).
      expect(room.lastSeenMine, isNull);
      final read = room.copyWith(readBy: {'u2': DateTime.parse(_iso(7))});
      expect(read.lastSeenMine?.id, 'b');
    });
  });

  group('konverzácia', () {
    late FakeChatApi api;
    late ProviderContainer container;

    setUp(() {
      api = FakeChatApi()
        ..messagesByConv['c1'] = [
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
        final sub = container.listen(chatRoomProvider('c1'), (_, _) {});
        addTearDown(sub.close);
        await container.read(chatRoomProvider('c1').future);
        final room = container.read(chatRoomProvider('c1').notifier);

        await room.send('  Super  ', replyTo: api.messagesByConv['c1']!.first);
        await room.refresh();

        final bodies = [
          for (final m
              in container.read(chatRoomProvider('c1')).value!.messages)
            m.body,
        ];
        expect(bodies, ['Ahoj', 'Zajtra nohy', 'Super']);
        expect(api.sent, ['Super']);
        expect(api.replies, ['m1']);
        // Priebežné načítanie sa pýta na zmeny od poslednej (s rezervou).
        expect(api.sinceCursors.last, isNotNull);
      },
    );

    test('úprava na serveri sa prejaví pri priebežnom načítaní', () async {
      final sub = container.listen(chatRoomProvider('c1'), (_, _) {});
      addTearDown(sub.close);
      await container.read(chatRoomProvider('c1').future);

      api.messagesByConv['c1'] = [
        _msg('m1', 'Ahoj', minute: 1),
        _msg('m2', 'Zajtra ruky', minute: 2, edited: true, updatedMinute: 9),
      ];
      await container.read(chatRoomProvider('c1').notifier).refresh();

      final m2 = container
          .read(chatRoomProvider('c1'))
          .value!
          .messages
          .firstWhere((m) => m.id == 'm2');
      expect(m2.body, 'Zajtra ruky');
      expect(m2.edited, isTrue);
    });

    test('pri chybe sa neodoslaná správa zo zoznamu odoberie', () async {
      final sub = container.listen(chatRoomProvider('c1'), (_, _) {});
      addTearDown(sub.close);
      await container.read(chatRoomProvider('c1').future);
      api.sendError = const ApiError(403, 'chat_forbidden', 'Nedá sa písať.');

      await expectLater(
        container.read(chatRoomProvider('c1').notifier).send('Haló'),
        throwsA(isA<ApiError>()),
      );
      expect(
        container.read(chatRoomProvider('c1')).value!.messages,
        hasLength(2),
      );
    });

    test('reakcia: ťuk pridá, rovnaký ťuk odoberie', () async {
      final sub = container.listen(chatRoomProvider('c1'), (_, _) {});
      addTearDown(sub.close);
      await container.read(chatRoomProvider('c1').future);
      final room = container.read(chatRoomProvider('c1').notifier);

      ChatMessage m2() => container
          .read(chatRoomProvider('c1'))
          .value!
          .messages
          .firstWhere((m) => m.id == 'm2');
      await room.toggleReaction(m2(), '🔥');
      expect(m2().reactions.single.emoji, '🔥');
      await room.toggleReaction(m2(), '🔥');
      expect(api.reactions, ['🔥', null]);
      expect(m2().reactions, isEmpty);
    });

    test('ID prihláseného pre odchod zo skupiny', () {
      expect(container.read(chatActionsProvider).myId, 'u1');
    });
  });

  group('obrazovky', () {
    late FakeChatApi api;

    Widget app(Widget home) => ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_SignedIn.new),
        chatApiProvider.overrideWithValue(api),
        notificationsApiProvider.overrideWithValue(FakeNotificationsApi()),
        phoneAlertsProvider.overrideWithValue(FakePhoneAlerts()),
      ],
      child: MaterialApp(home: Scaffold(body: home)),
    );

    setUp(() {
      api = FakeChatApi()
        ..conversationsList.addAll([
          _conv('c1', 'Tréner Tomáš'),
          _conv('g1', 'Ranný beh', group: true, unread: 4),
        ])
        ..messagesByConv['g1'] = [
          ChatMessage.fromJson({
            'id': 's1',
            'kind': 'system',
            'body': 'Tomáš pridal(a) Annu.',
            'sentAt': _iso(0),
            'updatedAt': _iso(0),
            'mine': false,
          }),
          _msg('m1', 'Ahoj všetci', minute: 1, sender: 'Tomáš'),
          _msg('m2', 'Idem aj ja', minute: 2, sender: 'Jana'),
        ];
    });

    testWidgets('zoznam ukáže skupinu s neprečítanými', (tester) async {
      await tester.pumpWidget(app(const ChatsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Ranný beh'), findsOneWidget);
      expect(find.text('Skupina · 3 členovia'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Tréner Tomáš'), findsOneWidget);
    });

    testWidgets('skupina: mená, systémová správa, odpoveď a odoslanie', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(const ConversationScreen(conversationId: 'g1', title: 'Ranný beh')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tomáš pridal(a) Annu.'), findsOneWidget);
      expect(find.text('Jana'), findsOneWidget);
      expect(find.text('Idem aj ja'), findsOneWidget);

      // Podržanie → Odpovedať → nad poľom je, komu odpovedám.
      await tester.longPress(find.text('Idem aj ja'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Odpovedať'));
      await tester.pumpAndSettle();
      expect(find.text('Odpoveď pre Jana'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Super, vidíme sa');
      await tester.pump();
      await tester.tap(find.byTooltip('Odoslať'));
      await tester.pumpAndSettle();

      expect(api.sent, ['Super, vidíme sa']);
      expect(api.replies, ['m2']);
      expect(find.text('Odpoveď pre Jana'), findsNothing);
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
