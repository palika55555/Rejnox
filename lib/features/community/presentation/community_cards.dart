import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../application/community_providers.dart';
import '../domain/community_models.dart';
import 'community_format.dart';
import 'community_glass.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/undo_snack.dart';

/// Ponuka „Zmazať“ pri vlastnom zázname (tlačidlo „⋯“).
class _OwnerMenu extends StatelessWidget {
  const _OwnerMenu({
    required this.what,
    required this.onDelete,
    this.confirm = true,
  });

  final String what;

  /// false = zmaže hneď a ponúkne „Späť“ (onDelete to rieši sám).
  final bool confirm;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Možnosti',
      icon: const Icon(Icons.more_horiz_rounded, color: AppColors.muted),
      onSelected: (_) async {
        if (!confirm || await confirmDelete(context, what)) await onDelete();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'delete', child: Text('Zmazať')),
      ],
    );
  }
}

/// Spoločná hlavička karty: avatar, meno, podnadpis, ponuka autora.
class _Byline extends StatelessWidget {
  const _Byline({required this.name, required this.subtitle, this.menu});

  final String name;
  final String subtitle;
  final Widget? menu;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        GlassAvatar(name),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: text.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
              Text(subtitle, style: text.bodySmall),
            ],
          ),
        ),
        ?menu,
      ],
    );
  }
}

/// Príspevok s lajkom (prejaví sa hneď) a komentármi.
class PostCard extends ConsumerStatefulWidget {
  const PostCard(this.post, {super.key, required this.onComments});

  final CommunityPost post;
  final VoidCallback onComments;

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  late CommunityPost _post = widget.post;
  bool _busy = false;
  bool _hidden = false;

  @override
  void didUpdateWidget(PostCard old) {
    super.didUpdateWidget(old);
    if (old.post != widget.post) _post = widget.post;
  }

  Future<void> _toggleLike() async {
    final before = _post;
    final liked = !before.likedByMe;
    setState(() {
      _busy = true;
      _post = before.copyWith(
        likedByMe: liked,
        likes: before.likes + (liked ? 1 : -1),
      );
    });
    try {
      final fresh = await ref
          .read(communityActionsProvider)
          .setLike(before.id, liked);
      if (mounted) setState(() => _post = fresh);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _post = before);
      showCommunityError(context, e, 'Lajk sa nepodarilo uložiť.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final actions = ref.read(communityActionsProvider);
    final id = _post.id;
    setState(() => _hidden = true);
    if (await showUndoSnack(context, 'Príspevok zmazaný')) {
      if (mounted) setState(() => _hidden = false);
      return;
    }
    try {
      await actions.deletePost(id);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _hidden = false);
      showCommunityError(context, e, 'Zmazať sa nepodarilo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    final post = _post;
    return FrostCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Byline(
            name: post.authorName,
            subtitle: agoLabel(post.createdAt),
            menu: post.mine
                ? _OwnerMenu(
                    what: 'príspevok',
                    confirm: false,
                    onDelete: _delete,
                  )
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(post.body, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: 8,
            children: [
              GlassToggle(
                on: post.likedByMe,
                icon: Icons.favorite_border_rounded,
                onIcon: Icons.favorite_rounded,
                label: '${post.likes}',
                busy: _busy,
                onPressed: _toggleLike,
              ),
              GlassToggle(
                on: false,
                icon: Icons.mode_comment_outlined,
                onIcon: Icons.mode_comment_outlined,
                label: '${post.comments}',
                onPressed: widget.onComments,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Spoločné „pridať sa / odísť“ s ochranou pred dvojitým ťuknutím.
mixin _JoinAction<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool busy = false;

  Future<void> run(Future<void> Function() action, String fail) async {
    setState(() => busy = true);
    try {
      await action();
    } on Object catch (e) {
      if (mounted) showCommunityError(context, e, fail);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class BuddyCard extends ConsumerStatefulWidget {
  const BuddyCard(this.buddy, {super.key});

  final BuddyRequest buddy;

  @override
  ConsumerState<BuddyCard> createState() => _BuddyCardState();
}

class _BuddyCardState extends ConsumerState<BuddyCard>
    with _JoinAction<BuddyCard> {
  @override
  Widget build(BuildContext context) {
    final b = widget.buddy;
    final actions = ref.read(communityActionsProvider);
    final people = b.members + 1;
    return FrostCard(
      highlight: b.joined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Byline(
            name: b.hostName,
            subtitle: b.mine ? 'Tvoj tréning' : 'hľadá parťáka',
            menu: b.mine
                ? _OwnerMenu(
                    what: 'tréning',
                    onDelete: () => run(
                      () => actions.deleteBuddy(b.id),
                      'Zmazať sa nepodarilo.',
                    ),
                  )
                : null,
          ),
          if (b.focus != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(b.focus!, style: Theme.of(context).textTheme.titleMedium),
          ],
          if (b.note != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(b.note!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              InfoTag(Icons.schedule_rounded, whenLabel(b.startsAt)),
              if (b.place != null) InfoTag(Icons.place_outlined, b.place!),
              InfoTag(
                Icons.group_outlined,
                '$people ${plural(people, 'človek', 'ľudia', 'ľudí')}',
              ),
            ],
          ),
          if (!b.mine) ...[
            const SizedBox(height: AppSpacing.lg),
            GlassToggle(
              on: b.joined,
              icon: Icons.handshake_outlined,
              onIcon: Icons.check_rounded,
              label: b.joined ? 'Ideš s nimi' : 'Pridať sa',
              busy: busy,
              onPressed: () => run(
                () => actions.joinBuddy(b.id, !b.joined),
                'Nepodarilo sa to uložiť.',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class EventCard extends ConsumerStatefulWidget {
  const EventCard(this.event, {super.key});

  final CommunityEvent event;

  @override
  ConsumerState<EventCard> createState() => _EventCardState();
}

class _EventCardState extends ConsumerState<EventCard>
    with _JoinAction<EventCard> {
  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final text = Theme.of(context).textTheme;
    final actions = ref.read(communityActionsProvider);
    return FrostCard(
      highlight: e.joined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _DateBadge(e.startsAt),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.title, style: text.titleMedium),
                    Text(
                      'Organizuje ${e.organizerName}',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              if (e.mine)
                _OwnerMenu(
                  what: 'udalosť',
                  onDelete: () => run(
                    () => actions.deleteEvent(e.id),
                    'Zmazať sa nepodarilo.',
                  ),
                ),
            ],
          ),
          if (e.description != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(e.description!, style: text.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              InfoTag(Icons.schedule_rounded, whenLabel(e.startsAt)),
              InfoTag(Icons.place_outlined, e.place),
              InfoTag(Icons.group_outlined, '${e.attendees} prihlásených'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassToggle(
            on: e.joined,
            icon: Icons.event_available_outlined,
            onIcon: Icons.check_rounded,
            label: e.joined ? 'Prídeš' : 'Prídem',
            busy: busy,
            onPressed: () => run(
              () => actions.joinEvent(e.id, !e.joined),
              'Nepodarilo sa to uložiť.',
            ),
          ),
        ],
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge(this.at);

  final DateTime at;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent.withValues(alpha: 0.35),
            AppColors.accent.withValues(alpha: 0.1),
          ],
        ),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text('${at.day}', style: text.titleLarge),
          Text('${at.month}. mes.', style: text.bodySmall),
        ],
      ),
    );
  }
}

class ChallengeCard extends ConsumerStatefulWidget {
  const ChallengeCard(this.challenge, {super.key});

  final Challenge challenge;

  @override
  ConsumerState<ChallengeCard> createState() => _ChallengeCardState();
}

class _ChallengeCardState extends ConsumerState<ChallengeCard>
    with _JoinAction<ChallengeCard> {
  @override
  Widget build(BuildContext context) {
    final c = widget.challenge;
    final text = Theme.of(context).textTheme;
    final actions = ref.read(communityActionsProvider);
    return FrostCard(
      highlight: c.completed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                c.completed ? Icons.emoji_events_rounded : Icons.flag_rounded,
                color: c.completed ? Plate.yellow.color : AppColors.accent,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(c.title, style: text.titleMedium)),
              if (c.mine)
                _OwnerMenu(
                  what: 'výzvu',
                  onDelete: () => run(
                    () => actions.deleteChallenge(c.id),
                    'Zmazať sa nepodarilo.',
                  ),
                ),
            ],
          ),
          if (c.description != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(c.description!, style: text.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              InfoTag(
                Icons.date_range_rounded,
                '${dayLabel(c.startsOn)} – ${dayLabel(c.endsOn)}',
              ),
              InfoTag(
                Icons.fitness_center_rounded,
                'cieľ ${c.goalDays} ${plural(c.goalDays, 'deň', 'dni', 'dní')}',
              ),
              InfoTag(Icons.group_outlined, '${c.members} v hre'),
            ],
          ),
          if (c.joined) ...[
            const SizedBox(height: AppSpacing.lg),
            _ProgressBar(value: c.progress),
            const SizedBox(height: AppSpacing.sm),
            Text(
              c.completed
                  ? 'Splnené! ${c.myDays} z ${c.goalDays} dní'
                  : '${c.myDays ?? 0} z ${c.goalDays} dní s tréningom',
              style: text.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          GlassToggle(
            on: c.joined,
            icon: Icons.add_rounded,
            onIcon: Icons.check_rounded,
            label: c.joined ? 'Si vo výzve' : 'Pridať sa',
            busy: busy,
            onPressed: () => run(
              () => actions.joinChallenge(c.id, !c.joined),
              'Nepodarilo sa to uložiť.',
            ),
          ),
        ],
      ),
    );
  }
}

/// Pokrok so žiarivou výplňou, ktorá sa pri zmene plynulo dorovná.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      value: '${(value * 100).round()} %',
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          color: Colors.white.withValues(alpha: 0.08),
        ),
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => FractionallySizedBox(
            widthFactor: v,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                gradient: const LinearGradient(
                  colors: [AppColors.accentDeep, AppColors.accent],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.5),
                    blurRadius: 10,
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
