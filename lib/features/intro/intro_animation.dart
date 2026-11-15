import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/rejnox_mark.dart';

/// Pri spustení appky ukáže úvodnú animáciu nad obsahom.
/// Pri vypnutých animáciách v systéme sa úvod vynechá.
class IntroGate extends StatefulWidget {
  const IntroGate({super.key, required this.child, this.skip = false});

  final Widget child;

  /// Úvodná obrazovka pre odhlásených má vlastné odhalenie znaku,
  /// preto sa úvod vtedy zruší.
  final bool skip;

  @override
  State<IntroGate> createState() => _IntroGateState();
}

class _IntroGateState extends State<IntroGate> {
  bool? _show;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _show ??= !widget.skip && !MediaQuery.of(context).disableAnimations;
  }

  @override
  void didUpdateWidget(IntroGate old) {
    super.didUpdateWidget(old);
    if (widget.skip) _show = false;
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
                        Transform.scale(
                          scale:
                              0.94 + 0.06 * _seg(0, 1.0, Curves.easeOutCubic),
                          child: CustomPaint(
                            size: const Size(136, 136),
                            painter: RejnoxMarkPainter(
                              outlineProgress: _seg(0, 0.75, Curves.easeInOut),
                              fillProgress: _seg(0.65, 1.05, Curves.easeOut),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Opacity(
                          opacity: word,
                          child: Text(
                            'REJNOX',
                            style: text.headlineMedium!.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 7,
                              fontSize: 34,
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

/// Vycentruje obsah a na veľmi malom okne ho zmenší, aby nič nepretieklo.
class ScaleDownCenter extends StatelessWidget {
  const ScaleDownCenter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: FittedBox(fit: BoxFit.scaleDown, child: child),
  );
}
