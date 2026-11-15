/// Upozornenie zo servera (nový plán, rezervácia, prepojenie…).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.createdAt,
    required this.read,
    this.body,
    this.linkId,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        kind: json['kind'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String?,
        linkId: json['linkId'] as String?,
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
        read: json['read'] as bool? ?? false,
      );

  final String id;

  /// plan, booking, link, link_ended.
  final String kind;
  final String title;
  final String? body;

  /// Prepojenie tréner–klient, ku ktorému upozornenie patrí.
  final String? linkId;
  final DateTime createdAt;
  final bool read;

  AppNotification markedRead() => AppNotification(
    id: id,
    kind: kind,
    title: title,
    body: body,
    linkId: linkId,
    createdAt: createdAt,
    read: true,
  );
}

class NotificationFeed {
  const NotificationFeed({
    this.notifications = const [],
    this.unread = 0,
    this.unreadMessages = 0,
  });

  factory NotificationFeed.fromJson(Map<String, dynamic> json) =>
      NotificationFeed(
        notifications: [
          for (final n in json['notifications'] as List? ?? const [])
            AppNotification.fromJson(n as Map<String, dynamic>),
        ],
        unread: json['unread'] as int? ?? 0,
        unreadMessages: json['unreadMessages'] as int? ?? 0,
      );

  final List<AppNotification> notifications;

  /// Neprečítané upozornenia (zvonček).
  final int unread;

  /// Neprečítané správy v chate (Správy).
  final int unreadMessages;
}
