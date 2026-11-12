import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/gym.dart';

/// Fitká a hodnotenia na serveri (tabuľky gyms a gym_reviews).
abstract interface class GymRepository {
  Future<List<Gym>> fetchGyms(String token);

  /// Uloží moje hodnotenie a vráti fitko s novým súhrnom.
  Future<Gym> rate(String token, String gymId, int stars);

  /// Zmaže moje hodnotenie a vráti fitko s novým súhrnom.
  Future<Gym> unrate(String token, String gymId);
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
}

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

  /// Ohodnotí fitko (null = zmaže moje hodnotenie). Chyby posiela ďalej.
  Future<void> rate(String gymId, int? stars) async {
    final token = _token;
    if (token == null) return;
    final repository = ref.read(gymRepositoryProvider);
    final updated = stars == null
        ? await repository.unrate(token, gymId)
        : await repository.rate(token, gymId, stars);
    final current = state.value;
    if (current == null) return;
    state = AsyncData([
      for (final gym in current) gym.id == gymId ? updated : gym,
    ]);
  }
}

final gymsProvider = AsyncNotifierProvider<GymsController, List<Gym>>(
  GymsController.new,
);

/// Jedno fitko podľa id (null, ak neexistuje).
final gymByIdProvider = FutureProvider.family<Gym?, String>((ref, id) async {
  final gyms = await ref.watch(gymsProvider.future);
  return gyms.where((g) => g.id == id).firstOrNull;
});
