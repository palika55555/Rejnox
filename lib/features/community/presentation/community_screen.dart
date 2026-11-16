import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/screen_header.dart';
import '../application/community_providers.dart';
import '../domain/community_models.dart';
import 'community_async.dart';
import 'community_cards.dart';
import 'community_glass.dart';
import 'community_sheets.dart';
import 'community_social.dart';

enum CommunitySection {
  feed('Príspevky', Icons.dynamic_feed_rounded),
  buddies('Parťáci', Icons.handshake_rounded),
  events('Udalosti', Icons.event_rounded),
  challenges('Výzvy', Icons.flag_rounded),
  groups('Skupiny', Icons.groups_rounded),
  leaderboard('Rebríčky', Icons.leaderboard_rounded);

  const CommunitySection(this.label, this.icon);
  final String label;
  final IconData icon;

  /// Čo pridá tlačidlo „+“ (skupiny a rebríček ho nemajú).
  (String, Widget Function())? get create => switch (this) {
    feed => ('Nový príspevok', NewPostSheet.new),
    buddies => ('Hľadám parťáka', NewBuddySheet.new),
    events => ('Nová udalosť', NewEventSheet.new),
    challenges => ('Nová výzva', NewChallengeSheet.new),
    groups || leaderboard => null,
  };
}

/// Komunita: príspevky, parťáci na tréning, udalosti, výzvy, skupiny
/// a týždenný rebríček. Všetko sú skutočné údaje zo servera.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  CommunitySection _section = CommunitySection.feed;

  @override
  Widget build(BuildContext context) {
    final create = _section.create;
    return GlowBackdrop(
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ScreenHeader(
                  'Komunita',
                  trailing: [
                    IconButton(
                      tooltip: 'Správy',
                      onPressed: () => context.go('/chat'),
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                    ),
                    IconButton(
                      tooltip: 'Upozornenia',
                      onPressed: () => context.push('/notifications'),
                      icon: const Icon(Icons.notifications_none_rounded),
                    ),
                  ],
                ),
                _SectionChips(
                  selected: _section,
                  onChanged: (s) => setState(() => _section = s),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0.04, 0),
                          end: Offset.zero,
                        ).animate(a),
                        child: child,
                      ),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(_section),
                      child: _body(_section),
                    ),
                  ),
                ),
              ],
            ),
            if (create != null)
              Positioned(
                right: 16,
                bottom: 20,
                child: _CreateButton(
                  label: create.$1,
                  onPressed: () => showCommunitySheet(context, create.$2()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _body(CommunitySection section) => switch (section) {
    CommunitySection.feed => const _FeedSection(),
    CommunitySection.buddies => const _BuddiesSection(),
    CommunitySection.events => const _EventsSection(),
    CommunitySection.challenges => const _ChallengesSection(),
    CommunitySection.groups => const GroupsSection(),
    CommunitySection.leaderboard => const LeaderboardSection(),
  };
}

class _FeedSection extends ConsumerWidget {
  const _FeedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      AsyncSection<List<CommunityPost>>(
        value: ref.watch(communityPostsProvider),
        onRefresh: () => ref.invalidate(communityPostsProvider),
        isEmpty: (l) => l.isEmpty,
        empty: const GlassEmpty(
          icon: Icons.dynamic_feed_rounded,
          title: 'Zatiaľ nič…',
          text: 'Zatiaľ tu nie sú žiadne príspevky. Buď prvý a pochváľ sa.',
        ),
        builder: (posts) => [
          for (final p in posts)
            PostCard(
              p,
              key: ValueKey(p.id),
              onComments: () =>
                  showCommunitySheet(context, CommentsSheet(postId: p.id)),
            ),
        ],
      );
}

class _BuddiesSection extends ConsumerWidget {
  const _BuddiesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      AsyncSection<List<BuddyRequest>>(
        value: ref.watch(buddyRequestsProvider),
        onRefresh: () => ref.invalidate(buddyRequestsProvider),
        isEmpty: (l) => l.isEmpty,
        empty: const GlassEmpty(
          icon: Icons.handshake_rounded,
          title: 'Zatiaľ nič…',
          text:
              'Zatiaľ nikto nehľadá parťáka. Daj vedieť, kedy a kde ideš '
              'trénovať.',
        ),
        builder: (list) => [
          for (final b in list) BuddyCard(b, key: ValueKey(b.id)),
        ],
      );
}

class _EventsSection extends ConsumerWidget {
  const _EventsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      AsyncSection<List<CommunityEvent>>(
        value: ref.watch(communityEventsProvider),
        onRefresh: () => ref.invalidate(communityEventsProvider),
        isEmpty: (l) => l.isEmpty,
        empty: const GlassEmpty(
          icon: Icons.event_rounded,
          title: 'Zatiaľ nič…',
          text:
              'Zatiaľ nie sú žiadne udalosti. Zorganizuj spoločný beh '
              'alebo tréning.',
        ),
        builder: (list) => [
          for (final e in list) EventCard(e, key: ValueKey(e.id)),
        ],
      );
}

class _ChallengesSection extends ConsumerWidget {
  const _ChallengesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      AsyncSection<List<Challenge>>(
        value: ref.watch(challengesProvider),
        onRefresh: () => ref.invalidate(challengesProvider),
        isEmpty: (l) => l.isEmpty,
        empty: const GlassEmpty(
          icon: Icons.flag_rounded,
          title: 'Zatiaľ nič…',
          text:
              'Zatiaľ nie sú žiadne výzvy. Pokrok sa ráta z tvojich '
              'zapísaných tréningov.',
        ),
        builder: (list) => [
          for (final c in list) ChallengeCard(c, key: ValueKey(c.id)),
        ],
      );
}

/// Vodorovné sklenené čipy sekcií; vybraný svieti značkou.
class _SectionChips extends StatelessWidget {
  const _SectionChips({required this.selected, required this.onChanged});

  final CommunitySection selected;
  final ValueChanged<CommunitySection> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        scrollDirection: Axis.horizontal,
        itemCount: CommunitySection.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final section = CommunitySection.values[i];
          final on = section == selected;
          return Semantics(
            button: true,
            selected: on,
            child: GestureDetector(
              onTap: () => onChanged(section),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: on
                      ? const LinearGradient(
                          colors: [AppColors.accent, AppColors.accentDeep],
                        )
                      : null,
                  color: on ? null : Colors.white.withValues(alpha: 0.06),
                  border: Border.all(
                    color: on
                        ? AppColors.accent
                        : Colors.white.withValues(alpha: 0.12),
                  ),
                  boxShadow: on
                      ? [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.4),
                            blurRadius: 14,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      section.icon,
                      size: 16,
                      color: on ? AppColors.onAccent : AppColors.ink2,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      section.label,
                      style: text.bodyMedium!.copyWith(
                        fontWeight: FontWeight.w600,
                        color: on ? AppColors.onAccent : AppColors.ink2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Žiarivé plávajúce tlačidlo na pridanie do aktuálnej sekcie.
class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(label),
      tween: Tween(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.elasticOut,
      builder: (context, s, child) => Transform.scale(scale: s, child: child),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.45),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          heroTag: null,
          onPressed: onPressed,
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          icon: const Icon(Icons.add_rounded),
          label: Text(label),
        ),
      ),
    );
  }
}
