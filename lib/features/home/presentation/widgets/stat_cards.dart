import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/tm_card.dart';
import '../../../community/presentation/community_format.dart';
import '../../domain/home_overview.dart';
import '../../../../core/theme/app_spacing.dart';

/// Osobný rekord: veľké číslo, krivka vývoja a zmena za mesiac.
class PersonalRecordRow extends StatelessWidget {
  const PersonalRecordRow(this.record, {super.key});

  final PersonalRecord record;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth / MediaQuery.textScalerOf(context).scale(1) <
              320;
          return Flex(
            direction: compact ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: compact
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Flexible(
                flex: compact ? 0 : 1,
                fit: FlexFit.tight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${record.exercise} · osobný rekord',
                      style: text.bodyMedium!.copyWith(color: AppColors.ink2),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text.rich(
                      TextSpan(
                        text: record.weightLabel,
                        children: [
                          TextSpan(
                            text: ' kg',
                            style: text.bodySmall!.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                      style: text.displaySmall,
                    ),
                  ],
                ),
              ),
              if (compact) const SizedBox(height: AppSpacing.md),
              Column(
                crossAxisAlignment: compact
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 84,
                    height: 30,
                    child: CustomPaint(painter: SparklinePainter(record.trend)),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (compact)
                    Text(record.deltaLabel, style: text.bodySmall)
                  else
                    AppPill(
                      record.deltaLabel,
                      tone: record.monthDeltaKg >= 0
                          ? PillTone.good
                          : PillTone.warn,
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Ešte žiadna odcvičená séria, teda ani rekord.
class EmptyRecordRow extends StatelessWidget {
  const EmptyRecordRow({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppRow(
      leading: Icon(Icons.emoji_events_outlined, color: AppColors.muted),
      title: 'Zatiaľ bez rekordu',
      subtitle: 'Odcvič prvú sériu a uvidíš tu svoj osobný rekord.',
    );
  }
}

/// Krivka: neutrálna čiara, koralový koncový bod.
class SparklinePainter extends CustomPainter {
  SparklinePainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final range = max - min == 0 ? 1 : max - min;
    Offset at(int i) => Offset(
      3 + (size.width - 8) * i / (values.length - 1),
      4 + (1 - (values[i] - min) / range) * (size.height - 8),
    );
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final p = at(i);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.muted
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(
      at(values.length - 1),
      3.2,
      Paint()..color = AppColors.accent,
    );
  }

  @override
  bool shouldRepaint(SparklinePainter old) => old.values != values;
}

/// Pozícia v rebríčku.
class RankingRow extends StatelessWidget {
  const RankingRow(this.ranking, {super.key});

  final Ranking ranking;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppRow(
      leading: SizedBox(
        width: 40,
        child: Text(
          '${ranking.position}',
          textAlign: TextAlign.center,
          style: text.headlineLarge!.copyWith(color: AppColors.accent),
        ),
      ),
      title: 'Týždenný rebríček',
      subtitle:
          '${ranking.position}. z ${ranking.total} · '
          '${ranking.days} ${plural(ranking.days, 'deň', 'dni', 'dní')} '
          's tréningom',
      trailing: const Icon(
        Icons.emoji_events_outlined,
        color: AppColors.accent,
      ),
    );
  }
}

/// Najbližšie fitko s vyťaženosťou.
class NearbyGymRow extends StatelessWidget {
  const NearbyGymRow(this.gym, {super.key, required this.onTap});

  final NearbyGym gym;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppRow(
      onTap: onTap,
      leading: const _RoundIcon(Icons.place_outlined),
      title: gym.name,
      subtitle: '${gym.distanceLabel} · vyťaženosť ${gym.occupancyPercent} %',
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
    );
  }
}

/// Niekto hľadá parťáka na tréning.
class PartnerRequestRow extends StatelessWidget {
  const PartnerRequestRow(this.request, {super.key, required this.onJoin});

  final PartnerRequest request;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return AppRow(
      leading: const _RoundIcon(Icons.handshake_outlined),
      title: '${request.name} hľadá parťáka',
      subtitle: [
        whenLabel(request.startsAt),
        ?request.focus,
        ?request.place,
      ].join(' · '),
      trailing: PrimaryButton(
        label: 'Pridať sa',
        compact: true,
        tone: ButtonTone.ghost,
        onPressed: onJoin,
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
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.well,
        border: Border.all(color: AppColors.border),
      ),
      child: Icon(icon, size: 20, color: AppColors.ink2),
    );
  }
}
