import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Pozadie celej appky: tmavá noc s fialovými žiarami v rohoch.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.bg),
      child: Stack(
        children: [
          const Positioned.fill(child: _Glows()),
          child,
        ],
      ),
    );
  }
}

class _Glows extends StatelessWidget {
  const _Glows();

  static Widget _glow(Alignment alignment, Color color, double radius) =>
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: alignment,
            radius: radius,
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _glow(
              const Alignment(0.9, -1.0),
              AppColors.violet.withValues(alpha: 0.28),
              0.9,
            ),
            _glow(
              const Alignment(-1.1, -0.2),
              AppColors.blue.withValues(alpha: 0.14),
              0.8,
            ),
            _glow(
              const Alignment(0.6, 1.1),
              AppColors.violet.withValues(alpha: 0.16),
              0.9,
            ),
          ],
        ),
      ),
    );
  }
}
