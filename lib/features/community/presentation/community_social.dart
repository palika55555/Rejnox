import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_button.dart';
import '../../chat/application/chat_providers.dart';
import '../../chat/domain/chat_models.dart';
import '../../chat/presentation/chats_screen.dart' show showJoinGroupDialog;
import '../application/community_providers.dart';
import '../domain/community_models.dart';
import 'community_async.dart';
import 'community_format.dart';
import 'community_glass.dart';

// Rebríček a skupiny.

/// Týždenný rebríček aktivity so súhlasom na zobrazenie.
class LeaderboardSection extends ConsumerWidget {
  const LeaderboardSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(leaderboardProvider);
    return AsyncSection<Leaderboard>(
      value: value,
      onRefresh: () => ref.invalidate(leaderboardProvider),
      header: [
        if (value.value case final board?) _OptInCard(optedIn: board.optedIn),
      ],
      isEmpty: (b) => b.entries.isEmpty,
      empty: const GlassEmpty(
        icon: Icons.leaderboard_outlined,
        title: 'Zatiaľ nič…',
        text:
            'Tento týždeň ešte nikto z rebríčka netrénoval. Rátajú sa dni '
            's tréningom za posledných 7 dní.',
      ),
      builder: (b) => [
        if (b.entries.length >= 3) _Podium(b.entries.take(3).toList()),
        for (final (i, e) in b.entries.indexed.skip(
          b.entries.length >= 3 ? 3 : 0,
        ))
          _RankRow(rank: i + 1, entry: e),
      ],
    );
  }
}

class _OptInCard extends ConsumerStatefulWidget {
  const _OptInCard({required this.optedIn});

  final bool optedIn;

  @override
  ConsumerState<_OptInCard> createState() => _OptInCardState();
}

class _OptInCardState extends ConsumerState<_OptInCard> {
  bool _busy = false;

  Future<void> _set(bool on) async {
    setState(() => _busy = true);
    try {
      await ref.read(communityActionsProvider).setLeaderboardOptIn(on);
    } on Object catch (e) {
      if (mounted) showCommunityError(context, e, 'Nepodarilo sa to uložiť.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FrostCard(
      highlight: widget.optedIn,
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: widget.optedIn,
        onChanged: _busy ? null : _set,
        title: const Text('Ukázať ma v rebríčku'),
        subtitle: const Text(
          'Ostatní uvidia tvoje meno, mesto a počet dní s tréningom.',
        ),
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium(this.top);

  final List<LeaderboardEntry> top;

  @override
  Widget build(BuildContext context) {
    // Poradie na stupienku: 2. – 1. – 3.
    const order = [1, 0, 2];
    const heights = [92.0, 120.0, 72.0];
    final medals = [Plate.yellow.color, AppColors.steel, AppColors.accentDeep];
    return FrostCard(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (slot, i) in order.indexed)
            Expanded(
              child: Column(
                children: [
                  GlassAvatar(top[i].name, size: i == 0 ? 56 : 46),
                  const SizedBox(height: 6),
                  Text(
                    top[i].me ? '${top[i].name} (ty)' : top[i].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    '${top[i].days} ${plural(top[i].days, 'deň', 'dni', 'dní')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: heights[slot]),
                    duration: Duration(milliseconds: 600 + slot * 120),
                    curve: Curves.easeOutBack,
                    builder: (context, h, _) => Container(
                      height: h,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.topCenter,
                      padding: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(14),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            medals[i].withValues(alpha: 0.55),
                            medals[i].withValues(alpha: 0.08),
                          ],
                        ),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.entry});

  final int rank;
  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return FrostCard(
      highlight: entry.me,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(width: 28, child: Text('$rank', style: text.titleMedium)),
          GlassAvatar(entry.name, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.me ? '${entry.name} (ty)' : entry.name),
                if (entry.city != null)
                  Text(entry.city!, style: text.bodySmall),
              ],
            ),
          ),
          Text(
            '${entry.days} ${plural(entry.days, 'deň', 'dni', 'dní')}',
            style: text.titleSmall!.copyWith(color: AppColors.accent),
          ),
        ],
      ),
    );
  }
}

/// Moje skupiny z chatu: založenie, pridanie kódom, otvorenie.
class GroupsSection extends ConsumerWidget {
  const GroupsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(conversationsProvider);
    final actions = Row(
      children: [
        Expanded(
          child: PrimaryButton(
            label: 'Nová skupina',
            icon: Icons.add_rounded,
            compact: true,
            onPressed: () => context.push('/chat-new?group=1'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: PrimaryButton(
            label: 'Mám kód',
            icon: Icons.vpn_key_outlined,
            compact: true,
            tone: ButtonTone.ghost,
            onPressed: () => showJoinGroupDialog(context, ref),
          ),
        ),
      ],
    );
    return AsyncSection<List<Conversation>>(
      value: value,
      onRefresh: () => ref.invalidate(conversationsProvider),
      header: [actions],
      isEmpty: (list) => !list.any((c) => c.kind == ConversationKind.group),
      empty: const GlassEmpty(
        icon: Icons.groups_outlined,
        title: 'Zatiaľ nič…',
        text:
            'Nie si v žiadnej skupine. Založ si vlastnú alebo sa pridaj '
            'kódom, ktorý ti niekto pošle.',
      ),
      builder: (list) => [
        for (final c in list.where((c) => c.kind == ConversationKind.group))
          FrostCard(
            onTap: () => context.push('/conversation/${c.id}'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                GlassAvatar(c.title),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        '${c.memberCount} '
                        '${plural(c.memberCount, 'člen', 'členovia', 'členov')}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (c.unread > 0)
                  Badge(label: Text('${c.unread}'))
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.muted,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
