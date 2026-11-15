import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/progress_models.dart';

/// „24. 8.“
String shortDate(DateTime d) => '${d.day}. ${d.month}.';

/// Objem čitateľne: 850 kg, 12,4 t.
String formatVolume(double kg) {
  if (kg < 1000) return '${kg.round()} kg';
  final t = (kg / 100).round() / 10;
  final s = t == t.roundToDouble() ? t.toInt().toString() : t.toString();
  return '${s.replaceAll('.', ',')} t';
}

/// Stĺpce objemu po týždňoch; tento týždeň je koralový.
class WeeklyVolumeChart extends StatelessWidget {
  const WeeklyVolumeChart(this.weeks, {super.key});

  final List<WeekStat> weeks;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.labelSmall!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: 'Objem za posledných ${weeks.length} týždňov',
          child: SizedBox(
            height: 120,
            child: CustomPaint(painter: _BarsPainter(weeks)),
          ),
        ),
        const SizedBox(height: 6),
        if (weeks.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(shortDate(weeks.first.start), style: small),
              Text('Tento týždeň', style: small),
            ],
          ),
      ],
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.weeks);

  final List<WeekStat> weeks;

  @override
  void paint(Canvas canvas, Size size) {
    if (weeks.isEmpty) return;
    final max = weeks.map((w) => w.volumeKg).fold(0.0, (a, b) => a > b ? a : b);
    final slot = size.width / weeks.length;
    final barWidth = slot * 0.62;
    final grid = Paint()
      ..color = AppColors.grid
      ..strokeWidth = 1;
    for (final f in [0.0, 0.5, 1.0]) {
      final y = (size.height - 1) * f;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    for (var i = 0; i < weeks.length; i++) {
      final isLast = i == weeks.length - 1;
      final value = weeks[i].volumeKg;
      // Prázdny týždeň má aspoň malý pahýľ, aby bolo vidno, že tam je.
      final h = max == 0
          ? 3.0
          : (value / max * (size.height - 4)).clamp(3, size.height);
      final left = slot * i + (slot - barWidth) / 2;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(left, size.height - h, barWidth, h.toDouble()),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        ),
        Paint()
          ..color = isLast
              ? AppColors.accent
              : value == 0
              ? AppColors.well
              : AppColors.steel.withValues(alpha: 0.55),
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => old.weeks != weeks;
}

/// Väčšia krivka cviku s bodmi, mriežkou a rozsahom váh.
class ExerciseTrendChart extends StatelessWidget {
  const ExerciseTrendChart(this.points, {super.key});

  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.labelSmall!;
    if (points.length < 2) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'Krivka sa ukáže po druhom tréningu tohto cviku.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 150,
          child: CustomPaint(painter: _TrendPainter(points)),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(shortDate(points.first.day), style: small),
            Text(shortDate(points.last.day), style: small),
          ],
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.points);

  final List<TrendPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final values = [for (final p in points) p.kg];
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final range = max - min == 0 ? 1 : max - min;
    const pad = 8.0;
    Offset at(int i) => Offset(
      pad + (size.width - 2 * pad) * i / (values.length - 1),
      pad + (1 - (values[i] - min) / range) * (size.height - 2 * pad),
    );

    final grid = Paint()
      ..color = AppColors.grid
      ..strokeWidth = 1;
    for (final f in [0.0, 0.5, 1.0]) {
      final y = pad + (size.height - 2 * pad) * f;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final line = Path();
    final fill = Path()..moveTo(at(0).dx, size.height);
    for (var i = 0; i < values.length; i++) {
      final p = at(i);
      i == 0 ? line.moveTo(p.dx, p.dy) : line.lineTo(p.dx, p.dy);
      fill.lineTo(p.dx, p.dy);
    }
    fill
      ..lineTo(at(values.length - 1).dx, size.height)
      ..close();
    canvas
      ..drawPath(
        fill,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.accentSoft, Colors.transparent],
          ).createShader(Offset.zero & size),
      )
      ..drawPath(
        line,
        Paint()
          ..color = AppColors.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    for (var i = 0; i < values.length; i++) {
      final best = values[i] == max;
      canvas.drawCircle(
        at(i),
        best ? 4.5 : 3,
        Paint()..color = best ? AppColors.accent : AppColors.text,
      );
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) => old.points != points;
}
