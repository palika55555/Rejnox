import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/screen_header.dart';
import '../../gyms/application/gym_photo_picker.dart';
import '../application/chat_providers.dart';
import '../domain/chat_models.dart';
import 'chat_composer.dart';
import 'chat_widgets.dart';
import 'message_bubble.dart';

/// Chat tréner–klient podľa ID prepojenia (z karty trénera/klienta
/// a z upozornení). Nájde konverzáciu a ukáže ju.
class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key, required this.linkId, this.name});

  final String linkId;
  final String? name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversation = ref.watch(linkConversationProvider(linkId));
    return conversation.when(
      data: (id) => ConversationScreen(conversationId: id, title: name),
      loading: () => _Frame(
        title: name ?? 'Správy',
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _Frame(
        title: name ?? 'Správy',
        child: ChatEmptyState(
          icon: Icons.chat_bubble_outline_rounded,
          title: chatErrorText(e),
          action: TextButton(
            onPressed: () => ref.invalidate(linkConversationProvider(linkId)),
            child: const Text('Skúsiť znova'),
          ),
        ),
      ),
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) => AppBackground(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ScreenHeader(
                  title,
                  subtitle: subtitle,
                  trailing: trailing,
                  onBack: () =>
                      context.canPop() ? context.pop() : context.go('/chat'),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Jedna konverzácia (tréner–klient, súkromná alebo skupina).
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({
    super.key,
    required this.conversationId,
    this.title,
  });

  final String conversationId;

  /// Názov, ak ho volajúci pozná (inak sa dohľadá v zozname).
  final String? title;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  ChatMessage? _replyTo;
  ChatMessage? _editing;

  String get _id => widget.conversationId;
  ChatRoomController get _room => ref.read(chatRoomProvider(_id).notifier);

  Future<bool> _send(String text) async {
    final editing = _editing;
    final reply = _replyTo;
    setState(() {
      _editing = null;
      _replyTo = null;
    });
    try {
      if (editing != null) {
        await _room.edit(editing.id, text);
      } else {
        await _room.send(text, replyTo: reply);
      }
      return true;
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _editing = editing;
          _replyTo = reply;
        });
        showChatError(context, e, 'Správu sa nepodarilo odoslať.');
      }
      return false;
    }
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<PhotoSource>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Odfotiť'),
              onTap: () => Navigator.of(sheet).pop(PhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Vybrať z galérie'),
              onTap: () => Navigator.of(sheet).pop(PhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      final bytes = await ref.read(gymPhotoPickerProvider).pick(source);
      if (bytes == null || !mounted) return;
      final reply = _replyTo;
      setState(() => _replyTo = null);
      await _room.sendImage(bytes, replyTo: reply);
    } on PhotoPickFailed {
      if (mounted) {
        showChatError(
          context,
          const PhotoPickFailed(),
          'Fotku sa nepodarilo načítať. Skontroluj povolenia.',
        );
      }
    } on Object catch (e) {
      if (mounted) showChatError(context, e, 'Fotku sa nepodarilo odoslať.');
    }
  }

  Future<void> _onAction(ChatMessage message, MessageAction action) async {
    switch (action) {
      case ReplyAction():
        setState(() {
          _editing = null;
          _replyTo = message;
        });
      case EditAction():
        setState(() {
          _replyTo = null;
          _editing = message;
        });
      case ReactAction(:final emoji):
        try {
          await _room.toggleReaction(message, emoji);
        } on Object catch (e) {
          if (mounted) showChatError(context, e);
        }
      case DeleteAction():
        final ok = await confirmChatAction(
          context,
          title: 'Zmazať správu?',
          body: 'Správa zmizne u všetkých v konverzácii.',
          confirm: 'Zmazať',
        );
        if (!ok) return;
        try {
          await _room.delete(message);
        } on Object catch (e) {
          if (mounted) showChatError(context, e);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(chatRoomProvider(_id));
    final conversation = ref
        .watch(conversationsProvider)
        .value
        ?.where((c) => c.id == _id)
        .firstOrNull;
    final title = conversation?.title ?? widget.title ?? 'Správy';
    final typing = room.value?.typing ?? const <String>[];
    final subtitle = typing.isNotEmpty
        ? typing.length == 1
              ? '${typing.first} píše…'
              : '${typing.length} ľudia píšu…'
        : conversation?.subtitle;
    final canSend = room.value?.canSend ?? conversation?.canSend ?? false;

    return _Frame(
      title: title,
      subtitle: subtitle,
      trailing: [
        IconButton(
          tooltip: 'Nastavenia konverzácie',
          onPressed: () => context.push('/conversation/$_id/info'),
          icon: Icon(
            conversation?.isGroup ?? false
                ? Icons.groups_outlined
                : Icons.info_outline_rounded,
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: room.when(
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ChatEmptyState(
                icon: Icons.cloud_off_rounded,
                title: chatErrorText(e),
                action: TextButton(
                  onPressed: () => ref.invalidate(chatRoomProvider(_id)),
                  child: const Text('Skúsiť znova'),
                ),
              ),
              data: (data) => _MessageList(
                room: data,
                isGroup: conversation?.isGroup ?? false,
                isAdmin: conversation?.isAdmin ?? false,
                onLoadOlder: _room.loadOlder,
                onAction: _onAction,
              ),
            ),
          ),
          if (room.hasValue && !canSend)
            _ClosedNote(conversation)
          else if (room.hasValue)
            ChatComposer(
              replyTo: _replyTo,
              editing: _editing,
              onCancel: () => setState(() {
                _replyTo = null;
                _editing = null;
              }),
              onSend: _send,
              onTyping: _room.typing,
              onPickImage: _pickImage,
            ),
        ],
      ),
    );
  }
}

class _MessageList extends StatefulWidget {
  const _MessageList({
    required this.room,
    required this.isGroup,
    required this.isAdmin,
    required this.onLoadOlder,
    required this.onAction,
  });

  final ChatRoom room;
  final bool isGroup;
  final bool isAdmin;
  final Future<void> Function() onLoadOlder;
  final void Function(ChatMessage, MessageAction) onAction;

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      // Obrátený zoznam: začiatok konverzácie je na konci posunu.
      if (_scroll.position.extentAfter < 400) widget.onLoadOlder();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final room = widget.room;
    final messages = room.messages;
    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            room.canSend
                ? 'Zatiaľ žiadne správy. Napíš prvú.'
                : 'Zatiaľ žiadne správy.',
            style: text.bodyMedium!.copyWith(color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final seen = room.lastSeenMine;
    // Obrátený zoznam: najnovšie dole a pri novej správe ostane dole.
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      itemCount: messages.length + (room.loadingOlder ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == messages.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final index = messages.length - 1 - i;
        final m = messages[index];
        final previous = index > 0 ? messages[index - 1] : null;
        final newDay = previous == null || !_sameDay(previous.sentAt, m.sentAt);
        final firstOfRun =
            previous == null ||
            newDay ||
            previous.isSystem ||
            previous.senderId != m.senderId;
        return Column(
          key: ValueKey(m.id),
          children: [
            if (newDay)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  dayLabel(m.sentAt),
                  style: text.bodySmall!.copyWith(color: AppColors.muted),
                ),
              ),
            if (m.isSystem)
              SystemNote(m)
            else
              Padding(
                padding: EdgeInsets.only(top: firstOfRun ? 6 : 0),
                child: MessageBubble(
                  message: m,
                  showSender: widget.isGroup && firstOfRun,
                  seen: identical(m, seen),
                  canInteract: room.canSend,
                  canDelete: widget.isGroup && widget.isAdmin,
                  onAction: (a) => widget.onAction(m, a),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ClosedNote extends StatelessWidget {
  const _ClosedNote(this.conversation);

  final Conversation? conversation;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
    child: Text(
      switch (conversation?.kind) {
        ConversationKind.link =>
          'Spolupráca skončila. Správy si môžeš prečítať, písať už nejde.',
        ConversationKind.direct =>
          'Do tejto konverzácie sa písať nedá (blokovanie).',
        _ => 'Do tejto konverzácie už písať nemôžeš.',
      },
      textAlign: TextAlign.center,
      style: Theme.of(
        context,
      ).textTheme.bodySmall!.copyWith(color: AppColors.muted),
    ),
  );
}
