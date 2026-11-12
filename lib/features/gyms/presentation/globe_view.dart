import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/gym.dart';
import 'flat_map_view.dart';
import 'globe_projection.dart';
import 'map_style.dart';

/// Ovládanie zemegule zvonka (napr. „preleť na moju polohu“).
class GlobeController {
  _GlobeViewState? _state;

  void flyTo(GeoPoint point) => _state?._flyTo(point);
}

/// Otáčateľná zemeguľa so všetkými fitkami sveta.
class GlobeView extends StatefulWidget {
  const GlobeView({
    super.key,
    required this.controller,
    required this.gyms,
    required this.user,
    required this.selectedId,
    required this.onSelect,
    required this.initialCenter,
    this.texture,
  });

  final GlobeController controller;
  final List<Gym> gyms;
  final GeoPoint? user;
  final String? selectedId;
  final ValueChanged<Gym?> onSelect;
  final GeoPoint initialCenter;
  final ui.Image? texture;

  @override
  State<GlobeView> createState() => _GlobeViewState();
}

class _GlobeViewState extends State<GlobeView>
    with SingleTickerProviderStateMixin {
  static const _maxLat = 80.0;

  late double _lat = widget.initialCenter.lat.clamp(-_maxLat, _maxLat);
  late double _lng = widget.initialCenter.lng;
  double _zoom = 1;
  double _zoomAtStart = 1;
  Size _size = Size.zero;

  late final AnimationController _fly;
  double _fromLat = 0, _fromLng = 0, _dLat = 0, _dLng = 0;

  @override
  void initState() {
    super.initState();
    _fly = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addListener(_onFly);
    widget.controller._state = this;
  }

  @override
  void didUpdateWidget(GlobeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller._state = null;
      widget.controller._state = this;
    }
  }

  @override
  void dispose() {
    if (widget.controller._state == this) widget.controller._state = null;
    _fly.dispose();
    super.dispose();
  }

  double get _radius => math.min(_size.width, _size.height) / 2 * 0.86 * _zoom;

  GlobeFrame get _frame => GlobeFrame(
    center: _size.center(Offset.zero),
    radius: _radius,
    lat: _lat,
    lng: _lng,
  );

  void _flyTo(GeoPoint point) {
    _fromLat = _lat;
    _fromLng = _lng;
    _dLat = point.lat.clamp(-_maxLat, _maxLat) - _lat;
    _dLng = shortestLngDelta(_lng, point.lng);
    _fly.forward(from: 0);
  }

  void _onFly() {
    final t = Curves.easeInOutCubic.transform(_fly.value);
    setState(() {
      _lat = _fromLat + _dLat * t;
      _lng = normalizeLng(_fromLng + _dLng * t);
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final degreesPerPixel = 180 / math.pi / _radius;
    setState(() {
      _lng = normalizeLng(_lng - details.focalPointDelta.dx * degreesPerPixel);
      _lat = (_lat + details.focalPointDelta.dy * degreesPerPixel).clamp(
        -_maxLat,
        _maxLat,
      );
      if (details.pointerCount > 1) {
        _zoom = (_zoomAtStart * details.scale).clamp(0.8, 4.0);
      }
    });
  }

  void _onWheel(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    setState(() {
      _zoom = (_zoom * math.pow(0.998, event.scrollDelta.dy)).clamp(0.8, 4.0);
    });
  }

  void _onTap(TapUpDetails details) {
    final frame = _frame;
    Gym? best;
    var bestDistance = 26.0;
    for (final gym in widget.gyms) {
      final at = frame.toScreen(gym.location);
      if (at == null) continue;
      final head = at.translate(0, -_pinSize.height * 0.62);
      final distance = (head - details.localPosition).distance;
      if (distance < bestDistance) {
        best = gym;
        bestDistance = distance;
      }
    }
    widget.onSelect(best);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        return Listener(
          onPointerSignal: _onWheel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (_) {
              _fly.stop();
              _zoomAtStart = _zoom;
            },
            onScaleUpdate: _onScaleUpdate,
            onTapUp: _onTap,
            child: Semantics(
              label: 'Zemeguľa s fitkami. Ťahaním ju otočíš.',
              child: CustomPaint(
                size: Size.infinite,
                painter: _GlobePainter(
                  frame: _frame,
                  texture: widget.texture,
                  gyms: widget.gyms,
                  user: widget.user,
                  selectedId: widget.selectedId,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

const _pinSize = Size(26, 33);

class _GlobePainter extends CustomPainter {
  _GlobePainter({
    required this.frame,
    required this.texture,
    required this.gyms,
    required this.user,
    required this.selectedId,
  });

  final GlobeFrame frame;
  final ui.Image? texture;
  final List<Gym> gyms;
  final GeoPoint? user;
  final String? selectedId;

  @override
  void paint(Canvas canvas, Size size) {
    final c = frame.center;
    final r = frame.radius;
    final sphere = Rect.fromCircle(center: c, radius: r);

    // Žiara atmosféry a tmavý oceán pod mapou.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = AppColors.blue.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.outer, r * 0.22),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = AppColors.violet.withValues(alpha: 0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 10),
    );
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF060A1E));

    canvas.save();
    canvas.clipPath(Path()..addOval(sphere));
    final image = texture;
    if (image != null) {
      canvas.drawVertices(
        _mesh(image),
        BlendMode.modulate,
        Paint()
          ..shader = ui.ImageShader(
            image,
            TileMode.clamp,
            TileMode.clamp,
            Matrix4.identity().storage,
          )
          ..colorFilter = MapStyle.darkFilter
          ..filterQuality = FilterQuality.medium,
      );
    }
    _paintGraticule(canvas, alpha: image == null ? 0.22 : 0.08);
    // Tieň na okraji gule – dodá jej objem.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 1.15,
          colors: [
            Colors.white.withValues(alpha: 0.07),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.6),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(sphere),
    );
    canvas.restore();

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.accent.withValues(alpha: 0.35),
    );

    _paintGyms(canvas);
    _paintUser(canvas);
  }

  /// Sieť trojuholníkov po 5° s povrchom mapy (Mercator) ako textúrou.
  ui.Vertices _mesh(ui.Image image) {
    const step = 5;
    // Dlaždice končia na ±85°; póly vyplní okrajový pás textúry.
    const rows = 180 ~/ step + 1; // −90° … 90°
    const cols = 360 ~/ step + 1; // −180° … 180°
    final positions = Float32List(rows * cols * 2);
    final uv = Float32List(rows * cols * 2);
    final front = List<bool>.filled(rows * cols, false);
    final w = image.width.toDouble();
    final h = image.height.toDouble();

    for (var i = 0; i < rows; i++) {
      final lat = -90.0 + i * step;
      final v = mercatorY(lat) * h;
      for (var j = 0; j < cols; j++) {
        final lng = -180.0 + j * step;
        final k = i * cols + j;
        var (:x, :y, :z) = frame.unit(lat, lng);
        if (z < 0) {
          // Body za okrajom pritiahne na okraj, nech je obrys gule hladký.
          final length = math.sqrt(x * x + y * y);
          if (length > 0) {
            x /= length;
            y /= length;
          }
        } else {
          front[k] = true;
        }
        final p = frame.screenOf(x, y);
        positions[k * 2] = p.dx;
        positions[k * 2 + 1] = p.dy;
        uv[k * 2] = (lng + 180) / 360 * w;
        uv[k * 2 + 1] = v;
      }
    }

    final indices = <int>[];
    for (var i = 0; i < rows - 1; i++) {
      for (var j = 0; j < cols - 1; j++) {
        final a = i * cols + j, b = a + 1, d = a + cols, e = d + 1;
        if (front[a] || front[b] || front[d]) indices.addAll([a, b, d]);
        if (front[b] || front[e] || front[d]) indices.addAll([b, e, d]);
      }
    }
    return ui.Vertices.raw(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: uv,
      indices: Uint16List.fromList(indices),
    );
  }

  void _paintGraticule(Canvas canvas, {required double alpha}) {
    final path = Path();
    void line(Iterable<GeoPoint> points) {
      var drawing = false;
      for (final point in points) {
        final at = frame.toScreen(point);
        if (at == null) {
          drawing = false;
        } else if (drawing) {
          path.lineTo(at.dx, at.dy);
        } else {
          path.moveTo(at.dx, at.dy);
          drawing = true;
        }
      }
    }

    for (var lat = -60.0; lat <= 60; lat += 30) {
      line([for (var lng = -180.0; lng <= 180; lng += 4) GeoPoint(lat, lng)]);
    }
    for (var lng = -180.0; lng < 180; lng += 30) {
      line([for (var lat = -84.0; lat <= 84; lat += 4) GeoPoint(lat, lng)]);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = AppColors.accent.withValues(alpha: alpha),
    );
  }

  void _paintGyms(Canvas canvas) {
    Gym? selected;
    for (final gym in gyms) {
      if (gym.id == selectedId) {
        selected = gym;
        continue;
      }
      final at = frame.toScreen(gym.location);
      if (at != null) _paintPin(canvas, at, selected: false);
    }
    if (selected == null) return;
    final at = frame.toScreen(selected.location);
    if (at == null) return;
    _paintPin(canvas, at, selected: true);
    _paintLabel(
      canvas,
      at.translate(0, -_pinSize.height * 1.25),
      selected.name,
    );
  }

  void _paintPin(Canvas canvas, Offset tip, {required bool selected}) {
    final size = selected ? _pinSize * 1.3 : _pinSize;
    canvas.save();
    canvas.translate(tip.dx - size.width / 2, tip.dy - size.height);
    GymPinPainter(selected: selected).paint(canvas, size);
    canvas.restore();
  }

  void _paintLabel(Canvas canvas, Offset at, String text) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 180);
    final box = Rect.fromCenter(
      center: at.translate(0, -14),
      width: painter.width + 16,
      height: painter.height + 8,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(10)),
      Paint()..color = AppColors.surface.withValues(alpha: 0.92),
    );
    painter.paint(canvas, box.topLeft + const Offset(8, 4));
    painter.dispose();
  }

  void _paintUser(Canvas canvas) {
    final point = user;
    if (point == null) return;
    final at = frame.toScreen(point);
    if (at == null) return;
    canvas.drawCircle(
      at,
      16,
      Paint()..color = AppColors.blue.withValues(alpha: 0.25),
    );
    canvas.drawCircle(at, 6.5, Paint()..color = AppColors.blue);
    canvas.drawCircle(
      at,
      6.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_GlobePainter old) => true;
}
