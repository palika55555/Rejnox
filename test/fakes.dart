import 'package:rejnox/core/api/api_client.dart';
import 'package:rejnox/features/coaching/data/coaching_api.dart';
import 'package:rejnox/features/coaching/domain/coaching_models.dart';
import 'package:rejnox/features/reminders/reminder_service.dart';
import 'package:rejnox/features/training/data/set_storage.dart';
import 'package:rejnox/features/training/domain/training_models.dart';

class MemorySetStore implements LocalSetStore {
  final data = <String, List<LoggedSet>>{};

  @override
  Future<List<LoggedSet>> load(String userId) async => [...?data[userId]];

  @override
  Future<void> save(String userId, List<LoggedSet> sets) async =>
      data[userId] = [...sets];
}

/// Falošný server: keď [online] je false, správa sa ako bez internetu.
class FakeTrainingApi implements TrainingApi {
  bool online = false;
  final rejectIds = <String>{};
  final received = <String>[];

  @override
  Future<SyncResponse> syncSets(String token, List<LoggedSet> sets) async {
    if (!online) throw const ApiError.network();
    received.addAll(sets.map((s) => s.id));
    return SyncResponse(
      accepted: {
        for (final s in sets)
          if (!rejectIds.contains(s.id)) s.id,
      },
      rejected: {
        for (final s in sets)
          if (rejectIds.contains(s.id)) s.id,
      },
    );
  }
}

/// Pripomienky v testoch nič neplánujú.
class FakeReminderScheduler implements ReminderScheduler {
  FakeReminderScheduler({this.supported = false});

  @override
  final bool supported;

  final scheduled = <(int, int)>[];

  @override
  Future<bool> scheduleDaily(int hour, int minute) async {
    scheduled.add((hour, minute));
    return true;
  }

  @override
  Future<void> cancel() async => scheduled.clear();
}

/// Falošné API trénera a klienta v pamäti.
class FakeCoachingApi implements CoachingApi {
  final clientsList = <ClientLink>[];
  final trainers = <MyTrainer>[];
  final plans = <Plan>[];
  String validCode = 'K7QM4XPA';
  int _next = 0;

  ClientLink _find(String id) => clientsList.firstWhere((c) => c.id == id);

  void _replace(ClientLink c) {
    final i = clientsList.indexWhere((x) => x.id == c.id);
    clientsList[i] = c;
  }

  @override
  Future<List<ClientLink>> clients(String token) async => [...clientsList];

  @override
  Future<ClientLink> addClient(
    String token, {
    required String name,
    String? note,
  }) async {
    final c = ClientLink(
      id: 'c${_next++}',
      name: name,
      note: note,
      status: LinkStatus.recordOnly,
      hasAccount: false,
    );
    clientsList.add(c);
    return c;
  }

  @override
  Future<ClientDetail> client(String token, String id) async =>
      ClientDetail(client: _find(id), plans: [...plans], sets: const []);

  @override
  Future<InviteCode> invite(String token, String clientId) async {
    final c = _find(clientId);
    _replace(
      ClientLink(
        id: c.id,
        name: c.name,
        note: c.note,
        status: LinkStatus.invited,
        hasAccount: false,
        inviteExpiresAt: DateTime(2030),
      ),
    );
    return InviteCode(code: 'K7QM-4XPA', expiresAt: DateTime(2030));
  }

  @override
  Future<void> endClient(String token, String clientId) async {}

  @override
  Future<void> deleteClient(String token, String clientId) async =>
      clientsList.removeWhere((c) => c.id == clientId);

  @override
  Future<Plan> addPlan(
    String token,
    String clientId, {
    required String title,
    DateTime? scheduledOn,
    required List<NewPlanItem> items,
  }) async {
    final plan = Plan(
      id: 'p${_next++}',
      title: title,
      trainerName: 'Marek',
      scheduledOn: scheduledOn,
      items: const [],
    );
    plans.add(plan);
    return plan;
  }

  @override
  Future<void> deletePlan(String token, String clientId, String planId) async =>
      plans.removeWhere((p) => p.id == planId);

  @override
  Future<void> logSet(
    String token,
    String clientId, {
    required String id,
    required String exerciseId,
    required int reps,
    required double weightKg,
  }) async {}

  @override
  Future<MyTrainer> acceptInvite(String token, String code) async {
    if (code != validCode) {
      throw const ApiError(
        404,
        'invalid_code',
        'Kód neplatí alebo už vypršal.',
      );
    }
    const t = MyTrainer(
      linkId: 'l1',
      trainerName: 'Marek',
      status: LinkStatus.linked,
    );
    trainers.add(t);
    return t;
  }

  @override
  Future<List<MyTrainer>> myTrainers(String token) async => [...trainers];

  @override
  Future<void> endTrainer(String token, String linkId) async =>
      trainers.removeWhere((t) => t.linkId == linkId);

  @override
  Future<List<Plan>> myPlans(String token) async => [...plans];
}
