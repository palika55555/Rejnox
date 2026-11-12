import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/tm_card.dart';
import 'health_platform.dart';

/// Odkaz na sekciu Zdravie (v profile).
class HeartRateTile extends StatelessWidget {
  const HeartRateTile({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return TmCard(
      onTap: () => context.push('/health'),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.health_and_safety_outlined, color: AppColors.violet),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Zdravie', style: text.titleMedium),
                Text(
                  'Tep, kroky, kalórie, spánok a váha z '
                  '${healthPlatformSupported ? healthStoreName : 'mobilu'}',
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
