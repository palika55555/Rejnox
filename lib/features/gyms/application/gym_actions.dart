import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/gym.dart';

/// Akcie mimo appky: mapy, prehliadač, zdieľanie (v testoch sa nahradia).
abstract interface class ExternalActions {
  /// Otvorí odkaz v inej appke. false = nepodarilo sa.
  Future<bool> openUrl(Uri url);

  /// [origin] je miesto tlačidla – iPad podľa neho ukáže okno zdieľania.
  Future<void> share(String text, {String? subject, Rect? origin});
}

class SystemExternalActions implements ExternalActions {
  const SystemExternalActions();

  @override
  Future<bool> openUrl(Uri url) async {
    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } on Exception {
      return false;
    }
  }

  @override
  Future<void> share(String text, {String? subject, Rect? origin}) async {
    await SharePlus.instance.share(
      ShareParams(text: text, subject: subject, sharePositionOrigin: origin),
    );
  }
}

final externalActionsProvider = Provider<ExternalActions>(
  (ref) => const SystemExternalActions(),
);

/// Odkaz na navigáciu k fitku: na iPhone Apple Mapy, inde Google Mapy.
Uri navigationUrl(Gym gym, {TargetPlatform? platform}) {
  final at = '${gym.location.lat},${gym.location.lng}';
  return (platform ?? defaultTargetPlatform) == TargetPlatform.iOS
      ? Uri.https('maps.apple.com', '/', {'daddr': at})
      : Uri.https('www.google.com', '/maps/dir/', {
          'api': '1',
          'destination': at,
        });
}

/// Text, ktorý sa pošle pri zdieľaní fitka.
String shareText(Gym gym) {
  final map = Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': '${gym.location.lat},${gym.location.lng}',
  });
  return '${gym.name}\n${gym.fullAddress}\n$map';
}

/// Uložené (obľúbené) fitká. Držia sa v telefóne.
class FavoriteGyms extends Notifier<Set<String>> {
  static const _key = 'favorite_gyms';

  @override
  Set<String> build() {
    _load();
    return const {};
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_key);
    if (saved != null && ref.mounted) state = {...state, ...saved};
  }

  Future<void> toggle(String gymId) async {
    final next = {...state};
    if (!next.remove(gymId)) next.add(gymId);
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, next.toList());
  }
}

final favoriteGymsProvider = NotifierProvider<FavoriteGyms, Set<String>>(
  FavoriteGyms.new,
);
