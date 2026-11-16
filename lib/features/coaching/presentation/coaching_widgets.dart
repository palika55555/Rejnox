import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/plate_chip.dart';
import '../../../core/widgets/tm_card.dart';
import '../domain/coaching_models.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/adaptive_dialog.dart';

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
    final tone = switch (status) {
      LinkStatus.linked => PillTone.good,
      LinkStatus.invited => PillTone.warn,
      LinkStatus.recordOnly => PillTone.neutral,
      LinkStatus.ended => PillTone.neutral,
    };
    return AppPill(status.label, tone: tone);
  }
}

/// Karta tréningového plánu (pre trénera aj klienta).
class PlanCard extends StatelessWidget {
  const PlanCard(
    this.plan, {
    super.key,
    this.showTrainer = false,
    this.onDelete,
    this.onStart,
  });

  final Plan plan;
  final bool showTrainer;
  final VoidCallback? onDelete;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final subtitle = [
      if (plan.scheduledOn != null) formatDay(plan.scheduledOn!),
      if (showTrainer && plan.trainerName.isNotEmpty) 'od ${plan.trainerName}',
    ].join(' · ');
    return TmCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              onDelete == null ? AppSpacing.lg : AppSpacing.sm,
              AppSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (subtitle.isNotEmpty) ...[
                        SectionLabel(subtitle),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      Text(
                        plan.title.toUpperCase(),
                        style: text.headlineMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    tooltip: 'Zmazať plán',
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.muted,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
          for (final item in plan.items)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  PlateDot(item.group.plate, size: 9),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      item.name,
                      style: text.bodyLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(item.scheme, style: text.titleLarge),
                ],
              ),
            ),
          if (onStart != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: OutlinedButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Cvičiť podľa plánu'),
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
}) {
  return showAppConfirm(
    context,
    title: title,
    message: message,
    confirmLabel: confirmLabel,
  );
}
