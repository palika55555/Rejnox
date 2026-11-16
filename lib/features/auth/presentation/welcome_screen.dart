import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/rejnox_mark.dart';
import 'auth_background.dart';
import '../../../core/theme/app_spacing.dart';

/// Úvod pre odhlásených: fotka v koralovom svetle a znak, ktorý sa nakreslí,
/// rozžiari a prebehne ním lesk. Animácia prebehne raz (~2,6 s); pri
/// vypnutých animáciách v systéme sa ukáže hneď konečný stav.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  static const reveal = Duration(milliseconds: 2600);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: WelcomeScreen.reveal,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else if (_c.isDismissed) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Úsek animácie v sekundách → 0..1.
  double _seg(double from, double to, [Curve curve = Curves.linear]) {
    final seconds = WelcomeScreen.reveal.inMilliseconds / 1000;
    final t = ((_c.value * seconds - from) / (to - from)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.bg,
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: _seg(0, 0.9, Curves.easeOut),
            child: Transform.scale(
              scale: 1.08 - 0.08 * _seg(0, 2.6, Curves.easeOutCubic),
              child: const AuthHeroPhoto(),
            ),
          ),
          const _Scrim(),
          Scaffold(
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, viewport) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxl,
                    AppSpacing.md,
                    AppSpacing.xxl,
                    AppSpacing.xxl,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 420,
                        minHeight: (viewport.maxHeight - 36).clamp(
                          0,
                          double.infinity,
                        ),
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Spacer(flex: 5),
                            _Brand(seg: _seg),
                            const Spacer(flex: 4),
                            const SizedBox(height: AppSpacing.xxl),
                            _Actions(progress: _seg(2.0, 2.6, Curves.easeOut)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Stmavenie hore pre stavový riadok, v strede za znakom a dole pod tlačidlami.
class _Scrim extends StatelessWidget {
  const _Scrim();

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.bg.withValues(alpha: 0.45),
              AppColors.bg.withValues(alpha: 0),
              AppColors.bg.withValues(alpha: 0),
              AppColors.bg.withValues(alpha: 0.92),
            ],
            stops: const [0, 0.22, 0.6, 1],
          ),
        ),
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, 0.05),
            radius: 0.7,
            colors: [
              AppColors.bg.withValues(alpha: 0.5),
              AppColors.bg.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    ],
  );
}

typedef _Seg = double Function(double from, double to, [Curve curve]);

/// Znak, názov, svietiaca čiarka a slogan.
class _Brand extends StatelessWidget {
  const _Brand({required this.seg});

  final _Seg seg;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final glow =
        seg(0.2, 1.3, Curves.easeOut) - 0.45 * seg(1.4, 2.5, Curves.easeInOut);
    final word = seg(1.25, 1.8, Curves.easeOutCubic);
    final line = seg(1.6, 2.0, Curves.easeOutCubic);
    final tagline = seg(1.75, 2.25, Curves.easeOut);
    return Semantics(
      label: 'Rejnox. Lepší pohyb, zdravší ty.',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 240,
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _Glow(strength: glow),
                Transform.scale(
                  scale: 0.86 + 0.14 * seg(0.25, 1.45, Curves.easeOutCubic),
                  child: _ShinyMark(
                    outline: seg(0.25, 1.15, Curves.easeInOut),
                    fill: seg(1.0, 1.45, Curves.easeOut),
                    shine: seg(1.45, 2.25, Curves.easeInOutCubic),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Opacity(
            opacity: word,
            child: Text(
              'REJNOX',
              style: text.displaySmall!.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 22 - 12 * word,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Container(
            width: 56 * line,
            height: 2,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xs),
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0),
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.7 * line),
                  blurRadius: 12,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Opacity(
            opacity: tagline,
            child: Transform.translate(
              offset: Offset(0, 8 * (1 - tagline)),
              child: Text(
                'LEPŠÍ POHYB\nZDRAVŠÍ TY',
                textAlign: TextAlign.center,
                style: text.bodyMedium!.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 5,
                  height: 1.9,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Koralová žiara za znakom.
class _Glow extends StatelessWidget {
  const _Glow({required this.strength});

  final double strength;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.32 * strength),
            AppColors.primary.withValues(alpha: 0),
          ],
        ),
      ),
    ),
  );
}

/// Znak kreslený obrysom a výplňou; [shine] ním prevedie svetlý pás.
class _ShinyMark extends StatelessWidget {
  const _ShinyMark({
    required this.outline,
    required this.fill,
    required this.shine,
  });

  final double outline;
  final double fill;
  final double shine;

  static const _width = 150.0;

  @override
  Widget build(BuildContext context) {
    final mark = CustomPaint(
      size: Size(_width, _width * rejnoxMarkSize.height / rejnoxMarkSize.width),
      painter: RejnoxMarkPainter(outlineProgress: outline, fillProgress: fill),
    );
    if (shine <= 0 || shine >= 1) return mark;
    // Pás prejde zľava doprava; mimo neho ostáva znak nezmenený.
    final center = -0.3 + 1.6 * shine;
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.85),
          Colors.white.withValues(alpha: 0),
        ],
        stops: [
          (center - 0.15).clamp(0.0, 1.0),
          center.clamp(0.0, 1.0),
          (center + 0.15).clamp(0.0, 1.0),
        ],
      ).createShader(bounds),
      child: mark,
    );
  }
}

/// Tlačidlá sa vysunú až po dokreslení značky.
class _Actions extends StatelessWidget {
  const _Actions({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: progress,
    child: Transform.translate(
      offset: Offset(0, 24 * (1 - progress)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryButton(
            label: 'Začať',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => context.go('/register'),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.bg.withValues(alpha: 0.55),
              foregroundColor: AppColors.text,
              side: BorderSide(
                color: AppColors.text.withValues(alpha: 0.28),
                width: 1.5,
              ),
            ),
            onPressed: () => context.go('/login'),
            child: const Text('Prihlásiť sa'),
          ),
        ],
      ),
    ),
  );
}
