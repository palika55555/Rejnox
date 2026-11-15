import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../coaching/domain/coaching_models.dart';
import '../../../training/application/exercise_stats.dart';
import '../../../training/application/workout_log_controller.dart';
import '../../../training/application/workout_session.dart';
import '../../../training/data/exercise_catalog.dart';
import '../../../training/domain/training_models.dart' show MuscleGroup;
import '../../../training/presentation/workout_session_widgets.dart';
import '../../domain/home_overview.dart';
import 'workout_cards.dart';

/// Hlavná karta dňa. Poradie: prebiehajúci tréning, dnes už hotový,
/// plán od trénera, voľno.
class TodayHero extends ConsumerWidget {
  const TodayHero({super.key, required this.planned});

  final Workout? planned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(workoutSessionProvider);
    final active = session.active;
    final finished = session.lastFinished;
    final planned = this.planned;

    Future<void> start({Workout? workout}) async {
      await ref
          .read(workoutSessionProvider.notifier)
          .start(
            title: workout?.title ?? WorkoutSessionController.freeTitle,
            plan: workout == null ? const [] : _planItems(workout),
          );
      if (context.mounted) context.go('/workout');
    }

    if (active != null) return ActiveWorkoutHero(active);
    if (finished != null && finished.isOn(DateTime.now())) {
      return FinishedWorkoutHero(finished);
    }
    if (planned != null) {
      return TodayWorkoutHero(planned, onStart: () => start(workout: planned));
    }
    return RestDayHero(onStart: start);
  }
}

// Staršie odpovede nemusia mať identifikátor. Použi iba presnú zhodu
// katalógu, aby sa séria omylom nezapísala k inému cviku.
List<PlanItem> _planItems(Workout workout) {
  final items = <PlanItem>[];
  for (final exercise in workout.exercises) {
    final catalogEntry = exercise.exerciseId == null
        ? exerciseCatalog.where((e) => e.name == exercise.name).firstOrNull
        : exerciseById(exercise.exerciseId!);
    final id = exercise.exerciseId ?? catalogEntry?.id;
    if (id == null || exercise.sets <= 0) continue;
    items.add(
      PlanItem(
        exerciseId: id,
        name: exercise.name,
        group: exercise.group ?? catalogEntry?.group ?? MuscleGroup.legs,
        sets: exercise.sets,
        reps: exercise.reps,
        weightKg: exercise.weightKg,
        note: exercise.note,
      ),
    );
  }
  return items;
}

/// Tréning práve beží: čas, série, objem a postup voči plánu.
class ActiveWorkoutHero extends ConsumerWidget {
  const ActiveWorkoutHero(this.workout, {super.key});

  final ActiveWorkout workout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final logged = ref.watch(workoutLogProvider).sets;
    final sets = workout.setsFrom(logged);
    final volume = sets.fold(0.0, (v, s) => v + s.volumeKg);
    final progress = workout.progressFrom(logged);
    final metaStyle = text.bodyMedium!.copyWith(
      fontSize: 14.5,
      fontWeight: FontWeight.w500,
      color: AppColors.onHero2,
    );

    return HeroPanel(
      children: [
        HeroTitle(eyebrow: 'Prebieha tréning', title: workout.title),
        Row(
          children: [
            Flexible(
              child: Text(
                progress.total == 0
                    ? sessionProgressLabel(sets.length, volume)
                    : '${progress.done} z ${progress.total} sérií plánu · '
                          '${formatKg(volume.roundToDouble())} kg',
                style: metaStyle,
              ),
            ),
            Text(' · ', style: metaStyle),
            LiveElapsed(since: workout.startedAt, style: metaStyle),
          ],
        ),
        if (progress.total > 0)
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.done / progress.total,
              minHeight: 6,
              color: progress.next == null ? AppColors.good : AppColors.accent,
              backgroundColor: AppColors.heroLine,
            ),
          ),
        PrimaryButton(
          label: 'Pokračovať',
          icon: Icons.play_arrow_rounded,
          tone: ButtonTone.onHero,
          onPressed: () => context.go('/workout'),
        ),
        PrimaryButton(
          label: 'Ukončiť tréning',
          icon: Icons.flag_outlined,
          tone: ButtonTone.ghostOnHero,
          onPressed: () => confirmFinishWorkout(context, ref),
        ),
      ],
    );
  }
}

/// Dnešný tréning je za tebou.
class FinishedWorkoutHero extends StatelessWidget {
  const FinishedWorkoutHero(this.workout, {super.key});

  final FinishedWorkout workout;

  @override
  Widget build(BuildContext context) {
    final minutes = workout.duration.inMinutes;
    return HeroPanel(
      children: [
        HeroTitle(eyebrow: 'Hotovo na dnes', title: workout.title),
        HeroMeta(
          '$minutes min · '
          '${sessionProgressLabel(workout.sets, workout.volumeKg)} zdvihnutých',
        ),
        PrimaryButton(
          label: 'Pozrieť záznam',
          tone: ButtonTone.ghostOnHero,
          onPressed: () => context.go('/workout'),
        ),
      ],
    );
  }
}
