import 'package:flutter/material.dart';

/// Rozmer znaku v návrhových súradniciach (cesty nižšie).
const rejnoxMarkSize = Size(492, 305);

const rejnoxMarkViolet = Color(0xFF9B5CFF);
const rejnoxMarkIndigo = Color(0xFF5B6CFF);

/// Biele "R" znaku Rejnox (návrhové súradnice 492×305).
Path rejnoxLetterPath() => Path()
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

/// Fialový pruh znaku Rejnox (návrhové súradnice 492×305).
Path rejnoxStripePath() => Path()
  ..moveTo(150, 155)
  ..lineTo(235, 155)
  ..lineTo(135, 280)
  ..quadraticBezierTo(115, 305, 85, 305)
  ..lineTo(0, 305)
  ..lineTo(100, 180)
  ..quadraticBezierTo(120, 155, 150, 155)
  ..close();

Paint rejnoxStripePaint() => Paint()
  ..shader = const LinearGradient(
    colors: [rejnoxMarkViolet, rejnoxMarkIndigo],
  ).createShader(const Rect.fromLTWH(0, 155, 235, 150));

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
        height: width * rejnoxMarkSize.height / rejnoxMarkSize.width,
        child: const CustomPaint(painter: _MarkPainter()),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(
      size.width / rejnoxMarkSize.width,
      size.height / rejnoxMarkSize.height,
    );
    canvas.drawPath(rejnoxLetterPath(), Paint()..color = Colors.white);
    canvas.drawPath(rejnoxStripePath(), rejnoxStripePaint());
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => false;
}
