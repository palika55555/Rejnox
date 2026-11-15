import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/tm_card.dart';
import '../domain/community_demo_data.dart';

/// Kruh s iniciálou (ako avatar v hlavičke Dnes).
class CommunityAvatar extends StatelessWidget {
  const CommunityAvatar(this.name, {super.key, this.size = 42});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(RegExp(r'[\s,]+'))
        .where((p) => p.isNotEmpty && RegExp(r'^\D').hasMatch(p))
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.well,
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.ink2,
        ),
      ),
    );
  }
}

/// Riadok „avatar + meno + podtitulok“ v hlavičke karty.
class _Byline extends StatelessWidget {
  const _Byline({required this.name, required this.meta, this.trailing});

  final String name;
  final String meta;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        CommunityAvatar(name),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: text.bodyLarge),
              Text(meta, style: text.bodySmall),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Príloha príspevku: ikona a krátky údaj v zapustenej ploche.
class _Attachment extends StatelessWidget {
  const _Attachment({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.well,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.ink2),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Príspevok vo feede s lajkom, komentármi a zdieľaním.
class PostCard extends StatefulWidget {
  const PostCard(this.post, {super.key, required this.onSoon});

  final CommunityPost post;

  /// Akcia, ktorá ešte nemá backend.
  final ValueChanged<String> onSoon;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _liked = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final post = widget.post;
    return TmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Byline(
            name: post.author,
            meta: post.meta,
            trailing: IconButton(
              tooltip: 'Možnosti príspevku',
              onPressed: () => widget.onSoon('Možnosti príspevku'),
              icon: const Icon(
                Icons.more_horiz_rounded,
                color: AppColors.muted,
              ),
            ),
          ),
          const SizedBox(height: 11),
          Text(post.title, style: text.titleMedium),
          const SizedBox(height: 4),
          Text(post.body, style: text.bodyMedium!.copyWith(fontSize: 15.5)),
          const SizedBox(height: 11),
          _Attachment(icon: post.icon, label: post.highlight),
          const SizedBox(height: 6),
          Row(
            children: [
              _ActionChip(
                icon: _liked ? Icons.favorite : Icons.favorite_border,
                label: '${post.likes + (_liked ? 1 : 0)}',
                active: _liked,
                tooltip: _liked ? 'Zrušiť páči sa mi' : 'Páči sa mi',
                onTap: () => setState(() => _liked = !_liked),
              ),
              _ActionChip(
                icon: Icons.chat_bubble_outline_rounded,
                label: '${post.comments}',
                tooltip: 'Komentáre',
                onTap: () => widget.onSoon('Komentáre'),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Zdieľať',
                onPressed: () => widget.onSoon('Zdieľanie'),
                icon: const Icon(
                  Icons.ios_share_rounded,
                  color: AppColors.ink2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accent : AppColors.ink2;
    return Semantics(
      button: true,
      selected: active,
      label: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Niekto hľadá parťáka na tréning.
class BuddyCard extends StatelessWidget {
  const BuddyCard(this.buddy, {super.key, required this.onContact});

  final BuddyRequest buddy;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    return TmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Byline(name: buddy.name, meta: buddy.place),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AppPill(buddy.when, tone: PillTone.info, icon: Icons.schedule),
              AppPill(buddy.activity, icon: Icons.fitness_center_rounded),
            ],
          ),
          const SizedBox(height: 10),
          Text(buddy.note, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'Osloviť',
            compact: true,
            tone: ButtonTone.ghost,
            onPressed: onContact,
          ),
        ],
      ),
    );
  }
}

/// Nadchádzajúca spoločná udalosť.
class EventCard extends StatelessWidget {
  const EventCard(this.event, {super.key, required this.onJoin});

  final CommunityEvent event;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return TmCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(event.icon, color: AppColors.accent, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel(event.when),
                const SizedBox(height: 4),
                Text(event.title, style: text.titleMedium),
                const SizedBox(height: 4),
                Text(event.place, style: text.bodySmall),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${event.attendees} účastníkov',
                        style: text.bodySmall,
                      ),
                    ),
                    PrimaryButton(
                      label: 'Prihlásiť sa',
                      compact: true,
                      onPressed: onJoin,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Výzva s priebehom.
class ChallengeCard extends StatelessWidget {
  const ChallengeCard(this.challenge, {super.key, required this.onOpen});

  final Challenge challenge;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = challenge;
    return TmCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(c.title.toUpperCase(), style: text.headlineMedium),
              ),
              Icon(c.icon, color: AppColors.ink2),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            c.description,
            style: text.bodyMedium!.copyWith(color: AppColors.ink2),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text.rich(
                TextSpan(
                  text: '${c.progress}',
                  children: [
                    TextSpan(
                      text: ' / ${c.goal}',
                      style: text.bodySmall!.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                style: text.headlineLarge!.copyWith(fontSize: 28),
              ),
              const Spacer(),
              Text(c.members, style: text.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: c.progress / c.goal,
              minHeight: 6,
              color: AppColors.accent,
              backgroundColor: AppColors.border,
            ),
          ),
        ],
      ),
    );
  }
}

/// Riadok skupiny v zozname.
class GroupRow extends StatelessWidget {
  const GroupRow(this.group, {super.key, required this.onTap});

  final CommunityGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppRow(
      onTap: onTap,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.well,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(group.icon, color: AppColors.ink2, size: 20),
      ),
      title: group.name,
      subtitle: '${group.members} · ${group.description}',
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
    );
  }
}

/// Stupne víťazov: druhý, prvý, tretí. Prvé miesto je tmavá hero plocha.
class Podium extends StatelessWidget {
  const Podium(this.top, {super.key}) : assert(top.length == 3);

  final List<LeaderboardEntry> top;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _Step(rank: 2, entry: top[1], height: 88)),
        const SizedBox(width: 8),
        Expanded(child: _Step(rank: 1, entry: top[0], height: 120)),
        const SizedBox(width: 8),
        Expanded(child: _Step(rank: 3, entry: top[2], height: 72)),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.rank, required this.entry, required this.height});

  final int rank;
  final LeaderboardEntry entry;
  final double height;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final first = rank == 1;
    return Column(
      children: [
        CommunityAvatar(entry.name),
        const SizedBox(height: 6),
        Text(
          entry.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.bodyMedium!.copyWith(fontWeight: FontWeight.w700),
        ),
        Text('${entry.workouts} tréningov', style: text.bodySmall),
        const SizedBox(height: 8),
        Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: first ? AppColors.hero : AppColors.surface,
            border: first ? null : Border.all(color: AppColors.border),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Text(
            '$rank',
            style: text.headlineLarge!.copyWith(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: first ? AppColors.accent : AppColors.text,
            ),
          ),
        ),
      ],
    );
  }
}

/// Riadok rebríčka od 4. miesta.
class LeaderboardRow extends StatelessWidget {
  const LeaderboardRow({super.key, required this.rank, required this.entry});

  final int rank;
  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: text.headlineLarge!.copyWith(
                fontSize: 22,
                color: AppColors.muted,
              ),
            ),
          ),
          const SizedBox(width: 10),
          CommunityAvatar(entry.name, size: 36),
          const SizedBox(width: 10),
          Expanded(child: Text(entry.name, style: text.bodyLarge)),
          Text(
            '${entry.workouts}',
            style: text.headlineLarge!.copyWith(fontSize: 22),
          ),
          const SizedBox(width: 4),
          Text('tréningov', style: text.bodySmall),
        ],
      ),
    );
  }
}

/// Vyhľadávacie pole v štýle návrhu.
class CommunitySearch extends StatelessWidget {
  const CommunitySearch({super.key, required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted),
      ),
    );
  }
}
