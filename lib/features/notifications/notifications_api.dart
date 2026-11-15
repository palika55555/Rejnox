import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import 'notification_models.dart';

abstract interface class NotificationsApi {
  Future<NotificationFeed> feed(String token);

  /// Označí jedno upozornenie, alebo všetky, keď [id] chýba.
  Future<void> markRead(String token, {String? id});

  Future<void> delete(String token, String id);
}

class HttpNotificationsApi implements NotificationsApi {
  const HttpNotificationsApi(this._api);

  final ApiClient _api;

  @override
  Future<NotificationFeed> feed(String token) async =>
      NotificationFeed.fromJson(
        await _api.send('GET', '/notifications', token: token),
      );

  @override
  Future<void> markRead(String token, {String? id}) =>
      _api.send('POST', '/notifications/read', token: token, body: {'id': ?id});

  @override
  Future<void> delete(String token, String id) =>
      _api.send('DELETE', '/notifications/$id', token: token);
}

final notificationsApiProvider = Provider<NotificationsApi>(
  (ref) => HttpNotificationsApi(ref.watch(apiClientProvider)),
);
