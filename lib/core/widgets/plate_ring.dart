import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Koralový týždenný progres; zelený po dosiahnutí cieľa.
class PlateRing extends StatelessWidget {
  const PlateRing({
    super.key,
    required this.done,
    required this.total,
    this.size = 120,
  }) : assert(total > 0),
       assert(done >= 0);

  final int done;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Splnené $done z $total',
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _PlateRingPainter(done, total)),
      ),
    );
  }
}

class _PlateRingPainter extends CustomPainter {
  _PlateRingPainter(this.done, this.total);

  final int done;
  final int total;

  /// Medzera medzi dielmi v radiánoch.
  static const _gap = 0.1;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.16;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.width - stroke) / 2,
    );
    final sweep = 2 * math.pi / total;
    for (var i = 0; i < total; i++) {
      final color = i < done
          ? (done >= total ? AppColors.good : AppColors.accent)
          : AppColors.border;
      canvas.drawArc(
        rect,
        -math.pi / 2 + i * sweep + _gap / 2,
        sweep - _gap,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      );
    }
    // Stredový otvor kotúča.
    canvas.drawCircle(
      rect.center,
      size.width * 0.14,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_PlateRingPainter old) =>
      old.done != done || old.total != total;
}
