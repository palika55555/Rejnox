import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/body_measurements.dart';

/// Postava spredu s bodmi na meranie. Každá časť má štítok vľavo alebo
/// vpravo s posledným rozmerom; ťuknutie na štítok alebo bod otvorí zápis.
class BodyFigure extends StatelessWidget {
  const BodyFigure({super.key, required this.latest, required this.onTap});

  final Map<BodyPart, Measurement> latest;
  final ValueChanged<BodyPart> onTap;

  static const _height = 420.0;
  static const _chipWidth = 88.0;
  static const _chipHeight = 40.0;

  /// Postava je nakreslená v súradniciach 100 × 240.
  static const _unitW = 100.0;
  static const _unitH = 240.0;

  static const _left = {
    BodyPart.arm,
    BodyPart.belly,
    BodyPart.thigh,
    BodyPart.calf,
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final scale = (_height - 10) / _unitH;
        final figureLeft = (width - _unitW * scale) / 2;
        Offset point(BodyPart p) =>
            Offset(figureLeft + p.anchor.$1 * scale, 5 + p.anchor.$2 * scale);
        Offset chipEdge(BodyPart p) => Offset(
          _left.contains(p) ? _chipWidth : width - _chipWidth,
          point(p).dy,
        );

        return SizedBox(
          height: _height,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _FigurePainter(
                    scale: scale,
                    left: figureLeft,
                    lines: [
                      for (final p in BodyPart.values)
                        (
                          from: chipEdge(p),
                          to: point(p),
                          measured: latest.containsKey(p),
                        ),
                    ],
                  ),
                ),
              ),
              for (final p in BodyPart.values) ...[
                // Väčší neviditeľný cieľ na bode, aby sa dal ľahko trafiť.
                Positioned(
                  left: point(p).dx - 20,
                  top: point(p).dy - 20,
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(p),
                  ),
                ),
                Positioned(
                  left: _left.contains(p) ? 0 : width - _chipWidth,
                  top: point(p).dy - _chipHeight / 2,
                  width: _chipWidth,
                  height: _chipHeight,
                  child: _PartChip(
                    part: p,
                    value: latest[p]?.cm,
                    onTap: () => onTap(p),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PartChip extends StatelessWidget {
  const _PartChip({
    required this.part,
    required this.value,
    required this.onTap,
  });

  final BodyPart part;
  final double? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final v = value;
    return Semantics(
      button: true,
      label: v == null
          ? '${part.label}, nezapísané'
          : '${part.label} ${formatCm(v)} centimetrov',
      excludeSemantics: true,
      child: Material(
        color: v == null ? AppColors.surface : AppColors.surfaceHi,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: v == null ? AppColors.border : AppColors.buttonBorder,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  part.label,
                  maxLines: 1,
                  style: text.bodySmall!.copyWith(fontSize: 11.5),
                ),
                Text(
                  v == null ? '+ zapísať' : '${formatCm(v)} cm',
                  maxLines: 1,
                  style: text.bodyLarge!.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: v == null ? AppColors.accent : AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

typedef _Line = ({Offset from, Offset to, bool measured});

class _FigurePainter extends CustomPainter {
  _FigurePainter({
    required this.scale,
    required this.left,
    required this.lines,
  });

  final double scale;
  final double left;
  final List<_Line> lines;

  Offset _p(double x, double y) => Offset(left + x * scale, 5 + y * scale);

  @override
  void paint(Canvas canvas, Size size) {
    final figureRect = Rect.fromPoints(_p(0, 0), _p(100, 240));
    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.surfaceHi, AppColors.well],
      ).createShader(figureRect);
    Paint limb(double width) => Paint()
      ..shader = fill.shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * scale
      ..strokeCap = StrokeCap.round;

    // Hlava a krk.
    canvas
      ..drawCircle(_p(50, 16), 12.5 * scale, fill)
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromPoints(_p(44, 24), _p(56, 42)),
          Radius.circular(4 * scale),
        ),
        fill,
      );

    // Trup: ramená, pás, boky.
    final torso = Path()..moveTo(_p(43, 38).dx, _p(43, 38).dy);
    void quad(double cx, double cy, double x, double y) {
      final c = _p(cx, cy);
      final e = _p(x, y);
      torso.quadraticBezierTo(c.dx, c.dy, e.dx, e.dy);
    }

    void line(double x, double y) {
      final e = _p(x, y);
      torso.lineTo(e.dx, e.dy);
    }

    line(57, 38);
    quad(76, 39, 78, 50);
    line(72, 66);
    quad(70, 80, 66, 92);
    quad(73, 104, 72, 118);
    line(62, 128);
    line(38, 128);
    line(28, 118);
    quad(27, 104, 34, 92);
    quad(30, 80, 28, 66);
    line(22, 50);
    quad(24, 39, 43, 38);
    torso.close();
    canvas.drawPath(torso, fill);

    // Ruky a nohy zrkadlovo.
    for (final m in [false, true]) {
      double x(double v) => m ? 100 - v : v;
      canvas
        ..drawLine(_p(x(25), 48), _p(x(18), 88), limb(10.5))
        ..drawLine(_p(x(18), 88), _p(x(14), 124), limb(8.5))
        ..drawCircle(_p(x(13), 130), 5.2 * scale, fill)
        ..drawLine(_p(x(39.5), 124), _p(x(38), 176), limb(17))
        ..drawLine(_p(x(38), 182), _p(x(38), 208), limb(13))
        ..drawLine(_p(x(38), 208), _p(x(39), 228), limb(9))
        ..drawOval(Rect.fromPoints(_p(x(33), 228), _p(x(44), 237)), fill);
    }

    // Vodiace čiary od štítkov k bodom.
    for (final l in lines) {
      canvas.drawLine(
        l.from,
        l.to,
        Paint()
          ..color = l.measured ? AppColors.heroLine : AppColors.border
          ..strokeWidth = 1.2,
      );
    }
    for (final l in lines) {
      canvas
        ..drawCircle(l.to, 6.5, Paint()..color = AppColors.bg)
        ..drawCircle(
          l.to,
          4.5,
          l.measured
              ? (Paint()..color = AppColors.accent)
              : (Paint()
                  ..color = AppColors.muted
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.6),
        );
    }
  }

  @override
  bool shouldRepaint(_FigurePainter old) =>
      old.scale != scale || old.left != left || old.lines != lines;
}
