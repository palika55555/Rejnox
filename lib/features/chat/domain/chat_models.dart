DateTime _time(Object? value) =>
    (value is String ? DateTime.tryParse(value) : null)?.toLocal() ??
    DateTime.now();

/// Konverzácia s trénerom (pre klienta) alebo s klientom (pre trénera).
class ChatThread {
  const ChatThread({
    required this.linkId,
    required this.name,
    required this.withTrainer,
    required this.canSend,
    required this.unread,
    this.lastMessage,
  });

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    final last = json['lastMessage'];
    return ChatThread(
      linkId: json['linkId'] as String,
      name: json['name'] as String? ?? '',
      withTrainer: json['otherRole'] == 'trainer',
      canSend: json['canSend'] as bool? ?? false,
      unread: json['unread'] as int? ?? 0,
      lastMessage: last is Map<String, dynamic>
          ? ChatMessage.fromJson({...last, 'id': ''})
          : null,
    );
  }

  /// ID prepojenia tréner–klient, podľa neho sa konverzácia otvára.
  final String linkId;
  final String name;

  /// Druhá strana je môj tréner.
  final bool withTrainer;

  /// Po ukončení spolupráce sa dá len čítať.
  final bool canSend;
  final int unread;
  final ChatMessage? lastMessage;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.body,
    required this.sentAt,
    required this.mine,
    this.rawSentAt,
    this.pending = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    body: json['body'] as String,
    sentAt: _time(json['sentAt']),
    rawSentAt: json['sentAt'] as String?,
    mine: json['mine'] as bool? ?? false,
  );

  final String id;
  final String body;
  final DateTime sentAt;

  /// Čas presne tak, ako ho poslal server (kurzor pre nové správy).
  final String? rawSentAt;
  final bool mine;

  /// Odoslaná, ale server ju ešte nepotvrdil.
  final bool pending;
}
