import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/rejnox_mark.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tm_card.dart';
import '../data/progress_repository.dart';
import '../domain/progress_models.dart';
import 'progress_charts.dart';
import 'progress_widgets.dart';
import '../../../core/theme/app_spacing.dart';

/// Progres: posledný mesiac, objem po týždňoch, rekordy cvikov a partie.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  ScreenHeader(
                    'Progres',
                    subtitle: 'Z tvojich zapísaných sérií',
                    onBack: () => context.pop(),
                  ),
                  Expanded(
                    child: progress.when(
                      loading: () => const Center(child: RejnoxLoader()),
                      error: (_, _) => _ErrorView(
                        onRetry: () => ref.invalidate(progressProvider),
                      ),
                      data: (data) => RefreshIndicator.adaptive(
                        onRefresh: () => ref.refresh(progressProvider.future),
                        child: _ProgressBody(data),
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

class _ProgressBody extends StatelessWidget {
  const _ProgressBody(this.data);

  final ProgressOverview data;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (data.isEmpty) return const _EmptyView();
    final activeWeeks = data.weeks.where((w) => w.days > 0).length;
    final perWeek = data.weeks.isEmpty
        ? 0.0
        : data.weeks.fold(0, (a, w) => a + w.days) / data.weeks.length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxxl,
      ),
      children: [
        SectionStack(
          children: [
            AppSection(title: 'Posledných 30 dní', child: MonthSummary(data)),
            AppSection(
              title: 'Objem po týždňoch',
              child: TmCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    WeeklyVolumeChart(data.weeks),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Priemerne ${perWeek.toStringAsFixed(1).replaceAll('.', ',')} '
                      'tréningu týždenne · aktívnych $activeWeeks z '
                      '${data.weeks.length} týždňov',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            if (data.exercises.isNotEmpty)
              AppSection(
                title: 'Rekordy a vývoj',
                child: AppList(
                  children: [
                    for (final e in data.exercises)
                      ExerciseProgressRow(
                        e,
                        onTap: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => ExerciseDetailSheet(e),
                        ),
                      ),
                  ],
                ),
              ),
            if (data.muscles.isNotEmpty)
              AppSection(
                title: 'Partie za 30 dní',
                child: MuscleSplit(data.muscles),
              ),
            AppSection(
              title: 'Celkovo',
              child: Row(
                children: [
                  Expanded(
                    child: StatTile(
                      value: '${data.trainingDays}',
                      label: 'Tréningov',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: StatTile(value: '${data.totalSets}', label: 'Sérií'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: StatTile(
                      value: formatVolume(data.totalVolumeKg),
                      label: 'Zdvihnuté',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxxl,
        AppSpacing.huge,
        AppSpacing.xxxl,
        AppSpacing.xxxl,
      ),
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.well,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              color: AppColors.accent,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Zatiaľ bez progresu',
          style: text.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Zapíš prvé série v Tréningu a tu uvidíš rekordy, objem a vývoj '
          'každého cviku.',
          style: text.bodyMedium!.copyWith(color: AppColors.ink2),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          label: 'Začať tréning',
          icon: Icons.play_arrow_rounded,
          tone: ButtonTone.accent,
          onPressed: () => context.go('/workout'),
        ),
      ],
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
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nepodarilo sa načítať progres.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
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
