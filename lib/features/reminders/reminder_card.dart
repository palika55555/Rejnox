import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/tm_card.dart';
import 'reminder_service.dart';

/// Nastavenie dennej pripomienky tréningu (v profile).
class ReminderCard extends ConsumerWidget {
  const ReminderCard({super.key});

  Future<void> _update(
    BuildContext context,
    WidgetRef ref, {
    bool? enabled,
    TimeOfDay? time,
  }) async {
    final allowed = await ref
        .read(reminderControllerProvider.notifier)
        .save(enabled: enabled, hour: time?.hour, minute: time?.minute);
    if (!allowed && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notifikácie nie sú povolené. Zapni ich v nastaveniach telefónu.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final supported = ref.watch(reminderSchedulerProvider).supported;
    final settings =
        ref.watch(reminderControllerProvider).value ?? const ReminderSettings();

    return TmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.notifications_active_outlined,
                color: AppColors.accent,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Pripomienka tréningu', style: text.titleMedium),
              ),
              Switch(
                value: settings.enabled,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.violet,
                onChanged: supported
                    ? (value) => _update(context, ref, enabled: value)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (!supported)
            Text(
              'Pripomienky fungujú v mobilnej appke (iPhone a Android).',
              style: text.bodySmall,
            )
          else
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                    hour: settings.hour,
                    minute: settings.minute,
                  ),
                );
                if (picked != null && context.mounted) {
                  await _update(context, ref, time: picked);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Text('Každý deň o ', style: text.bodyMedium),
                    Text(
                      settings.timeLabel,
                      style: text.bodyLarge!.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: AppColors.muted,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
