import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/tm_card.dart';
import 'heart_rate_charts.dart';
import 'heart_rate_stats.dart';

String hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String dayLabel(DateTime t, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(t.year, t.month, t.day);
  if (d == today) return 'Dnes o ${hhmm(t)}';
  if (d == today.subtract(const Duration(days: 1))) return 'Včera o ${hhmm(t)}';
  return '${t.day}. ${t.month}. o ${hhmm(t)}';
}

/// Prepínač (Prehľad / Zóny / Trendy, Dnes / 7 dní / 30 dní).
class Segments<T> extends StatelessWidget {
  const Segments({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final v in values)
            Expanded(
              child: Semantics(
                button: true,
                selected: v == selected,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(v),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: v == selected ? AppColors.actionGradient : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      label(v),
                      style: text.bodyMedium!.copyWith(
                        fontWeight: FontWeight.w700,
                        color: v == selected ? Colors.white : AppColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Malá dlaždica s hodnotou (Minimum, HRV, Pokojový tep…).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.unit = 'BPM',
    this.hint,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String unit;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return TmCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: text.bodySmall!.copyWith(color: AppColors.text),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (hint != null) Text(hint!, style: text.bodySmall),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                text: value,
                style: text.headlineMedium,
                children: [TextSpan(text: ' $unit', style: text.bodySmall)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Graf tepu za obdobie + minimum, priemer, maximum.
class OverviewChartCard extends StatelessWidget {
  const OverviewChartCard({
    super.key,
    required this.title,
    required this.samples,
    required this.from,
    required this.to,
  });

  final String title;
  final List<HrSample> samples;
  final DateTime from;
  final DateTime to;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final stats = heartRateStats(samples);
    String v(double? x) => x == null ? '—' : '${x.round()}';
    return Column(
      children: [
        TmCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: text.titleMedium)),
                  Text('BPM', style: text.bodySmall),
                ],
              ),
              const SizedBox(height: 12),
              if (samples.length < 2)
                SizedBox(
                  height: 120,
                  child: Center(
                    child: Text('Zatiaľ málo meraní.', style: text.bodySmall),
                  ),
                )
              else
                HeartLineChart(samples: samples, from: from, to: to),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: Icons.arrow_downward_rounded,
                color: AppColors.blue,
                label: 'Minimum',
                value: v(stats?.min),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                icon: Icons.monitor_heart_outlined,
                color: AppColors.accent,
                label: 'Priemer',
                value: v(stats?.avg),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                icon: Icons.arrow_upward_rounded,
                color: Plate.red.color,
                label: 'Maximum',
                value: v(stats?.max),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Tepové zóny: prstenec a legenda s časom.
class ZonesCard extends StatelessWidget {
  const ZonesCard({super.key, required this.zones, required this.maxHr});

  final Map<HrZone, Duration> zones;
  final double maxHr;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    String fmt(Duration d) => d.inHours > 0
        ? '${d.inHours} h ${d.inMinutes % 60} min'
        : '${d.inMinutes} min';
    return TmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tepové zóny', style: text.titleMedium),
          Text(
            'Z max. tepu ${maxHr.round()} BPM (odhad pre dospelého).',
            style: text.bodySmall,
          ),
          const SizedBox(height: 14),
          Center(child: ZoneDonut(zones: zones)),
          const SizedBox(height: 14),
          for (final z in HrZone.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: z.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${z.label} (${z.range})',
                      style: text.bodyMedium,
                    ),
                  ),
                  Text(
                    fmt(zones[z]!),
                    style: text.bodyMedium!.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Posledné merania so štítkom (Pokoj / Tréning / Po prebudení).
class RecentMeasurements extends StatelessWidget {
  const RecentMeasurements({
    super.key,
    required this.history,
    required this.now,
  });

  final HeartRateHistory history;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final recent = history.samples.reversed.take(5).toList();
    return TmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Posledné merania', style: text.titleMedium),
          const SizedBox(height: 6),
          if (recent.isEmpty) Text('Žiadne merania.', style: text.bodySmall),
          for (final s in recent)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Plate.red.color.withValues(alpha: 0.14),
                    ),
                    child: Icon(
                      Icons.favorite_border_rounded,
                      size: 18,
                      color: Plate.red.color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${s.bpm.round()} BPM', style: text.bodyLarge),
                        Text(dayLabel(s.at, now), style: text.bodySmall),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHi,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      measurementTag(s, restingBpm: history.restingBpm),
                      style: text.bodySmall!.copyWith(color: AppColors.text),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Zaujímavosť: najvyšší tep za obdobie v porovnaní s priemerom.
class InsightCard extends StatelessWidget {
  const InsightCard({super.key, required this.samples});

  final List<HrSample> samples;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final stats = heartRateStats(samples);
    if (stats == null || samples.length < 5) return const SizedBox.shrink();
    final peak = samples.reduce((a, b) => b.bpm > a.bpm ? b : a);
    final pct = ((stats.max / stats.avg - 1) * 100).round();
    return TmCard(
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Najvyšší tep: ${peak.bpm.round()} BPM o ${hhmm(peak.at)}, '
              'o $pct % viac ako tvoj priemer.',
              style: text.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
