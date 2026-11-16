import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/chat_models.dart';

/// API chatu: konverzácie (tréner–klient, súkromné, skupiny) a správy.
abstract interface class ChatApi {
  Future<List<Conversation>> conversations(String token);
  Future<ConversationDetail> conversation(String token, String id);

  /// ID konverzácie k prepojeniu tréner–klient (založí ju, ak treba).
  Future<String> linkConversation(String token, String linkId);

  /// ID súkromnej konverzácie s človekom, ktorého poznám.
  Future<String> directConversation(String token, String userId);

  /// Správy, staršie hore. Bez kurzora posledná strana, s [before] staršie,
  /// so [since] nové aj zmenené. Načítanie označí prečítané.
  Future<MessagePage> messages(
    String token,
    String conversationId, {
    String? before,
    String? since,
  });

  Future<ChatMessage> send(
    String token,
    String conversationId,
    String body, {
    String? replyTo,
  });

  Future<ChatMessage> sendImage(
    String token,
    String conversationId,
    List<int> bytes, {
    String? replyTo,
  });

  Future<ChatMessage> edit(String token, String messageId, String body);
  Future<void> deleteMessage(String token, String messageId);

  /// Reakcia na správu, null ju odoberie.
  Future<ChatMessage> react(String token, String messageId, String? emoji);

  Future<void> typing(String token, String conversationId);
  Future<void> setMuted(String token, String conversationId, bool muted);

  Future<List<ChatContact>> contacts(String token);
  Future<String> createGroup(String token, String title, List<String> members);
  Future<String> joinGroup(String token, String code);
  Future<void> renameGroup(String token, String groupId, String title);
  Future<void> deleteGroup(String token, String groupId);
  Future<void> addMembers(String token, String groupId, List<String> userIds);

  /// Odobratie člena, alebo odchod zo skupiny (moje ID).
  Future<void> removeMember(String token, String groupId, String userId);
  Future<void> setAdmin(
    String token,
    String groupId,
    String userId, {
    required bool admin,
  });

  /// Nový pozývací kód (starý prestane platiť).
  Future<String> newInvite(String token, String groupId);
  Future<void> disableInvite(String token, String groupId);

  Future<List<ChatContact>> blocked(String token);
  Future<void> block(String token, String userId);
  Future<void> unblock(String token, String userId);
}

/// Adresa fotky zo správy (načíta sa s prihlasovacím tokenom).
String chatImageUrl(String messageId) => '$apiBaseUrl/chat-images/$messageId';

class HttpChatApi implements ChatApi {
  const HttpChatApi(this._api);

  final ApiClient _api;

  @override
  Future<List<Conversation>> conversations(String token) async {
    final json = await _api.send('GET', '/conversations', token: token);
    return [
      for (final c in json['conversations'] as List)
        Conversation.fromJson(c as Map<String, dynamic>),
    ];
  }

  @override
  Future<ConversationDetail> conversation(String token, String id) async =>
      ConversationDetail.fromJson(
        await _api.send('GET', '/conversations/$id', token: token),
      );

  @override
  Future<String> linkConversation(String token, String linkId) async =>
      (await _api.send(
            'POST',
            '/conversations/link/$linkId',
            token: token,
          ))['id']
          as String;

  @override
  Future<String> directConversation(String token, String userId) async =>
      (await _api.send(
            'POST',
            '/conversations/direct',
            token: token,
            body: {'userId': userId},
          ))['id']
          as String;

  @override
  Future<MessagePage> messages(
    String token,
    String conversationId, {
    String? before,
    String? since,
  }) async {
    final query = {'before': ?before, 'since': ?since};
    final path = Uri(
      path: '/conversations/$conversationId/messages',
      queryParameters: query.isEmpty ? null : query,
    ).toString();
    return MessagePage.fromJson(await _api.send('GET', path, token: token));
  }

  @override
  Future<ChatMessage> send(
    String token,
    String conversationId,
    String body, {
    String? replyTo,
  }) async => ChatMessage.fromJson(
    await _api.send(
      'POST',
      '/conversations/$conversationId/messages',
      token: token,
      body: {'body': body, 'replyTo': ?replyTo},
    ),
  );

  @override
  Future<ChatMessage> sendImage(
    String token,
    String conversationId,
    List<int> bytes, {
    String? replyTo,
  }) async {
    final path = Uri(
      path: '/conversations/$conversationId/images',
      queryParameters: replyTo == null ? null : {'replyTo': replyTo},
    ).toString();
    return ChatMessage.fromJson(
      await _api.send(
        'POST',
        path,
        token: token,
        bytes: bytes,
        contentType: 'image/jpeg',
      ),
    );
  }

  @override
  Future<ChatMessage> edit(String token, String messageId, String body) async =>
      ChatMessage.fromJson(
        await _api.send(
          'PUT',
          '/messages/$messageId',
          token: token,
          body: {'body': body},
        ),
      );

  @override
  Future<void> deleteMessage(String token, String messageId) =>
      _api.send('DELETE', '/messages/$messageId', token: token);

  @override
  Future<ChatMessage> react(
    String token,
    String messageId,
    String? emoji,
  ) async => ChatMessage.fromJson(
    await _api.send(
      'PUT',
      '/messages/$messageId/reaction',
      token: token,
      body: {'emoji': emoji},
    ),
  );

  @override
  Future<void> typing(String token, String conversationId) =>
      _api.send('POST', '/conversations/$conversationId/typing', token: token);

  @override
  Future<void> setMuted(String token, String conversationId, bool muted) =>
      _api.send(
        'PUT',
        '/conversations/$conversationId/mute',
        token: token,
        body: {'muted': muted},
      );

  @override
  Future<List<ChatContact>> contacts(String token) async {
    final json = await _api.send('GET', '/chat/contacts', token: token);
    return [
      for (final c in json['contacts'] as List)
        ChatContact.fromJson(c as Map<String, dynamic>),
    ];
  }

  @override
  Future<String> createGroup(
    String token,
    String title,
    List<String> members,
  ) async =>
      (await _api.send(
            'POST',
            '/groups',
            token: token,
            body: {'title': title, 'memberIds': members},
          ))['id']
          as String;

  @override
  Future<String> joinGroup(String token, String code) async =>
      (await _api.send(
            'POST',
            '/groups/join',
            token: token,
            body: {'code': code},
          ))['id']
          as String;

  @override
  Future<void> renameGroup(String token, String groupId, String title) => _api
      .send('PUT', '/groups/$groupId', token: token, body: {'title': title});

  @override
  Future<void> deleteGroup(String token, String groupId) =>
      _api.send('DELETE', '/groups/$groupId', token: token);

  @override
  Future<void> addMembers(String token, String groupId, List<String> userIds) =>
      _api.send(
        'POST',
        '/groups/$groupId/members',
        token: token,
        body: {'userIds': userIds},
      );

  @override
  Future<void> removeMember(String token, String groupId, String userId) =>
      _api.send('DELETE', '/groups/$groupId/members/$userId', token: token);

  @override
  Future<void> setAdmin(
    String token,
    String groupId,
    String userId, {
    required bool admin,
  }) => _api.send(
    'PUT',
    '/groups/$groupId/members/$userId',
    token: token,
    body: {'role': admin ? 'admin' : 'member'},
  );

  @override
  Future<String> newInvite(String token, String groupId) async =>
      (await _api.send('POST', '/groups/$groupId/invite', token: token))['code']
          as String;

  @override
  Future<void> disableInvite(String token, String groupId) =>
      _api.send('DELETE', '/groups/$groupId/invite', token: token);

  @override
  Future<List<ChatContact>> blocked(String token) async {
    final json = await _api.send('GET', '/chat/blocks', token: token);
    return [
      for (final c in json['blocks'] as List)
        ChatContact.fromJson(c as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> block(String token, String userId) =>
      _api.send('PUT', '/chat/blocks/$userId', token: token);

  @override
  Future<void> unblock(String token, String userId) =>
      _api.send('DELETE', '/chat/blocks/$userId', token: token);
}

final chatApiProvider = Provider<ChatApi>(
  (ref) => HttpChatApi(ref.watch(apiClientProvider)),
);
