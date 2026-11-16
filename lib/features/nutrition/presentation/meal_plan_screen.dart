import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tm_card.dart';
import '../../coaching/presentation/coaching_widgets.dart';
import '../application/meal_plans_controller.dart';
import '../domain/meal_plan.dart';

/// Jedálniček od trénera: dni v týždni, jedlá a odškrtávanie zjedeného.
class MealPlanScreen extends ConsumerStatefulWidget {
  const MealPlanScreen({super.key, this.now});

  /// Pre testy: pevný „dnes“.
  final DateTime? now;

  @override
  ConsumerState<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends ConsumerState<MealPlanScreen> {
  late int _day = weekdayIndex(widget.now ?? DateTime.now());

  DateTime get _today => widget.now ?? DateTime.now();

  Future<void> _toggle(MealPlan plan, MealItem item, DateTime date) async {
    try {
      await ref
          .read(mealPlansProvider.notifier)
          .toggle(plan.id, item, date, eaten: !plan.isEaten(item.id, date));
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(mealPlansProvider);
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  ScreenHeader(
                    'Jedálniček',
                    subtitle: plans.value?.current == null
                        ? 'Od tvojho trénera'
                        : 'od ${plans.value!.current!.trainerName}',
                    onBack: () =>
                        context.canPop() ? context.pop() : context.go('/home'),
                  ),
                  Expanded(
                    child: switch (plans) {
                      AsyncData(:final value) when value.current != null =>
                        _body(value.current!, offline: value.offline),
                      AsyncData() => const _Empty(),
                      AsyncError(:final error) => _Message(
                        '$error',
                        onRetry: () => ref.invalidate(mealPlansProvider),
                      ),
                      _ => const Center(child: CircularProgressIndicator()),
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(MealPlan plan, {required bool offline}) {
    final text = Theme.of(context).textTheme;
    final date = dateInWeek(_today, _day);
    final items = plan.itemsFor(_day);
    final planned = plan.planned(_day);
    final eaten = plan.eaten(_day, date);
    final canCheck = canCheckOn(date, _today) && !offline;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(mealPlansProvider.future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: [
          Text(plan.title, style: text.headlineMedium),
          if (plan.note != null) ...[
            const SizedBox(height: 6),
            Text(plan.note!, style: text.bodyMedium),
          ],
          if (offline) ...[
            const SizedBox(height: 8),
            const AppPill('uložené v telefóne – bez internetu'),
          ],
          const SizedBox(height: 16),
          _DayPicker(
            selected: _day,
            today: weekdayIndex(_today),
            onSelect: (d) => setState(() => _day = d),
          ),
          const SizedBox(height: 14),
          _DaySummary(
            eaten: eaten,
            planned: planned,
            targetKcal: plan.targets.kcal,
            targetProtein: plan.targets.proteinG,
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            TmCard(
              child: Text(
                'Na ${dayNames[_day].toLowerCase()} tréner nič nenaplánoval.',
                style: text.bodyMedium,
              ),
            )
          else
            AppList(
              children: [
                for (final item in items)
                  _MealRow(
                    item: item,
                    eaten: plan.isEaten(item.id, date),
                    onToggle: canCheck ? () => _toggle(plan, item, date) : null,
                  ),
              ],
            ),
          if (!canCheck && items.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              offline
                  ? 'Odškrtnúť sa dá, keď budeš online.'
                  : 'Odškrtnúť sa dá dnešok a posledný týždeň.',
              style: text.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({
    required this.selected,
    required this.today,
    required this.onSelect,
  });

  final int selected;
  final int today;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        for (var d = 0; d < 7; d++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Semantics(
                selected: d == selected,
                button: true,
                label: dayNames[d],
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onSelect(d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: d == selected ? AppColors.accent : AppColors.well,
                      borderRadius: BorderRadius.circular(14),
                      border: d == today && d != selected
                          ? Border.all(color: AppColors.accent)
                          : null,
                    ),
                    child: Text(
                      dayShort[d],
                      textAlign: TextAlign.center,
                      style: text.labelLarge!.copyWith(
                        color: d == selected
                            ? AppColors.onAccent
                            : AppColors.ink2,
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

class _DaySummary extends StatelessWidget {
  const _DaySummary({
    required this.eaten,
    required this.planned,
    this.targetKcal,
    this.targetProtein,
  });

  final MacroTotals eaten;
  final MacroTotals planned;
  final int? targetKcal;
  final int? targetProtein;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final goal = targetKcal ?? planned.kcal;
    final progress = goal == 0 ? 0.0 : (eaten.kcal / goal).clamp(0.0, 1.0);
    return TmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${eaten.kcal}', style: text.headlineMedium),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('/ $goal kcal', style: text.bodyMedium),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.well,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Macro(
                'Bielkoviny',
                eaten.proteinG,
                targetProtein?.toDouble() ?? planned.proteinG,
              ),
              _Macro('Sacharidy', eaten.carbsG, planned.carbsG),
              _Macro('Tuky', eaten.fatG, planned.fatG),
            ],
          ),
        ],
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro(this.label, this.value, this.goal);

  final String label;
  final double value;
  final double goal;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.bodySmall),
          Text(
            '${value.round()} / ${goal.round()} g',
            style: text.bodyMedium!.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _MealRow extends StatelessWidget {
  const _MealRow({required this.item, required this.eaten, this.onToggle});

  final MealItem item;
  final bool eaten;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final details = [
      ?item.amount,
      '${item.kcal} kcal',
      'B ${item.proteinG.round()} g',
      'S ${item.carbsG.round()} g',
      'T ${item.fatG.round()} g',
    ].join(' · ');
    return AppRow(
      leading: Checkbox(
        value: eaten,
        onChanged: onToggle == null ? null : (_) => onToggle!(),
        activeColor: AppColors.good,
        checkColor: AppColors.bg,
      ),
      title: item.name,
      subtitle: [
        item.meal,
        details,
        if (item.note != null) item.note!,
      ].join('\n'),
      onTap: onToggle,
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => const _Message(
    'Zatiaľ ti tréner neposlal jedálniček. Keď ho pošle, príde ti '
    'upozornenie a nájdeš ho tu.',
  );
}

class _Message extends StatelessWidget {
  const _Message(this.message, {this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.restaurant_menu_rounded,
              size: 44,
              color: AppColors.muted,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onRetry, child: const Text('Skúsiť znova')),
            ],
          ],
        ),
      ),
    );
  }
}
