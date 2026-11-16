import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Sklenený štýl komunity: farebné žiary v pozadí, matné sklo s rozmazaním,
/// jemný svetlý okraj a pohyb pri objavení a ťuknutí.

/// Rozmazané farebné žiary za obsahom, aby sklo malo čo lámať.
class GlowBackdrop extends StatelessWidget {
  const GlowBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(child: CustomPaint(painter: _GlowPainter())),
          ),
        ),
        child,
      ],
    );
  }
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter();

  static const _blobs = [
    (Alignment(-1.1, -0.85), 0.55, AppColors.accent, 0.30),
    (Alignment(1.15, -0.2), 0.45, Color(0xFF4D8BFF), 0.20),
    (Alignment(-0.6, 0.95), 0.5, Color(0xFF2BD98B), 0.13),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final (align, radius, color, alpha) in _blobs) {
      final center = align.alongSize(size);
      final r = size.shortestSide * radius;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: r));
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) => false;
}

/// Matná sklenená karta. [highlight] ju jemne podfarbí značkou.
class FrostCard extends StatelessWidget {
  const FrostCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.onLongPress,
    this.highlight = false,
    this.radius = 22,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool highlight;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    final tint = highlight ? AppColors.accent : Colors.white;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: shape,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tint.withValues(alpha: highlight ? 0.16 : 0.09),
                  AppColors.surface.withValues(alpha: 0.55),
                ],
              ),
              border: Border.all(
                color: tint.withValues(alpha: highlight ? 0.35 : 0.12),
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                splashColor: AppColors.accent.withValues(alpha: 0.12),
                child: Padding(padding: padding, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Postupné objavenie: zospodu a z priehľadnosti, podľa poradia [index].
class Appear extends StatelessWidget {
  const Appear({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delay = (index.clamp(0, 8) * 60).toDouble();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + delay.round()),
      curve: Interval(delay / (380 + delay), 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - t)),
          child: child,
        ),
      ),
    );
  }
}

/// Okrúhly avatar s iniciálami na farebnom prechode podľa mena.
class GlassAvatar extends StatelessWidget {
  const GlassAvatar(this.name, {super.key, this.size = 42});

  final String name;
  final double size;

  static const _palette = [
    AppColors.accent,
    Color(0xFF4D8BFF),
    Color(0xFF2BD98B),
    Color(0xFFFFC542),
    Color(0xFFB57BFF),
  ];

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p.characters.first.toUpperCase());
    return letters.isEmpty ? '?' : letters.join();
  }

  @override
  Widget build(BuildContext context) {
    final color = _palette[name.hashCode.abs() % _palette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.45)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          color: AppColors.onAccent,
        ),
      ),
    );
  }
}

/// Prepínacie tlačidlo akcie (lajk, pridať sa…), pri zapnutí poskočí.
class GlassToggle extends StatelessWidget {
  const GlassToggle({
    super.key,
    required this.on,
    required this.icon,
    required this.onIcon,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final bool on;
  final IconData icon;
  final IconData onIcon;
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final color = on ? AppColors.accent : AppColors.ink2;
    return Semantics(
      button: true,
      toggled: on,
      child: Material(
        color: on
            ? AppColors.accent.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.06),
        shape: StadiumBorder(
          side: BorderSide(color: color.withValues(alpha: on ? 0.5 : 0.18)),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: busy ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  transitionBuilder: (child, a) => ScaleTransition(
                    scale: CurvedAnimation(parent: a, curve: Curves.elasticOut),
                    child: child,
                  ),
                  child: Icon(
                    on ? onIcon : icon,
                    key: ValueKey(on),
                    size: 18,
                    color: color,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: on ? AppColors.text : AppColors.ink2,
                    fontWeight: FontWeight.w600,
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

/// Malý štítok s ikonou (čas, miesto, počet ľudí).
class InfoTag extends StatelessWidget {
  const InfoTag(this.icon, this.text, {super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.muted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall!.copyWith(color: AppColors.ink2),
          ),
        ),
      ],
    );
  }
}

/// Prázdny stav sekcie s výzvou na akciu.
class GlassEmpty extends StatelessWidget {
  const GlassEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
    this.action,
  });

  final IconData icon;
  final String title;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return FrostCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: 0.14),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.35),
              ),
            ),
            child: Icon(icon, color: AppColors.accent, size: 28),
          ),
          const SizedBox(height: 14),
          Text(title, style: theme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            text,
            style: theme.bodyMedium!.copyWith(color: AppColors.ink2),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
