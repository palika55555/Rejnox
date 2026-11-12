import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/plate_chip.dart';
import '../../../core/widgets/tm_card.dart';
import '../domain/coaching_models.dart';

String formatDay(DateTime d) => '${d.day}. ${d.month}. ${d.year}';

/// Správa pre používateľa z chyby servera alebo spojenia.
String errorText(Object error) =>
    error is ApiError ? error.message : 'Niečo sa pokazilo.';

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(errorText(error))));
}

/// Farebný štítok stavu spolupráce.
class LinkStatusChip extends StatelessWidget {
  const LinkStatusChip(this.status, {super.key});

  final LinkStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      LinkStatus.linked => AppColors.accent,
      LinkStatus.invited => AppColors.flame,
      LinkStatus.recordOnly => AppColors.muted,
      LinkStatus.ended => Plate.red.color,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.bodySmall!.copyWith(
          color: AppColors.text,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Karta tréningového plánu (pre trénera aj klienta).
class PlanCard extends StatelessWidget {
  const PlanCard(
    this.plan, {
    super.key,
    this.showTrainer = false,
    this.onDelete,
  });

  final Plan plan;
  final bool showTrainer;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final subtitle = [
      if (plan.scheduledOn != null) formatDay(plan.scheduledOn!),
      if (showTrainer && plan.trainerName.isNotEmpty) 'od ${plan.trainerName}',
    ].join(' · ');
    return TmCard(
      grid: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.title.toUpperCase(),
                  style: text.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Zmazať plán',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.muted,
                    size: 20,
                  ),
                ),
            ],
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: text.bodySmall),
          ],
          const SizedBox(height: 8),
          for (final item in plan.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  PlateDot(item.group.plate, size: 9),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.name,
                      style: text.bodyLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.scheme,
                    style: text.bodyLarge!.copyWith(
                      fontWeight: FontWeight.w800,
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

/// Potvrdenie nevratnej akcie.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Zrušiť'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Plate.red.color),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
