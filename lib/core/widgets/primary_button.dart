import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Koralové hlavné akcie a pokojné antracitové vedľajšie tlačidlá.
enum ButtonTone { accent, ink, ghost, ghostOnHero, onHero }

/// Hlavné akčné tlačidlo.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.compact = false,
    this.tone = ButtonTone.accent,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Malá verzia do riadkov zoznamu.
  final bool compact;
  final ButtonTone tone;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(compact ? 12 : 14);
    final text = Theme.of(context).textTheme;
    final (bg, fg, line) = switch (tone) {
      ButtonTone.accent => (AppColors.primary, AppColors.onAccent, null),
      ButtonTone.onHero => (AppColors.primary, AppColors.onAccent, null),
      ButtonTone.ink => (
        AppColors.buttonSurface,
        AppColors.text,
        AppColors.buttonBorder,
      ),
      ButtonTone.ghost => (
        AppColors.buttonSurface,
        AppColors.accent,
        AppColors.buttonBorder,
      ),
      ButtonTone.ghostOnHero => (
        AppColors.accentSoft,
        AppColors.onHero,
        AppColors.heroLine,
      ),
    };
    // Nedostupné tlačidlo je stlmené, aby nepôsobilo klikateľne.
    return Opacity(
      opacity: onPressed == null ? 0.4 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          color: bg,
          border: line == null ? null : Border.all(color: line, width: 1.5),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: compact ? 40 : 50),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? AppSpacing.lg : AppSpacing.xl,
                ),
                child: Row(
                  mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: fg, size: compact ? 16 : 20),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelLarge!.copyWith(
                          color: fg,
                          fontSize: compact ? 14 : 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
