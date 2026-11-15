import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Čistá antracitová karta. Priehľadné prekrytia môžu používať blur.
/// Nepriesvitné karty nepotrebujú rozmazávanie obsahu pod nimi.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.blur = 12,
    this.color = AppColors.surface,
    this.border = true,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double blur;
  final Color color;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        border: border ? Border.all(color: AppColors.border) : null,
      ),
      child: child,
    );
    return ClipRRect(
      borderRadius: borderRadius,
      child: color.a < 1 && blur > 0
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: panel,
            )
          : panel,
    );
  }
}
