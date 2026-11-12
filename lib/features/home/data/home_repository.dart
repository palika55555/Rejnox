import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/home_overview.dart';

/// Zdroj dát pre domovskú obrazovku. Neskôr ho nahradí volanie na server.
abstract interface class HomeRepository {
  Future<HomeOverview> fetchOverview();
}

/// Dočasné ukážkové dáta, kým nie je pripojená databáza.
class DemoHomeRepository implements HomeRepository {
  const DemoHomeRepository();

  @override
  Future<HomeOverview> fetchOverview() async => const HomeOverview(
    userName: 'Pavol',
    streakDays: 14,
    weeklyGoal: WeeklyGoal(done: 4, total: 5),
    todayWorkout: Workout(
      title: 'Nohy & zadok',
      trainerName: 'Marek K.',
      minutes: 55,
      kcal: 480,
      exercises: [
        Exercise(
          name: 'Drep s činkou',
          shortName: 'Drep',
          sets: 4,
          reps: 6,
          weightKg: 120,
          note: '4 série • pauza 120 s',
          plate: Plate.red,
          isPr: true,
        ),
        Exercise(
          name: 'Rumunský mŕtvy ťah',
          shortName: 'RDL',
          sets: 3,
          reps: 8,
          weightKg: 90,
          note: '3 série • pauza 90 s',
          plate: Plate.blue,
        ),
        Exercise(
          name: 'Bulharské výpady',
          shortName: 'Výpady',
          sets: 3,
          reps: 10,
          weightKg: 20,
          note: '3 série na nohu',
          plate: Plate.yellow,
        ),
        Exercise(
          name: 'Hip thrust',
          shortName: 'Hip thrust',
          sets: 3,
          reps: 12,
          weightKg: 100,
          note: '3 série • pauza 90 s',
          plate: Plate.green,
        ),
        Exercise(
          name: 'Výpony na lýtka',
          shortName: 'Lýtka',
          sets: 4,
          reps: 15,
          weightKg: 60,
          note: '4 série • pauza 60 s',
          plate: Plate.red,
        ),
      ],
    ),
    personalRecord: PersonalRecord(
      exercise: 'Drep',
      weightKg: 140,
      monthDeltaKg: 5,
      trend: [125, 127.5, 130, 130, 135, 135, 140],
    ),
    ranking: Ranking(
      position: 14,
      region: 'SK',
      topPercent: 5,
      gymName: 'Gym Fit',
    ),
    nearbyGym: NearbyGym(
      name: 'Gym Fit Nitra',
      distanceKm: 0.8,
      occupancyPercent: 45,
    ),
    partnerRequest: PartnerRequest(
      name: 'Jakub',
      when: 'Dnes o 18:00',
      focus: 'Nohy & lýtka',
    ),
  );
}

final homeRepositoryProvider = Provider<HomeRepository>(
  (ref) => const DemoHomeRepository(),
);

final homeOverviewProvider = FutureProvider<HomeOverview>(
  (ref) => ref.watch(homeRepositoryProvider).fetchOverview(),
);
