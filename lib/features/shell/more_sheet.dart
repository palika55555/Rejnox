import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/tm_card.dart';

/// Jedna položka v menu „Viac“.
typedef MoreItem = ({
  IconData icon,
  String title,
  String? subtitle,
  VoidCallback onTap,
});

/// Otvorí menu „Viac“ s časťami, ktoré sa do spodnej lišty nezmestili.
/// Menu sa najprv zavrie, až potom sa otvorí vybraná časť.
Future<void> showMoreSheet(BuildContext context, List<MoreItem> items) async {
  final picked = await showModalBottomSheet<MoreItem>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _MoreSheet(items),
  );
  picked?.onTap();
}

class _MoreSheet extends StatelessWidget {
  const _MoreSheet(this.items);

  final List<MoreItem> items;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('VIAC', style: text.headlineMedium),
            const SizedBox(height: 12),
            AppList(
              children: [
                for (final item in items)
                  AppRow(
                    leading: Icon(item.icon, color: AppColors.accent),
                    title: item.title,
                    subtitle: item.subtitle,
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.muted,
                    ),
                    onTap: () => Navigator.of(context).pop(item),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
