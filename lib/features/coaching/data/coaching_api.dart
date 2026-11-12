import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/coaching_models.dart';

/// Nový cvik do plánu (z formulára trénera).
class NewPlanItem {
  const NewPlanItem({
    required this.exerciseId,
    required this.sets,
    required this.reps,
    this.weightKg,
  });

  final String exerciseId;
  final int sets;
  final int reps;
  final double? weightKg;

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'sets': sets,
    'reps': reps,
    if (weightKg != null) 'weightKg': weightKg,
  };
}

abstract interface class CoachingApi {
  // Tréner.
  Future<List<ClientLink>> clients(String token);
  Future<ClientLink> addClient(
    String token, {
    required String name,
    String? note,
  });
  Future<ClientDetail> client(String token, String id);
  Future<InviteCode> invite(String token, String clientId);
  Future<void> endClient(String token, String clientId);
  Future<void> deleteClient(String token, String clientId);
  Future<Plan> addPlan(
    String token,
    String clientId, {
    required String title,
    DateTime? scheduledOn,
    required List<NewPlanItem> items,
  });
  Future<void> deletePlan(String token, String clientId, String planId);
  Future<void> logSet(
    String token,
    String clientId, {
    required String id,
    required String exerciseId,
    required int reps,
    required double weightKg,
  });

  // Klient.
  Future<MyTrainer> acceptInvite(String token, String code);
  Future<List<MyTrainer>> myTrainers(String token);
  Future<void> endTrainer(String token, String linkId);
  Future<List<Plan>> myPlans(String token);
}

class HttpCoachingApi implements CoachingApi {
  const HttpCoachingApi(this._api);

  final ApiClient _api;

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Future<List<ClientLink>> clients(String token) async {
    final json = await _api.send('GET', '/clients', token: token);
    return [
      for (final c in json['clients'] as List)
        ClientLink.fromJson(c as Map<String, dynamic>),
    ];
  }

  @override
  Future<ClientLink> addClient(
    String token, {
    required String name,
    String? note,
  }) async => ClientLink.fromJson(
    await _api.send(
      'POST',
      '/clients',
      token: token,
      body: {'name': name, if (note != null && note.isNotEmpty) 'note': note},
    ),
  );

  @override
  Future<ClientDetail> client(String token, String id) async =>
      ClientDetail.fromJson(
        await _api.send('GET', '/clients/$id', token: token),
      );

  @override
  Future<InviteCode> invite(String token, String clientId) async {
    final json = await _api.send(
      'POST',
      '/clients/$clientId/invite',
      token: token,
    );
    return InviteCode(
      code: json['code'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String).toLocal(),
    );
  }

  @override
  Future<void> endClient(String token, String clientId) =>
      _api.send('POST', '/clients/$clientId/end', token: token);

  @override
  Future<void> deleteClient(String token, String clientId) =>
      _api.send('DELETE', '/clients/$clientId', token: token);

  @override
  Future<Plan> addPlan(
    String token,
    String clientId, {
    required String title,
    DateTime? scheduledOn,
    required List<NewPlanItem> items,
  }) async => Plan.fromJson(
    await _api.send(
      'POST',
      '/clients/$clientId/workouts',
      token: token,
      body: {
        'title': title,
        if (scheduledOn != null) 'scheduledOn': _date(scheduledOn),
        'exercises': [for (final i in items) i.toJson()],
      },
    ),
  );

  @override
  Future<void> deletePlan(String token, String clientId, String planId) =>
      _api.send('DELETE', '/clients/$clientId/workouts/$planId', token: token);

  @override
  Future<void> logSet(
    String token,
    String clientId, {
    required String id,
    required String exerciseId,
    required int reps,
    required double weightKg,
  }) => _api.send(
    'POST',
    '/clients/$clientId/sets',
    token: token,
    body: {
      'id': id,
      'exerciseId': exerciseId,
      'reps': reps,
      'weightKg': weightKg,
    },
  );

  @override
  Future<MyTrainer> acceptInvite(String token, String code) async =>
      MyTrainer.fromJson(
        await _api.send(
          'POST',
          '/invites/accept',
          token: token,
          body: {'code': code},
        ),
      );

  @override
  Future<List<MyTrainer>> myTrainers(String token) async {
    final json = await _api.send('GET', '/me/trainers', token: token);
    return [
      for (final t in json['trainers'] as List)
        MyTrainer.fromJson(t as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> endTrainer(String token, String linkId) =>
      _api.send('POST', '/me/trainers/$linkId/end', token: token);

  @override
  Future<List<Plan>> myPlans(String token) async {
    final json = await _api.send('GET', '/me/plans', token: token);
    return [
      for (final p in json['plans'] as List)
        Plan.fromJson(p as Map<String, dynamic>),
    ];
  }
}

final coachingApiProvider = Provider<CoachingApi>(
  (ref) => HttpCoachingApi(ref.watch(apiClientProvider)),
);
