import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Progres ako činka: každý splnený krok pridá farebný kotúč na tyč.
class BarbellProgress extends StatelessWidget {
  const BarbellProgress({super.key, required this.done, required this.total})
    : assert(total > 0),
      assert(done >= 0);

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Splnené $done z $total',
      child: SizedBox(
        height: 30,
        width: double.infinity,
        child: CustomPaint(painter: _BarbellPainter(done, total)),
      ),
    );
  }
}

class _BarbellPainter extends CustomPainter {
  _BarbellPainter(this.done, this.total);

  final int done;
  final int total;

  static const _plateWidth = 9.0;
  static const _gap = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;

    // Tyč.
    final shaft = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, mid - 3, size.width, 6),
      const Radius.circular(3),
    );
    canvas.drawRRect(shaft, Paint()..color = AppColors.surfaceHi);

    // Objímka na konci tyče.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, mid - 6, 8, 12),
        const Radius.circular(2),
      ),
      Paint()..color = AppColors.muted,
    );

    for (var i = 0; i < total; i++) {
      final isDone = i < done;
      // Kotúče sa smerom von zmenšujú, ako na skutočnej čince.
      final height = (size.height - i * 3).clamp(14.0, size.height);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          12 + i * (_plateWidth + _gap),
          mid - height / 2,
          _plateWidth,
          height,
        ),
        const Radius.circular(3),
      );
      if (isDone) {
        final color = Plate.values[i % Plate.values.length].color;
        canvas.drawRRect(rect, Paint()..color = color);
      } else {
        canvas.drawRRect(
          rect,
          Paint()
            ..color = AppColors.muted.withValues(alpha: 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BarbellPainter old) =>
      old.done != done || old.total != total;
}
