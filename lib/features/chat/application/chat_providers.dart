import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/chat_api.dart';
import '../domain/chat_models.dart';

const _signedOut = ApiError(401, 'unauthorized', 'Prihlás sa, prosím.');

String _token(AuthState auth) =>
    auth is SignedIn ? auth.token : throw _signedOut;

/// Ako často sa v otvorenej konverzácii pýtame na nové správy.
const chatPollInterval = Duration(seconds: 4);

/// Zoznam konverzácií. Obnoví sa pri návrate na obrazovku a keď
/// upozornenia zistia nové správy.
final chatThreadsProvider = FutureProvider<List<ChatThread>>(
  (ref) => ref
      .read(chatApiProvider)
      .threads(_token(ref.watch(authControllerProvider))),
);

/// Otvorená konverzácia: načíta správy, priebežne dopĺňa nové a posiela.
class ChatController extends AsyncNotifier<List<ChatMessage>> {
  ChatController(this.linkId);

  final String linkId;
  Timer? _poll;
  bool _polling = false;

  ChatApi get _api => ref.read(chatApiProvider);

  @override
  Future<List<ChatMessage>> build() async {
    final token = _token(ref.watch(authControllerProvider));
    _poll?.cancel();
    _poll = Timer.periodic(chatPollInterval, (_) => refresh());
    ref.onDispose(() => _poll?.cancel());
    final messages = await _api.messages(token, linkId);
    ref.invalidate(chatThreadsProvider);
    return messages;
  }

  String? get _cursor {
    for (final m in (state.value ?? const <ChatMessage>[]).reversed) {
      if (!m.pending && m.rawSentAt != null) return m.rawSentAt;
    }
    return null;
  }

  /// Doplní správy, ktoré prišli od posledného načítania.
  Future<void> refresh() async {
    final current = state.value;
    if (_polling || current == null) return;
    _polling = true;
    try {
      final token = _token(ref.read(authControllerProvider));
      final fresh = await _api.messages(token, linkId, after: _cursor);
      if (fresh.isEmpty) return;
      final known = {for (final m in state.value ?? current) m.id};
      state = AsyncData([
        ...?state.value,
        for (final m in fresh)
          if (!known.contains(m.id)) m,
      ]);
      ref.invalidate(chatThreadsProvider);
    } on ApiError {
      // Výpadok spojenia: skúsi sa to znova pri ďalšom kole.
    } finally {
      _polling = false;
    }
  }

  /// Pošle správu. Kým ju server nepotvrdí, je v zozname ako „odosiela sa“.
  /// Pri chybe ju odoberie a chybu pošle ďalej (obrazovka ju ukáže).
  Future<void> send(String body) async {
    final text = body.trim();
    if (text.isEmpty) return;
    final tempId = 'pending-${DateTime.now().microsecondsSinceEpoch}';
    final pending = ChatMessage(
      id: tempId,
      body: text,
      sentAt: DateTime.now(),
      mine: true,
      pending: true,
    );
    state = AsyncData([...?state.value, pending]);
    try {
      final sent = await _api.send(
        _token(ref.read(authControllerProvider)),
        linkId,
        text,
      );
      state = AsyncData([
        for (final m in state.value ?? const <ChatMessage>[])
          if (m.id != tempId && m.id != sent.id) m,
        sent,
      ]);
      ref.invalidate(chatThreadsProvider);
    } on Object {
      state = AsyncData([
        for (final m in state.value ?? const <ChatMessage>[])
          if (m.id != tempId) m,
      ]);
      rethrow;
    }
  }
}

final chatProvider = AsyncNotifierProvider.autoDispose
    .family<ChatController, List<ChatMessage>, String>(ChatController.new);
