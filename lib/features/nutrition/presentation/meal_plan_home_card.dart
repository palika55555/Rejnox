import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/tm_card.dart';
import '../application/meal_plans_controller.dart';
import '../domain/meal_plan.dart';
import '../../../core/theme/app_spacing.dart';

/// Karta na Domove: dnešný jedálniček od trénera (len keď nejaký je).
class MealPlanHomeCard extends ConsumerWidget {
  const MealPlanHomeCard({super.key, this.fallback = const SizedBox.shrink()});

  /// Čo ukázať, keď jedálniček nie je.
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(mealPlansProvider).value?.current;
    if (plan == null) return fallback;

    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final day = weekdayIndex(now);
    final items = plan.itemsFor(day);
    final done = items.where((i) => plan.isEaten(i.id, now)).length;

    return TmCard(
      onTap: () => context.push('/nutrition'),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const Icon(
              Icons.restaurant_menu_rounded,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Jedálniček na dnes', style: text.bodyLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  items.isEmpty
                      ? plan.title
                      : '$done z ${items.length} jedál · '
                            '${plan.eaten(day, now).kcal} / '
                            '${plan.targets.kcal ?? plan.planned(day).kcal} kcal',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}
