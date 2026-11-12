import 'package:rejnox/core/api/api_client.dart';
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
