import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/tm_card.dart';
import '../application/user_location.dart';
import '../data/gym_repository.dart';
import '../domain/gym.dart';
import 'flat_map_view.dart';
import 'globe_texture.dart';
import 'globe_view.dart';
import 'gym_map_widgets.dart';
import 'map_style.dart';

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
              if (showTiles) const _Attribution(),
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
        const SizedBox(height: 8),
        const SectionLabel('Mestá s fitkami', icon: Icons.location_city),
        const SizedBox(height: 8),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: gymCities(gyms).length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
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
          ),
          Positioned(
            right: 10,
            top: 10,
            child: Column(
              children: [
                locateButton,
                const SizedBox(height: 10),
                MapRoundButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Priblížiť',
                  onPressed: () => _zoomMap(1),
                ),
                const SizedBox(height: 6),
                MapRoundButton(
                  icon: Icons.remove_rounded,
                  tooltip: 'Oddialiť',
                  onPressed: () => _zoomMap(-1),
                ),
              ],
            ),
          ),
          if (showTiles) const _Attribution(),
          if (cardGym != null)
            Positioned(
              left: 10,
              right: 10,
              bottom: 22,
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
        : ListView.separated(
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: ranked.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = ranked[index];
              return GymListTile(
                gym: item.gym,
                distance: item.distance,
                onTap: () => _openDetail(item.gym),
              );
            },
          );

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('MAPA FITIEK', style: text.headlineMedium),
            Text(
              'Objavuj fitká po celom svete',
              style: text.bodyMedium!.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            MapModeSwitch(selected: _mode, onChanged: _setMode),
            const SizedBox(height: 10),
            GymSearchField(controller: _search),
            const SizedBox(height: 10),
            if (loadFailed) ...[
              GymsErrorBanner(onRetry: () => ref.invalidate(gymsProvider)),
              const SizedBox(height: 10),
            ],
            if (issue != null) ...[
              LocationBanner(
                issue: issue,
                onAction: () => _onLocationAction(issue),
              ),
              const SizedBox(height: 10),
            ],
            Expanded(
              child: IndexedStack(
                index: _mode.index,
                sizing: StackFit.expand,
                children: [globe, map, list],
              ),
            ),
          ],
        ),
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
    final radius = BorderRadius.circular(22);
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

/// Zdroj dlaždíc mapy v rohu (podmienka OpenStreetMap).
class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) => Positioned(
    left: 10,
    bottom: 4,
    child: IgnorePointer(
      child: Text(
        MapStyle.attribution,
        style: Theme.of(context).textTheme.bodySmall!.copyWith(
          fontSize: 9.5,
          color: AppColors.muted.withValues(alpha: 0.8),
        ),
      ),
    ),
  );
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
      padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const GymThumb(size: 34, highlighted: true),
          const SizedBox(width: 10),
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
