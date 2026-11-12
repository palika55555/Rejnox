import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'map_style.dart';

/// Povrch zemegule poskladaný zo 16 dlaždíc mapy (zoom 2, 1024 × 1024 px).
/// Načíta sa raz za behu appky. Bez internetu vráti null a zemeguľa
/// sa nakreslí len so sieťou poludníkov.
final globeTextureProvider = FutureProvider<ui.Image?>((ref) async {
  if (!ref.watch(mapTilesEnabledProvider)) return null;
  final client = http.Client();
  ref.onDispose(client.close);
  try {
    return await loadGlobeTexture(client);
  } on Exception {
    return null;
  }
});

const _zoom = 2;
const _tiles = 1 << _zoom;
const _tileSize = 256;

Future<ui.Image> loadGlobeTexture(http.Client client) async {
  final images = await Future.wait([
    for (var y = 0; y < _tiles; y++)
      for (var x = 0; x < _tiles; x++) _loadTile(client, x, y),
  ]);
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  for (var i = 0; i < images.length; i++) {
    final offset = ui.Offset(
      (i % _tiles) * _tileSize.toDouble(),
      (i ~/ _tiles) * _tileSize.toDouble(),
    );
    canvas.drawImage(images[i], offset, ui.Paint());
    images[i].dispose();
  }
  const side = _tiles * _tileSize;
  return recorder.endRecording().toImage(side, side);
}

Future<ui.Image> _loadTile(http.Client client, int x, int y) async {
  final url = MapStyle.tileUrl
      .replaceFirst('{z}', '$_zoom')
      .replaceFirst('{x}', '$x')
      .replaceFirst('{y}', '$y');
  final response = await client.get(
    Uri.parse(url),
    // Prehliadač si User-Agent nastaví sám a nedovolí ho prepísať.
    headers: kIsWeb ? null : {'User-Agent': 'Rejnox (${MapStyle.packageName})'},
  );
  if (response.statusCode != 200) {
    throw http.ClientException('Dlaždica $x/$y: ${response.statusCode}');
  }
  final codec = await ui.instantiateImageCodec(response.bodyBytes);
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}
