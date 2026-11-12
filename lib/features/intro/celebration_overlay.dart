import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../auth/presentation/celebration_state.dart';
import 'intro_animation.dart';

/// Ukáže oslavu cez celú obrazovku hneď po prihlásení / registrácii.
class CelebrationGate extends ConsumerWidget {
  const CelebrationGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final celebration = ref.watch(celebrationProvider);
    return Stack(
      children: [
        child,
        if (celebration != null)
          Positioned.fill(
            child: CelebrationOverlay(
              key: ObjectKey(celebration),
              celebration: celebration,
              onDone: () => ref.read(celebrationProvider.notifier).done(),
            ),
          ),
      ],
    );
  }
}

/// Na tyč dopadnú kotúče, otras, činka vyletí so zábleskom a pozdrav.
/// Ťuknutie preskočí; pri vypnutých animáciách len krátke zobrazenie.
class CelebrationOverlay extends StatefulWidget {
  const CelebrationOverlay({
    super.key,
    required this.celebration,
    required this.onDone,
  });

  final Celebration celebration;
  final VoidCallback onDone;

  static const full = Duration(milliseconds: 2800);
  static const reduced = Duration(milliseconds: 700);

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  static const _landAt = 1.04;

  late final bool _reduced = MediaQuery.of(context).disableAnimations;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _reduced ? CelebrationOverlay.reduced : CelebrationOverlay.full,
  );
  bool _hapticDone = false;
  bool _finished = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_c.isAnimating && _c.value == 0) {
      _c
        ..addListener(_haptic)
        ..forward().whenComplete(_finish);
    }
  }

  void _haptic() {
    if (!_hapticDone && !_reduced && _c.value * 2.8 >= _landAt) {
      _hapticDone = true;
      HapticFeedback.heavyImpact();
    }
  }

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

  double _seg(double from, double to, [Curve curve = Curves.linear]) {
    const total = 2.8;
    final t = ((_c.value * total - from) / (to - from)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _finish,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          if (_reduced) {
            final v = _c.value;
            final opacity = v < 0.3 ? v / 0.3 : (v > 0.7 ? (1 - v) / 0.3 : 1.0);
            return Opacity(
              opacity: opacity,
              child: ColoredBox(
                color: AppColors.bg,
                child: Center(child: _Heading(widget.celebration, text)),
              ),
            );
          }

          final enter = _seg(0, 0.15);
          final leave = _seg(2.4, 2.8, Curves.easeIn);
          final shakeT = _seg(_landAt, 1.3);
          final shake = shakeT == 0 || shakeT == 1
              ? 0.0
              : sin(shakeT * pi * 10) * 8 * (1 - shakeT);
          final lift = _seg(1.3, 1.6, Curves.easeOutCubic);
          final flash = sin(pi * _seg(1.3, 1.75));
          final heading = _seg(1.45, 1.9, Curves.easeOutCubic);
          final subtitle = _seg(1.8, 2.1, Curves.easeOut);

          return Opacity(
            opacity: enter * (1 - leave),
            child: ColoredBox(
              color: AppColors.bg.withValues(alpha: 0.97),
              child: Transform.translate(
                offset: Offset(shake, 0),
                child: ScaleDownCenter(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 320,
                        height: 200,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Opacity(
                              opacity: flash,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    colors: [
                                      AppColors.violet.withValues(alpha: 0.7),
                                      AppColors.violet.withValues(alpha: 0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Transform.translate(
                              offset: Offset(0, -26 * lift),
                              child: CustomPaint(
                                size: const Size(320, 200),
                                painter: _BarbellPainter(
                                  bar: _seg(0.05, 0.25, Curves.easeOut),
                                  plates: [
                                    for (var i = 0; i < 4; i++)
                                      _seg(
                                        0.2 + i * 0.18,
                                        0.5 + i * 0.18,
                                        Curves.easeOutBack,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Opacity(
                        opacity: heading,
                        child: Transform.scale(
                          scale: lerpDouble(1.4, 1, heading),
                          child: ImageFiltered(
                            imageFilter: ImageFilter.blur(
                              sigmaX: 10 * (1 - heading),
                              sigmaY: 10 * (1 - heading),
                            ),
                            child: _Heading(widget.celebration, text),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Opacity(
                        opacity: subtitle,
                        child: Text(
                          'Ideme na to.',
                          style: text.bodyLarge!.copyWith(
                            color: AppColors.muted,
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
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.celebration, this.text);

  final Celebration celebration;
  final TextTheme text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Text(
      celebration.title,
      textAlign: TextAlign.center,
      style: text.headlineLarge,
    ),
  );
}

/// Tyč s objímkami a kotúčmi (od najväčšieho po najmenší).
class _BarbellPainter extends CustomPainter {
  _BarbellPainter({required this.bar, required this.plates});

  /// 0..1 objavenie tyče.
  final double bar;

  /// 0..~1.1 dopad každého kotúča (s prekmitom).
  final List<double> plates;

  static final _colors = [
    Plate.red.color,
    Plate.blue.color,
    Plate.yellow.color,
    Plate.green.color,
  ];
  static const _heights = [118.0, 100.0, 82.0, 64.0];
  static const _width = 15.0, _gap = 4.0, _collar = 92.0;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final half = size.width / 2 * bar;
    if (bar <= 0) return;

    // Tyč.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: half * 2, height: 8),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFB9BCCB),
    );
    // Objímky.
    for (final side in [-1, 1]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: c + Offset(side * _collar * bar, 0),
            width: 10,
            height: 26,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xFFE6E7EE),
      );
    }

    // Kotúče padajú zhora na obe strany.
    for (var i = 0; i < plates.length; i++) {
      final t = plates[i];
      if (t <= 0) continue;
      final h = _heights[i];
      final dx = _collar + 10 + i * (_width + _gap);
      final fallY = -size.height * (1 - t);
      for (final side in [-1, 1]) {
        final rect = Rect.fromCenter(
          center: c + Offset(side * dx, fallY),
          width: _width,
          height: h,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          Paint()..color = _colors[i],
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.deflate(3), const Radius.circular(3)),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.12)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BarbellPainter old) => true;
}
