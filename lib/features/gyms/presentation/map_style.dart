import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Spoločný vzhľad mapy aj zemegule: rovnaké dlaždice a tmavý filter.
abstract final class MapStyle {
  /// Dlaždice OpenStreetMap. Pre ostrú prevádzku s veľa používateľmi
  /// treba vlastného poskytovateľa dlaždíc (pravidlá tile.openstreetmap.org).
  static const tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const packageName = 'com.rejnox.rejnox';
  static const attribution = '© OpenStreetMap contributors';

  /// Svetlú mapu prefarbí na nočnú modrú: pevnina tmavomodrá, voda
  /// takmer čierna. Vodu spozná podľa toho, že je modrejšia než červená
  /// (s = jas + 1,5 × (R − B)), a s namapuje na odtiene appky.
  static const darkFilter = ColorFilter.matrix(<double>[
    0.2149, 0.0898, -0.1792, 0, -9.7, //
    0.2821, 0.1178, -0.2352, 0, -11.6, //
    0.6179, 0.2580, -0.5151, 0, -19, //
    0, 0, 0, 1, 0, //
  ]);
}

/// Či sa majú sťahovať dlaždice mapy (v testoch vypnuté).
final mapTilesEnabledProvider = Provider<bool>((ref) => true);
