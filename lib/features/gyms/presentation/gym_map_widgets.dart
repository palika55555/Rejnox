import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/tm_card.dart';
import '../application/user_location.dart';
import '../domain/gym.dart';

enum MapMode {
  globe('Svet', Icons.public_rounded),
  map('Mapa', Icons.map_outlined),
  list('Zoznam', Icons.format_list_bulleted_rounded);

  const MapMode(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Prepínač Svet / Mapa / Zoznam.
class MapModeSwitch extends StatelessWidget {
  const MapModeSwitch({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final MapMode selected;
  final ValueChanged<MapMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final mode in MapMode.values)
            Expanded(
              child: Semantics(
                button: true,
                selected: mode == selected,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(mode),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: mode == selected
                          ? AppColors.actionGradient
                          : null,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: mode == selected
                          ? [
                              BoxShadow(
                                color: AppColors.blue.withValues(alpha: 0.45),
                                blurRadius: 16,
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          mode.icon,
                          size: 17,
                          color: mode == selected
                              ? Colors.white
                              : AppColors.muted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          mode.label,
                          style: text.bodyMedium!.copyWith(
                            fontWeight: FontWeight.w700,
                            color: mode == selected
                                ? Colors.white
                                : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Vyhľadávanie fitka podľa názvu, mesta alebo adresy.
class GymSearchField extends StatelessWidget {
  const GymSearchField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: color),
    );
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Hľadaj fitko, mesto alebo adresu',
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Vymazať',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: controller.clear,
                ),
          filled: true,
          fillColor: AppColors.surface.withValues(alpha: 0.75),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          enabledBorder: border(AppColors.border),
          focusedBorder: border(AppColors.accent),
        ),
      ),
    );
  }
}

/// Štvorček s činkou namiesto fotky fitka.
class GymThumb extends StatelessWidget {
  const GymThumb({super.key, this.size = 56, this.highlighted = false});

  final double size;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * 0.28),
      gradient: highlighted
          ? AppColors.actionGradient
          : const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF241E5C), Color(0xFF0D0B2A)],
            ),
      border: Border.all(color: AppColors.border),
    ),
    child: Icon(
      Icons.fitness_center_rounded,
      size: size * 0.45,
      color: highlighted ? Colors.white : AppColors.accent,
    ),
  );
}

/// Riadok so vzdialenosťou: ikonka šípky a „1,2 km“.
class DistanceLabel extends StatelessWidget {
  const DistanceLabel(this.distance, {super.key});

  final String distance;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.near_me_rounded, size: 13, color: AppColors.accent),
      const SizedBox(width: 4),
      Text(distance, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

/// Karta vybraného (alebo najbližšieho) fitka nad mapou.
class GymCard extends StatelessWidget {
  const GymCard({
    super.key,
    required this.gym,
    required this.distance,
    this.caption,
    this.onTap,
  });

  final Gym gym;
  final String? distance;

  /// Napr. „Najbližšie fitko“.
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final distance = this.distance;
    return TmCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const GymThumb(size: 64, highlighted: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (caption case final caption?)
                  Text(caption.toUpperCase(), style: text.labelSmall),
                Text(
                  gym.name,
                  style: text.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  gym.fullAddress,
                  style: text.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (gym.rating case final rating?
                        when rating.count > 0) ...[
                      const Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: Color(0xFFFFC542),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${rating.averageLabel} (${rating.count})',
                        style: text.bodySmall,
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (distance != null) DistanceLabel(distance),
                  ],
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}

/// Riadok fitka v zozname.
class GymListTile extends StatelessWidget {
  const GymListTile({
    super.key,
    required this.gym,
    required this.distance,
    required this.onTap,
  });

  final Gym gym;
  final String? distance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final distance = this.distance;
    return TmCard(
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          const GymThumb(size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gym.name,
                  style: text.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(gym.city, style: text.bodySmall),
              ],
            ),
          ),
          if (distance != null) DistanceLabel(distance),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}

/// Karta mesta pod zemeguľou („Tokio · 276 fitiek“).
class CityCard extends StatelessWidget {
  const CityCard({
    super.key,
    required this.city,
    required this.count,
    required this.onTap,
  });

  final String city;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: 120,
      child: TmCard(
        grid: true,
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Icon(
              Icons.location_city_rounded,
              size: 18,
              color: AppColors.accent,
            ),
            const Spacer(),
            Text(
              city,
              style: text.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(gymCountLabel(count), style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// „1 fitko“, „3 fitká“, „12 fitiek“.
String gymCountLabel(int count) => switch (count) {
  1 => '1 fitko',
  >= 2 && <= 4 => '$count fitká',
  _ => '$count fitiek',
};

/// Fitká sa nepodarilo načítať zo servera.
class GymsErrorBanner extends StatelessWidget {
  const GymsErrorBanner({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => TmCard(
    padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
    child: Row(
      children: [
        const Icon(Icons.cloud_off_rounded, size: 20, color: AppColors.flame),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Fitká sa nepodarilo načítať. Skontroluj pripojenie.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Skúsiť znova')),
      ],
    ),
  );
}

/// Upozornenie, keď nepoznáme polohu, s akciou na nápravu.
class LocationBanner extends StatelessWidget {
  const LocationBanner({
    super.key,
    required this.issue,
    required this.onAction,
  });

  final LocationIssue issue;
  final VoidCallback onAction;

  (String, String) get _copy => switch (issue) {
    LocationIssue.serviceOff => (
      'Poloha je vypnutá. Zapni ju a ukážeme fitká v okolí.',
      'Zapnúť',
    ),
    LocationIssue.denied => (
      'Bez povolenia polohy nevieme, ktoré fitká sú blízko.',
      'Povoliť',
    ),
    LocationIssue.deniedForever => (
      'Poloha je pre Rejnox zakázaná. Povoľ ju v nastaveniach.',
      'Nastavenia',
    ),
    LocationIssue.failed => ('Polohu sa nepodarilo zistiť.', 'Skúsiť znova'),
  };

  @override
  Widget build(BuildContext context) {
    final (message, action) = _copy;
    return TmCard(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Row(
        children: [
          const Icon(
            Icons.location_off_outlined,
            size: 20,
            color: AppColors.flame,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
          TextButton(onPressed: onAction, child: Text(action)),
        ],
      ),
    );
  }
}

/// Okrúhle tlačidlo nad mapou.
class MapRoundButton extends StatelessWidget {
  const MapRoundButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.busy = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface.withValues(alpha: 0.92),
    shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
    child: IconButton(
      tooltip: tooltip,
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, color: AppColors.text),
    ),
  );
}
