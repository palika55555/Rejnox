import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../auth/presentation/auth_controller.dart';
import '../chat/application/chat_providers.dart';
import 'notification_models.dart';
import 'notifications_api.dart';
import 'phone_alerts.dart';

/// Ako často sa appka pýta servera na novinky.
const notificationsPollInterval = Duration(seconds: 20);

/// Upozornenia a počet neprečítaných správ. Kým je používateľ prihlásený,
/// načítavajú sa priebežne; novinky, ktoré prídu, keď je appka na pozadí,
/// sa ukážu aj ako systémové upozornenie v telefóne.
class NotificationsController extends AsyncNotifier<NotificationFeed> {
  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  bool _inForeground = true;
  bool _loading = false;
  final _seen = <String>{};
  int _lastUnreadMessages = 0;

  NotificationsApi get _api => ref.read(notificationsApiProvider);

  String? get _token {
    final auth = ref.read(authControllerProvider);
    return auth is SignedIn ? auth.token : null;
  }

  @override
  Future<NotificationFeed> build() async {
    final auth = ref.watch(authControllerProvider);
    _timer?.cancel();
    _lifecycle?.dispose();
    _seen.clear();
    if (auth is! SignedIn) return const NotificationFeed();

    _timer = Timer.periodic(notificationsPollInterval, (_) => refresh());
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        _inForeground = state == AppLifecycleState.resumed;
        if (_inForeground) unawaited(refresh());
      },
    );
    ref.onDispose(() {
      _timer?.cancel();
      _lifecycle?.dispose();
    });

    final feed = await _api.feed(auth.token);
    _seen.addAll(feed.notifications.map((n) => n.id));
    _lastUnreadMessages = feed.unreadMessages;
    // Povolenie na upozornenia v telefóne sa pýta po prihlásení.
    unawaited(ref.read(phoneAlertsProvider).requestPermission());
    return feed;
  }

  /// Načíta novinky zo servera (priebežne aj potiahnutím nadol).
  Future<void> refresh() async {
    final token = _token;
    if (token == null || _loading) return;
    _loading = true;
    try {
      final feed = await _api.feed(token);
      await _alertAboutNews(feed);
      if (feed.unreadMessages != _lastUnreadMessages) {
        ref.invalidate(chatThreadsProvider);
      }
      _lastUnreadMessages = feed.unreadMessages;
      state = AsyncData(feed);
    } on ApiError {
      // Bez spojenia ostanú posledné načítané údaje.
    } finally {
      _loading = false;
    }
  }

  Future<void> _alertAboutNews(NotificationFeed feed) async {
    final fresh = [
      for (final n in feed.notifications)
        if (!n.read && !_seen.contains(n.id)) n,
    ];
    _seen.addAll(feed.notifications.map((n) => n.id));
    if (_inForeground) return;

    final alerts = ref.read(phoneAlertsProvider);
    for (final n in fresh) {
      await alerts.show(id: n.id.hashCode, title: n.title, body: n.body);
    }
    final newMessages = feed.unreadMessages - _lastUnreadMessages;
    if (newMessages > 0) {
      await alerts.show(
        id: 'chat'.hashCode,
        title: newMessages == 1 ? 'Nová správa' : 'Nové správy ($newMessages)',
        body: 'Otvor Rejnox a odpíš.',
        message: true,
      );
    }
  }

  Future<void> markRead(String id) async {
    final token = _token;
    final current = state.value;
    if (token == null || current == null) return;
    state = AsyncData(
      NotificationFeed(
        notifications: [
          for (final n in current.notifications)
            n.id == id ? n.markedRead() : n,
        ],
        unread: current.notifications.any((n) => n.id == id && !n.read)
            ? current.unread - 1
            : current.unread,
        unreadMessages: current.unreadMessages,
      ),
    );
    await _api.markRead(token, id: id);
  }

  Future<void> markAllRead() async {
    final token = _token;
    final current = state.value;
    if (token == null || current == null) return;
    state = AsyncData(
      NotificationFeed(
        notifications: [for (final n in current.notifications) n.markedRead()],
        unreadMessages: current.unreadMessages,
      ),
    );
    await _api.markRead(token);
  }

  Future<void> delete(String id) async {
    final token = _token;
    final current = state.value;
    if (token == null || current == null) return;
    final removed = current.notifications.where((n) => n.id == id);
    state = AsyncData(
      NotificationFeed(
        notifications: [
          for (final n in current.notifications)
            if (n.id != id) n,
        ],
        unread: removed.any((n) => !n.read)
            ? current.unread - 1
            : current.unread,
        unreadMessages: current.unreadMessages,
      ),
    );
    await _api.delete(token, id);
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsController, NotificationFeed>(
      NotificationsController.new,
    );
