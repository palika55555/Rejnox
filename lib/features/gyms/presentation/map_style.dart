import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Spoločný vzhľad mapy aj zemegule: rovnaké dlaždice a tmavý filter.
abstract final class MapStyle {
  /// Dlaždice OpenStreetMap. Pre ostrú prevádzku s veľa používateľmi
  /// treba vlastného poskytovateľa dlaždíc (pravidlá tile.openstreetmap.org).
  static const tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const packageName = 'com.rejnox.rejnox';
  static const attribution = '© OpenStreetMap contributors';
  static final attributionUrl = Uri.https(
    'www.openstreetmap.org',
    '/copyright',
  );

  /// Svetlú mapu prefarbí na antracit: pevnina tmavosivá, voda
  /// takmer čierna. Vodu spozná podľa toho, že je modrejšia než červená
  /// (s = jas + 1,5 × (R − B)), a s namapuje na odtiene appky.
  static const darkFilter = ColorFilter.matrix(<double>[
    0.2149, 0.0898, -0.1792, 0, -4, //
    0.2450, 0.1024, -0.2043, 0, -3, //
    0.2778, 0.1160, -0.2317, 0, -2, //
    0, 0, 0, 1, 0, //
  ]);
}

/// Či sa majú sťahovať dlaždice mapy (v testoch vypnuté).
final mapTilesEnabledProvider = Provider<bool>((ref) => true);
