import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/plate_chip.dart';
import '../../../core/widgets/tm_card.dart';
import '../../home/presentation/widgets/stat_cards.dart';
import '../../training/application/exercise_stats.dart';
import '../../training/domain/training_models.dart';
import '../domain/progress_models.dart';
import 'progress_charts.dart';

/// Malé číslo s popisom (tréningy, série, objem).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.note,
    this.noteColor = AppColors.muted,
  });

  final String value;
  final String label;
  final String? note;
  final Color noteColor;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final n = note;
    return TmCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: text.titleLarge),
          ),
          const SizedBox(height: 2),
          Text(label, style: text.bodySmall, maxLines: 1),
          if (n != null) ...[
            const SizedBox(height: 4),
            Text(
              n,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall!.copyWith(
                color: noteColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Posledných 30 dní: tréningy, série a objem s porovnaním.
class MonthSummary extends StatelessWidget {
  const MonthSummary(this.overview, {super.key});

  final ProgressOverview overview;

  @override
  Widget build(BuildContext context) {
    final change = overview.monthVolumeChangePercent;
    return Row(
      children: [
        Expanded(
          child: StatTile(value: '${overview.monthDays}', label: 'Tréningov'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatTile(value: '${overview.monthSets}', label: 'Sérií'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatTile(
            value: formatVolume(overview.monthVolumeKg),
            label: 'Objem',
            note: change == null ? null : '${change >= 0 ? '+' : ''}$change %',
            noteColor: change == null || change >= 0
                ? AppColors.good
                : AppColors.warn,
          ),
        ),
      ],
    );
  }
}

/// Riadok cviku: rekord, zlepšenie od začiatku a krivka.
class ExerciseProgressRow extends StatelessWidget {
  const ExerciseProgressRow(this.exercise, {super.key, required this.onTap});

  final ExerciseProgress exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final e = exercise;
    final group = e.group;
    final gain = e.gainKg;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (group != null) ...[
              PlateDot(group.plate, size: 9),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.name,
                    style: text.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'rekord ${formatKg(e.bestKg)} kg'),
                        if (gain > 0)
                          TextSpan(
                            text: '  +${formatKg(gain)} kg',
                            style: const TextStyle(
                              color: AppColors.good,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 64,
              height: 30,
              child: CustomPaint(
                painter: SparklinePainter([for (final p in e.trend) p.kg]),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

/// Koľko sérií dostala ktorá partia za 30 dní.
class MuscleSplit extends StatelessWidget {
  const MuscleSplit(this.muscles, {super.key});

  final List<({MuscleGroup group, int sets})> muscles;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final max = muscles.isEmpty ? 1 : muscles.first.sets;
    return TmCard(
      child: Column(
        children: [
          for (final m in muscles)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 78,
                    child: Text(m.group.label, style: text.bodyMedium),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: m.sets / max,
                        minHeight: 8,
                        backgroundColor: AppColors.well,
                        color: m.group.plate.color,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text(
                      '${m.sets} s.',
                      textAlign: TextAlign.right,
                      style: text.bodySmall,
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

/// Detail cviku v spodnom okne: krivka a čísla.
class ExerciseDetailSheet extends StatelessWidget {
  const ExerciseDetailSheet(this.exercise, {super.key});

  final ExerciseProgress exercise;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final e = exercise;
    final e1rm = e.bestE1rmKg;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(e.name.toUpperCase(), style: text.headlineMedium),
            const SizedBox(height: 4),
            Text(
              '${e.group?.label ?? 'Cvik'} · naposledy ${shortDate(e.lastDay)}',
              style: text.bodySmall,
            ),
            const SizedBox(height: 16),
            const SectionLabel('Najťažšia séria po dňoch'),
            const SizedBox(height: 10),
            ExerciseTrendChart(e.trend),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    value: '${formatKg(e.bestKg)} kg',
                    label: 'Rekord',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    value: e1rm == null ? '–' : '${formatKg(e1rm)} kg',
                    label: 'Odhad 1 opak.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    value: '+${formatKg(e.gainKg)} kg',
                    label: 'Od začiatku',
                    note: 'začiatok ${formatKg(e.firstKg)} kg',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(value: '${e.days}', label: 'Tréningov'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Odhad 1 opakovania je výpočet zo sérií do 12 opakovaní.',
              style: text.bodySmall!.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
