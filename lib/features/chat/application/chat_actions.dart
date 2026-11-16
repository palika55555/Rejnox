import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/chat_api.dart';
import 'chat_providers.dart';

/// Zmeny mimo otvorenej konverzácie: skupiny, členovia, stlmenie, blokovanie.
/// Po každej zmene obnoví zoznamy, ktorých sa týka.
class ChatActions {
  const ChatActions(this._ref);

  final Ref _ref;

  ChatApi get _api => _ref.read(chatApiProvider);
  String get _token => chatToken(_ref);

  String? get myId => switch (_ref.read(authControllerProvider)) {
    SignedIn(:final user) => user.id,
    _ => null,
  };

  void _changed([String? conversationId]) {
    _ref.invalidate(conversationsProvider);
    _ref.invalidate(chatContactsProvider);
    if (conversationId != null) {
      _ref.invalidate(conversationDetailProvider(conversationId));
    }
  }

  Future<String> openDirect(String userId) =>
      _api.directConversation(_token, userId);

  Future<String> createGroup(String title, List<String> members) async {
    final id = await _api.createGroup(_token, title.trim(), members);
    _changed();
    return id;
  }

  Future<String> joinGroup(String code) async {
    final id = await _api.joinGroup(_token, code.trim());
    _changed(id);
    return id;
  }

  Future<void> rename(String groupId, String title) async {
    await _api.renameGroup(_token, groupId, title.trim());
    _changed(groupId);
  }

  Future<void> addMembers(String groupId, List<String> userIds) async {
    await _api.addMembers(_token, groupId, userIds);
    _changed(groupId);
  }

  Future<void> removeMember(String groupId, String userId) async {
    await _api.removeMember(_token, groupId, userId);
    _changed(groupId);
  }

  Future<void> leave(String groupId) async {
    final me = myId;
    if (me == null) return;
    await _api.removeMember(_token, groupId, me);
    _changed();
  }

  Future<void> deleteGroup(String groupId) async {
    await _api.deleteGroup(_token, groupId);
    _changed();
  }

  Future<void> setAdmin(
    String groupId,
    String userId, {
    required bool admin,
  }) async {
    await _api.setAdmin(_token, groupId, userId, admin: admin);
    _changed(groupId);
  }

  Future<String> newInvite(String groupId) async {
    final code = await _api.newInvite(_token, groupId);
    _changed(groupId);
    return code;
  }

  Future<void> disableInvite(String groupId) async {
    await _api.disableInvite(_token, groupId);
    _changed(groupId);
  }

  Future<void> setMuted(String conversationId, {required bool muted}) async {
    await _api.setMuted(_token, conversationId, muted);
    _changed(conversationId);
  }

  Future<void> block(String userId, {String? conversationId}) async {
    await _api.block(_token, userId);
    _ref.invalidate(blockedUsersProvider);
    _changed(conversationId);
  }

  Future<void> unblock(String userId, {String? conversationId}) async {
    await _api.unblock(_token, userId);
    _ref.invalidate(blockedUsersProvider);
    _changed(conversationId);
  }
}

final chatActionsProvider = Provider<ChatActions>(ChatActions.new);
