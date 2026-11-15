import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tm_card.dart';
import '../../notifications/notifications_screen.dart';
import '../application/chat_providers.dart';
import '../domain/chat_models.dart';
import 'chat_widgets.dart';

/// Správy: konverzácie s trénerom (klient) alebo s klientmi (tréner).
class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threads = ref.watch(chatThreadsProvider);
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ScreenHeader('Správy', trailing: [NotificationBell()]),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(chatThreadsProvider.future),
              child: threads.when(
                skipLoadingOnRefresh: true,
                skipLoadingOnReload: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _Message(
                  icon: Icons.cloud_off_rounded,
                  title: e is ApiError ? e.message : 'Niečo sa pokazilo.',
                  action: TextButton(
                    onPressed: () => ref.invalidate(chatThreadsProvider),
                    child: const Text('Skúsiť znova'),
                  ),
                ),
                data: (list) => list.isEmpty
                    ? const _Message(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'Zatiaľ nemáš s kým písať',
                        body:
                            'Chat sa otvorí, keď sa prepojíš s trénerom '
                            '(alebo tréner s klientom) cez pozývací kód.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _ThreadTile(
                          list[i],
                          onTap: () => context.push(
                            '/chat/${list[i].linkId}',
                            extra: list[i].name,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile(this.thread, {required this.onTap});

  final ChatThread thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final last = thread.lastMessage;
    final unread = thread.unread > 0;
    final preview = last == null
        ? (thread.canSend ? 'Napíš prvú správu' : 'Bez správ')
        : '${last.mine ? 'Ty: ' : ''}${last.body}';
    return TmCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          ChatAvatar(thread.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        thread.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium,
                      ),
                    ),
                    if (last != null)
                      Text(
                        shortTime(last.sentAt),
                        style: text.bodySmall!.copyWith(
                          color: unread ? AppColors.accent : AppColors.muted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium!.copyWith(
                          color: unread ? AppColors.text : AppColors.muted,
                          fontWeight: unread ? FontWeight.w600 : null,
                        ),
                      ),
                    ),
                    if (unread) ...[
                      const SizedBox(width: 8),
                      CountBadge(thread.unread),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    thread.withTrainer ? 'Tréner' : 'Klient',
                    if (!thread.canSend) 'spolupráca ukončená',
                  ].join(' · '),
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

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // ListView, aby sa dalo potiahnuť nadol aj na prázdnej obrazovke.
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 28),
      children: [
        Icon(icon, size: 40, color: AppColors.muted),
        const SizedBox(height: 12),
        Text(title, style: text.titleMedium, textAlign: TextAlign.center),
        if (body != null) ...[
          const SizedBox(height: 6),
          Text(
            body!,
            style: text.bodyMedium!.copyWith(color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
        ],
        if (action != null) Center(child: action),
      ],
    );
  }
}
