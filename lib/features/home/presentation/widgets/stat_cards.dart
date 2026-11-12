import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/tm_card.dart';
import '../../domain/home_overview.dart';

/// Osobný rekord s malým grafom vývoja.
class PersonalRecordTile extends StatelessWidget {
  const PersonalRecordTile(this.record, {super.key});

  final PersonalRecord record;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return TmCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: SectionLabel('${record.exercise} PR')),
              const Icon(
                Icons.military_tech_rounded,
                size: 16,
                color: AppColors.accent,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              text: record.weightLabel,
              style: text.headlineLarge,
              children: [TextSpan(text: ' kg', style: text.bodyMedium)],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.trending_up_rounded,
                size: 14,
                color: AppColors.accent,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  record.deltaLabel,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall!.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 22,
            width: double.infinity,
            child: CustomPaint(painter: _SparklinePainter(record.trend)),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final range = max - min == 0 ? 1 : max - min;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - (values[i] - min) / range * (size.height - 4) - 2;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.values != values;
}

/// Pozícia v rebríčku.
class RankingTile extends StatelessWidget {
  const RankingTile(this.ranking, {super.key});

  final Ranking ranking;

  static const _segments = 4;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Čím lepšie umiestnenie, tým viac vyplnených dielikov.
    final filled = switch (ranking.topPercent) {
      <= 5 => 4,
      <= 20 => 3,
      <= 50 => 2,
      _ => 1,
    };
    return TmCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(child: SectionLabel('Rebríček')),
              Icon(
                Icons.emoji_events_rounded,
                size: 16,
                color: AppColors.accent,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              text: '#${ranking.position}',
              style: text.headlineLarge,
              children: [
                TextSpan(
                  text: ' ${ranking.region}',
                  style: text.bodyMedium!.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Top ${ranking.topPercent} % v ${ranking.gymName}',
            style: text.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < _segments; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: i < filled
                          ? AppColors.accent
                          : AppColors.surfaceHi,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Najbližšie fitko s vyťaženosťou.
class NearbyGymCard extends StatelessWidget {
  const NearbyGymCard(this.gym, {super.key, required this.onTap});

  final NearbyGym gym;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return TmCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const _RoundIcon(Icons.place_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: gym.name,
                    style: text.titleMedium,
                    children: [
                      TextSpan(
                        text: '  •  ${gym.distanceLabel}',
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Vyťaženosť ${gym.occupancyPercent} %',
                  style: text.bodySmall!.copyWith(color: Plate.green.color),
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

/// Niekto hľadá parťáka na tréning.
class PartnerRequestCard extends StatelessWidget {
  const PartnerRequestCard(this.request, {super.key, required this.onJoin});

  final PartnerRequest request;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return TmCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const _RoundIcon(Icons.handshake_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${request.name} hľadá parťáka', style: text.titleMedium),
                const SizedBox(height: 2),
                Text(
                  '${request.when} • ${request.focus}',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PrimaryButton(label: 'Pridať sa', compact: true, onPressed: onJoin),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.bg,
        border: Border.all(color: AppColors.border),
      ),
      child: Icon(icon, size: 20, color: AppColors.accent),
    );
  }
}
