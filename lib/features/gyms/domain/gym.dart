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

/// Bod z parametrov odkazu `?lat=..&lng=..` (null, ak chýba alebo je mimo).
GeoPoint? geoPointFromQuery(Map<String, String> query) {
  final lat = double.tryParse(query['lat'] ?? '');
  final lng = double.tryParse(query['lng'] ?? '');
  if (lat == null || lng == null) return null;
  if (!lat.isFinite || !lng.isFinite) return null;
  if (lat.abs() > 90 || lng.abs() > 180) return null;
  return GeoPoint(lat, lng);
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
    this.photos = const [],
    this.prices = const [],
    this.mine = false,
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
      photos: [
        for (final p in json['photos'] as List? ?? const [])
          GymPhoto.fromJson(p as Map<String, dynamic>),
      ],
      prices: [
        for (final p in json['prices'] as List? ?? const [])
          GymPrice.fromJson(p as Map<String, dynamic>),
      ],
      mine: json['mine'] == true,
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

  /// Fotky, ktoré nahrali používatelia appky (sú na našom serveri).
  final List<GymPhoto> photos;

  /// Cenník, ktorý zadali používatelia.
  final List<GymPrice> prices;

  /// Fitko pridal prihlásený používateľ (môže ho upraviť a zmazať).
  final bool mine;
  final GymRating? rating;

  /// Koľko hviezdičiek dal fitku prihlásený používateľ (null = nehodnotil).
  final int? myStars;

  /// „Bajkalská 7, Bratislava“ alebo len mesto.
  String get fullAddress => address == null ? city : '$address, $city';
}

/// Fotka fitka nahratá cez appku. Obsah je na `GET /gym-photos/<id>`.
class GymPhoto {
  const GymPhoto({required this.id, this.mine = false});

  factory GymPhoto.fromJson(Map<String, dynamic> json) =>
      GymPhoto(id: json['id'] as String, mine: json['mine'] == true);

  final String id;

  /// Nahral ju prihlásený používateľ (môže ju zmazať).
  final bool mine;
}

/// Permanentka (aj jednorazový vstup) alebo produkt (proteín, nápoj…).
enum GymPriceKind {
  membership('Vstupy a permanentky'),
  product('Produkty');

  const GymPriceKind(this.label);

  final String label;
}

/// Položka cenníka fitka.
class GymPrice {
  const GymPrice({
    required this.id,
    required this.kind,
    required this.title,
    required this.priceCents,
    this.currency = 'EUR',
    this.period,
    this.mine = false,
  });

  factory GymPrice.fromJson(Map<String, dynamic> json) => GymPrice(
    id: json['id'] as String,
    kind: json['kind'] == 'product'
        ? GymPriceKind.product
        : GymPriceKind.membership,
    title: json['title'] as String,
    priceCents: (json['priceCents'] as num).toInt(),
    currency: json['currency'] as String? ?? 'EUR',
    period: json['period'] as String?,
    mine: json['mine'] == true,
  );

  final String id;
  final GymPriceKind kind;
  final String title;
  final int priceCents;
  final String currency;

  /// „mesiac“, „10 vstupov“… (null = jednorazovo).
  final String? period;
  final bool mine;

  /// „39,00 €“ alebo „39,00 CZK“.
  String get priceLabel {
    final amount = (priceCents / 100).toStringAsFixed(2).replaceAll('.', ',');
    return currency == 'EUR' ? '$amount €' : '$amount $currency';
  }
}

/// Cena zadaná ako text („39“, „39,90“, „39.9 €“) v centoch, inak null.
int? parsePriceCents(String text) {
  final cleaned = text.replaceAll(RegExp(r'[\s€]'), '').replaceAll(',', '.');
  if (!RegExp(r'^\d{1,6}(\.\d{1,2})?$').hasMatch(cleaned)) return null;
  return (double.parse(cleaned) * 100).round();
}

/// Fitko tak, ako ho používateľ vyplní vo formulári (nové alebo úprava).
class GymDraft {
  const GymDraft({
    required this.name,
    required this.city,
    required this.location,
    this.address,
    this.openingHours,
    this.tags = const [],
    this.website,
  });

  final String name;
  final String city;
  final GeoPoint location;
  final String? address;
  final String? openingHours;
  final List<String> tags;
  final String? website;

  Map<String, dynamic> toJson() => {
    'name': name,
    'city': city,
    'lat': location.lat,
    'lng': location.lng,
    'address': address,
    'openingHours': openingHours,
    'tags': tags,
    'website': website,
  };
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
