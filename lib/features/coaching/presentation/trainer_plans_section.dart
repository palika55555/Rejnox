import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/tm_card.dart';
import '../application/coaching_providers.dart';
import 'coaching_widgets.dart';

/// Plány od trénera na karte Tréning (aj bez internetu z pamäte telefónu).
class TrainerPlansSection extends ConsumerWidget {
  const TrainerPlansSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final plans = ref.watch(myPlansProvider).value;
    if (plans == null || plans.plans.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: SectionLabel(
                  'Plány od trénera',
                  icon: Icons.assignment_rounded,
                ),
              ),
              if (plans.offline)
                Text('uložené v telefóne', style: text.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          for (final p in plans.plans.take(3)) ...[
            PlanCard(p, showTrainer: true),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
