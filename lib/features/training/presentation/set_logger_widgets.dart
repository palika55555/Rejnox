import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/plate_chip.dart';
import '../application/exercise_stats.dart';
import '../domain/training_models.dart';

/// Vybraný cvik; ťuknutím sa otvorí výber cviku.
class ExerciseSelector extends StatelessWidget {
  const ExerciseSelector({
    super.key,
    required this.exercise,
    required this.history,
    required this.onTap,
  });

  final Exercise exercise;
  final ExerciseHistory? history;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final best = history?.bestKg;
    final radius = BorderRadius.circular(14);
    return Semantics(
      button: true,
      label: 'Zmeniť cvik',
      child: Material(
        color: AppColors.well,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                PlateDot(exercise.group.plate, size: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          exercise.group.label,
                          if (best != null) 'rekord ${formatKg(best)} kg',
                        ].join(' · '),
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.unfold_more_rounded, color: AppColors.ink2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Prepínač druhu série: P / R / D / Z.
class SetKindPicker extends StatelessWidget {
  const SetKindPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final SetKind selected;
  final ValueChanged<SetKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final kind in SetKind.values)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Tooltip(
              message: kind.label,
              child: Semantics(
                button: true,
                selected: kind == selected,
                label: kind.label,
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(kind);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 30,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: kind == selected ? AppColors.text : AppColors.well,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: kind == selected
                            ? AppColors.text
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      kind.code,
                      style: text.bodySmall!.copyWith(
                        fontWeight: FontWeight.w800,
                        color: kind == selected ? AppColors.bg : AppColors.ink2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Krokovač v zapustenej ploche: popis, − číslo +, jednotka.
/// Číslo sa dá aj prepísať klávesnicou.
class MetricStepper extends StatelessWidget {
  const MetricStepper({
    super.key,
    required this.label,
    required this.unit,
    required this.controller,
    required this.step,
    required this.validator,
    this.decimal = false,
  });

  final String label;
  final String unit;
  final TextEditingController controller;
  final double step;
  final bool decimal;
  final String? Function(String?) validator;

  static double? parse(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  void _change(double delta) {
    HapticFeedback.lightImpact();
    final current = parse(controller.text) ?? 0;
    controller.text = formatKg((current + delta).clamp(0, 1000).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.well,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.labelSmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _StepButton(
                icon: Icons.remove_rounded,
                label: '$label menej',
                onTap: () => _change(-step),
              ),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: decimal,
                  ),
                  style: text.headlineLarge!.copyWith(fontSize: 32),
                  decoration: const InputDecoration(
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                    isDense: true,
                    errorMaxLines: 2,
                  ),
                  validator: validator,
                ),
              ),
              _StepButton(
                icon: Icons.add_rounded,
                label: '$label viac',
                onTap: () => _change(step),
              ),
            ],
          ),
          Text(unit, style: text.bodySmall),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(
          side: BorderSide(color: AppColors.border, width: 1.5),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: 40,
            child: Icon(icon, size: 20, color: AppColors.text),
          ),
        ),
      ),
    );
  }
}

/// Malý čip rýchlej voľby (Minule, +2,5 kg…).
class QuickChip extends StatelessWidget {
  const QuickChip({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: StadiumBorder(side: BorderSide(color: AppColors.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Plávajúci odpočet pauzy medzi sériami (tmavá hero plocha).
class RestTimerBar extends StatelessWidget {
  const RestTimerBar({
    super.key,
    required this.remaining,
    required this.total,
    required this.onAdjust,
    required this.onClose,
  });

  final Duration remaining;
  final Duration total;
  final ValueChanged<int> onAdjust;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final progress = total.inSeconds == 0
        ? 0.0
        : remaining.inSeconds / total.inSeconds;
    Widget adjust(int seconds) => TextButton(
      onPressed: () => onAdjust(seconds),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.onHero,
        minimumSize: const Size(48, 40),
        padding: EdgeInsets.zero,
      ),
      child: Text(seconds > 0 ? '+${seconds}s' : '−${-seconds}s'),
    );
    return Semantics(
      liveRegion: true,
      label: 'Pauza ${formatClock(remaining)}',
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        decoration: BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2E12151A),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(
                value: progress.clamp(0, 1),
                strokeWidth: 3,
                color: AppColors.accent,
                backgroundColor: AppColors.heroLine,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'PAUZA',
                  style: text.labelSmall!.copyWith(color: AppColors.onHero2),
                ),
                Text(
                  formatClock(remaining),
                  style: text.headlineLarge!.copyWith(
                    fontSize: 24,
                    color: AppColors.onHero,
                  ),
                ),
              ],
            ),
            const Spacer(),
            adjust(-15),
            adjust(15),
            IconButton(
              tooltip: 'Preskočiť pauzu',
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, color: AppColors.onHero),
            ),
          ],
        ),
      ),
    );
  }
}
