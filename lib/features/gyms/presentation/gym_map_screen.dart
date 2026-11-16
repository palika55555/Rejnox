import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tm_card.dart';
import '../application/user_location.dart';
import '../data/gym_repository.dart';
import '../domain/gym.dart';
import 'flat_map_view.dart';
import 'globe_texture.dart';
import 'globe_view.dart';
import 'gym_map_widgets.dart';
import 'map_style.dart';
import '../../../core/theme/app_spacing.dart';

/// Fitká po celom svete: zemeguľa, mapa okolia alebo zoznam.
/// Podľa polohy používateľa ukáže najbližšie fitká.
class GymMapScreen extends ConsumerStatefulWidget {
  const GymMapScreen({super.key});

  @override
  ConsumerState<GymMapScreen> createState() => _GymMapScreenState();
}

class _GymMapScreenState extends ConsumerState<GymMapScreen> {
  /// Kým nepoznáme polohu, mapa začne nad Slovenskom.
  static const _fallbackCenter = GeoPoint(48.67, 19.70);

  final _map = MapController();
  final _globe = GlobeController();
  final _search = TextEditingController();
  bool _mapReady = false;
  MapMode _mode = MapMode.globe;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _map.dispose();
    _search.dispose();
    super.dispose();
  }

  /// Presunie mapu aj zemeguľu na bod, nech sú oba pohľady v zhode.
  void _focus(GeoPoint point, {required double zoom}) {
    _globe.flyTo(point);
    if (_mapReady) {
      _map.move(toLatLng(point), math.max(zoom, _map.camera.zoom));
    }
  }

  /// Poloha mohla prísť skôr, než bola mapa pripravená – dobehneme presun.
  void _onMapReady() {
    _mapReady = true;
    if (ref.read(userLocationProvider).value case LocationFound(:final point)) {
      _map.move(toLatLng(point), math.max(13, _map.camera.zoom));
    }
  }

  void _setMode(MapMode mode) {
    setState(() => _mode = mode);
    if (mode != MapMode.map || !_mapReady) return;
    // Skrytá mapa (za zemeguľou) nevykreslí dlaždice, kým sa nepohne.
    // Po zobrazení ju preto nepatrne posunieme.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final camera = _map.camera;
      _map.move(camera.center, camera.zoom + 1e-6);
    });
  }

  void _zoomMap(double delta) {
    if (!_mapReady) return;
    final camera = _map.camera;
    _map.move(camera.center, (camera.zoom + delta).clamp(2, 18));
  }

  void _select(Gym? gym, {bool move = false}) {
    setState(() => _selectedId = gym?.id);
    if (gym != null && move) _focus(gym.location, zoom: 15);
  }

  void _openDetail(Gym gym) {
    setState(() => _selectedId = gym.id);
    context.push('/gym/${gym.id}');
  }

  /// Formulár nového fitka; [at] je miesto z dlhého podržania na mape.
  void _addGym([GeoPoint? at]) {
    final query = at == null ? '' : '?lat=${at.lat}&lng=${at.lng}';
    context.push('/gym/new$query');
  }

  void _onLocationAction(LocationIssue issue) {
    final source = ref.read(locationSourceProvider);
    switch (issue) {
      case LocationIssue.serviceOff:
      case LocationIssue.deniedForever:
        source.openSettings(issue);
      case LocationIssue.denied:
      case LocationIssue.failed:
        ref.invalidate(userLocationProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(userLocationProvider, (previous, next) {
      if (next.value case LocationFound(
        :final point,
      ) when previous?.value is! LocationFound) {
        _focus(point, zoom: 13);
      }
    });

    final location = ref.watch(userLocationProvider);
    final user = switch (location.value) {
      LocationFound(:final point) => point,
      _ => null,
    };
    final issue = switch (location.value) {
      LocationUnavailable(:final issue) when !location.isLoading => issue,
      _ => null,
    };
    final gymsAsync = ref.watch(gymsProvider);
    final all = gymsAsync.value ?? const <Gym>[];
    final loadFailed = gymsAsync.hasError && !gymsAsync.isLoading;
    final gyms = searchGyms(all, _search.text);
    final ranked = user == null
        ? [for (final gym in gyms) (gym: gym, distance: null as String?)]
        : [
            for (final near in nearestGyms(gyms, user))
              (gym: near.gym, distance: near.label as String?),
          ];
    String? distanceTo(Gym gym) =>
        user == null ? null : formatDistance(user.distanceKmTo(gym.location));
    final selected = all.where((g) => g.id == _selectedId).firstOrNull;
    final showTiles = ref.watch(mapTilesEnabledProvider);
    final text = Theme.of(context).textTheme;

    void myLocation() => user == null
        ? ref.invalidate(userLocationProvider)
        : _focus(user, zoom: 14);
    final locateButton = MapRoundButton(
      icon: Icons.near_me_rounded,
      tooltip: 'Moja poloha',
      busy: location.isLoading,
      onPressed: myLocation,
    );

    final globe = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              GlobeView(
                controller: _globe,
                gyms: gyms,
                user: user,
                selectedId: _selectedId,
                onSelect: (gym) => _select(gym, move: true),
                initialCenter: user ?? _fallbackCenter,
                texture: ref.watch(globeTextureProvider).value,
              ),
              Positioned(top: 4, right: 4, child: locateButton),
              Positioned(
                right: 4,
                bottom: selected == null ? 18 : 104,
                child: _CountBadge(
                  gyms: gyms.length,
                  cities: gymCities(gyms).length,
                ),
              ),
              if (selected != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 18,
                  child: GymCard(
                    gym: selected,
                    distance: distanceTo(selected),
                    onTap: () => _openDetail(selected),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionLabel('Mestá s fitkami'),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: gymCities(gyms).length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final city = gymCities(gyms)[index];
              return CityCard(
                city: city.city,
                count: city.count,
                onTap: () => _focus(city.location, zoom: 11),
              );
            },
          ),
        ),
      ],
    );

    final nearest = ranked.firstOrNull;
    final cardGym = selected ?? nearest?.gym;
    final map = _MapFrame(
      child: Stack(
        fit: StackFit.expand,
        children: [
          FlatMapView(
            controller: _map,
            gyms: gyms,
            user: user,
            selectedId: _selectedId,
            onSelect: _select,
            initialCenter: user ?? _fallbackCenter,
            initialZoom: user == null ? 5 : 13,
            showTiles: showTiles,
            onReady: _onMapReady,
            onLongPress: _addGym,
          ),
          Positioned(
            right: 10,
            top: 10,
            child: Column(
              children: [
                locateButton,
                const SizedBox(height: AppSpacing.sm),
                MapRoundButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Priblížiť',
                  onPressed: () => _zoomMap(1),
                ),
                const SizedBox(height: AppSpacing.sm),
                MapRoundButton(
                  icon: Icons.remove_rounded,
                  tooltip: 'Oddialiť',
                  onPressed: () => _zoomMap(-1),
                ),
              ],
            ),
          ),
          if (cardGym != null)
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: GymCard(
                gym: cardGym,
                distance: distanceTo(cardGym),
                caption: selected == null && user != null
                    ? 'Najbližšie fitko'
                    : null,
                onTap: () => _openDetail(cardGym),
              ),
            ),
        ],
      ),
    );

    final list = ranked.isEmpty
        ? Center(child: Text('Nič sme nenašli.', style: text.bodyMedium))
        : _ListFrame(
            child: ListView.separated(
              itemCount: ranked.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                final item = ranked[index];
                return GymListTile(
                  gym: item.gym,
                  distance: item.distance,
                  onTap: () => _openDetail(item.gym),
                );
              },
            ),
          );

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ScreenHeader(
            'Mapa fitiek',
            subtitle: 'Objavuj fitká po celom svete',
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MapModeSwitch(selected: _mode, onChanged: _setMode),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(child: GymSearchField(controller: _search)),
                      const SizedBox(width: AppSpacing.sm),
                      MapRoundButton(
                        icon: Icons.add_location_alt_outlined,
                        tooltip: 'Pridať fitko',
                        onPressed: _addGym,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (loadFailed) ...[
                    GymsErrorBanner(
                      onRetry: () => ref.invalidate(gymsProvider),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (issue != null) ...[
                    LocationBanner(
                      issue: issue,
                      onAction: () => _onLocationAction(issue),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  Expanded(
                    child: IndexedStack(
                      index: _mode.index,
                      sizing: StackFit.expand,
                      children: [globe, map, list],
                    ),
                  ),
                  if (showTiles && _mode != MapMode.list)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.ink2,
                          textStyle: text.bodySmall,
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                          ),
                        ),
                        onPressed: () => context.push('/about'),
                        child: const Text(MapStyle.attribution),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Zoznam fitiek v jednej karte s vlasovými linkami.
class _ListFrame extends StatelessWidget {
  const _ListFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.lg);
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(color: AppColors.surface, child: child),
      ),
    );
  }
}

/// Zaoblený rám plochej mapy.
class _MapFrame extends StatelessWidget {
  const _MapFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.lg);
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: ColoredBox(color: AppColors.bg, child: child),
      ),
    );
  }
}

/// Odznak „20 fitiek v 18 mestách“ pri zemeguli.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.gyms, required this.cities});

  final int gyms;
  final int cities;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.sheet.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const GymThumb(size: 34, highlighted: true),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(gymCountLabel(gyms), style: text.titleMedium),
              Text(
                cities == 1 ? 'v 1 meste' : 'v $cities mestách',
                style: text.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
