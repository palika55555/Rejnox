import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'heart_rate_stats.dart';

/// Veľký kruh s tepom (modro-fialový prechod ako v logu).
class HeartRing extends StatelessWidget {
  const HeartRing({super.key, required this.bpm, required this.caption});

  final int? bpm;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox.square(
      dimension: 210,
      child: CustomPaint(
        painter: _RingPainter(),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.favorite_border_rounded,
                color: AppColors.accent,
                size: 26,
              ),
              Text(
                bpm == null ? '—' : '$bpm',
                style: text.headlineLarge!.copyWith(fontSize: 58),
              ),
              Text('BPM', style: text.bodySmall),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHi,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: text.bodySmall!.copyWith(color: AppColors.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 10;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.surfaceHi
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12,
    );
    final sweep = 2 * pi * 0.86;
    final arc = Paint()
      ..shader = const SweepGradient(
        startAngle: 0,
        endAngle: 2 * pi,
        colors: [AppColors.blue, AppColors.violet, AppColors.accent],
        transform: GradientRotation(-pi / 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -pi / 2, sweep, false, arc);
    // Žiara.
    canvas.drawArc(
      rect,
      -pi / 2,
      sweep,
      false,
      arc
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
        ..color = AppColors.violet.withValues(alpha: 0.4),
    );
    final end = Offset(
      center.dx + radius * cos(-pi / 2 + sweep),
      center.dy + radius * sin(-pi / 2 + sweep),
    );
    canvas.drawCircle(end, 6, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => false;
}

/// Čiarový graf tepu s osami a vyznačeným maximom.
class HeartLineChart extends StatelessWidget {
  const HeartLineChart({
    super.key,
    required this.samples,
    required this.from,
    required this.to,
  });

  final List<HrSample> samples;
  final DateTime from;
  final DateTime to;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      width: double.infinity,
      child: CustomPaint(
        painter: _LinePainter(
          samples,
          from,
          to,
          Theme.of(context).textTheme.bodySmall!,
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.samples, this.from, this.to, this.label);

  final List<HrSample> samples;
  final DateTime from;
  final DateTime to;
  final TextStyle label;

  static const _left = 30.0, _bottom = 20.0;

  void _text(Canvas c, String s, Offset at, {bool center = false}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: label.copyWith(fontSize: 10)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center ? at - Offset(tp.width / 2, 0) : at);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width - _left, h = size.height - _bottom;
    const lo = 40.0, hi = 160.0;
    double x(DateTime t) =>
        _left +
        w *
            (t.difference(from).inSeconds /
                max(1, to.difference(from).inSeconds));
    double y(double bpm) => h * (1 - ((bpm.clamp(lo, hi) - lo) / (hi - lo)));

    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (final v in [40, 80, 120, 160]) {
      canvas.drawLine(
        Offset(_left, y(v.toDouble())),
        Offset(size.width, y(v.toDouble())),
        grid,
      );
      _text(canvas, '$v', Offset(0, y(v.toDouble()) - 6));
    }
    final span = to.difference(from);
    for (var i = 0; i <= 4; i++) {
      final t = from.add(span * (i / 4));
      final label = span.inHours <= 24
          ? '${t.hour.toString().padLeft(2, '0')}:00'
          : '${t.day}.${t.month}.';
      _text(canvas, label, Offset(x(t), h + 6), center: true);
    }
    if (samples.length < 2) return;

    final line = Path();
    for (var i = 0; i < samples.length; i++) {
      final p = Offset(x(samples[i].at), y(samples[i].bpm));
      i == 0 ? line.moveTo(p.dx, p.dy) : line.lineTo(p.dx, p.dy);
    }
    final fill = Path.from(line)
      ..lineTo(x(samples.last.at), h)
      ..lineTo(x(samples.first.at), h)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.violet.withValues(alpha: 0.35),
            AppColors.violet.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, h)),
    );
    canvas.drawPath(
      line,
      Paint()
        ..shader = const LinearGradient(
          colors: [AppColors.blue, AppColors.violet],
        ).createShader(Rect.fromLTWH(_left, 0, w, h))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );

    final peak = samples.reduce((a, b) => b.bpm > a.bpm ? b : a);
    final p = Offset(x(peak.at), y(peak.bpm));
    canvas.drawCircle(p, 5, Paint()..color = Colors.white);
    canvas.drawCircle(
      p,
      9,
      Paint()
        ..color = AppColors.violet.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.samples != samples || old.from != from || old.to != to;
}

/// Prstenec tepových zón s celkovým časom v strede.
class ZoneDonut extends StatelessWidget {
  const ZoneDonut({super.key, required this.zones});

  final Map<HrZone, Duration> zones;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final total = zones.values.fold(Duration.zero, (a, b) => a + b);
    return SizedBox.square(
      dimension: 130,
      child: CustomPaint(
        painter: _DonutPainter(zones, total),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${total.inHours} h ${total.inMinutes % 60} min',
                style: text.titleMedium,
              ),
              Text('celkom', style: text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.zones, this.total);

  final Map<HrZone, Duration> zones;
  final Duration total;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.width / 2 - 9,
    );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;
    if (total == Duration.zero) {
      canvas.drawArc(
        rect,
        0,
        2 * pi,
        false,
        stroke..color = AppColors.surfaceHi,
      );
      return;
    }
    var start = -pi / 2;
    for (final zone in HrZone.values) {
      final part = zones[zone]!.inSeconds / total.inSeconds;
      if (part <= 0) continue;
      final sweep = 2 * pi * part;
      canvas.drawArc(
        rect,
        start,
        max(0, sweep - 0.04),
        false,
        stroke..color = zone.color,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.zones != zones;
}
