import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/screen_header.dart';
import '../../core/widgets/tm_card.dart';
import '../auth/domain/auth_models.dart';
import '../auth/presentation/auth_controller.dart';
import '../notifications/notifications_controller.dart';
import '../training/application/workout_session.dart';
import '../training/presentation/workout_session_widgets.dart';
import 'more_sheet.dart';
import '../../core/theme/app_spacing.dart';

/// Rám appky: tmavé pozadie so žiarami, obsah a sklenená spodná lišta.
/// Na webe drží šírku telefónu.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  /// Poradie vetiev v routeri: 0 Dnes, 1 Mapa, 2 Tréning, 3 Správy,
  /// 4 Profil, 5 Klienti (len tréner), 6 Komunita. Čo sa do lišty nezmestí,
  /// je v menu „Viac“ (posledná položka lišty).
  static const _workoutBranch = 2;
  static const _mapBranch = 1;
  static const _chatBranch = 3;
  static const _profileBranch = 4;

  static const _communityBranch = 6;

  // Správy sú v lište: otvárajú sa najčastejšie a odznak je stále vidieť.
  static const _member = [
    (branch: 0, icon: Icons.home_outlined, label: 'Dnes'),
    (branch: 2, icon: Icons.fitness_center, label: 'Tréning'),
    (
      branch: _chatBranch,
      icon: Icons.chat_bubble_outline_rounded,
      label: 'Správy',
    ),
    (branch: _communityBranch, icon: Icons.forum_outlined, label: 'Komunita'),
  ];
  static const _trainer = [
    (branch: 0, icon: Icons.home_outlined, label: 'Dnes'),
    (branch: 5, icon: Icons.groups_outlined, label: 'Klienti'),
    (branch: 2, icon: Icons.fitness_center, label: 'Tréning'),
    (
      branch: _chatBranch,
      icon: Icons.chat_bubble_outline_rounded,
      label: 'Správy',
    ),
  ];

  void _goBranch(int branch) =>
      shell.goBranch(branch, initialLocation: branch == shell.currentIndex);

  List<MoreItem> _moreItems(BuildContext context, AuthUser? user) => [
    (
      icon: Icons.person_outline_rounded,
      title: 'Profil',
      subtitle: user?.displayName,
      onTap: () => _goBranch(_profileBranch),
    ),
    if (user?.role == UserRole.trainer)
      (
        icon: Icons.calendar_month_rounded,
        title: 'Kalendár',
        subtitle: 'Termíny, tréningy klientov a žiadosti',
        onTap: () => context.push('/calendar'),
      ),
    (
      icon: Icons.trending_up_rounded,
      title: 'Progres',
      subtitle: 'Rekordy, objem a vývoj cvikov',
      onTap: () => context.push('/progress'),
    ),
    (
      icon: Icons.accessibility_new_rounded,
      title: 'Telo a rozmery',
      subtitle: 'Váha, pás, brucho, obvody',
      onTap: () => context.push('/body'),
    ),
    (
      icon: Icons.map_outlined,
      title: 'Mapa fitiek',
      subtitle: 'Fitká v okolí, ceny a hodnotenia',
      onTap: () => _goBranch(_mapBranch),
    ),
    if (user?.role == UserRole.trainer)
      (
        icon: Icons.forum_outlined,
        title: 'Komunita',
        subtitle: 'Príspevky, výzvy a rebríčky',
        onTap: () => _goBranch(_communityBranch),
      ),
    (
      icon: Icons.favorite_outline_rounded,
      title: 'Tep srdca',
      subtitle: 'Z hodiniek a Zdravia',
      onTap: () => context.push('/heart-rate'),
    ),
    (
      icon: Icons.info_outline_rounded,
      title: 'O aplikácii',
      subtitle: null,
      onTap: () => context.push('/about'),
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth is SignedIn ? auth.user : null;
    final items = user?.role == UserRole.trainer ? _trainer : _member;
    final inBar = items.indexWhere((i) => i.branch == shell.currentIndex);
    // Časť otvorená z menu (Profil, Mapa…) zvýrazní tlačidlo „Viac“.
    final current = inBar == -1 ? items.length : inBar;
    final activeWorkout = ref.watch(workoutSessionProvider).active;
    // Sledovaním sa po prihlásení spustí priebežné načítavanie upozornení.
    final unreadMessages =
        ref.watch(notificationsProvider).value?.unreadMessages ?? 0;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Expanded(child: shell),
                // Bežiaci tréning je vidieť aj z ostatných záložiek.
                if (activeWorkout != null &&
                    shell.currentIndex != _workoutBranch)
                  ResumeWorkoutBar(
                    workout: activeWorkout,
                    onTap: () => shell.goBranch(_workoutBranch),
                  ),
                _NavBar(
                  items: [
                    for (final i in items)
                      (
                        icon: i.icon,
                        label: i.label,
                        badge:
                            i.branch == _chatBranch &&
                                shell.currentIndex != _chatBranch
                            ? unreadMessages
                            : 0,
                      ),
                    (icon: Icons.menu_rounded, label: 'Viac', badge: 0),
                  ],
                  current: current,
                  onTap: (index) => index < items.length
                      ? _goBranch(items[index].branch)
                      : showMoreSheet(context, _moreItems(context, user)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Spodná lišta: antracitová plocha s vlasovou linkou, aktívna záložka má
/// koralovú farbu a krátku čiarku nad ikonou.
class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.items,
    required this.current,
    required this.onTap,
  });

  final List<({IconData icon, String label, int badge})> items;
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Glass(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: false,
        color: AppColors.navGlass,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.xxl)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xs,
                0,
                AppSpacing.xs,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: Semantics(
                        selected: i == current,
                        button: true,
                        child: InkResponse(
                          onTap: () => onTap(i),
                          radius: 32,
                          child: _NavItem(
                            icon: items[i].icon,
                            label: items[i].label,
                            badge: items[i].badge,
                            active: i == current,
                            style: text.bodySmall!,
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.style,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final bool active;

  /// Počet neprečítaných (0 = bez odznaku).
  final int badge;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accent : AppColors.muted;
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 26,
          height: 3,
          decoration: BoxDecoration(
            color: active ? AppColors.accent : Colors.transparent,

            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(AppRadius.xs),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            0,
            AppSpacing.sm,
            0,
            AppSpacing.xs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Badge(
                isLabelVisible: badge > 0,
                backgroundColor: AppColors.accent,
                textColor: AppColors.bg,
                label: Text(badge > 99 ? '99+' : '$badge'),
                child: Icon(icon, size: 23, color: color),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Dočasná obrazovka pre časti, ktoré ešte nie sú postavené.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.features,
  });

  final String title;
  final IconData icon;
  final List<String> features;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          ScreenHeader(title),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xxxl,
              ),
              child: SectionStack(
                children: [
                  // Prázdny stav ako v návrhu: ikona v jamke a krátky text.
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xl,
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.well,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Icon(icon, color: AppColors.ink2, size: 28),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Zatiaľ tu nič nie je',
                          style: text.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Na tejto časti práve pracujeme.',
                          style: text.bodyMedium!.copyWith(
                            color: AppColors.ink2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  AppSection(
                    title: 'Čoskoro tu nájdeš',
                    child: AppList(
                      children: [
                        for (final feature in features)
                          AppRow(
                            leading: const Icon(
                              Icons.radio_button_unchecked_rounded,
                              size: 20,
                              color: AppColors.accent,
                            ),
                            title: feature,
                          ),
                      ],
                    ),
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
