import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tm_card.dart';
import '../domain/community_demo_data.dart';
import 'community_widgets.dart';

enum CommunitySection {
  feed('Príspevky'),
  buddies('Parťáci'),
  events('Udalosti'),
  challenges('Výzvy'),
  groups('Skupiny'),
  leaderboard('Rebríčky');

  const CommunitySection(this.label);
  final String label;
}

/// Komunita: príspevky, parťáci, udalosti, výzvy, skupiny a rebríčky.
/// Zatiaľ na ukážkových údajoch – akcie bez backendu ohlásia „čoskoro“.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  CommunitySection _section = CommunitySection.feed;

  void _soon(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$feature pribudne čoskoro.')));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
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
                onPressed: () => _soon('Upozornenia'),
                icon: const Icon(Icons.notifications_none_rounded),
              ),
            ],
          ),
          _SectionChips(
            selected: _section,
            onChanged: (s) => setState(() => _section = s),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: IndexedStack(
              index: _section.index,
              children: [
                _page([
                  _Composer(onTap: _newPost),
                  for (final p in demoPosts) PostCard(p, onSoon: _soon),
                ]),
                _page([
                  _lead(
                    'Nájdi niekoho na spoločný tréning, beh '
                    'alebo inú aktivitu.',
                  ),
                  const CommunitySearch(hint: 'Hľadať podľa mesta alebo mena'),
                  for (final b in demoBuddies)
                    BuddyCard(b, onContact: () => _soon('Oslovenie parťáka')),
                ]),
                _page([
                  AppSection(
                    title: 'Nadchádzajúce udalosti',
                    child: Column(
                      children: [
                        for (final (i, e) in demoEvents.indexed) ...[
                          if (i > 0) const SizedBox(height: 12),
                          EventCard(
                            e,
                            onJoin: () => _soon('Prihlasovanie na udalosti'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ]),
                _page([
                  _lead('Prekonávaj svoje limity spolu s ostatnými.'),
                  for (final c in demoChallenges)
                    ChallengeCard(c, onOpen: () => _soon('Detail výzvy')),
                ]),
                _page([
                  const CommunitySearch(hint: 'Hľadať skupinu'),
                  AppList(
                    children: [
                      for (final g in demoGroups)
                        GroupRow(g, onTap: () => _soon('Detail skupiny')),
                    ],
                  ),
                  PrimaryButton(
                    label: 'Vytvoriť skupinu',
                    icon: Icons.add_rounded,
                    tone: ButtonTone.ghost,
                    onPressed: () => _soon('Vytváranie skupín'),
                  ),
                ]),
                _page([
                  AppSection(
                    title: 'Najaktívnejší tento týždeň',
                    child: Podium(demoLeaderboard.take(3).toList()),
                  ),
                  AppList(
                    children: [
                      for (final (i, e) in demoLeaderboard.indexed.skip(3))
                        LeaderboardRow(rank: i + 1, entry: e),
                    ],
                  ),
                  Text(
                    'Ukážkové údaje. Reálne rebríčky budú počítať len '
                    'overené tréningy.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _page(List<Widget> children) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
    child: SectionStack(gap: 12, children: children),
  );

  Widget _lead(String text) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.bodyMedium!.copyWith(color: AppColors.ink2),
  );

  Future<void> _newPost() async {
    final posted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _NewPostSheet(),
    );
    if (posted ?? false) _soon('Ukladanie príspevkov');
  }
}

/// Vodorovné čipy sekcií; vybraný je atramentový.
class _SectionChips extends StatelessWidget {
  const _SectionChips({required this.selected, required this.onChanged});

  final CommunitySection selected;
  final ValueChanged<CommunitySection> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 42,
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
            child: Material(
              color: on ? AppColors.text : AppColors.surface,
              shape: StadiumBorder(
                side: BorderSide(color: on ? AppColors.text : AppColors.border),
              ),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => onChanged(section),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Center(
                    child: Text(
                      section.label,
                      style: text.bodyMedium!.copyWith(
                        fontWeight: FontWeight.w600,
                        color: on ? AppColors.bg : AppColors.ink2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// „Podeľ sa o svoj progres…“ – otvorí nový príspevok.
class _Composer extends StatelessWidget {
  const _Composer({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(26);
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: AppColors.border, width: 1.5),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              const SizedBox(width: 16),
              const Icon(Icons.edit_outlined, color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Podeľ sa o svoj progres…',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Spodný panel na napísanie príspevku. Vráti true, ak sa zdieľal.
class _NewPostSheet extends StatefulWidget {
  const _NewPostSheet();

  @override
  State<_NewPostSheet> createState() => _NewPostSheetState();
}

class _NewPostSheetState extends State<_NewPostSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        10,
        MediaQuery.viewInsetsOf(context).bottom + 22,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'NOVÝ PRÍSPEVOK',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Zavrieť',
                onPressed: () => Navigator.pop(context, false),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _controller,
                  autofocus: true,
                  minLines: 4,
                  maxLines: 7,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    hintText: 'Čo máš na mysli?',
                  ),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder(
                  valueListenable: _controller,
                  builder: (context, value, _) => PrimaryButton(
                    label: 'Zdieľať príspevok',
                    onPressed: value.text.trim().isEmpty
                        ? null
                        : () => Navigator.pop(context, true),
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
