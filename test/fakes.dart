import 'dart:ui';

import 'package:rejnox/core/api/api_client.dart';
import 'package:rejnox/features/coaching/data/coaching_api.dart';
import 'package:rejnox/features/coaching/domain/coaching_models.dart';
import 'package:rejnox/features/gyms/application/gym_actions.dart';
import 'package:rejnox/features/gyms/application/user_location.dart';
import 'package:rejnox/features/gyms/application/gym_photo_picker.dart';
import 'package:rejnox/features/gyms/data/gym_repository.dart';
import 'package:rejnox/core/theme/app_colors.dart';
import 'package:rejnox/features/gyms/domain/gym.dart';
import 'package:rejnox/features/home/data/home_repository.dart';
import 'package:rejnox/features/home/domain/home_overview.dart' as home;
import 'package:rejnox/features/progress/data/progress_repository.dart';
import 'package:rejnox/features/progress/domain/progress_models.dart';
import 'package:rejnox/features/reminders/reminder_service.dart';
import 'package:rejnox/features/training/data/set_storage.dart';
import 'package:rejnox/features/training/domain/training_models.dart';
import 'package:rejnox/features/training/application/rest_alerts.dart';

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

/// Progres bez servera: odpoveď v tvare, aký posiela GET /progress.
class FakeProgressRepository implements ProgressRepository {
  FakeProgressRepository([Map<String, dynamic>? json])
    : json = json ?? sampleJson;

  final Map<String, dynamic> json;

  static Map<String, dynamic> get sampleJson => {
    'totals': {'trainingDays': 24, 'sets': 310, 'volumeKg': 48250},
    'month': {'days': 9, 'sets': 112, 'volumeKg': 16400, 'prevVolumeKg': 14000},
    'weeks': [
      for (var i = 0; i < 12; i++)
        {
          'start': DateTime(
            2026,
            8,
            24,
          ).add(Duration(days: 7 * i)).toIso8601String().substring(0, 10),
          'days': i % 4 == 0 ? 0 : 2,
          'sets': i % 4 == 0 ? 0 : 20,
          'volumeKg': i % 4 == 0 ? 0 : 3000 + 200 * i,
        },
    ],
    'exercises': [
      {
        'exerciseId': '00000000-0000-4000-8000-000000000001',
        'name': 'Drep s činkou',
        'muscleGroup': 'nohy',
        'bestKg': 120,
        'bestE1rmKg': 138.5,
        'firstKg': 100,
        'lastDay': '2026-11-14',
        'days': 8,
        'trend': [
          {'day': '2026-10-01', 'kg': 100},
          {'day': '2026-10-15', 'kg': 110},
          {'day': '2026-11-14', 'kg': 120},
        ],
      },
    ],
    'muscles': [
      {'muscleGroup': 'nohy', 'sets': 40},
      {'muscleGroup': 'hrudnik', 'sets': 22},
    ],
  };

  static Map<String, dynamic> get emptyJson => {
    'totals': {'trainingDays': 0, 'sets': 0, 'volumeKg': 0},
    'month': {'days': 0, 'sets': 0, 'volumeKg': 0, 'prevVolumeKg': 0},
    'weeks': <Object>[],
    'exercises': <Object>[],
    'muscles': <Object>[],
  };

  @override
  Future<ProgressOverview> fetch(String token) async =>
      ProgressOverview.fromJson(json);
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
  final uploads = <List<int>>[];
  var _nextId = 0;

  @override
  Future<List<Gym>> fetchGyms(String token) async {
    if (fail) throw const ApiError.network();
    return gyms;
  }

  /// Kópia fitka so zmenenými poľami (ako by ho vrátil server).
  Gym _replace(
    String gymId, {
    GymRating? rating,
    int? Function()? myStars,
    List<GymPhoto>? photos,
    List<GymPrice>? prices,
  }) {
    if (fail) throw const ApiError.network();
    final gym = gyms.firstWhere((g) => g.id == gymId);
    final updated = Gym(
      id: gym.id,
      name: gym.name,
      city: gym.city,
      address: gym.address,
      location: gym.location,
      openingHours: gym.openingHours,
      tags: gym.tags,
      website: gym.website,
      photoUrls: gym.photoUrls,
      photos: photos ?? gym.photos,
      prices: prices ?? gym.prices,
      mine: gym.mine,
      rating: rating ?? gym.rating,
      myStars: myStars == null ? gym.myStars : myStars(),
    );
    gyms = [for (final g in gyms) g.id == gymId ? updated : g];
    return updated;
  }

  Gym _withMine(String gymId, int? stars) {
    ratings[gymId] = stars;
    final gym = gyms.firstWhere((g) => g.id == gymId);
    final counts = [
      ...gym.rating?.stars ?? [0, 0, 0, 0, 0],
    ];
    if (gym.myStars != null) counts[gym.myStars! - 1]--;
    if (stars != null) counts[stars - 1]++;
    return _replace(
      gymId,
      rating: GymRating(stars: counts),
      myStars: () => stars,
    );
  }

  @override
  Future<Gym> rate(String token, String gymId, int stars) async =>
      _withMine(gymId, stars);

  @override
  Future<Gym> unrate(String token, String gymId) async =>
      _withMine(gymId, null);

  Gym _fromDraft(String id, GymDraft draft) => Gym(
    id: id,
    name: draft.name,
    city: draft.city,
    address: draft.address,
    location: draft.location,
    openingHours: draft.openingHours,
    tags: draft.tags,
    website: draft.website == null ? null : Uri.parse(draft.website!),
    mine: true,
  );

  @override
  Future<Gym> create(String token, GymDraft draft) async {
    if (fail) throw const ApiError.network();
    final gym = _fromDraft('new-${_nextId++}', draft);
    gyms = [...gyms, gym];
    return gym;
  }

  @override
  Future<Gym> update(String token, String gymId, GymDraft draft) async {
    if (fail) throw const ApiError.network();
    final gym = _fromDraft(gymId, draft);
    gyms = [for (final g in gyms) g.id == gymId ? gym : g];
    return gym;
  }

  @override
  Future<void> delete(String token, String gymId) async {
    if (fail) throw const ApiError.network();
    gyms = [
      for (final g in gyms)
        if (g.id != gymId) g,
    ];
  }

  @override
  Future<Gym> addPhoto(String token, String gymId, List<int> bytes) async {
    uploads.add(bytes);
    final gym = gyms.firstWhere((g) => g.id == gymId);
    return _replace(
      gymId,
      photos: [
        ...gym.photos,
        GymPhoto(id: 'p${_nextId++}', mine: true),
      ],
    );
  }

  @override
  Future<Gym> deletePhoto(String token, String photoId) async {
    final gym = gyms.firstWhere((g) => g.photos.any((p) => p.id == photoId));
    return _replace(
      gym.id,
      photos: [
        for (final p in gym.photos)
          if (p.id != photoId) p,
      ],
    );
  }

  @override
  Future<Gym> addPrice(
    String token,
    String gymId, {
    required GymPriceKind kind,
    required String title,
    required int priceCents,
    String? period,
  }) async {
    final gym = gyms.firstWhere((g) => g.id == gymId);
    return _replace(
      gymId,
      prices: [
        ...gym.prices,
        GymPrice(
          id: 'c${_nextId++}',
          kind: kind,
          title: title,
          priceCents: priceCents,
          period: period,
          mine: true,
        ),
      ],
    );
  }

  @override
  Future<Gym> deletePrice(String token, String priceId) async {
    final gym = gyms.firstWhere((g) => g.prices.any((p) => p.id == priceId));
    return _replace(
      gym.id,
      prices: [
        for (final p in gym.prices)
          if (p.id != priceId) p,
      ],
    );
  }
}

/// Výber fotky bez galérie: vráti pripravené bajty.
class FakeGymPhotoPicker implements GymPhotoPicker {
  List<int>? next = const [0xff, 0xd8, 0xff, 0xe0];
  bool fail = false;

  @override
  Future<List<int>?> pick(PhotoSource source) async {
    if (fail) throw const PhotoPickFailed();
    return next;
  }
}

/// Zaznamená odpočty pauzy namiesto systémových upozornení.
class FakeRestAlerts implements RestAlerts {
  DateTime? end;
  int cancels = 0;

  @override
  Future<void> start(DateTime end) async => this.end = end;

  @override
  Future<void> cancel() async {
    end = null;
    cancels++;
  }
}
