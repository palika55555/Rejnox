import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/tm_card.dart';
import '../domain/gym.dart';

/// Kým fitko nemá fotky: tmavá „sála“ so žiarou a činkou.
class GymPhotoPlaceholder extends StatelessWidget {
  const GymPhotoPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(0.3, -0.2),
        radius: 1.1,
        colors: [Color(0xFF3A2A8F), Color(0xFF14103A), AppColors.bg],
        stops: [0, 0.55, 1],
      ),
    ),
    child: Center(
      child: Icon(
        Icons.fitness_center_rounded,
        size: 96,
        color: AppColors.accent.withValues(alpha: 0.35),
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
    final radius = BorderRadius.circular(18);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        borderRadius: radius,
        color: primary ? null : AppColors.surface.withValues(alpha: 0.8),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: primary ? AppColors.actionGradient : null,
            border: primary ? null : Border.all(color: AppColors.border),
            boxShadow: primary
                ? [
                    BoxShadow(
                      color: AppColors.blue.withValues(alpha: 0.45),
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
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                children: [
                  Icon(icon, color: primary ? Colors.white : AppColors.text),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: primary ? Colors.white : AppColors.text,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: style.copyWith(color: color)),
          ),
          if (trailing case final trailing?) ...[
            const SizedBox(width: 8),
            Text(trailing, style: style.copyWith(color: AppColors.accent)),
          ],
        ],
      ),
    );
  }
}

class GymGallery extends StatelessWidget {
  const GymGallery({super.key, required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 92,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: urls.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, index) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          urls[index],
          width: 120,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              const SizedBox(width: 120, child: GymPhotoPlaceholder()),
        ),
      ),
    ),
  );
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hodnotenie', style: text.titleMedium),
          const SizedBox(height: 12),
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
                    Text(
                      rating.averageLabel,
                      style: text.headlineLarge!.copyWith(fontSize: 44),
                    ),
                    Text(rating.countLabel, style: text.bodySmall),
                  ],
                ),
                const SizedBox(width: 20),
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
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),
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
                  visualDensity: VisualDensity.compact,
                  tooltip: '$star z 5',
                  // Ťuknutie na už zvolenú hviezdičku hodnotenie zruší.
                  onPressed: () => onRate(star == myStars ? null : star),
                  icon: Icon(
                    star <= (myStars ?? 0)
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: const Color(0xFFFFC542),
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
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(
          width: 12,
          child: Text('$star', style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 7,
              backgroundColor: AppColors.surfaceHi,
              valueColor: const AlwaysStoppedAnimation(AppColors.blue),
            ),
          ),
        ),
      ],
    ),
  );
}
