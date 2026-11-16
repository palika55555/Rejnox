import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/chat_api.dart';
import '../domain/chat_models.dart';

const _signedOut = ApiError(401, 'unauthorized', 'Prihlás sa, prosím.');

String chatToken(Ref ref) => switch (ref.read(authControllerProvider)) {
  SignedIn(:final token) => token,
  _ => throw _signedOut,
};

/// Ako často sa v otvorenej konverzácii pýtame na novinky.
const chatPollInterval = Duration(seconds: 3);

/// O koľko sa kurzor priebežného načítania vracia späť, aby sa nestratila
/// správa, ktorú server zapísal skôr, ale potvrdil (commit) neskôr.
const _sinceOverlap = Duration(seconds: 10);

/// Ako často najviac povieme serveru „píšem“.
const _typingEvery = Duration(seconds: 4);

/// Zoznam konverzácií. Obnoví sa pri návrate na obrazovku a keď
/// upozornenia zistia nové správy.
final conversationsProvider = FutureProvider<List<Conversation>>((ref) {
  ref.watch(authControllerProvider);
  return ref.read(chatApiProvider).conversations(chatToken(ref));
});

/// Pôvodný názov (upozornenia ho pri nových správach obnovia).
final chatThreadsProvider = conversationsProvider;

final conversationDetailProvider = FutureProvider.autoDispose
    .family<ConversationDetail, String>((ref, id) {
      ref.watch(authControllerProvider);
      return ref.read(chatApiProvider).conversation(chatToken(ref), id);
    });

/// Konverzácia k prepojeniu tréner–klient (z karty trénera / klienta).
final linkConversationProvider = FutureProvider.autoDispose
    .family<String, String>((ref, linkId) {
      ref.watch(authControllerProvider);
      return ref.read(chatApiProvider).linkConversation(chatToken(ref), linkId);
    });

/// Ľudia, ktorým môžem písať (prepojenia a spoločné skupiny).
final chatContactsProvider = FutureProvider.autoDispose<List<ChatContact>>((
  ref,
) {
  ref.watch(authControllerProvider);
  return ref.read(chatApiProvider).contacts(chatToken(ref));
});

final blockedUsersProvider = FutureProvider.autoDispose<List<ChatContact>>((
  ref,
) {
  ref.watch(authControllerProvider);
  return ref.read(chatApiProvider).blocked(chatToken(ref));
});

/// Stav otvorenej konverzácie.
class ChatRoom {
  const ChatRoom({
    required this.messages,
    required this.canSend,
    this.typing = const [],
    this.readBy = const {},
    this.hasOlder = true,
    this.loadingOlder = false,
  });

  final List<ChatMessage> messages;
  final bool canSend;
  final List<String> typing;
  final Map<String, DateTime> readBy;

  /// Na serveri môžu byť ešte staršie správy.
  final bool hasOlder;
  final bool loadingOlder;

  ChatRoom copyWith({
    List<ChatMessage>? messages,
    bool? canSend,
    List<String>? typing,
    Map<String, DateTime>? readBy,
    bool? hasOlder,
    bool? loadingOlder,
  }) => ChatRoom(
    messages: messages ?? this.messages,
    canSend: canSend ?? this.canSend,
    typing: typing ?? this.typing,
    readBy: readBy ?? this.readBy,
    hasOlder: hasOlder ?? this.hasOlder,
    loadingOlder: loadingOlder ?? this.loadingOlder,
  );

  /// Moja posledná potvrdená správa, ktorú už všetci ostatní prečítali.
  ChatMessage? get lastSeenMine {
    if (readBy.isEmpty) return null;
    final seenUntil = readBy.values.reduce((a, b) => a.isBefore(b) ? a : b);
    for (final m in messages.reversed) {
      if (!m.mine || m.pending || m.isSystem) continue;
      return m.sentAt.isAfter(seenUntil) ? null : m;
    }
    return null;
  }
}

int _byTime(ChatMessage a, ChatMessage b) {
  if (a.pending != b.pending) return a.pending ? 1 : -1;
  final t = a.sentAt.compareTo(b.sentAt);
  return t != 0 ? t : a.id.compareTo(b.id);
}

/// Spojí známe správy s novými / zmenenými (podľa ID) a zoradí ich.
List<ChatMessage> mergeMessages(
  List<ChatMessage> known,
  List<ChatMessage> fresh,
) {
  final byId = {for (final m in known) m.id: m};
  for (final m in fresh) {
    byId[m.id] = m;
  }
  return byId.values.toList()..sort(_byTime);
}

/// Otvorená konverzácia: načíta správy, priebežne dopĺňa novinky
/// (nové, upravené, zmazané, reakcie) a posiela.
class ChatRoomController extends AsyncNotifier<ChatRoom> {
  ChatRoomController(this.conversationId);

  final String conversationId;
  Timer? _poll;
  bool _polling = false;
  DateTime? _lastTyping;

  ChatApi get _api => ref.read(chatApiProvider);

  @override
  Future<ChatRoom> build() async {
    ref.watch(authControllerProvider);
    _poll?.cancel();
    _poll = Timer.periodic(chatPollInterval, (_) => refresh());
    ref.onDispose(() => _poll?.cancel());
    final page = await _api.messages(chatToken(ref), conversationId);
    ref.invalidate(conversationsProvider);
    return ChatRoom(
      messages: page.messages,
      canSend: page.canSend,
      typing: page.typing,
      readBy: page.readBy,
      hasOlder: page.messages.length >= 50,
    );
  }

  /// Kurzor pre priebežné načítanie: posledná zmena mínus rezerva.
  String? get _since {
    DateTime? newest;
    for (final m in state.value?.messages ?? const <ChatMessage>[]) {
      final raw = m.rawUpdatedAt;
      final at = raw == null ? null : DateTime.tryParse(raw);
      if (at != null && (newest == null || at.isAfter(newest))) newest = at;
    }
    return newest?.toUtc().subtract(_sinceOverlap).toIso8601String();
  }

  void _replace(ChatMessage message) {
    final room = state.value;
    if (room == null) return;
    state = AsyncData(
      room.copyWith(messages: mergeMessages(room.messages, [message])),
    );
  }

  /// Doplní novinky od posledného načítania.
  Future<void> refresh() async {
    final room = state.value;
    if (_polling || room == null) return;
    _polling = true;
    try {
      final page = await _api.messages(
        chatToken(ref),
        conversationId,
        since: _since,
      );
      final current = state.value ?? room;
      final known = {for (final m in current.messages) m.id};
      final news = page.messages.any((m) => !known.contains(m.id) && !m.mine);
      state = AsyncData(
        current.copyWith(
          messages: mergeMessages(current.messages, page.messages),
          canSend: page.canSend,
          typing: page.typing,
          readBy: page.readBy,
        ),
      );
      if (news) ref.invalidate(conversationsProvider);
    } on ApiError {
      // Výpadok spojenia: skúsi sa to znova pri ďalšom kole.
    } finally {
      _polling = false;
    }
  }

  /// Dočíta staršie správy (pri posune na začiatok).
  Future<void> loadOlder() async {
    final room = state.value;
    if (room == null || !room.hasOlder || room.loadingOlder) return;
    final oldest = room.messages
        .where((m) => !m.pending && m.rawSentAt != null)
        .firstOrNull;
    if (oldest == null) {
      state = AsyncData(room.copyWith(hasOlder: false));
      return;
    }
    state = AsyncData(room.copyWith(loadingOlder: true));
    try {
      final page = await _api.messages(
        chatToken(ref),
        conversationId,
        before: oldest.rawSentAt,
      );
      final current = state.value ?? room;
      state = AsyncData(
        current.copyWith(
          messages: mergeMessages(current.messages, page.messages),
          hasOlder: page.messages.length >= 50,
          loadingOlder: false,
        ),
      );
    } on ApiError {
      state = AsyncData((state.value ?? room).copyWith(loadingOlder: false));
    }
  }

  Future<void> _sendPending(
    ChatMessage pending,
    Future<ChatMessage> Function(String token) request,
  ) async {
    final room = state.value;
    if (room != null) {
      state = AsyncData(room.copyWith(messages: [...room.messages, pending]));
    }
    try {
      final sent = await request(chatToken(ref));
      final current = state.value;
      if (current != null) {
        state = AsyncData(
          current.copyWith(
            messages: mergeMessages(
              [
                for (final m in current.messages)
                  if (m.id != pending.id) m,
              ],
              [sent],
            ),
          ),
        );
      }
      ref.invalidate(conversationsProvider);
    } on Object {
      final current = state.value;
      if (current != null) {
        state = AsyncData(
          current.copyWith(
            messages: [
              for (final m in current.messages)
                if (m.id != pending.id) m,
            ],
          ),
        );
      }
      rethrow;
    }
  }

  String _tempId() => 'pending-${DateTime.now().microsecondsSinceEpoch}';

  ReplyPreview? _replyPreview(ChatMessage? to) => to == null
      ? null
      : ReplyPreview(
          id: to.id,
          kind: to.kind,
          body: to.body,
          senderName: to.senderName,
          deleted: to.deleted,
        );

  /// Pošle správu. Kým ju server nepotvrdí, je v zozname ako „odosiela sa“.
  /// Pri chybe ju odoberie a chybu pošle ďalej (obrazovka ju ukáže).
  Future<void> send(String body, {ChatMessage? replyTo}) async {
    final text = body.trim();
    if (text.isEmpty) return;
    _lastTyping = null;
    await _sendPending(
      ChatMessage(
        id: _tempId(),
        kind: MessageKind.text,
        body: text,
        sentAt: DateTime.now(),
        mine: true,
        pending: true,
        replyTo: _replyPreview(replyTo),
      ),
      (token) => _api.send(token, conversationId, text, replyTo: replyTo?.id),
    );
  }

  Future<void> sendImage(List<int> bytes, {ChatMessage? replyTo}) =>
      _sendPending(
        ChatMessage(
          id: _tempId(),
          kind: MessageKind.image,
          body: null,
          sentAt: DateTime.now(),
          mine: true,
          pending: true,
          localImage: bytes,
          replyTo: _replyPreview(replyTo),
        ),
        (token) =>
            _api.sendImage(token, conversationId, bytes, replyTo: replyTo?.id),
      );

  Future<void> edit(String messageId, String body) async =>
      _replace(await _api.edit(chatToken(ref), messageId, body.trim()));

  /// Skryje správu len v telefóne (pred potvrdením zmazania na serveri).
  void hideLocally(ChatMessage message) => _replace(_tombstone(message));

  /// Vráti skrytú správu späť (používateľ ťukol na „Späť“).
  void restoreLocally(ChatMessage message) => _replace(message);

  Future<void> delete(ChatMessage message) async {
    await _api.deleteMessage(chatToken(ref), message.id);
    _replace(_tombstone(message));
    ref.invalidate(conversationsProvider);
  }

  ChatMessage _tombstone(ChatMessage message) => ChatMessage(
    id: message.id,
    kind: message.kind,
    body: null,
    sentAt: message.sentAt,
    rawSentAt: message.rawSentAt,
    rawUpdatedAt: message.rawUpdatedAt,
    mine: message.mine,
    senderId: message.senderId,
    senderName: message.senderName,
    deleted: true,
  );

  /// Ťuk na reakciu: rovnaká ju odoberie, iná ju nahradí.
  Future<void> toggleReaction(ChatMessage message, String emoji) async {
    final mine = message.reactions.where((r) => r.mine).firstOrNull;
    final next = mine?.emoji == emoji ? null : emoji;
    _replace(await _api.react(chatToken(ref), message.id, next));
  }

  /// Povie serveru, že píšem (najviac raz za pár sekúnd).
  void typing() {
    final now = DateTime.now();
    final last = _lastTyping;
    if (last != null && now.difference(last) < _typingEvery) return;
    _lastTyping = now;
    unawaited(
      _api.typing(chatToken(ref), conversationId).catchError((Object _) {}),
    );
  }
}

final chatRoomProvider = AsyncNotifierProvider.autoDispose
    .family<ChatRoomController, ChatRoom, String>(ChatRoomController.new);
