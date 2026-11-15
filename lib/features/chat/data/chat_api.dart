import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/chat_models.dart';

abstract interface class ChatApi {
  Future<List<ChatThread>> threads(String token);

  /// Správy v konverzácii, staršie hore. S [after] len novšie ako tento čas.
  /// Načítanie označí konverzáciu ako prečítanú.
  Future<List<ChatMessage>> messages(
    String token,
    String linkId, {
    String? after,
  });

  Future<ChatMessage> send(String token, String linkId, String body);
}

class HttpChatApi implements ChatApi {
  const HttpChatApi(this._api);

  final ApiClient _api;

  @override
  Future<List<ChatThread>> threads(String token) async {
    final json = await _api.send('GET', '/chats', token: token);
    return [
      for (final c in json['chats'] as List)
        ChatThread.fromJson(c as Map<String, dynamic>),
    ];
  }

  @override
  Future<List<ChatMessage>> messages(
    String token,
    String linkId, {
    String? after,
  }) async {
    final query = after == null ? '' : '?after=${Uri.encodeComponent(after)}';
    final json = await _api.send(
      'GET',
      '/chats/$linkId/messages$query',
      token: token,
    );
    return [
      for (final m in json['messages'] as List)
        ChatMessage.fromJson(m as Map<String, dynamic>),
    ];
  }

  @override
  Future<ChatMessage> send(String token, String linkId, String body) async =>
      ChatMessage.fromJson(
        await _api.send(
          'POST',
          '/chats/$linkId/messages',
          token: token,
          body: {'body': body},
        ),
      );
}

final chatApiProvider = Provider<ChatApi>(
  (ref) => HttpChatApi(ref.watch(apiClientProvider)),
);
