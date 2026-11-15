import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/progress_models.dart';

/// Zdroj dát pre obrazovku Progres.
abstract interface class ProgressRepository {
  Future<ProgressOverview> fetch(String token);
}

/// Prehľad zo servera: týždne, rekordy cvikov a partie.
class HttpProgressRepository implements ProgressRepository {
  const HttpProgressRepository(this._api);

  final ApiClient _api;

  @override
  Future<ProgressOverview> fetch(String token) async =>
      ProgressOverview.fromJson(
        await _api.send('GET', '/progress', token: token),
      );
}

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => HttpProgressRepository(ref.watch(apiClientProvider)),
);

/// Pri každom otvorení sa načíta znova, aby boli vidno aj dnešné série.
final progressProvider = FutureProvider.autoDispose<ProgressOverview>((ref) {
  final token = switch (ref.watch(authControllerProvider)) {
    SignedIn(:final token) => token,
    _ => null,
  };
  if (token == null) throw const ApiError(401, 'unauthorized', 'Prihlás sa.');
  return ref.watch(progressRepositoryProvider).fetch(token);
});
