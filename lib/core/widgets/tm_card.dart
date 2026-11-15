import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'glass.dart';

/// Základná karta appky: sklenená plocha s vlasovou linkou.
class TmCard extends StatelessWidget {
  const TmCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color = AppColors.surface,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    final content = Padding(padding: padding, child: child);
    return Glass(
      color: color,
      borderRadius: radius,
      child: Material(
        type: MaterialType.transparency,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

/// Malý nadpis sekcie verzálkami s riedkym prestrkaním (eyebrow).
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
          Icon(icon, size: 14, color: color ?? AppColors.muted),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            text.toUpperCase(),
            style: style.copyWith(color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Sekcia obrazovky: eyebrow nadpis, voliteľný odkaz vpravo a obsah.
class AppSection extends StatelessWidget {
  const AppSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: SectionLabel(title)),
            ?trailing,
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

/// Zoznam riadkov v jednej karte, oddelených vlasovou linkou.
class AppList extends StatelessWidget {
  const AppList({
    super.key,
    required this.children,
    this.color = AppColors.surface,
  });

  final List<Widget> children;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Glass(
      color: color,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Riadok zoznamu: ikona/avatar, titulok s podtitulkom a koncovka.
class AppRow extends StatelessWidget {
  const AppRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final sub = subtitle;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: text.bodyLarge),
                    if (sub != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        style: text.bodyMedium!.copyWith(
                          color: AppColors.ink2,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Malý štítok stavu (potvrdené, čaká, rekord…).
enum PillTone { neutral, good, warn, info, accent }

class AppPill extends StatelessWidget {
  const AppPill(
    this.label, {
    super.key,
    this.tone = PillTone.neutral,
    this.icon,
  });

  final String label;
  final PillTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      PillTone.neutral => (AppColors.well, AppColors.ink2),
      PillTone.good => (AppColors.goodSoft, AppColors.good),
      PillTone.warn => (AppColors.warnSoft, AppColors.warn),
      PillTone.info => (AppColors.infoSoft, AppColors.info),
      PillTone.accent => (AppColors.accentSoft, AppColors.accent),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
