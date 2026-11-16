DateTime _time(Object? value) =>
    (value is String ? DateTime.tryParse(value) : null)?.toLocal() ??
    DateTime.now();

/// Reakcie, ktoré server prijme (rovnaký zoznam ako v databáze).
const chatReactions = ['👍', '❤️', '😂', '😮', '😢', '🔥', '💪', '👏'];

enum ConversationKind {
  /// Tréner a klient (jedna konverzácia na prepojenie).
  link,

  /// Súkromná konverzácia dvoch ľudí, ktorí sa poznajú.
  direct,

  /// Skupina s názvom, správcami a členmi.
  group;

  static ConversationKind parse(Object? value) => switch (value) {
    'link' => link,
    'group' => group,
    _ => direct,
  };
}

enum MessageKind {
  text,
  image,

  /// Napr. „Jana pridala Petra“ (vzniká na serveri).
  system;

  static MessageKind parse(Object? value) => switch (value) {
    'image' => image,
    'system' => system,
    _ => text,
  };
}

/// Krátky text správy do zoznamu a do citácie odpovede.
String messagePreview({
  required MessageKind kind,
  required String? body,
  required bool deleted,
}) {
  if (deleted) return 'Správa bola odstránená';
  if (kind == MessageKind.image) return '📷 Fotka';
  return body ?? '';
}

class LastMessage {
  const LastMessage({
    required this.kind,
    required this.body,
    required this.sentAt,
    required this.mine,
    required this.senderName,
    required this.deleted,
  });

  factory LastMessage.fromJson(Map<String, dynamic> json) => LastMessage(
    kind: MessageKind.parse(json['kind']),
    body: json['body'] as String?,
    sentAt: _time(json['sentAt']),
    mine: json['mine'] as bool? ?? false,
    senderName: json['senderName'] as String?,
    deleted: json['deleted'] as bool? ?? false,
  );

  final MessageKind kind;
  final String? body;
  final DateTime sentAt;
  final bool mine;
  final String? senderName;
  final bool deleted;

  String get preview =>
      messagePreview(kind: kind, body: body, deleted: deleted);
}

/// Konverzácia v zozname.
class Conversation {
  const Conversation({
    required this.id,
    required this.kind,
    required this.title,
    required this.canSend,
    required this.muted,
    required this.unread,
    required this.memberCount,
    required this.isAdmin,
    this.linkId,
    this.otherUserId,
    this.otherRole,
    this.lastMessage,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final last = json['lastMessage'];
    return Conversation(
      id: json['id'] as String,
      kind: ConversationKind.parse(json['kind']),
      title: json['title'] as String? ?? '',
      linkId: json['linkId'] as String?,
      otherUserId: json['otherUserId'] as String?,
      otherRole: json['otherRole'] as String?,
      canSend: json['canSend'] as bool? ?? false,
      muted: json['muted'] as bool? ?? false,
      unread: json['unread'] as int? ?? 0,
      memberCount: json['memberCount'] as int? ?? 0,
      isAdmin: json['myRole'] == 'admin',
      lastMessage: last is Map<String, dynamic>
          ? LastMessage.fromJson(last)
          : null,
    );
  }

  final String id;
  final ConversationKind kind;

  /// Názov skupiny alebo meno druhej strany.
  final String title;
  final String? linkId;
  final String? otherUserId;

  /// "trainer", "client" alebo "member".
  final String? otherRole;
  final bool canSend;
  final bool muted;
  final int unread;
  final int memberCount;

  /// Som správca skupiny.
  final bool isAdmin;
  final LastMessage? lastMessage;

  bool get isGroup => kind == ConversationKind.group;

  /// Krátky popis pod názvom („Tréner“, „Skupina · 5 členov“…).
  String get subtitle => switch (kind) {
    ConversationKind.group => 'Skupina · ${memberLabel(memberCount)}',
    ConversationKind.link => [
      otherRole == 'trainer' ? 'Tvoj tréner' : 'Tvoj klient',
      if (!canSend) 'spolupráca ukončená',
    ].join(' · '),
    ConversationKind.direct => [
      otherRole == 'trainer' ? 'Tréner' : 'Súkromná správa',
      if (!canSend) 'písanie nie je možné',
    ].join(' · '),
  };
}

String memberLabel(int n) => switch (n) {
  1 => '1 člen',
  >= 2 && <= 4 => '$n členovia',
  _ => '$n členov',
};

class ChatMember {
  const ChatMember({
    required this.id,
    required this.name,
    required this.isAdmin,
    required this.isMe,
    required this.lastReadAt,
  });

  factory ChatMember.fromJson(Map<String, dynamic> json) => ChatMember(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    isAdmin: json['role'] == 'admin',
    isMe: json['me'] as bool? ?? false,
    lastReadAt: _time(json['lastReadAt']),
  );

  final String id;
  final String name;
  final bool isAdmin;
  final bool isMe;
  final DateTime lastReadAt;
}

/// Detail konverzácie (nastavenia, členovia skupiny).
class ConversationDetail {
  const ConversationDetail({
    required this.conversation,
    required this.members,
    required this.hasInvite,
    required this.blocked,
  });

  factory ConversationDetail.fromJson(Map<String, dynamic> json) =>
      ConversationDetail(
        conversation: Conversation.fromJson(json),
        members: [
          for (final m in json['members'] as List? ?? const [])
            ChatMember.fromJson(m as Map<String, dynamic>),
        ],
        hasInvite: json['hasInvite'] as bool? ?? false,
        blocked: json['blocked'] as bool? ?? false,
      );

  final Conversation conversation;
  final List<ChatMember> members;
  final bool hasInvite;

  /// Druhú stranu súkromnej konverzácie som zablokoval.
  final bool blocked;
}

class ReplyPreview {
  const ReplyPreview({
    required this.id,
    required this.kind,
    required this.body,
    required this.senderName,
    required this.deleted,
  });

  factory ReplyPreview.fromJson(Map<String, dynamic> json) => ReplyPreview(
    id: json['id'] as String,
    kind: MessageKind.parse(json['kind']),
    body: json['body'] as String?,
    senderName: json['senderName'] as String?,
    deleted: json['deleted'] as bool? ?? false,
  );

  final String id;
  final MessageKind kind;
  final String? body;
  final String? senderName;
  final bool deleted;

  String get preview =>
      messagePreview(kind: kind, body: body, deleted: deleted);
}

class Reaction {
  const Reaction({
    required this.emoji,
    required this.count,
    required this.mine,
  });

  factory Reaction.fromJson(Map<String, dynamic> json) => Reaction(
    emoji: json['emoji'] as String,
    count: json['count'] as int? ?? 1,
    mine: json['mine'] as bool? ?? false,
  );

  final String emoji;
  final int count;
  final bool mine;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.kind,
    required this.body,
    required this.sentAt,
    required this.mine,
    this.rawSentAt,
    this.rawUpdatedAt,
    this.senderId,
    this.senderName,
    this.edited = false,
    this.deleted = false,
    this.replyTo,
    this.reactions = const [],
    this.pending = false,
    this.localImage,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    kind: MessageKind.parse(json['kind']),
    body: json['body'] as String?,
    sentAt: _time(json['sentAt']),
    rawSentAt: json['sentAt'] as String?,
    rawUpdatedAt: json['updatedAt'] as String?,
    mine: json['mine'] as bool? ?? false,
    senderId: json['senderId'] as String?,
    senderName: json['senderName'] as String?,
    edited: json['edited'] as bool? ?? false,
    deleted: json['deleted'] as bool? ?? false,
    replyTo: json['replyTo'] is Map<String, dynamic>
        ? ReplyPreview.fromJson(json['replyTo'] as Map<String, dynamic>)
        : null,
    reactions: [
      for (final r in json['reactions'] as List? ?? const [])
        Reaction.fromJson(r as Map<String, dynamic>),
    ],
  );

  final String id;
  final MessageKind kind;
  final String? body;
  final DateTime sentAt;

  /// Čas presne tak, ako ho poslal server (kurzor pre staršie správy).
  final String? rawSentAt;

  /// Posledná zmena na serveri (kurzor pre priebežné načítanie).
  final String? rawUpdatedAt;
  final bool mine;
  final String? senderId;
  final String? senderName;
  final bool edited;
  final bool deleted;
  final ReplyPreview? replyTo;
  final List<Reaction> reactions;

  /// Odoslaná, ale server ju ešte nepotvrdil.
  final bool pending;

  /// Bajty fotky, kým sa odosiela (náhľad bez servera).
  final List<int>? localImage;

  bool get isSystem => kind == MessageKind.system;
  bool get isImage => kind == MessageKind.image && !deleted;

  String get preview =>
      messagePreview(kind: kind, body: body, deleted: deleted);
}

/// Odpoveď na načítanie správ.
class MessagePage {
  const MessagePage({
    required this.messages,
    required this.canSend,
    this.typing = const [],
    this.readBy = const {},
  });

  factory MessagePage.fromJson(Map<String, dynamic> json) => MessagePage(
    messages: [
      for (final m in json['messages'] as List? ?? const [])
        ChatMessage.fromJson(m as Map<String, dynamic>),
    ],
    canSend: json['canSend'] as bool? ?? false,
    typing: [
      for (final t in json['typing'] as List? ?? const [])
        if (t is String) t,
    ],
    readBy: {
      for (final r in json['readBy'] as List? ?? const [])
        if (r is Map<String, dynamic> && r['userId'] is String)
          r['userId'] as String: _time(r['lastReadAt']),
    },
  );

  final List<ChatMessage> messages;
  final bool canSend;

  /// Mená tých, čo práve píšu.
  final List<String> typing;

  /// Dokedy ostatní členovia prečítali (ID → čas).
  final Map<String, DateTime> readBy;
}

/// Človek, ktorému sa dá písať alebo ho pridať do skupiny.
class ChatContact {
  const ChatContact({required this.id, required this.name, this.role});

  factory ChatContact.fromJson(Map<String, dynamic> json) => ChatContact(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    role: json['role'] as String?,
  );

  final String id;
  final String name;
  final String? role;

  bool get isTrainer => role == 'trainer';
}
