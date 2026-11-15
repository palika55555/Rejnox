import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/screen_header.dart';
import '../../core/widgets/tm_card.dart';
import '../auth/domain/auth_models.dart';
import '../auth/presentation/auth_controller.dart';
import '../coaching/presentation/my_trainer_card.dart';
import '../health/heart_rate_tile.dart';
import '../reminders/reminder_card.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const _comingSoon = [
    (Icons.badge_outlined, 'Tvoja permanentka v mobile'),
    (Icons.emoji_events_outlined, 'Rebríček osobných rekordov'),
    (Icons.lock_outline_rounded, 'Súkromie a nastavenia účtu'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth is SignedIn ? auth.user : null;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const ScreenHeader('Profil'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
              child: SectionStack(
                children: [
                  if (user != null) _UserCard(user),
                  const AppSection(title: 'Tréner', child: MyTrainerCard()),
                  const AppSection(title: 'Zdravie', child: HeartRateTile()),
                  const AppSection(title: 'Pripomienky', child: ReminderCard()),
                  AppSection(
                    title: 'Čoskoro',
                    child: AppList(
                      children: [
                        for (final (icon, label) in _comingSoon)
                          AppRow(
                            leading: Icon(icon, color: AppColors.ink2),
                            title: label,
                            trailing: const AppPill('Čoskoro'),
                          ),
                      ],
                    ),
                  ),
                  AppSection(
                    title: 'Nastavenia',
                    child: AppList(
                      children: [
                        AppRow(
                          leading: const Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.accent,
                          ),
                          title: 'O aplikácii',
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.muted,
                          ),
                          onTap: () => context.push('/about'),
                        ),
                      ],
                    ),
                  ),
                  PrimaryButton(
                    label: 'Odhlásiť sa',
                    icon: Icons.logout_rounded,
                    tone: ButtonTone.ghost,
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).logout(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar s iniciálou, meno, e-mail a rola.
class _UserCard extends StatelessWidget {
  const _UserCard(this.user);

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final name = user.displayName;
    return TmCard(
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.text,
            ),
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: text.titleMedium!.copyWith(
                fontSize: 21,
                color: AppColors.bg,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.toUpperCase(),
                  style: text.headlineMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  user.email,
                  style: text.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                AppPill(user.role.label, tone: PillTone.accent),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
