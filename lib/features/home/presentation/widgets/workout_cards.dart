import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/barbell_progress.dart';
import '../../../../core/widgets/plate_chip.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/tm_card.dart';
import '../../domain/home_overview.dart';

/// Týždenný cieľ zobrazený ako činka s kotúčmi.
class WeeklyGoalCard extends StatelessWidget {
  const WeeklyGoalCard(this.goal, {super.key});

  final WeeklyGoal goal;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return TmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: SectionLabel('Týždenný cieľ', icon: Icons.flag_rounded),
              ),
              Text(
                '${goal.done} z ${goal.total} tréningov',
                style: text.bodyMedium!.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: BarbellProgress(done: goal.done, total: goal.total),
              ),
              const SizedBox(width: 12),
              Text(
                '${goal.percent}%',
                style: text.bodyMedium!.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                goal.reached
                    ? Icons.check_circle_rounded
                    : Icons.check_circle_outline_rounded,
                size: 16,
                color: AppColors.accent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dnešný tréning s hlavným tlačidlom.
class TodayWorkoutCard extends StatelessWidget {
  const TodayWorkoutCard(this.workout, {super.key, required this.onStart});

  final Workout workout;
  final VoidCallback onStart;

  static const _maxChips = 3;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final shown = workout.exercises.take(_maxChips).toList();
    final rest = workout.exercises.length - shown.length;
    final trainer = workout.trainerName;

    return TmCard(
      grid: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SectionLabel(
                  trainer == null
                      ? 'Dnešný tréning'
                      : 'Dnešný tréning • $trainer',
                  icon: Icons.circle,
                ),
              ),
              _Pill(
                icon: Icons.local_fire_department_rounded,
                label: '${workout.kcal} kcal',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(workout.title.toUpperCase(), style: text.headlineLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.timer_outlined,
                size: 16,
                color: AppColors.accent,
              ),
              const SizedBox(width: 4),
              Text('${workout.minutes} minút', style: text.bodySmall),
              const SizedBox(width: 14),
              const Icon(
                Icons.format_list_bulleted_rounded,
                size: 16,
                color: AppColors.accent,
              ),
              const SizedBox(width: 4),
              Text('${workout.exercises.length} cvikov', style: text.bodySmall),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in shown)
                PlateChip('${e.shortName} ${e.scheme}', plate: e.plate),
              if (rest > 0) PlateChip('+$rest ${_cvikyWord(rest)}'),
            ],
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Začať tréning',
            icon: Icons.play_arrow_rounded,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }

  static String _cvikyWord(int n) => switch (n) {
    1 => 'cvik',
    >= 2 && <= 4 => 'cviky',
    _ => 'cvikov',
  };
}

/// Zoznam cvikov dnešného tréningu.
class ExerciseListCard extends StatelessWidget {
  const ExerciseListCard(this.workout, {super.key});

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return TmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.assignment_rounded,
                size: 18,
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Cviky dnešného tréningu', style: text.titleMedium),
              ),
              if (workout.trainerName != null)
                Text('Predpísané', style: text.bodySmall),
            ],
          ),
          const SizedBox(height: 6),
          for (final e in workout.exercises) _ExerciseRow(e),
        ],
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow(this.exercise);

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          PlateDot(exercise.plate, size: 9),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        exercise.name,
                        style: text.bodyLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (exercise.isPr) ...[
                      const SizedBox(width: 8),
                      const _PrBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(exercise.note, style: text.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${exercise.scheme} • ${exercise.weightLabel}',
            style: text.bodyLarge!.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _PrBadge extends StatelessWidget {
  const _PrBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.accent),
      ),
      child: Text(
        'PR',
        style: Theme.of(context).textTheme.labelSmall!.copyWith(
          color: AppColors.accent,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceHi,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.flame),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              color: AppColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
