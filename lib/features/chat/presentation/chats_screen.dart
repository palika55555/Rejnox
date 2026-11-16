import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tm_card.dart';
import '../../notifications/notifications_screen.dart';
import '../application/chat_actions.dart';
import '../application/chat_providers.dart';
import '../domain/chat_models.dart';
import 'chat_widgets.dart';

/// Správy: konverzácie s trénerom / klientmi, súkromné správy a skupiny.
class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  String _query = '';

  List<Conversation> _filter(List<Conversation> list) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return [
      for (final c in list)
        if (c.title.toLowerCase().contains(q)) c,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationsProvider);
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenHeader(
            'Správy',
            trailing: [
              IconButton(
                tooltip: 'Nová konverzácia',
                onPressed: () => showNewChatMenu(context, ref),
                icon: const Icon(Icons.edit_square),
              ),
              const NotificationBell(),
            ],
          ),
          if ((conversations.value?.length ?? 0) > 5)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Hľadať v konverzáciách',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(conversationsProvider.future),
              child: conversations.when(
                skipLoadingOnRefresh: true,
                skipLoadingOnReload: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ChatEmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: chatErrorText(e),
                  action: TextButton(
                    onPressed: () => ref.invalidate(conversationsProvider),
                    child: const Text('Skúsiť znova'),
                  ),
                ),
                data: (all) {
                  final list = _filter(all);
                  if (all.isEmpty) {
                    return ChatEmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Zatiaľ žiadne konverzácie',
                      body:
                          'Chat s trénerom sa otvorí po prepojení cez pozývací '
                          'kód. Môžeš tiež založiť skupinu alebo sa do nejakej '
                          'pridať kódom.',
                      action: FilledButton.icon(
                        onPressed: () => showNewChatMenu(context, ref),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Nová konverzácia'),
                      ),
                    );
                  }
                  if (list.isEmpty) {
                    return const ChatEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Nič sa nenašlo',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => ConversationTile(
                      list[i],
                      onTap: () => context.push(
                        '/conversation/${list[i].id}',
                        extra: list[i].title,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ConversationTile extends StatelessWidget {
  const ConversationTile(this.conversation, {super.key, required this.onTap});

  final Conversation conversation;
  final VoidCallback onTap;

  String get _preview {
    final last = conversation.lastMessage;
    if (last == null) {
      return conversation.canSend ? 'Napíš prvú správu' : 'Bez správ';
    }
    if (last.kind == MessageKind.system) return last.preview;
    final who = last.mine
        ? 'Ty: '
        : conversation.isGroup && last.senderName != null
        ? '${last.senderName!.split(' ').first}: '
        : '';
    return '$who${last.preview}';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = conversation;
    final last = c.lastMessage;
    final unread = c.unread > 0;
    return TmCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          ChatAvatar(c.title, group: c.isGroup),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium,
                      ),
                    ),
                    if (c.muted)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.notifications_off_outlined,
                          size: 15,
                          color: AppColors.muted,
                        ),
                      ),
                    if (last != null)
                      Text(
                        shortTime(last.sentAt),
                        style: text.bodySmall!.copyWith(
                          color: unread && !c.muted
                              ? AppColors.accent
                              : AppColors.muted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium!.copyWith(
                          color: unread ? AppColors.text : AppColors.muted,
                          fontWeight: unread ? FontWeight.w600 : null,
                          fontStyle:
                              last?.deleted == true ||
                                  last?.kind == MessageKind.system
                              ? FontStyle.italic
                              : null,
                        ),
                      ),
                    ),
                    if (unread) ...[
                      const SizedBox(width: 8),
                      CountBadge(c.unread, muted: c.muted),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  c.subtitle,
                  style: text.bodySmall!.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ponuka: nová súkromná správa, nová skupina, vstup do skupiny kódom.
Future<void> showNewChatMenu(BuildContext context, WidgetRef ref) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: AppList(
            children: [
              AppRow(
                leading: const Icon(Icons.person_outline_rounded),
                title: 'Nová správa',
                subtitle: 'Tréner, klient alebo človek zo spoločnej skupiny',
                onTap: () {
                  Navigator.of(sheet).pop();
                  context.push('/chat-new');
                },
              ),
              AppRow(
                leading: const Icon(Icons.group_add_outlined),
                title: 'Nová skupina',
                subtitle: 'Spoločný chat pre viac ľudí',
                onTap: () {
                  Navigator.of(sheet).pop();
                  context.push('/chat-new?group=1');
                },
              ),
              AppRow(
                leading: const Icon(Icons.vpn_key_outlined),
                title: 'Pridať sa kódom',
                subtitle: 'Kód skupiny v tvare XXXX-XXXX',
                onTap: () {
                  Navigator.of(sheet).pop();
                  showJoinGroupDialog(context, ref);
                },
              ),
            ],
          ),
        ),
      ),
    );

/// Vstup do skupiny cez pozývací kód; po úspechu otvorí skupinu.
Future<void> showJoinGroupDialog(BuildContext context, WidgetRef ref) async {
  final code = await showDialog<String>(
    context: context,
    builder: (_) => const _JoinDialog(),
  );
  if (code == null || !context.mounted) return;
  try {
    final id = await ref.read(chatActionsProvider).joinGroup(code);
    if (context.mounted) context.push('/conversation/$id');
  } on Object catch (e) {
    if (context.mounted) showChatError(context, e, 'Pridať sa nepodarilo.');
  }
}

class _JoinDialog extends StatefulWidget {
  const _JoinDialog();

  @override
  State<_JoinDialog> createState() => _JoinDialogState();
}

class _JoinDialogState extends State<_JoinDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim();
    if (code.isNotEmpty) Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Pridať sa do skupiny'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 12,
      textCapitalization: TextCapitalization.characters,
      decoration: const InputDecoration(hintText: 'XXXX-XXXX', counterText: ''),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Zrušiť'),
      ),
      TextButton(onPressed: _submit, child: const Text('Pridať sa')),
    ],
  );
}
