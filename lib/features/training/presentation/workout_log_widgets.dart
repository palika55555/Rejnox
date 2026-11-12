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
    final (icon, color, label) = switch (state) {
      _ when state.syncing && pending > 0 => (
        Icons.cloud_upload_outlined,
        AppColors.accent,
        'Odosielam…',
      ),
      _ when pending > 0 && state.offline => (
        Icons.cloud_off_rounded,
        AppColors.flame,
        'Offline · čaká $pending',
      ),
      _ when pending > 0 => (
        Icons.cloud_upload_outlined,
        AppColors.flame,
        'Čaká $pending',
      ),
      _ => (Icons.cloud_done_rounded, AppColors.accent, 'Všetko uložené'),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vysvetlenie pre offline režim, aby sa človek nebál, že niečo stratil.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.pending});

  final int pending;

  @override
  Widget build(BuildContext context) {
    return TmCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppColors.flame, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Si offline. Série ($pending) sú bezpečne uložené v telefóne '
              'a odošlú sa samy, keď sa pripojíš.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Jeden riadok zapísanej série.
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
        Icons.cloud_done_rounded,
        AppColors.accent,
        'Uložené na serveri',
      ),
      SyncState.pending => (
        Icons.cloud_upload_outlined,
        AppColors.flame,
        'Čaká na odoslanie',
      ),
      SyncState.rejected => (
        Icons.error_outline_rounded,
        Plate.red.color,
        'Server sériu odmietol',
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          PlateDot(exercise?.group.plate ?? Plate.blue, size: 9),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise?.name ?? 'Neznámy cvik',
                  style: text.bodyLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(time, style: text.bodySmall),
              ],
            ),
          ),
          Text(
            '${set.reps} × ${set.weightLabel}',
            style: text.bodyLarge!.copyWith(fontWeight: FontWeight.w800),
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

/// Tlačidlá − / + okolo čísla (opakovania, váha).
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
    return Row(
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
            decoration: InputDecoration(labelText: label),
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 44,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: AppColors.surfaceHi,
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, color: AppColors.text),
        ),
      ),
    );
  }
}
