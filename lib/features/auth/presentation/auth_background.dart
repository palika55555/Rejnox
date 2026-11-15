import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Koralová fotka športovkyne bez loga; znak kreslíme vektorovo nad ňou.
const authHeroAsset = 'assets/images/auth_hero.webp';

/// Fotka na celú plochu; bez súboru ostane antracitové pozadie.
class AuthHeroPhoto extends StatelessWidget {
  const AuthHeroPhoto({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image.asset(
      authHeroAsset,
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.3),
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.bg),
    ),
  );
}

/// Prihlásenie a registrácia: rovnaká fotka ako úvod, výrazne stlmená,
/// aby formulár ostal čitateľný.
class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.bg,
    child: Stack(
      fit: StackFit.expand,
      children: [
        const AuthHeroPhoto(),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.bg.withValues(alpha: 0.55),
                AppColors.bg.withValues(alpha: 0.78),
                AppColors.bg.withValues(alpha: 0.94),
              ],
              stops: const [0, 0.45, 1],
            ),
          ),
        ),
        child,
      ],
    ),
  );
}
