import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/rejnox_mark.dart';

/// Pri spustení appky ukáže úvodnú animáciu nad obsahom.
/// Pri vypnutých animáciách v systéme sa úvod vynechá.
class IntroGate extends StatefulWidget {
  const IntroGate({super.key, required this.child});

  final Widget child;

  @override
  State<IntroGate> createState() => _IntroGateState();
}

class _IntroGateState extends State<IntroGate> {
  bool? _show;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _show ??= !MediaQuery.of(context).disableAnimations;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_show == true)
          Positioned.fill(
            child: IntroAnimation(onDone: () => setState(() => _show = false)),
          ),
      ],
    );
  }
}

/// Úvod REJNOX (~1,9 s + odchod). Ťuknutie ho preskočí.
class IntroAnimation extends StatefulWidget {
  const IntroAnimation({super.key, required this.onDone});

  final VoidCallback onDone;

  static const total = Duration(milliseconds: 2300);

  @override
  State<IntroAnimation> createState() => _IntroAnimationState();
}

class _IntroAnimationState extends State<IntroAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: IntroAnimation.total,
  )..forward().whenComplete(_finish);

  bool _finished = false;

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Úsek animácie v sekundách → 0..1.
  double _seg(double from, double to, [Curve curve = Curves.linear]) {
    const total = 2.3;
    final t = ((_c.value * total - from) / (to - from)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _finish,
      child: Semantics(
        label: 'Rejnox. Lepší pohyb, zdravší ty.',
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final exit = _seg(1.9, 2.3, Curves.easeInCubic);
            final word = _seg(1.0, 1.5, Curves.easeOutCubic);
            final tagline = _seg(1.3, 1.6, Curves.easeOut);
            final glow = sin(pi * _seg(0.85, 1.4));
            return Opacity(
              opacity: 1 - exit,
              child: ColoredBox(
                color: AppColors.bg,
                child: Transform.translate(
                  offset: Offset(0, -48 * exit),
                  child: ScaleDownCenter(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 220,
                          height: 170,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Fialová žiara za znakom.
                              Opacity(
                                opacity: glow,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                      colors: [
                                        AppColors.violet.withValues(alpha: 0.6),
                                        AppColors.violet.withValues(alpha: 0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              CustomPaint(
                                size: const Size(150, 93),
                                painter: _IntroMarkPainter(
                                  draw: _seg(0, 0.8, Curves.easeInOut),
                                  fill: _seg(0.7, 1.0),
                                  stripe: _seg(0.75, 1.05, Curves.easeOutBack),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Opacity(
                          opacity: word,
                          child: Text(
                            'REJNOX',
                            style: text.headlineMedium!.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: lerpDouble(28, 10, word),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Opacity(
                          opacity: tagline,
                          child: Transform.translate(
                            offset: Offset(0, 6 * (1 - tagline)),
                            child: Text(
                              'Lepší pohyb, zdravší ty.',
                              style: text.bodyMedium!.copyWith(
                                color: AppColors.muted,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _IntroMarkPainter extends CustomPainter {
  _IntroMarkPainter({
    required this.draw,
    required this.fill,
    required this.stripe,
  });

  /// 0..1 nakreslenie obrysu "R".
  final double draw;

  /// 0..1 vyplnenie "R".
  final double fill;

  /// 0..~1.1 príchod pruhu (s prekmitom).
  final double stripe;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(
      size.width / rejnoxMarkSize.width,
      size.height / rejnoxMarkSize.height,
    );
    final letter = rejnoxLetterPath();

    // Obrys sa kreslí ťahom.
    if (draw > 0) {
      final outline = Path();
      for (final metric in letter.computeMetrics()) {
        outline.addPath(
          metric.extractPath(0, metric.length * draw),
          Offset.zero,
        );
      }
      canvas.drawPath(
        outline,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }
    if (fill > 0) {
      canvas.drawPath(
        letter,
        Paint()..color = Colors.white.withValues(alpha: fill),
      );
    }

    // Pruh prešvihne zľava zdola na svoje miesto.
    if (stripe > 0) {
      canvas.save();
      canvas.translate(-160 * (1 - stripe), 120 * (1 - stripe));
      canvas.saveLayer(
        null,
        Paint()
          ..color = Colors.white.withValues(alpha: (stripe * 2).clamp(0, 1)),
      );
      canvas.drawPath(rejnoxStripePath(), rejnoxStripePaint());
      canvas.restore();
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_IntroMarkPainter old) =>
      old.draw != draw || old.fill != fill || old.stripe != stripe;
}

/// Vycentruje obsah a na veľmi malom okne ho zmenší, aby nič nepretieklo.
class ScaleDownCenter extends StatelessWidget {
  const ScaleDownCenter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: FittedBox(fit: BoxFit.scaleDown, child: child),
  );
}
