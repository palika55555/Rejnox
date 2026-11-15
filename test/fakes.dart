import 'dart:ui';

import 'package:rejnox/core/api/api_client.dart';
import 'package:rejnox/features/coaching/data/coaching_api.dart';
import 'package:rejnox/features/coaching/domain/coaching_models.dart';
import 'package:rejnox/features/gyms/application/gym_actions.dart';
import 'package:rejnox/features/gyms/application/user_location.dart';
import 'package:rejnox/features/gyms/data/gym_repository.dart';
import 'package:rejnox/core/theme/app_colors.dart';
import 'package:rejnox/features/gyms/domain/gym.dart';
import 'package:rejnox/features/home/data/home_repository.dart';
import 'package:rejnox/features/home/domain/home_overview.dart' as home;
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

/// Prehľad domovskej obrazovky bez servera.
class FakeHomeRepository implements HomeRepository {
  FakeHomeRepository([this.overview = sampleOverview]);

  home.HomeOverview overview;
  int calls = 0;

  static const empty = home.HomeOverview(
    streakDays: 0,
    weeklyGoal: home.WeeklyGoal(done: 0, total: 3),
    todayWorkout: null,
    personalRecord: null,
  );

  static const sampleOverview = home.HomeOverview(
    streakDays: 14,
    weeklyGoal: home.WeeklyGoal(done: 4, total: 5),
    todayWorkout: home.Workout(
      title: 'Nohy & zadok',
      trainerName: 'Marek',
      exercises: [
        home.Exercise(
          name: 'Drep s činkou',
          shortName: 'Drep s činkou',
          sets: 4,
          reps: 6,
          weightKg: 120,
          note: '4 série',
          plate: Plate.red,
        ),
        home.Exercise(
          name: 'Rumunský mŕtvy ťah',
          shortName: 'Rumunský mŕtvy ťah',
          sets: 3,
          reps: 8,
          weightKg: 90,
          note: '3 série',
          plate: Plate.blue,
        ),
        home.Exercise(
          name: 'Bulharské výpady',
          shortName: 'Bulharské výpady',
          sets: 3,
          reps: 10,
          weightKg: null,
          note: 'na každú nohu',
          plate: Plate.yellow,
        ),
        home.Exercise(
          name: 'Hip thrust',
          shortName: 'Hip thrust',
          sets: 3,
          reps: 12,
          weightKg: 100,
          note: '3 série',
          plate: Plate.green,
        ),
        home.Exercise(
          name: 'Výpony na lýtka',
          shortName: 'Výpony na lýtka',
          sets: 4,
          reps: 15,
          weightKg: 60,
          note: '4 série',
          plate: Plate.red,
        ),
      ],
    ),
    personalRecord: home.PersonalRecord(
      exercise: 'Drep',
      weightKg: 140,
      monthDeltaKg: 5,
      trend: [125, 130, 135, 140],
    ),
  );

  @override
  Future<home.HomeOverview> fetchOverview(String token) async {
    calls++;
    return overview;
  }
}

class FakeLocationSource implements LocationSource {
  FakeLocationSource([
    this.result = const LocationFound(GeoPoint(48.3, 18.08)),
  ]);

  UserLocation result;
  int calls = 0;
  final opened = <LocationIssue>[];

  @override
  Future<UserLocation> current() async {
    calls++;
    return result;
  }

  @override
  Future<void> openSettings(LocationIssue issue) async => opened.add(issue);
}

class FakeExternalActions implements ExternalActions {
  final opened = <Uri>[];
  final shared = <String>[];
  bool canOpen = true;

  @override
  Future<bool> openUrl(Uri url) async {
    opened.add(url);
    return canOpen;
  }

  @override
  Future<void> share(String text, {String? subject, Rect? origin}) async =>
      shared.add(text);
}

class FakeGymRepository implements GymRepository {
  FakeGymRepository(this.gyms);

  List<Gym> gyms;
  bool fail = false;
  final ratings = <String, int?>{};

  @override
  Future<List<Gym>> fetchGyms(String token) async {
    if (fail) throw const ApiError.network();
    return gyms;
  }

  Gym _withMine(String gymId, int? stars) {
    if (fail) throw const ApiError.network();
    ratings[gymId] = stars;
    final gym = gyms.firstWhere((g) => g.id == gymId);
    final counts = [
      ...gym.rating?.stars ?? [0, 0, 0, 0, 0],
    ];
    if (gym.myStars != null) counts[gym.myStars! - 1]--;
    if (stars != null) counts[stars - 1]++;
    final updated = Gym(
      id: gym.id,
      name: gym.name,
      city: gym.city,
      location: gym.location,
      openingHours: gym.openingHours,
      tags: gym.tags,
      rating: GymRating(stars: counts),
      myStars: stars,
    );
    gyms = [for (final g in gyms) g.id == gymId ? updated : g];
    return updated;
  }

  @override
  Future<Gym> rate(String token, String gymId, int stars) async =>
      _withMine(gymId, stars);

  @override
  Future<Gym> unrate(String token, String gymId) async =>
      _withMine(gymId, null);
}
