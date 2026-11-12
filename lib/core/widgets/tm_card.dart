import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Základná karta appky: tmavý povrch, tenký okraj, voliteľná mriežka.
class TmCard extends StatelessWidget {
  const TmCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.grid = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool grid;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);
    Widget content = Padding(padding: padding, child: child);
    if (grid) {
      content = CustomPaint(painter: const _GridPainter(), child: content);
    }
    // Sklenená karta: jemný prechod zhora zľava a tenký fialový okraj.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: AppColors.border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceHi.withValues(alpha: 0.82),
            AppColors.surface.withValues(alpha: 0.72),
          ],
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.grid
      ..strokeWidth = 1;
    const step = 18.0;
    for (var x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}

/// Malý nadpis sekcie verzálkami s ikonou.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.icon, this.color});

  final String text;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color ?? AppColors.accent),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            text.toUpperCase(),
            style: style,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
