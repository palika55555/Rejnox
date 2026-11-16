import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../core/theme/app_colors.dart';
import '../domain/gym.dart';
import 'map_style.dart';

LatLng toLatLng(GeoPoint point) => LatLng(point.lat, point.lng);

/// Plochá mapa ulíc s fitkami a polohou používateľa.
class FlatMapView extends StatelessWidget {
  const FlatMapView({
    super.key,
    required this.controller,
    required this.gyms,
    required this.user,
    required this.selectedId,
    required this.onSelect,
    required this.initialCenter,
    required this.initialZoom,
    required this.showTiles,
    required this.onReady,
    this.onLongPress,
    this.route = const [],
  });

  final MapController controller;
  final List<Gym> gyms;
  final GeoPoint? user;
  final String? selectedId;
  final ValueChanged<Gym?> onSelect;
  final GeoPoint initialCenter;
  final double initialZoom;
  final bool showTiles;
  final VoidCallback onReady;

  /// Dlhé podržanie na mape (pridanie fitka na tomto mieste).
  final ValueChanged<GeoPoint>? onLongPress;

  /// Body trasy k vybranému fitku (prázdne = bez trasy).
  final List<GeoPoint> route;

  @override
  Widget build(BuildContext context) {
    final userPoint = user;
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: toLatLng(initialCenter),
        initialZoom: initialZoom,
        minZoom: 2,
        maxZoom: 18,
        backgroundColor: AppColors.bg,
        onMapReady: onReady,
        onTap: (_, _) => onSelect(null),
        onLongPress: onLongPress == null
            ? null
            : (_, point) =>
                  onLongPress!(GeoPoint(point.latitude, point.longitude)),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        if (showTiles)
          TileLayer(
            urlTemplate: MapStyle.tileUrl,
            userAgentPackageName: MapStyle.packageName,
            tileBuilder: (context, tile, _) =>
                ColorFiltered(colorFilter: MapStyle.darkFilter, child: tile),
          ),
        if (route.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [for (final p in route) toLatLng(p)],
                strokeWidth: 9,
                color: AppColors.accent.withValues(alpha: 0.25),
              ),
              Polyline(
                points: [for (final p in route) toLatLng(p)],
                strokeWidth: 4.5,
                color: AppColors.accent,
                borderStrokeWidth: 1.5,
                borderColor: AppColors.accentDeep,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            for (final gym in gyms)
              if (gym.id != selectedId) _gymMarker(gym, selected: false),
            if (userPoint != null)
              Marker(
                point: toLatLng(userPoint),
                width: 64,
                height: 64,
                child: const _UserDot(),
              ),
            // Vybrané fitko kreslíme posledné, aby bolo navrchu.
            for (final gym in gyms)
              if (gym.id == selectedId) _gymMarker(gym, selected: true),
          ],
        ),
      ],
    );
  }

  Marker _gymMarker(Gym gym, {required bool selected}) {
    final scale = selected ? 1.25 : 1.0;
    return Marker(
      point: toLatLng(gym.location),
      width: 38 * scale,
      height: 48 * scale,
      // Hrot špendlíka sedí presne na mieste fitka.
      alignment: Alignment.topCenter,
      child: Semantics(
        button: true,
        label: gym.name,
        child: GestureDetector(
          onTap: () => onSelect(gym),
          child: GymPin(selected: selected),
        ),
      ),
    );
  }
}

/// Špendlík fitka: kruh s činkou a hrot dole.
class GymPin extends StatelessWidget {
  const GymPin({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: GymPinPainter(selected: selected));
}

class GymPinPainter extends CustomPainter {
  GymPinPainter({required this.selected});

  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2 - 2;
    final c = Offset(size.width / 2, r + 2);
    final tip = Offset(size.width / 2, size.height - 1);
    final shape = Path()
      ..addOval(Rect.fromCircle(center: c, radius: r))
      ..moveTo(c.dx - r * 0.55, c.dy + r * 0.8)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(c.dx + r * 0.55, c.dy + r * 0.8)
      ..close();
    canvas.drawPath(
      shape,
      Paint()
        ..color = AppColors.accent.withValues(alpha: selected ? 0.8 : 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, selected ? 10 : 6),
    );
    canvas.drawPath(
      shape,
      Paint()
        ..shader =
            (selected
                    ? AppColors.actionGradient
                    : const LinearGradient(
                        colors: [AppColors.buttonSurface, AppColors.surface],
                      ))
                .createShader(Offset.zero & size),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = selected ? AppColors.onAccent : AppColors.accent,
    );
    final icon = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.fitness_center_rounded.codePoint),
        style: TextStyle(
          fontFamily: Icons.fitness_center_rounded.fontFamily,
          package: Icons.fitness_center_rounded.fontPackage,
          fontSize: r * 1.1,
          color: selected ? AppColors.onAccent : AppColors.text,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    icon.paint(canvas, c - Offset(icon.width / 2, icon.height / 2));
    icon.dispose();
  }

  @override
  bool shouldRepaint(GymPinPainter old) => old.selected != selected;
}

/// Poloha používateľa: koralový bod a kruhmi.
class _UserDot extends StatelessWidget {
  const _UserDot();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Tvoja poloha',
    child: Stack(
      alignment: Alignment.center,
      children: [
        for (final (size, alpha) in const [(64.0, 0.10), (40.0, 0.18)])
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accentDeep.withValues(alpha: alpha),
              border: Border.all(
                color: AppColors.accentDeep.withValues(alpha: alpha * 2.5),
              ),
            ),
          ),
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accentDeep,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(color: AppColors.accentDeep, blurRadius: 14),
            ],
          ),
        ),
      ],
    ),
  );
}
