import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tm_card.dart';
import '../application/chat_actions.dart';
import '../application/chat_providers.dart';
import '../domain/chat_models.dart';
import 'chat_widgets.dart';
import 'new_chat_screen.dart';

/// Nastavenia konverzácie: stlmenie, blokovanie, pri skupine členovia,
/// správcovia, pozývací kód, premenovanie, odchod a zrušenie.
class ConversationInfoScreen extends ConsumerStatefulWidget {
  const ConversationInfoScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ConversationInfoScreen> createState() =>
      _ConversationInfoScreenState();
}

class _ConversationInfoScreenState
    extends ConsumerState<ConversationInfoScreen> {
  bool _busy = false;

  String get _id => widget.conversationId;
  ChatActions get _actions => ref.read(chatActionsProvider);

  /// Spustí zmenu; chybu ukáže. Vráti true pri úspechu.
  Future<bool> _run(Future<void> Function() work) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      await work();
      return true;
    } on Object catch (e) {
      if (mounted) showChatError(context, e);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rename(Conversation group) async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => _TextDialog(
        title: 'Názov skupiny',
        initial: group.title,
        confirm: 'Uložiť',
      ),
    );
    if (title == null || title.trim().isEmpty) return;
    await _run(() => _actions.rename(_id, title));
  }

  Future<void> _newCode() async {
    String? code;
    final ok = await _run(() async => code = await _actions.newInvite(_id));
    if (!ok || !mounted || code == null) return;
    await showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Pozývací kód'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(
              code!,
              style: Theme.of(dialog).textTheme.headlineMedium!.copyWith(
                color: AppColors.accent,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Kto má kód, pridá sa do skupiny. Kód sa ukáže len teraz; '
              'nový kód zruší starý.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code!));
              Navigator.of(dialog).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kód je skopírovaný.')),
              );
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Kopírovať'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('Hotovo'),
          ),
        ],
      ),
    );
  }

  Future<void> _memberMenu(ConversationDetail detail, ChatMember member) async {
    final admin = detail.conversation.isAdmin;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                member.name,
                style: Theme.of(sheet).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded),
              title: const Text('Napísať súkromne'),
              onTap: () => Navigator.of(sheet).pop('dm'),
            ),
            if (admin)
              ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: Text(
                  member.isAdmin ? 'Odobrať správcu' : 'Urobiť správcom',
                ),
                onTap: () => Navigator.of(sheet).pop('role'),
              ),
            if (admin)
              ListTile(
                leading: const Icon(
                  Icons.person_remove_outlined,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Odstrániť zo skupiny',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () => Navigator.of(sheet).pop('remove'),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'dm':
        String? id;
        final ok = await _run(
          () async => id = await _actions.openDirect(member.id),
        );
        if (ok && mounted && id != null) {
          context.push('/conversation/$id', extra: member.name);
        }
      case 'role':
        await _run(
          () => _actions.setAdmin(_id, member.id, admin: !member.isAdmin),
        );
      case 'remove':
        final sure = await confirmChatAction(
          context,
          title: 'Odstrániť ${member.name}?',
          body: 'Prestane vidieť správy v skupine.',
          confirm: 'Odstrániť',
        );
        if (sure) await _run(() => _actions.removeMember(_id, member.id));
    }
  }

  Future<void> _leave() async {
    final sure = await confirmChatAction(
      context,
      title: 'Opustiť skupinu?',
      body: 'Správy skupiny prestaneš vidieť. Vrátiť sa dá len pozvánkou.',
      confirm: 'Opustiť',
    );
    if (sure && await _run(() => _actions.leave(_id)) && mounted) {
      context.go('/chat');
    }
  }

  Future<void> _delete() async {
    final sure = await confirmChatAction(
      context,
      title: 'Zrušiť skupinu?',
      body: 'Skupina aj všetky správy sa zmažú pre všetkých členov.',
      confirm: 'Zrušiť skupinu',
    );
    if (sure && await _run(() => _actions.deleteGroup(_id)) && mounted) {
      context.go('/chat');
    }
  }

  Future<void> _toggleBlock(ConversationDetail detail) async {
    final other = detail.conversation.otherUserId;
    if (other == null) return;
    if (detail.blocked) {
      await _run(() => _actions.unblock(other, conversationId: _id));
      ref.invalidate(chatRoomProvider(_id));
      return;
    }
    final sure = await confirmChatAction(
      context,
      title: 'Zablokovať ${detail.conversation.title}?',
      body:
          'Nebudete si môcť písať súkromne a nepridá ťa do skupiny. '
          'Odblokovať sa dá kedykoľvek tu.',
      confirm: 'Zablokovať',
    );
    if (sure) {
      await _run(() => _actions.block(other, conversationId: _id));
      ref.invalidate(chatRoomProvider(_id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(conversationDetailProvider(_id));
    return AppBackground(
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
                    'Nastavenia',
                    onBack: () => context.canPop()
                        ? context.pop()
                        : context.go('/conversation/$_id'),
                  ),
                  if (_busy) const LinearProgressIndicator(minHeight: 2),
                  Expanded(
                    child: detail.when(
                      skipLoadingOnRefresh: true,
                      skipLoadingOnReload: true,
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => ChatEmptyState(
                        icon: Icons.cloud_off_rounded,
                        title: chatErrorText(e),
                        action: TextButton(
                          onPressed: () =>
                              ref.invalidate(conversationDetailProvider(_id)),
                          child: const Text('Skúsiť znova'),
                        ),
                      ),
                      data: _content,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(ConversationDetail detail) {
    final text = Theme.of(context).textTheme;
    final c = detail.conversation;
    final admin = c.isGroup && c.isAdmin;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Center(child: ChatAvatar(c.title, size: 72, group: c.isGroup)),
        const SizedBox(height: 10),
        Text(c.title, style: text.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 2),
        Text(
          c.subtitle,
          style: text.bodySmall!.copyWith(color: AppColors.muted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        AppList(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.notifications_off_outlined),
              title: const Text('Stlmiť upozornenia'),
              subtitle: const Text('Správy sa nerátajú do odznaku'),
              value: c.muted,
              onChanged: _busy
                  ? null
                  : (v) => _run(() => _actions.setMuted(_id, muted: v)),
            ),
            if (admin)
              AppRow(
                leading: const Icon(Icons.edit_outlined),
                title: 'Premenovať skupinu',
                onTap: _busy ? null : () => _rename(c),
              ),
            if (c.kind == ConversationKind.direct)
              AppRow(
                leading: Icon(
                  detail.blocked
                      ? Icons.lock_open_rounded
                      : Icons.block_rounded,
                  color: detail.blocked ? null : AppColors.error,
                ),
                title: detail.blocked ? 'Odblokovať' : 'Zablokovať',
                subtitle: detail.blocked
                    ? 'Si zablokoval(a) tohto človeka'
                    : null,
                onTap: _busy ? null : () => _toggleBlock(detail),
              ),
          ],
        ),
        if (admin) ...[
          const SizedBox(height: 18),
          const SectionLabel('Pozývací kód'),
          const SizedBox(height: 8),
          AppList(
            children: [
              AppRow(
                leading: const Icon(Icons.vpn_key_outlined),
                title: detail.hasInvite ? 'Nový kód' : 'Vytvoriť kód',
                subtitle: detail.hasInvite
                    ? 'Kód je aktívny. Nový zruší starý.'
                    : 'Ľudia sa pridajú sami zadaním kódu',
                onTap: _busy ? null : _newCode,
              ),
              if (detail.hasInvite)
                AppRow(
                  leading: const Icon(Icons.key_off_outlined),
                  title: 'Zrušiť kód',
                  onTap: _busy
                      ? null
                      : () => _run(() => _actions.disableInvite(_id)),
                ),
            ],
          ),
        ],
        if (c.isGroup) ...[
          const SizedBox(height: 18),
          SectionLabel('Členovia · ${detail.members.length}'),
          const SizedBox(height: 8),
          AppList(
            children: [
              if (admin)
                AppRow(
                  leading: const Icon(Icons.person_add_alt_rounded),
                  title: 'Pridať ľudí',
                  onTap: _busy
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => NewChatScreen(
                              mode: NewChatMode.addMembers,
                              groupId: _id,
                              existing: {for (final m in detail.members) m.id},
                            ),
                          ),
                        ),
                ),
              for (final m in detail.members)
                AppRow(
                  leading: ChatAvatar(m.name, size: 36),
                  title: m.isMe ? '${m.name} (ty)' : m.name,
                  trailing: m.isAdmin
                      ? const AppPill('Správca', tone: PillTone.accent)
                      : null,
                  onTap: m.isMe || _busy ? null : () => _memberMenu(detail, m),
                ),
            ],
          ),
          const SizedBox(height: 18),
          AppList(
            children: [
              AppRow(
                leading: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.error,
                ),
                title: 'Opustiť skupinu',
                onTap: _busy ? null : _leave,
              ),
              if (admin)
                AppRow(
                  leading: const Icon(
                    Icons.delete_forever_outlined,
                    color: AppColors.error,
                  ),
                  title: 'Zrušiť skupinu',
                  subtitle: 'Zmaže skupinu pre všetkých',
                  onTap: _busy ? null : _delete,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.initial,
    required this.confirm,
  });

  final String title;
  final String initial;
  final String confirm;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 60,
      textCapitalization: TextCapitalization.sentences,
      onSubmitted: (v) => Navigator.of(context).pop(v),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Zrušiť'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: Text(widget.confirm),
      ),
    ],
  );
}
