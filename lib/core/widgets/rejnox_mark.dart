import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Pôvodné proporcie futuristického znaku.
const rejnoxMarkSize = Size(492, 305);

// Pôvodné vektorové cesty pre SVG a Android VectorDrawable. Natívny Flutter
// ich kreslí cez zodpovedajúce oblúky a Bézierove krivky nižšie.
const rejnoxLetterData =
    'M68 0H385A107 107 0 0 1 385 214L400 215L478 305'
    'H365L235 155H385A38.5 38.5 0 0 0 385 78H130Z';
const rejnoxStripeData =
    'M150 155H235L135 280Q115 305 85 305H0L100 180'
    'Q120 155 150 155Z';

final _letter = Path()
  ..moveTo(68, 0)
  ..lineTo(385, 0)
  ..arcToPoint(const Offset(385, 214), radius: const Radius.circular(107))
  ..lineTo(400, 215)
  ..lineTo(478, 305)
  ..lineTo(365, 305)
  ..lineTo(235, 155)
  ..lineTo(385, 155)
  ..arcToPoint(
    const Offset(385, 78),
    radius: const Radius.circular(38.5),
    clockwise: false,
  )
  ..lineTo(130, 78)
  ..close();

final _stripe = Path()
  ..moveTo(150, 155)
  ..lineTo(235, 155)
  ..lineTo(135, 280)
  ..quadraticBezierTo(115, 305, 85, 305)
  ..lineTo(0, 305)
  ..lineTo(100, 180)
  ..quadraticBezierTo(120, 155, 150, 155)
  ..close();

/// Biele R s koralovým pruhom. [color] zafarbí celý znak napríklad pri vodoznaku.
class RejnoxMark extends StatelessWidget {
  const RejnoxMark({super.key, this.width = 36, this.color});

  final double width;
  final Color? color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Rejnox',
    image: true,
    child: SizedBox(
      width: width,
      height: width * rejnoxMarkSize.height / rejnoxMarkSize.width,
      child: CustomPaint(painter: RejnoxMarkPainter(color: color)),
    ),
  );
}

class RejnoxMarkPainter extends CustomPainter {
  const RejnoxMarkPainter({
    this.color,
    this.outlineProgress = 1,
    this.fillProgress = 1,
  });

  final Color? color;
  final double outlineProgress;
  final double fillProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final fitted = applyBoxFit(
      BoxFit.contain,
      rejnoxMarkSize,
      size,
    ).destination;
    final bounds = Alignment.center.inscribe(fitted, Offset.zero & size);
    final scale = bounds.width / rejnoxMarkSize.width;
    final fill = fillProgress.clamp(0.0, 1.0);
    canvas.save();
    canvas.translate(bounds.left, bounds.top);
    canvas.scale(scale);
    _drawPart(canvas, _letter, color ?? AppColors.text, fill);
    _drawPart(canvas, _stripe, color ?? AppColors.primary, fill);
    canvas.restore();
  }

  void _drawPart(Canvas canvas, Path path, Color partColor, double fill) {
    if (fill < 1 && outlineProgress > 0) {
      final progress = outlineProgress.clamp(0.0, 1.0);
      final outline = Path();
      for (final metric in path.computeMetrics()) {
        outline.addPath(
          metric.extractPath(0, metric.length * progress),
          Offset.zero,
        );
      }
      canvas.drawPath(
        outline,
        Paint()
          ..color = partColor.withValues(alpha: partColor.a * (1 - fill))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeJoin = StrokeJoin.round,
      );
    }
    if (fill > 0) {
      canvas.drawPath(
        path,
        Paint()..color = partColor.withValues(alpha: partColor.a * fill),
      );
    }
  }

  @override
  bool shouldRepaint(RejnoxMarkPainter old) =>
      old.color != color ||
      old.outlineProgress != outlineProgress ||
      old.fillProgress != fillProgress;
}

/// Krátky rytmus loga pri skutočnom načítavaní; rešpektuje obmedzenie pohybu.
class RejnoxLoader extends StatefulWidget {
  const RejnoxLoader({super.key});

  @override
  State<RejnoxLoader> createState() => _RejnoxLoaderState();
}

class _RejnoxLoaderState extends State<RejnoxLoader>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
      _pulse.value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Načítavam Rejnox',
    excludeSemantics: true,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: _pulse.drive(Tween(begin: 0.45, end: 1.0)),
          child: const RejnoxMark(width: 64),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Načítavam…', style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}
