import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Hlavička obrazovky: veľký zúžený nadpis verzálkami a akcie vpravo.
/// S [onBack] je to podstránka s menším nadpisom a šípkou späť.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader(
    this.title, {
    super.key,
    this.subtitle,
    this.trailing = const [],
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final List<Widget> trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final sub = subtitle;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        onBack == null ? AppSpacing.lg : AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            if (onBack != null)
              IconButton(
                tooltip: 'Späť',
                onPressed: onBack,
                icon: const Icon(Icons.chevron_left_rounded, size: 28),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: onBack == null
                        ? text.headlineLarge
                        : text.headlineMedium,
                  ),
                  if (sub != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall!.copyWith(
                        fontWeight: FontWeight.w500,
                        color: AppColors.ink2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            for (final w in trailing) ...[
              const SizedBox(width: AppSpacing.sm),
              w,
            ],
          ],
        ),
      ),
    );
  }
}

/// Zvislý zoznam sekcií s rovnakou medzerou ako v návrhu (22 px).
class SectionStack extends StatelessWidget {
  const SectionStack({super.key, required this.children, this.gap = 22});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          children[i],
        ],
      ],
    );
  }
}
