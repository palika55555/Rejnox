import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/plate_chip.dart';
import '../../../core/widgets/tm_card.dart';
import '../application/workout_log_controller.dart';
import '../data/exercise_catalog.dart';
import '../domain/training_models.dart';

/// Stav odosielania: všetko uložené / odosielam / offline s počtom čakajúcich.
class SyncStatusPill extends StatelessWidget {
  const SyncStatusPill(this.state, {super.key});

  final WorkoutLogState state;

  @override
  Widget build(BuildContext context) {
    final pending = state.pendingCount;
    final (icon, tone, label) = switch (state) {
      _ when state.syncing && pending > 0 => (
        Icons.cloud_upload_outlined,
        PillTone.info,
        'Odosielam…',
      ),
      _ when pending > 0 && state.offline => (
        Icons.cloud_off_rounded,
        PillTone.warn,
        'Offline · čaká $pending',
      ),
      _ when pending > 0 => (
        Icons.cloud_upload_outlined,
        PillTone.warn,
        'Čaká $pending',
      ),
      _ => (Icons.cloud_done_outlined, PillTone.good, 'Všetko uložené'),
    };
    return Semantics(
      liveRegion: true,
      child: AppPill(label, tone: tone, icon: icon),
    );
  }
}

/// Vysvetlenie pre offline režim, aby sa človek nebál, že niečo stratil.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.pending});

  final int pending;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warnSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppColors.warn, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Si offline. Série ($pending) sú bezpečne uložené v telefóne '
              'a odošlú sa samy, keď sa pripojíš.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(color: AppColors.warn),
            ),
          ),
        ],
      ),
    );
  }
}

/// Jeden riadok zapísanej série (v zozname s vlasovými linkami).
class LoggedSetRow extends StatelessWidget {
  const LoggedSetRow(this.set, {super.key, this.onDelete});

  final LoggedSet set;

  /// Len pre série, ktoré ešte neodišli na server.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final exercise = exerciseById(set.exerciseId);
    final at = set.performedAt;
    final time = '${at.hour}:${at.minute.toString().padLeft(2, '0')}';
    final (icon, color, tooltip) = switch (set.state) {
      SyncState.synced => (
        Icons.cloud_done_outlined,
        AppColors.good,
        'Uložené na serveri',
      ),
      SyncState.pending => (
        Icons.cloud_upload_outlined,
        AppColors.warn,
        'Čaká na odoslanie',
      ),
      SyncState.rejected => (
        Icons.error_outline_rounded,
        AppColors.error,
        'Server sériu odmietol',
      ),
    };
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 10, onDelete == null ? 16 : 4, 10),
      child: Row(
        children: [
          PlateDot(exercise?.group.plate ?? Plate.blue, size: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        exercise?.name ?? 'Neznámy cvik',
                        style: text.bodyLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (set.kind != SetKind.working) ...[
                      const SizedBox(width: 6),
                      AppPill(set.kind.label, tone: PillTone.accent),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [time, ?exercise?.group.label].join(' · '),
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          // Úzky displej alebo veľké písmo: číslo sa radšej zmenší.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${set.reps} × ${set.weightLabel}',
                style: text.headlineLarge!.copyWith(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Tooltip(
            message: tooltip,
            child: Icon(icon, size: 18, color: color, semanticLabel: tooltip),
          ),
          if (onDelete != null)
            IconButton(
              tooltip: 'Zmazať sériu',
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.muted,
              ),
            ),
        ],
      ),
    );
  }
}

/// Krokovač: okrúhle − / + a veľké číslo v strede (plány, záznam klienta).
class NumberStepper extends StatelessWidget {
  const NumberStepper({
    super.key,
    required this.label,
    required this.controller,
    required this.step,
    required this.validator,
    this.decimal = false,
  });

  final String label;
  final TextEditingController controller;
  final double step;
  final bool decimal;
  final String? Function(String?) validator;

  static double? parse(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  void _change(double delta) {
    final current = parse(controller.text) ?? 0;
    final next = (current + delta).clamp(0, 1000).toDouble();
    controller.text = next == next.roundToDouble()
        ? next.toInt().toString()
        : next.toString().replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        SectionLabel(label),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RoundButton(
              icon: Icons.remove_rounded,
              label: '$label menej',
              onTap: () => _change(-step),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: controller,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.numberWithOptions(decimal: decimal),
                style: text.headlineLarge!.copyWith(fontSize: 44),
                decoration: const InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 6),
                  isDense: true,
                ),
                validator: validator,
              ),
            ),
            const SizedBox(width: 8),
            _RoundButton(
              icon: Icons.add_rounded,
              label: '$label viac',
              onTap: () => _change(step),
            ),
          ],
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
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
            dimension: 56,
            child: Icon(icon, color: AppColors.text),
          ),
        ),
      ),
    );
  }
}
