import 'dart:math' as math;

/// Bod na Zemi v stupňoch.
class GeoPoint {
  const GeoPoint(this.lat, this.lng)
    : assert(lat >= -90 && lat <= 90),
      assert(lng >= -180 && lng <= 180);

  final double lat;
  final double lng;

  /// Vzdialenosť po povrchu Zeme (haversine) v kilometroch.
  double distanceKmTo(GeoPoint other) {
    const earthRadiusKm = 6371.0;
    double rad(double deg) => deg * math.pi / 180;
    final dLat = rad(other.lat - lat);
    final dLng = rad(other.lng - lng);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat)) *
            math.cos(rad(other.lat)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * earthRadiusKm * math.asin(math.min(1, math.sqrt(a)));
  }

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);
}

/// Fitko na mape.
class Gym {
  const Gym({
    required this.id,
    required this.name,
    required this.city,
    required this.location,
    this.address,
    this.openingHours,
    this.tags = const [],
    this.website,
    this.photoUrls = const [],
    this.rating,
    this.myStars,
  });

  /// Fitko z odpovede servera (GET /gyms).
  factory Gym.fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? value) =>
        value is List ? [for (final v in value) '$v'] : const [];
    final website = Uri.tryParse(json['website'] as String? ?? '');
    final stars = (json['rating'] as Map?)?['stars'];
    return Gym(
      id: json['id'] as String,
      name: json['name'] as String,
      city: json['city'] as String? ?? '',
      address: json['address'] as String?,
      location: GeoPoint(
        (json['lat'] as num).toDouble(),
        (json['lng'] as num).toDouble(),
      ),
      openingHours: json['openingHours'] as String?,
      tags: strings(json['tags']),
      website: website != null && website.isScheme('https') ? website : null,
      photoUrls: strings(json['photoUrls']),
      rating: stars is List && stars.length == 5
          ? GymRating(stars: [for (final n in stars) (n as num).toInt()])
          : null,
      myStars: (json['myStars'] as num?)?.toInt(),
    );
  }

  final String id;
  final String name;
  final String city;
  final String? address;
  final GeoPoint location;

  /// Otváracie hodiny tak, ako ich zadal používateľ („Nonstop“, „Po–Pi 6–22“).
  final String? openingHours;

  /// Čo sa tu dá cvičiť („Silový tréning“, „Kardio“…).
  final List<String> tags;
  final Uri? website;
  final List<String> photoUrls;
  final GymRating? rating;

  /// Koľko hviezdičiek dal fitku prihlásený používateľ (null = nehodnotil).
  final int? myStars;

  /// „Bajkalská 7, Bratislava“ alebo len mesto.
  String get fullAddress => address == null ? city : '$address, $city';
}

/// Súhrn hodnotení fitka.
class GymRating {
  const GymRating({required this.stars});

  /// Počet hodnotení s 1, 2, 3, 4 a 5 hviezdičkami (v tomto poradí).
  final List<int> stars;

  int get count => stars.fold(0, (sum, n) => sum + n);

  double get average {
    if (count == 0) return 0;
    var total = 0;
    for (var i = 0; i < stars.length; i++) {
      total += stars[i] * (i + 1);
    }
    return total / count;
  }

  /// Podiel hodnotení s [star] hviezdičkami (0–1).
  double share(int star) =>
      count == 0 || star > stars.length ? 0 : stars[star - 1] / count;

  /// „4,9“
  String get averageLabel => average.toStringAsFixed(1).replaceAll('.', ',');

  /// „1 recenzia“, „3 recenzie“, „328 recenzií“.
  String get countLabel => switch (count) {
    1 => '1 recenzia',
    >= 2 && <= 4 => '$count recenzie',
    _ => '$count recenzií',
  };
}

/// Fitko spolu so vzdialenosťou od používateľa.
class GymDistance {
  const GymDistance(this.gym, this.km);

  final Gym gym;
  final double km;

  /// „850 m“, „1,2 km“, „38 km“ alebo „8 412 km“.
  String get label => formatDistance(km);
}

String formatDistance(double km) {
  if (km < 1) return '${(km * 1000 / 10).round() * 10} m';
  if (km < 10) return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  final whole = km.round().toString();
  final grouped = whole.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ' ',
  );
  return '$grouped km';
}

const _accented = 'áäčďéíĺľňóôŕšťúýžãâàöüőű';
const _plain = 'aacdeillnoorstuyzaaaouou';

/// Malé písmená bez diakritiky, aby „kosice“ našlo „Košice“.
String foldForSearch(String text) {
  final lower = text.toLowerCase();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    final index = _accented.indexOf(char);
    out.write(index < 0 ? char : _plain[index]);
  }
  return out.toString();
}

/// Fitká, ktorých názov, mesto alebo adresa obsahuje [query].
List<Gym> searchGyms(Iterable<Gym> gyms, String query) {
  final needle = foldForSearch(query.trim());
  if (needle.isEmpty) return gyms.toList();
  return [
    for (final gym in gyms)
      if (foldForSearch(
        '${gym.name} ${gym.city} ${gym.address ?? ''}',
      ).contains(needle))
        gym,
  ];
}

/// Mestá s počtom fitiek, od najväčšieho.
List<({String city, int count, GeoPoint location})> gymCities(
  Iterable<Gym> gyms,
) {
  final byCity = <String, List<Gym>>{};
  for (final gym in gyms) {
    (byCity[gym.city] ??= []).add(gym);
  }
  final cities = [
    for (final MapEntry(key: city, value: list) in byCity.entries)
      (city: city, count: list.length, location: list.first.location),
  ];
  return cities..sort(
    (a, b) => a.count != b.count
        ? b.count.compareTo(a.count)
        : a.city.compareTo(b.city),
  );
}

/// Fitká zoradené od najbližšieho k [origin].
List<GymDistance> nearestGyms(
  Iterable<Gym> gyms,
  GeoPoint origin, {
  int? limit,
}) {
  final sorted = [
    for (final gym in gyms) GymDistance(gym, origin.distanceKmTo(gym.location)),
  ]..sort((a, b) => a.km.compareTo(b.km));
  return limit == null ? sorted : sorted.take(limit).toList();
}
