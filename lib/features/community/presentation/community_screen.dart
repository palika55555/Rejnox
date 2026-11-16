import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tm_card.dart';

enum CommunitySection {
  feed(
    'Príspevky',
    Icons.dynamic_feed_outlined,
    'Zatiaľ tu nie sú žiadne príspevky.',
  ),
  buddies(
    'Parťáci',
    Icons.group_add_outlined,
    'Zatiaľ nikto nehľadá parťáka na tréning.',
  ),
  events('Udalosti', Icons.event_outlined, 'Zatiaľ nie sú žiadne udalosti.'),
  challenges('Výzvy', Icons.flag_outlined, 'Zatiaľ nie sú žiadne výzvy.'),
  groups('Skupiny', Icons.groups_outlined, 'Zatiaľ nie sú žiadne skupiny.'),
  leaderboard(
    'Rebríčky',
    Icons.leaderboard_outlined,
    'Zatiaľ nie sú žiadne rebríčky.',
  );

  const CommunitySection(this.label, this.icon, this.emptyText);
  final String label;
  final IconData icon;
  final String emptyText;
}

/// Komunita: príspevky, parťáci, udalosti, výzvy, skupiny a rebríčky.
/// Server pre ne zatiaľ nemá údaje, preto každá sekcia ukazuje poctivý
/// prázdny stav namiesto vymyslených príspevkov a mien.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  CommunitySection _section = CommunitySection.feed;

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
                onPressed: () => context.push('/notifications'),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
              child: _EmptySection(_section),
            ),
          ),
        ],
      ),
    );
  }
}

/// Prázdny stav sekcie, kým pre ňu nie sú údaje na serveri.
class _EmptySection extends StatelessWidget {
  const _EmptySection(this.section);

  final CommunitySection section;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return TmCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        children: [
          Icon(section.icon, color: AppColors.muted, size: 32),
          const SizedBox(height: 12),
          Text(
            'Zatiaľ nič…',
            style: text.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            section.emptyText,
            style: text.bodyMedium!.copyWith(color: AppColors.ink2),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
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
