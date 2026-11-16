import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/tm_card.dart';
import '../domain/gym.dart';
import '../../../core/theme/app_spacing.dart';

/// Kým fitko nemá fotky: tmavá „sála“ so žiarou a činkou.
class GymPhotoPlaceholder extends StatelessWidget {
  const GymPhotoPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(0.3, -0.2),
        radius: 1.1,
        colors: [AppColors.buttonSurface, AppColors.surface, AppColors.bg],
        stops: [0, 0.55, 1],
      ),
    ),
    child: Center(
      child: Icon(
        Icons.fitness_center_rounded,
        size: 96,
        color: AppColors.accent.withValues(alpha: 0.3),
      ),
    ),
  );
}

/// Štvorcové tlačidlo akcie (Navigovať, Uložiť, Zdieľať, Web).
class DetailActionTile extends StatelessWidget {
  const DetailActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;

  /// Dostane polohu tlačidla na obrazovke (pre okno zdieľania na iPade).
  final void Function(Rect? origin) onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.lg);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        borderRadius: radius,
        color: primary ? null : AppColors.sheet.withValues(alpha: 0.8),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: primary ? AppColors.actionGradient : null,
            border: primary ? null : Border.all(color: AppColors.border),
            boxShadow: primary
                ? [
                    BoxShadow(
                      color: AppColors.accentDeep.withValues(alpha: 0.12),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: () {
              final box = context.findRenderObject() as RenderBox?;
              onTap(
                box == null ? null : box.localToGlobal(Offset.zero) & box.size,
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Column(
                children: [
                  Icon(
                    icon,
                    color: primary ? AppColors.onAccent : AppColors.text,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: primary ? AppColors.onAccent : AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DetailInfoRow extends StatelessWidget {
  const DetailInfoRow({
    super.key,
    required this.icon,
    required this.text,
    this.trailing,
    this.color,
  });

  final IconData icon;
  final String text;
  final String? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium!;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.muted),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(text, style: style.copyWith(color: color)),
          ),
          if (trailing case final trailing?) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(trailing, style: style.copyWith(color: AppColors.accent)),
          ],
        ],
      ),
    );
  }
}

/// Priemer a rozloženie hodnotení po hviezdičkách.
class GymRatingCard extends StatelessWidget {
  const GymRatingCard(
    this.rating, {
    super.key,
    required this.myStars,
    required this.onRate,
  });

  final GymRating? rating;

  /// Moje hodnotenie (null = ešte som nehodnotil).
  final int? myStars;

  /// Ťuknutie na hviezdičku; null = zrušiť moje hodnotenie.
  final ValueChanged<int?> onRate;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final rating = this.rating;
    return TmCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hodnotenie', style: text.titleMedium),
          const SizedBox(height: AppSpacing.md),
          if (rating == null || rating.count == 0)
            Text(
              'Toto fitko zatiaľ nikto nehodnotil.',
              style: text.bodyMedium!.copyWith(color: AppColors.muted),
            )
          else
            Row(
              children: [
                Column(
                  children: [
                    Text(rating.averageLabel, style: text.displayMedium),
                    Text(rating.countLabel, style: text.bodySmall),
                  ],
                ),
                const SizedBox(width: AppSpacing.xl),
                Expanded(
                  child: Column(
                    children: [
                      for (var star = 5; star >= 1; star--)
                        _StarBar(star: star, share: rating.share(star)),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  myStars == null ? 'Ohodnoť fitko' : 'Tvoje hodnotenie',
                  style: text.bodyMedium,
                ),
              ),
              for (var star = 1; star <= 5; star++)
                IconButton(
                  // Plná 48 px plocha: hviezdičky sa ťukajú aj v pohybe.
                  constraints: const BoxConstraints.tightFor(
                    width: 44,
                    height: 48,
                  ),
                  padding: EdgeInsets.zero,
                  tooltip: '$star z 5',
                  // Ťuknutie na už zvolenú hviezdičku hodnotenie zruší.
                  onPressed: () => onRate(star == myStars ? null : star),
                  icon: Icon(
                    star <= (myStars ?? 0)
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: Plate.yellow.color,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StarBar extends StatelessWidget {
  const _StarBar({required this.star, required this.share});

  final int star;
  final double share;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Row(
      children: [
        SizedBox(
          width: 12,
          child: Text('$star', style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 7,
              backgroundColor: AppColors.surfaceHi,
              valueColor: const AlwaysStoppedAnimation(AppColors.accentDeep),
            ),
          ),
        ),
      ],
    ),
  );
}
