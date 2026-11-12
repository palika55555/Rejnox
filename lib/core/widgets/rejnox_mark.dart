import 'package:flutter/material.dart';

/// Znak Rejnox: biele "R" s fialovým pruhom, kreslený vektorovo.
class RejnoxMark extends StatelessWidget {
  const RejnoxMark({super.key, this.width = 36});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Rejnox',
      image: true,
      child: SizedBox(
        width: width,
        height: width * _MarkPainter.designHeight / _MarkPainter.designWidth,
        child: const CustomPaint(painter: _MarkPainter()),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter();

  static const designWidth = 492.0;
  static const designHeight = 305.0;

  static const _violet = Color(0xFF9B5CFF);
  static const _indigo = Color(0xFF5B6CFF);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / designWidth, size.height / designHeight);

    final letter = Path()
      ..moveTo(68, 0)
      ..lineTo(385, 0)
      // Vonkajší oblúk bruška.
      ..arcToPoint(const Offset(385, 214), radius: const Radius.circular(107))
      ..lineTo(400, 215)
      // Noha.
      ..lineTo(478, 305)
      ..lineTo(365, 305)
      ..lineTo(235, 155)
      ..lineTo(385, 155)
      // Vnútorný oblúk bruška.
      ..arcToPoint(
        const Offset(385, 78),
        radius: const Radius.circular(38.5),
        clockwise: false,
      )
      ..lineTo(130, 78)
      ..close();
    canvas.drawPath(letter, Paint()..color = Colors.white);

    final stripe = Path()
      ..moveTo(150, 155)
      ..lineTo(235, 155)
      ..lineTo(135, 280)
      ..quadraticBezierTo(115, 305, 85, 305)
      ..lineTo(0, 305)
      ..lineTo(100, 180)
      ..quadraticBezierTo(120, 155, 150, 155)
      ..close();
    canvas.drawPath(
      stripe,
      Paint()
        ..shader = const LinearGradient(
          colors: [_violet, _indigo],
        ).createShader(const Rect.fromLTWH(0, 155, 235, 150)),
    );
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => false;
}
