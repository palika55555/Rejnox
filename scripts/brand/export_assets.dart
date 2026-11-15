// Run: flutter test scripts/brand/export_assets.dart --dart-define=REJNOX_EXPORT_BRAND=true
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:rejnox/core/theme/app_colors.dart';
import 'package:rejnox/core/widgets/rejnox_mark.dart';

Future<void> _icon(
  String path,
  int pixels, {
  bool transparent = false,
  double scale = 0.82,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  if (!transparent) canvas.drawColor(AppColors.bg, ui.BlendMode.src);
  final mark = pixels * scale;
  canvas.translate((pixels - mark) / 2, (pixels - mark) / 2);
  const RejnoxMarkPainter().paint(canvas, ui.Size.square(mark));
  final picture = recorder.endRecording();
  final image = await picture.toImage(pixels, pixels);
  final file = File(path);
  await file.parent.create(recursive: true);
  if (transparent) {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  } else {
    // iOS marketing icons must have no alpha channel, even when fully opaque.
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    await file.writeAsBytes(_rgbPng(rgba!.buffer.asUint8List(), pixels));
  }
  image.dispose();
  picture.dispose();
}

String _hex(ui.Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

String _svg({bool light = false}) {
  final letter = _hex(AppColors.text);
  final stripe = light ? letter : _hex(AppColors.primary);
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 492 305">\n'
      '  <title>Rejnox</title>\n'
      '  <path fill="$letter" d="$rejnoxLetterData"/>\n'
      '  <path fill="$stripe" d="$rejnoxStripeData"/>\n'
      '</svg>\n';
}

Uint8List _rgbPng(Uint8List rgba, int size) {
  final rows = Uint8List(size * (1 + size * 3));
  var target = 0;
  for (var y = 0; y < size; y++) {
    rows[target++] = 0; // PNG filter: none.
    for (var x = 0; x < size; x++) {
      final source = (y * size + x) * 4;
      rows[target++] = rgba[source];
      rows[target++] = rgba[source + 1];
      rows[target++] = rgba[source + 2];
    }
  }
  final png = BytesBuilder()..add([137, 80, 78, 71, 13, 10, 26, 10]);
  void chunk(String name, List<int> bytes) {
    final data = Uint8List.fromList([...ascii.encode(name), ...bytes]);
    var crc = 0xffffffff;
    for (final byte in data) {
      crc ^= byte;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc & 1) != 0 ? 0xedb88320 ^ (crc >> 1) : crc >> 1;
      }
    }
    final length = ByteData(4)..setUint32(0, bytes.length);
    final checksum = ByteData(4)..setUint32(0, crc ^ 0xffffffff);
    png
      ..add(length.buffer.asUint8List())
      ..add(data)
      ..add(checksum.buffer.asUint8List());
  }

  final header = ByteData(13)
    ..setUint32(0, size)
    ..setUint32(4, size)
    ..setUint8(8, 8)
    ..setUint8(9, 2); // RGB, 8 bits per channel.
  chunk('IHDR', header.buffer.asUint8List());
  chunk('IDAT', ZLibEncoder().convert(rows));
  chunk('IEND', []);
  return png.takeBytes();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'export brand assets from the shared vector geometry',
    () async {
      final brand = Directory('assets/brand');
      await brand.create(recursive: true);
      await File('${brand.path}/rejnox-mark.svg').writeAsString(_svg());
      await File(
        '${brand.path}/rejnox-mark-light.svg',
      ).writeAsString(_svg(light: true));
      await _icon('${brand.path}/rejnox-icon.png', 1024);
      await _icon(
        '${brand.path}/rejnox-mark.png',
        1024,
        transparent: true,
        scale: 1,
      );

      for (final entry in {
        'mdpi': 1.0,
        'hdpi': 1.5,
        'xhdpi': 2.0,
        'xxhdpi': 3.0,
        'xxxhdpi': 4.0,
      }.entries) {
        final base = 'android/app/src/main/res/mipmap-${entry.key}';
        await _icon('$base/ic_launcher.png', (48 * entry.value).round());
        await _icon(
          '$base/ic_launcher_foreground.png',
          (108 * entry.value).round(),
          transparent: true,
          scale: 0.50,
        );
      }
      // Reserve padding for the mask around the system splash icon.
      await File(
        'android/app/src/main/res/drawable/rejnox_mark.xml',
      ).writeAsString(
        '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
        '    android:width="108dp" android:height="108dp"\n'
        '    android:viewportWidth="492" android:viewportHeight="492">\n'
        '    <group android:scaleX="0.5" android:scaleY="0.5"\n'
        '        android:translateX="123" android:translateY="169.75">\n'
        '        <path android:fillColor="${_hex(AppColors.text)}" android:pathData="$rejnoxLetterData"/>\n'
        '        <path android:fillColor="${_hex(AppColors.primary)}" android:pathData="$rejnoxStripeData"/>\n'
        '    </group>\n'
        '</vector>\n',
      );

      const ios = 'ios/Runner/Assets.xcassets';
      final catalog =
          jsonDecode(
                await File(
                  '$ios/AppIcon.appiconset/Contents.json',
                ).readAsString(),
              )
              as Map<String, dynamic>;
      final written = <String>{};
      for (final item in catalog['images'] as List) {
        final filename = item['filename'] as String;
        if (!written.add(filename)) continue;
        final points = double.parse((item['size'] as String).split('x').first);
        final scale = double.parse(
          (item['scale'] as String).replaceAll('x', ''),
        );
        await _icon(
          '$ios/AppIcon.appiconset/$filename',
          (points * scale).round(),
        );
      }
      for (var scale = 1; scale <= 3; scale++) {
        final suffix = scale == 1 ? '' : '@${scale}x';
        await _icon(
          '$ios/LaunchImage.imageset/LaunchImage$suffix.png',
          136 * scale,
          transparent: true,
          scale: 1,
        );
      }
      // These are Flutter PWA assets, not the separate Next.js website.
      for (final size in [192, 512]) {
        await _icon('web/icons/Icon-$size.png', size);
        await _icon('web/icons/Icon-maskable-$size.png', size, scale: 0.68);
      }
      await _icon('web/favicon.png', 32);
    },
    skip: !const bool.fromEnvironment('REJNOX_EXPORT_BRAND'),
  );
}
