import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/screen_header.dart';
import '../../core/widgets/tm_card.dart';
import '../auth/domain/auth_models.dart';
import '../auth/presentation/auth_controller.dart';
import '../chat/presentation/chat_widgets.dart';
import 'notification_models.dart';
import 'notifications_controller.dart';

/// Zvonček s počtom neprečítaných upozornení, otvorí ich zoznam.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(notificationsProvider).value?.unread ?? 0;
    return IconButton(
      tooltip: unread == 0 ? 'Upozornenia' : 'Upozornenia, $unread neprečítané',
      onPressed: () => context.push('/notifications'),
      icon: Badge(
        isLabelVisible: unread > 0,
        backgroundColor: AppColors.accent,
        textColor: AppColors.bg,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: const Icon(Icons.notifications_none_rounded),
      ),
    );
  }
}

IconData _icon(String kind) => switch (kind) {
  'plan' => Icons.assignment_rounded,
  'booking' => Icons.event_rounded,
  'slot' => Icons.event_available_rounded,
  'training' => Icons.fitness_center_rounded,
  'link' => Icons.handshake_outlined,
  'link_ended' => Icons.link_off_rounded,
  _ => Icons.notifications_none_rounded,
};

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  /// Ťuknutie: označí ako prečítané a otvorí, k čomu patrí.
  void _open(BuildContext context, WidgetRef ref, AppNotification n) {
    ref.read(notificationsProvider.notifier).markRead(n.id).ignore();
    // Lajk, komentár, nový parťák alebo účastník → Komunita.
    if (n.kind == 'community') return context.go('/community');
    final link = n.linkId;
    if (link == null) return;
    final auth = ref.read(authControllerProvider);
    final trainer = auth is SignedIn && auth.user.role == UserRole.trainer;
    switch (n.kind) {
      case 'plan' when !trainer:
        context.go('/home');
      case 'booking' || 'slot' when !trainer:
        context.push('/trainer/$link/calendar');
      case 'training' when !trainer:
        context.go('/workout');
      case 'link_ended':
        break;
      default:
        if (trainer) context.go('/clients/$link');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(notificationsProvider);
    final controller = ref.read(notificationsProvider.notifier);
    final text = Theme.of(context).textTheme;
    final list = feed.value?.notifications ?? const <AppNotification>[];
    final unread = feed.value?.unread ?? 0;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ScreenHeader(
                    'Upozornenia',
                    onBack: () =>
                        context.canPop() ? context.pop() : context.go('/home'),
                    trailing: [
                      if (unread > 0)
                        TextButton(
                          onPressed: () => controller.markAllRead().ignore(),
                          child: const Text('Prečítať všetko'),
                        ),
                    ],
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: controller.refresh,
                      child: feed.isLoading && !feed.hasValue
                          ? const Center(child: CircularProgressIndicator())
                          : list.isEmpty
                          ? ListView(
                              padding: const EdgeInsets.all(32),
                              children: [
                                const Icon(
                                  Icons.notifications_none_rounded,
                                  size: 40,
                                  color: AppColors.muted,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Žiadne upozornenia',
                                  style: text.titleMedium,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Ozveme sa, keď ti tréner pošle plán, '
                                  'potvrdí tréning alebo sa niečo zmení.',
                                  style: text.bodyMedium!.copyWith(
                                    color: AppColors.muted,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                              itemCount: list.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) => Dismissible(
                                key: ValueKey(list[i].id),
                                direction: DismissDirection.endToStart,
                                onDismissed: (_) =>
                                    controller.delete(list[i].id).ignore(),
                                background: const Align(
                                  alignment: Alignment.centerRight,
                                  child: Padding(
                                    padding: EdgeInsets.only(right: 20),
                                    child: Icon(Icons.delete_outline_rounded),
                                  ),
                                ),
                                child: _Tile(
                                  list[i],
                                  onTap: () => _open(context, ref, list[i]),
                                ),
                              ),
                            ),
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
}

class _Tile extends StatelessWidget {
  const _Tile(this.notification, {required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final n = notification;
    return TmCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _icon(n.kind),
            color: n.read ? AppColors.muted : AppColors.accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.title,
                  style: text.titleMedium!.copyWith(
                    fontWeight: n.read ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
                if (n.body != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    n.body!,
                    style: text.bodyMedium!.copyWith(color: AppColors.muted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            shortTime(n.createdAt),
            style: text.bodySmall!.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
