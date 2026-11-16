import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/tm_card.dart';
import '../../coaching/domain/coaching_models.dart';
import '../../coaching/presentation/coaching_widgets.dart';
import '../application/booking_providers.dart';
import '../domain/booking_models.dart';
import '../domain/my_training.dart';
import 'calendar_widgets.dart';
import 'trainer_calendar_sheets.dart';
import '../../../core/theme/app_spacing.dart';

/// Karta Tréning: moje rezervované tréningy u trénera na 30 dní dopredu,
/// s časom a rozpisom, čo sa bude trénovať.
class UpcomingTrainingsSection extends ConsumerWidget {
  const UpcomingTrainingsSection({super.key, this.onStart});

  /// Spustí tréning podľa pripojeného plánu (null = práve beží iný tréning).
  final ValueChanged<Plan>? onStart;

  /// Koľko tréningov sa ukáže hneď, ostatné po rozbalení.
  static const _shown = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainings = ref.watch(myTrainingsProvider).value;
    if (trainings == null || trainings.isEmpty) return const SizedBox.shrink();

    return AppSection(
      title: 'Najbližšie tréningy u trénera',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, t) in trainings.take(_shown).indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            _TrainingTile(t, onStart: onStart),
          ],
          if (trainings.length > _shown)
            TextButton(
              onPressed: () => showCalendarSheet<void>(
                context,
                _AllTrainingsSheet(trainings, onStart: onStart),
              ),
              child: Text('Všetky na 30 dní (${trainings.length})'),
            ),
        ],
      ),
    );
  }
}

class _TrainingTile extends StatelessWidget {
  const _TrainingTile(this.training, {this.onStart});

  final MyTraining training;
  final ValueChanged<Plan>? onStart;

  @override
  Widget build(BuildContext context) {
    final t = training;
    final plan = t.plan;
    return CalendarEventTile(
      start: t.startsAt,
      end: t.endsAt,
      title: '${dayLabel(t.startsAt)} · ${t.displayTitle}',
      subtitle: [
        if (plan != null)
          'Plán: ${plan.title} · ${plan.items.length} cvikov'
        else
          'Rozpis zatiaľ nie je',
        if (t.trainerName.isNotEmpty) t.trainerName,
      ].join(' · '),
      accent: t.isPending ? AppColors.warn : AppColors.good,
      pill: t.isPending ? BookingStatusPill(t.status) : null,
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
      onTap: () => showCalendarSheet<void>(
        context,
        MyTrainingSheet(t, onStart: onStart),
      ),
    );
  }
}

class _AllTrainingsSheet extends StatelessWidget {
  const _AllTrainingsSheet(this.trainings, {this.onStart});

  final List<MyTraining> trainings;
  final ValueChanged<Plan>? onStart;

  @override
  Widget build(BuildContext context) => SheetFrame(
    title: 'Tréningy na 30 dní',
    children: [
      for (final t in trainings) ...[
        _TrainingTile(t, onStart: onStart),
        const SizedBox(height: AppSpacing.sm),
      ],
    ],
  );
}

/// Detail tréningu pre klienta: kedy, s kým, čo sa bude robiť a plán cvikov.
class MyTrainingSheet extends StatelessWidget {
  const MyTrainingSheet(this.training, {super.key, this.onStart});

  final MyTraining training;
  final ValueChanged<Plan>? onStart;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final t = training;
    final plan = t.plan;
    final minutes = t.endsAt.difference(t.startsAt).inMinutes;
    return SheetFrame(
      title: t.displayTitle,
      children: [
        Text(
          '${dayLabel(t.startsAt)} · ${timeRange(t.startsAt, t.endsAt)} '
          '(${lengthLabel(minutes)})',
          style: text.titleMedium,
        ),
        if (t.trainerName.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text('Tréner: ${t.trainerName}', style: text.bodyMedium),
        ],
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            BookingStatusPill(t.status),
            if (t.inSlot) const AppPill('Vypísaný termín', tone: PillTone.info),
          ],
        ),
        if (t.slotNote case final slotNote?) ...[
          const SizedBox(height: AppSpacing.md),
          Text(slotNote, style: text.bodyMedium),
        ],
        if (t.note case final note?) ...[
          const SizedBox(height: AppSpacing.sm),
          Text('„$note“', style: text.bodyMedium),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (plan != null)
          PlanCard(
            plan,
            onStart: onStart == null || plan.items.isEmpty
                ? null
                : () {
                    Navigator.pop(context);
                    onStart!(plan);
                  },
          )
        else
          Text(
            'Tréner k tréningu zatiaľ nepripojil plán. '
            'Keď ho pripojí, dostaneš upozornenie.',
            style: text.bodySmall,
          ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            context.push('/trainer/${t.linkId}/calendar');
          },
          icon: const Icon(Icons.calendar_month_rounded),
          label: const Text('Kalendár trénera'),
        ),
      ],
    );
  }
}
