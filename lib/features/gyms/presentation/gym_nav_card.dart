import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/tm_card.dart';
import '../domain/gym.dart';
import '../domain/gym_route.dart';
import 'gym_map_widgets.dart';

/// Stav trasy ku fitku na karte.
sealed class RouteView {
  const RouteView();
}

final class RouteIdle extends RouteView {
  const RouteIdle();
}

final class RouteLoading extends RouteView {
  const RouteLoading();
}

final class RouteShown extends RouteView {
  const RouteShown(this.route);
  final GymRoute route;
}

final class RouteFailed extends RouteView {
  const RouteFailed(this.message);
  final String message;
}

/// Plávajúca karta fitka nad mapou: názov, adresa a koralové tlačidlo
/// navigácie. Po vyhľadaní trasy ukáže Auto/Pešo, vzdialenosť a čas.
class GymNavCard extends StatelessWidget {
  const GymNavCard({
    super.key,
    required this.gym,
    required this.distance,
    required this.route,
    required this.mode,
    required this.onModeChanged,
    required this.onRoute,
    required this.onStartNavigation,
    required this.onClearRoute,
    required this.onOpenDetail,
    this.caption,
  });

  final Gym gym;
  final String? distance;
  final RouteView route;
  final TravelMode mode;
  final ValueChanged<TravelMode> onModeChanged;

  /// Vyhľadá trasu z polohy používateľa.
  final VoidCallback onRoute;

  /// Otvorí navigáciu v Mapách Google / Apple.
  final VoidCallback onStartNavigation;
  final VoidCallback onClearRoute;
  final VoidCallback onOpenDetail;

  /// Napr. „Najbližšie fitko“.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hasRoute = route is RouteShown;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      elevation: 6,
      shadowColor: AppColors.shadow,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onOpenDetail,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: _Heading(
                      gym: gym,
                      caption: caption,
                      distance: hasRoute ? null : distance,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                _NavButton(
                  busy: route is RouteLoading,
                  started: hasRoute,
                  onPressed: hasRoute ? onStartNavigation : onRoute,
                ),
              ],
            ),
            ...switch (route) {
              RouteIdle() || RouteLoading() => const [],
              RouteShown(:final route) => [
                const SizedBox(height: AppSpacing.md),
                _RouteSummary(
                  route: route,
                  mode: mode,
                  onModeChanged: onModeChanged,
                  onClear: onClearRoute,
                ),
              ],
              RouteFailed(:final message) => [
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message,
                  style: text.bodySmall?.copyWith(color: AppColors.error),
                ),
              ],
            },
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.gym, this.caption, this.distance});

  final Gym gym;
  final String? caption;
  final String? distance;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (caption case final caption?) ...[
          SectionLabel(caption),
          const SizedBox(height: AppSpacing.xs),
        ],
        Text(
          gym.name,
          style: text.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          gym.fullAddress,
          style: text.bodyMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (distance case final distance?) ...[
          const SizedBox(height: AppSpacing.xs),
          DistanceLabel(distance),
        ],
      ],
    );
  }
}

/// Štvorcové koralové tlačidlo so šípkou navigácie.
class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.busy,
    required this.started,
    required this.onPressed,
  });

  final bool busy;
  final bool started;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: started ? 'Spustiť navigáciu' : 'Trasa k fitku',
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          disabledBackgroundColor: AppColors.accentDeep,
          minimumSize: const Size(48, 48),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        child: busy
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.onAccent,
                ),
              )
            : Icon(
                started ? Icons.navigation_rounded : Icons.near_me_rounded,
                semanticLabel: started ? 'Spustiť navigáciu' : 'Trasa k fitku',
              ),
      ),
    );
  }
}

/// Auto/Pešo, dĺžka a čas trasy.
class _RouteSummary extends StatelessWidget {
  const _RouteSummary({
    required this.route,
    required this.mode,
    required this.onModeChanged,
    required this.onClear,
  });

  final GymRoute route;
  final TravelMode mode;
  final ValueChanged<TravelMode> onModeChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        for (final option in TravelMode.values) ...[
          ChoiceChip(
            label: Text(option.label),
            avatar: Icon(
              option == TravelMode.car
                  ? Icons.directions_car_rounded
                  : Icons.directions_walk_rounded,
              size: 16,
            ),
            showCheckmark: false,
            selected: option == mode,
            onSelected: (_) => onModeChanged(option),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            '${formatDistance(route.distanceKm)} · '
            '${formatTravelTime(route.duration)}',
            style: text.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          tooltip: 'Zrušiť trasu',
          icon: const Icon(Icons.close_rounded, color: AppColors.muted),
          onPressed: onClear,
        ),
      ],
    );
  }
}
