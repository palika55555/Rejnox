import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/rejnox_mark.dart';
import '../../../core/widgets/tm_card.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/home_repository.dart';
import '../domain/home_overview.dart';
import 'widgets/stat_cards.dart';
import 'widgets/workout_cards.dart';

enum _HomeTab {
  today('Dnes'),
  week('Týždeň'),
  records('Rekordy');

  const _HomeTab(this.label);
  final String label;
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  _HomeTab _tab = _HomeTab.today;

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(homeOverviewProvider);
    final auth = ref.watch(authControllerProvider);
    final firstName = auth is SignedIn ? auth.user.firstName : null;
    return SafeArea(
      bottom: false,
      child: overview.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            _ErrorView(onRetry: () => ref.invalidate(homeOverviewProvider)),
        data: (data) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(data, name: firstName ?? data.userName),
              const SizedBox(height: 16),
              _Segmented(
                selected: _tab,
                onChanged: (tab) => setState(() => _tab = tab),
              ),
              const SizedBox(height: 14),
              ...switch (_tab) {
                _HomeTab.today => _today(context, data),
                _HomeTab.week => const [
                  _ComingSoon('Týždenný prehľad tréningov a objemu.'),
                ],
                _HomeTab.records => const [
                  _ComingSoon('Všetky tvoje osobné rekordy na jednom mieste.'),
                ],
              },
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _today(BuildContext context, HomeOverview data) {
    const gap = SizedBox(height: 12);
    final workout = data.todayWorkout;
    final gym = data.nearbyGym;
    final partner = data.partnerRequest;
    return [
      WeeklyGoalCard(data.weeklyGoal),
      gap,
      if (workout != null) ...[
        TodayWorkoutCard(workout, onStart: () => context.go('/workout')),
        gap,
      ],
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: PersonalRecordTile(data.personalRecord)),
            const SizedBox(width: 12),
            Expanded(child: RankingTile(data.ranking)),
          ],
        ),
      ),
      if (workout != null) ...[gap, ExerciseListCard(workout)],
      if (gym != null) ...[
        gap,
        NearbyGymCard(gym, onTap: () => context.go('/map')),
      ],
      if (partner != null) ...[
        gap,
        PartnerRequestCard(
          partner,
          onJoin: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Spoločné tréningy pribudnú čoskoro.'),
            ),
          ),
        ),
      ],
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header(this.data, {required this.name});

  final HomeOverview data;
  final String name;

  static String _greeting(int hour) => switch (hour) {
    >= 4 && < 10 => 'Dobré ráno',
    >= 10 && < 18 => 'Dobrý deň',
    _ => 'Dobrý večer',
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const RejnoxMark(width: 30),
            const SizedBox(width: 10),
            Text(
              'REJNOX',
              style: text.titleMedium!.copyWith(
                letterSpacing: 4,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            _StreakPill(days: data.streakDays),
            const SizedBox(width: 10),
            _Avatar(name: name),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          '${_greeting(DateTime.now().hour)},'.toUpperCase(),
          style: text.labelSmall,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Flexible(
              child: Text(
                name,
                style: text.headlineLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.waving_hand_rounded,
              size: 26,
              color: Color(0xFFFFC542),
            ),
          ],
        ),
      ],
    );
  }
}

class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Séria $days dní',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.local_fire_department_rounded,
              size: 16,
              color: AppColors.flame,
            ),
            const SizedBox(width: 4),
            Text(
              '$days',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

/// Iniciála v kruhu s fialovým prstencom.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.actionGradient,
      ),
      child: Container(
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceHi,
        ),
        child: Text(
          name.isEmpty ? '?' : name[0].toUpperCase(),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.selected, required this.onChanged});

  final _HomeTab selected;
  final ValueChanged<_HomeTab> onChanged;

  static const _icons = {
    _HomeTab.today: Icons.home_rounded,
    _HomeTab.week: Icons.bar_chart_rounded,
    _HomeTab.records: Icons.emoji_events_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final tab in _HomeTab.values)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(tab),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: tab == selected ? AppColors.actionGradient : null,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: tab == selected
                        ? [
                            BoxShadow(
                              color: AppColors.violet.withValues(alpha: 0.35),
                              blurRadius: 14,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _icons[tab],
                        size: 16,
                        color: tab == selected ? Colors.white : AppColors.muted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tab.label,
                        style: text.bodyMedium!.copyWith(
                          fontWeight: FontWeight.w700,
                          color: tab == selected
                              ? Colors.white
                              : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return TmCard(
      grid: true,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SectionLabel('Čoskoro', icon: Icons.construction_rounded),
          const SizedBox(height: 10),
          Text(message, style: text.bodyMedium, textAlign: TextAlign.center),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Nepodarilo sa načítať údaje.'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Skúsiť znova')),
        ],
      ),
    );
  }
}
