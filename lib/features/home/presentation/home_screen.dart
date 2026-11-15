import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/rejnox_mark.dart';
import '../../../core/widgets/tm_card.dart';
import '../../auth/domain/auth_models.dart';
import '../../coaching/application/coaching_providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../notifications/notifications_controller.dart';
import '../../notifications/notifications_screen.dart';
import '../data/home_repository.dart';
import '../domain/home_overview.dart';
import 'widgets/dashboard_sections.dart';
import 'widgets/session_heroes.dart';
import 'widgets/stat_cards.dart';
import 'widgets/workout_cards.dart';

/// Obrazovka Dnes: jeden stĺpec, jedna tmavá hero plocha s dnešným
/// tréningom a pod ňou tiché sekcie s vlasovými linkami.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(homeOverviewProvider);
    final auth = ref.watch(authControllerProvider);
    final user = auth is SignedIn ? auth.user : null;
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _TopBar(
            name: user?.firstName ?? '',
            isTrainer: user?.role == UserRole.trainer,
          ),
          Expanded(
            child: overview.when(
              loading: () => const Center(child: RejnoxLoader()),
              error: (error, _) => _ErrorView(
                onRetry: () => ref.invalidate(homeOverviewProvider),
              ),
              data: (data) => RefreshIndicator(
                onRefresh: () async {
                  try {
                    await Future.wait([
                      ref.refresh(homeOverviewProvider.future),
                      ref.refresh(myPlansProvider.future),
                      if (user?.role != UserRole.trainer)
                        ref.refresh(myTrainersProvider.future),
                    ]);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Niektoré údaje sa nepodarilo obnoviť. Skús to znova.',
                          ),
                        ),
                      );
                    }
                  }
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (i, w) in _sections(
                            context,
                            data,
                            user,
                          ).indexed)
                            Padding(
                              padding: EdgeInsets.only(top: i == 0 ? 0 : 22),
                              child: w,
                            ),
                        ],
                      ),
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

  List<Widget> _sections(
    BuildContext context,
    HomeOverview data,
    AuthUser? user,
  ) {
    final workout = data.todayWorkout;
    final record = data.personalRecord;
    final ranking = data.ranking;
    final gym = data.nearbyGym;
    final partner = data.partnerRequest;
    return [
      _Hello(name: user?.firstName ?? ''),
      TodayHero(planned: workout),
      WeekSection(goal: data.weeklyGoal, streakDays: data.streakDays),
      const DashboardActions(),
      if (workout != null)
        AppSection(
          title: 'Cviky dnes',
          trailing: workout.trainerName == null
              ? null
              : Tooltip(
                  message: 'Predpísal ${workout.trainerName}',
                  child: const Icon(Icons.sports_outlined, size: 20),
                ),
          child: ExerciseList(workout),
        ),
      const BodySection(),
      AppSection(
        title: 'Výkon',
        child: AppList(
          children: [
            if (record == null)
              const EmptyRecordRow()
            else
              PersonalRecordRow(record),
            if (ranking != null) RankingRow(ranking),
          ],
        ),
      ),
      if (gym != null || partner != null)
        AppSection(
          title: 'V okolí',
          trailing: gym == null
              ? null
              : _Link('Mapa', onTap: () => context.go('/map')),
          child: AppList(
            children: [
              if (gym != null)
                NearbyGymRow(gym, onTap: () => context.go('/map')),
              if (partner != null)
                PartnerRequestRow(
                  partner,
                  onJoin: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Spoločné tréningy pribudnú čoskoro.'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      if (user?.role != UserRole.trainer) const TrainerSection(),
      const UpcomingSection(),
    ];
  }
}

/// Hlavička so znakom Rejnox a profilom.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.name, required this.isTrainer});

  final String name;
  final bool isTrainer;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            // Na úzkom displeji alebo pri veľkom písme sa značka zmenší.
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    children: [
                      const RejnoxMark(width: 34),
                      const SizedBox(width: 7),
                      Text('REJNOX', style: text.headlineLarge),
                    ],
                  ),
                ),
              ),
            ),
            const NotificationBell(),
            const _ChatButton(),
            const SizedBox(width: 4),
            _ProfilePill(
              name: name,
              role: isTrainer ? 'Tréner' : 'Klient',
              onTap: () => context.go('/profile'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Správy s počtom neprečítaných.
class _ChatButton extends ConsumerWidget {
  const _ChatButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(notificationsProvider).value?.unreadMessages ?? 0;
    return IconButton(
      tooltip: unread == 0 ? 'Správy' : 'Správy, $unread neprečítané',
      onPressed: () => context.go('/chat'),
      icon: Badge(
        isLabelVisible: unread > 0,
        backgroundColor: AppColors.accent,
        textColor: AppColors.bg,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: const Icon(Icons.chat_bubble_outline_rounded),
      ),
    );
  }
}

class _ProfilePill extends StatelessWidget {
  const _ProfilePill({
    required this.name,
    required this.role,
    required this.onTap,
  });

  final String name;
  final String role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(19);
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 11, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.text,
                ),
                child: Text(
                  name.isEmpty ? '?' : name[0].toUpperCase(),
                  style: text.bodySmall!.copyWith(
                    color: AppColors.bg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                role,
                style: text.bodyMedium!.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dátum ako eyebrow a pozdrav.
class _Hello extends StatelessWidget {
  const _Hello({required this.name});

  final String name;

  static const _days = [
    'pondelok',
    'utorok',
    'streda',
    'štvrtok',
    'piatok',
    'sobota',
    'nedeľa',
  ];
  static const _months = [
    'januára',
    'februára',
    'marca',
    'apríla',
    'mája',
    'júna',
    'júla',
    'augusta',
    'septembra',
    'októbra',
    'novembra',
    'decembra',
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final date =
        '${_days[now.weekday - 1]} ${now.day}. ${_months[now.month - 1]}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(date),
        const SizedBox(height: 4),
        Text(
          name.isEmpty ? 'Ahoj' : 'Ahoj, $name',
          style: text.titleMedium!.copyWith(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
      ],
    );
  }
}

class _Link extends StatelessWidget {
  const _Link(this.label, {required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 16,
            color: AppColors.accent,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nepodarilo sa načítať údaje.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Skúsiť znova',
              compact: true,
              tone: ButtonTone.ghost,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
