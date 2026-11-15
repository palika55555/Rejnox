import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/gym.dart';

/// Fitká, hodnotenia, fotky a cenníky na serveri.
/// Úpravy vracajú celé aktualizované fitko.
abstract interface class GymRepository {
  Future<List<Gym>> fetchGyms(String token);

  /// Uloží moje hodnotenie a vráti fitko s novým súhrnom.
  Future<Gym> rate(String token, String gymId, int stars);

  /// Zmaže moje hodnotenie a vráti fitko s novým súhrnom.
  Future<Gym> unrate(String token, String gymId);

  /// Pridá nové fitko (autorom je prihlásený používateľ).
  Future<Gym> create(String token, GymDraft draft);

  /// Zmení fitko. Server pustí len autora.
  Future<Gym> update(String token, String gymId, GymDraft draft);

  /// Zmaže fitko. Server pustí len autora.
  Future<void> delete(String token, String gymId);

  /// Nahrá fotku (JPEG, PNG alebo WebP) k fitku.
  Future<Gym> addPhoto(String token, String gymId, List<int> bytes);

  Future<Gym> deletePhoto(String token, String photoId);

  Future<Gym> addPrice(
    String token,
    String gymId, {
    required GymPriceKind kind,
    required String title,
    required int priceCents,
    String? period,
  });

  Future<Gym> deletePrice(String token, String priceId);
}

class HttpGymRepository implements GymRepository {
  const HttpGymRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Gym>> fetchGyms(String token) async {
    final json = await _api.send('GET', '/gyms', token: token);
    return [
      for (final g in json['gyms'] as List)
        Gym.fromJson(g as Map<String, dynamic>),
    ];
  }

  @override
  Future<Gym> rate(String token, String gymId, int stars) async => Gym.fromJson(
    await _api.send(
      'PUT',
      '/gyms/$gymId/review',
      token: token,
      body: {'stars': stars},
    ),
  );

  @override
  Future<Gym> unrate(String token, String gymId) async => Gym.fromJson(
    await _api.send('DELETE', '/gyms/$gymId/review', token: token),
  );

  @override
  Future<Gym> create(String token, GymDraft draft) async => Gym.fromJson(
    await _api.send('POST', '/gyms', token: token, body: draft.toJson()),
  );

  @override
  Future<Gym> update(String token, String gymId, GymDraft draft) async =>
      Gym.fromJson(
        await _api.send(
          'PUT',
          '/gyms/$gymId',
          token: token,
          body: draft.toJson(),
        ),
      );

  @override
  Future<void> delete(String token, String gymId) =>
      _api.send('DELETE', '/gyms/$gymId', token: token);

  @override
  Future<Gym> addPhoto(String token, String gymId, List<int> bytes) async =>
      Gym.fromJson(
        await _api.send(
          'POST',
          '/gyms/$gymId/photos',
          token: token,
          bytes: bytes,
          contentType: 'image/jpeg',
        ),
      );

  @override
  Future<Gym> deletePhoto(String token, String photoId) async => Gym.fromJson(
    await _api.send('DELETE', '/gym-photos/$photoId', token: token),
  );

  @override
  Future<Gym> addPrice(
    String token,
    String gymId, {
    required GymPriceKind kind,
    required String title,
    required int priceCents,
    String? period,
  }) async => Gym.fromJson(
    await _api.send(
      'POST',
      '/gyms/$gymId/prices',
      token: token,
      body: {
        'kind': kind.name,
        'title': title,
        'priceCents': priceCents,
        'period': period,
      },
    ),
  );

  @override
  Future<Gym> deletePrice(String token, String priceId) async => Gym.fromJson(
    await _api.send('DELETE', '/gym-prices/$priceId', token: token),
  );
}

/// Adresa fotky na našom serveri (načíta sa s tokenom v hlavičke).
String gymPhotoUrl(GymPhoto photo) => '$apiBaseUrl/gym-photos/${photo.id}';

final gymRepositoryProvider = Provider<GymRepository>(
  (ref) => HttpGymRepository(ref.watch(apiClientProvider)),
);

/// Token prihláseného používateľa pre volania /gyms (null = odhlásený).
final gymSessionTokenProvider = Provider<String?>(
  (ref) => switch (ref.watch(authControllerProvider)) {
    SignedIn(:final token) => token,
    _ => null,
  },
);

/// Všetky fitká sveta. Po prihlásení / odhlásení sa načítajú znova.
class GymsController extends AsyncNotifier<List<Gym>> {
  String? get _token => ref.read(gymSessionTokenProvider);

  @override
  Future<List<Gym>> build() async {
    final token = ref.watch(gymSessionTokenProvider);
    if (token == null) return const [];
    return ref.watch(gymRepositoryProvider).fetchGyms(token);
  }

  String get _requireToken =>
      _token ?? (throw const ApiError(401, 'unauthorized', 'Prihlás sa.'));

  GymRepository get _repository => ref.read(gymRepositoryProvider);

  /// Nahradí fitko v zozname (alebo ho pridá, ak je nové).
  Gym _put(Gym updated) {
    final current = state.value;
    if (current != null) {
      final exists = current.any((g) => g.id == updated.id);
      state = AsyncData([
        for (final gym in current) gym.id == updated.id ? updated : gym,
        if (!exists) updated,
      ]);
    }
    return updated;
  }

  /// Ohodnotí fitko (null = zmaže moje hodnotenie). Chyby posiela ďalej.
  Future<void> rate(String gymId, int? stars) async {
    final token = _token;
    if (token == null) return;
    _put(
      stars == null
          ? await _repository.unrate(token, gymId)
          : await _repository.rate(token, gymId, stars),
    );
  }

  /// Pridá nové fitko a vráti ho (s ID zo servera).
  Future<Gym> create(GymDraft draft) async =>
      _put(await _repository.create(_requireToken, draft));

  Future<Gym> edit(String gymId, GymDraft draft) async =>
      _put(await _repository.update(_requireToken, gymId, draft));

  Future<void> delete(String gymId) async {
    await _repository.delete(_requireToken, gymId);
    final current = state.value;
    if (current == null) return;
    state = AsyncData([
      for (final gym in current)
        if (gym.id != gymId) gym,
    ]);
  }

  Future<void> addPhoto(String gymId, List<int> bytes) async =>
      _put(await _repository.addPhoto(_requireToken, gymId, bytes));

  Future<void> deletePhoto(String photoId) async =>
      _put(await _repository.deletePhoto(_requireToken, photoId));

  Future<void> addPrice(
    String gymId, {
    required GymPriceKind kind,
    required String title,
    required int priceCents,
    String? period,
  }) async => _put(
    await _repository.addPrice(
      _requireToken,
      gymId,
      kind: kind,
      title: title,
      priceCents: priceCents,
      period: period,
    ),
  );

  Future<void> deletePrice(String priceId) async =>
      _put(await _repository.deletePrice(_requireToken, priceId));
}

final gymsProvider = AsyncNotifierProvider<GymsController, List<Gym>>(
  GymsController.new,
);

/// Jedno fitko podľa id (null, ak neexistuje).
final gymByIdProvider = FutureProvider.family<Gym?, String>((ref, id) async {
  final gyms = await ref.watch(gymsProvider.future);
  return gyms.where((g) => g.id == id).firstOrNull;
});
