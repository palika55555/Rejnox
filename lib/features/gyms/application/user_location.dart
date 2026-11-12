import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/gym.dart';

/// Prečo poloha nie je k dispozícii.
enum LocationIssue { serviceOff, denied, deniedForever, failed }

/// Výsledok zisťovania polohy používateľa.
sealed class UserLocation {
  const UserLocation();
}

class LocationFound extends UserLocation {
  const LocationFound(this.point);
  final GeoPoint point;
}

class LocationUnavailable extends UserLocation {
  const LocationUnavailable(this.issue);
  final LocationIssue issue;
}

/// Odkiaľ appka berie polohu (v testoch sa nahradí).
abstract interface class LocationSource {
  Future<UserLocation> current();

  /// Otvorí nastavenia, kde si používateľ polohu zapne alebo povolí.
  Future<void> openSettings(LocationIssue issue);
}

class GeolocatorLocationSource implements LocationSource {
  const GeolocatorLocationSource();

  @override
  Future<UserLocation> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationUnavailable(LocationIssue.serviceOff);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      switch (permission) {
        case LocationPermission.denied:
          return const LocationUnavailable(LocationIssue.denied);
        case LocationPermission.deniedForever:
          return const LocationUnavailable(LocationIssue.deniedForever);
        case LocationPermission.whileInUse:
        case LocationPermission.always:
        case LocationPermission.unableToDetermine:
          break;
      }
      // Na hľadanie fitiek v okolí stačí presnosť na desiatky metrov.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LocationFound(GeoPoint(position.latitude, position.longitude));
    } on Exception {
      return const LocationUnavailable(LocationIssue.failed);
    }
  }

  @override
  Future<void> openSettings(LocationIssue issue) async {
    if (kIsWeb) return;
    switch (issue) {
      case LocationIssue.serviceOff:
        await Geolocator.openLocationSettings();
      case LocationIssue.deniedForever:
        await Geolocator.openAppSettings();
      case LocationIssue.denied:
      case LocationIssue.failed:
        break;
    }
  }
}

final locationSourceProvider = Provider<LocationSource>(
  (ref) => const GeolocatorLocationSource(),
);

/// Aktuálna poloha používateľa. `ref.invalidate` ju zistí znova.
final userLocationProvider = FutureProvider<UserLocation>(
  (ref) => ref.watch(locationSourceProvider).current(),
);
