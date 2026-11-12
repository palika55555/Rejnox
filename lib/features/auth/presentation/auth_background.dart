import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

const _image = 'assets/images/auth_background.webp';

/// Pozadie úvodu, prihlásenia a registrácie: fotka s logom Rejnox.
///
/// [lift] posunie fotku nahor (časť výšky obrazovky), aby logo z fotky
/// ostalo viditeľné nad formulárom. Spodok prechádza do tmavej farby,
/// na ktorej je formulár dobre čitateľný.
class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key, required this.child, this.lift = 0});

  final Widget child;
  final double lift;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            child: FractionalTranslation(
              translation: Offset(0, -lift),
              child: Image.asset(
                _image,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                // Pri chybe načítania ostane len tmavé pozadie.
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.5 - lift, 0.78 - lift / 2, 1],
                colors: [
                  AppColors.bg.withValues(alpha: 0),
                  AppColors.bg.withValues(alpha: 0.8),
                  AppColors.bg,
                ],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
