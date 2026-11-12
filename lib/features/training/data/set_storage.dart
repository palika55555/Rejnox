import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../domain/training_models.dart';

/// Série uložené v telefóne. Každý používateľ má vlastný zoznam, aby sa
/// po prihlásení iného človeka na tom istom telefóne nič nepomiešalo.
abstract interface class LocalSetStore {
  Future<List<LoggedSet>> load(String userId);
  Future<void> save(String userId, List<LoggedSet> sets);
}

class PrefsSetStore implements LocalSetStore {
  const PrefsSetStore();

  static String _key(String userId) => 'rejnox_sets_v1_$userId';

  /// Synchronizované série staršie ako toto sa z telefónu upracú.
  static const _keepSynced = Duration(days: 14);

  @override
  Future<List<LoggedSet>> load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    if (raw == null) return [];
    try {
      return [
        for (final item in jsonDecode(raw) as List)
          LoggedSet.fromJson(item as Map<String, dynamic>),
      ];
    } on Object {
      // Poškodené dáta nesmú zablokovať appku.
      return [];
    }
  }

  @override
  Future<void> save(String userId, List<LoggedSet> sets) async {
    final cutoff = DateTime.now().subtract(_keepSynced);
    final kept = sets.where(
      (s) => s.state == SyncState.pending || s.performedAt.isAfter(cutoff),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(userId),
      jsonEncode([for (final s in kept) s.toJson()]),
    );
  }
}

/// Výsledok odoslania na server.
class SyncResponse {
  const SyncResponse({required this.accepted, required this.rejected});

  final Set<String> accepted;
  final Set<String> rejected;
}

abstract interface class TrainingApi {
  Future<SyncResponse> syncSets(String token, List<LoggedSet> sets);
}

class HttpTrainingApi implements TrainingApi {
  const HttpTrainingApi(this._api);

  final ApiClient _api;

  @override
  Future<SyncResponse> syncSets(String token, List<LoggedSet> sets) async {
    final json = await _api.send(
      'POST',
      '/sets/sync',
      token: token,
      body: {
        'sets': [for (final s in sets) s.toApiJson()],
      },
    );
    return SyncResponse(
      accepted: {for (final id in json['accepted'] as List) id as String},
      rejected: {
        for (final r in json['rejected'] as List)
          (r as Map<String, dynamic>)['id'] as String,
      },
    );
  }
}

final localSetStoreProvider = Provider<LocalSetStore>(
  (ref) => const PrefsSetStore(),
);

final trainingApiProvider = Provider<TrainingApi>(
  (ref) => HttpTrainingApi(ref.watch(apiClientProvider)),
);
