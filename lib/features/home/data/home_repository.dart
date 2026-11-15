import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/home_overview.dart';

/// Zdroj dát pre domovskú obrazovku.
abstract interface class HomeRepository {
  Future<HomeOverview> fetchOverview(String token);
}

/// Prehľad zo servera: séria, týždenný cieľ, dnešný plán a osobný rekord.
class HttpHomeRepository implements HomeRepository {
  const HttpHomeRepository(this._api);

  final ApiClient _api;

  @override
  Future<HomeOverview> fetchOverview(String token) async =>
      HomeOverview.fromJson(await _api.send('GET', '/home', token: token));
}

final homeRepositoryProvider = Provider<HomeRepository>(
  (ref) => HttpHomeRepository(ref.watch(apiClientProvider)),
);

/// Pri každom návrate na domovskú obrazovku sa načíta znova (autoDispose),
/// aby sa po tréningu ukázala nová séria a rekord.
final homeOverviewProvider = FutureProvider.autoDispose<HomeOverview>((ref) {
  final token = switch (ref.watch(authControllerProvider)) {
    SignedIn(:final token) => token,
    _ => null,
  };
  if (token == null) throw const ApiError(401, 'unauthorized', 'Prihlás sa.');
  return ref.watch(homeRepositoryProvider).fetchOverview(token);
});
