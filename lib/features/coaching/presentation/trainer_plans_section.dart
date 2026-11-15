import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/tm_card.dart';
import '../application/coaching_providers.dart';
import '../domain/coaching_models.dart';
import 'coaching_widgets.dart';

/// Plány od trénera na karte Tréning (aj bez internetu z pamäte telefónu).
class TrainerPlansSection extends ConsumerWidget {
  const TrainerPlansSection({super.key, this.onStart});

  final ValueChanged<Plan>? onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final plans = ref.watch(myPlansProvider).value;
    if (plans == null || plans.plans.isEmpty) return const SizedBox.shrink();

    return AppSection(
      title: 'Plány od trénera',
      trailing: plans.offline
          ? Text('uložené v telefóne', style: text.bodySmall)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, p) in plans.plans.take(3).indexed) ...[
            if (i > 0) const SizedBox(height: 10),
            PlanCard(
              p,
              showTrainer: true,
              onStart: onStart == null || p.items.isEmpty
                  ? null
                  : () => onStart!(p),
            ),
          ],
        ],
      ),
    );
  }
}
