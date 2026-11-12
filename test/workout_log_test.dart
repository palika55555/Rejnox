import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rejnox/features/auth/data/auth_repository.dart';
import 'package:rejnox/features/auth/domain/auth_models.dart';
import 'package:rejnox/features/auth/presentation/auth_controller.dart';
import 'package:rejnox/features/reminders/reminder_service.dart';
import 'package:rejnox/features/training/application/workout_log_controller.dart';
import 'package:rejnox/features/training/data/set_storage.dart';
import 'package:rejnox/features/training/domain/training_models.dart';

import 'fakes.dart';

const _squat = '00000000-0000-4000-8000-000000000001';

class _Tokens implements TokenStore {
  _Tokens(this.token);

  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String token) async => this.token = token;

  AuthUser? user;

  @override
  Future<AuthUser?> readUser() async => user;

  @override
  Future<void> writeUser(AuthUser user) async => this.user = user;

  @override
  Future<void> clear() async {
    token = null;
    user = null;
  }
}

class _Auth implements AuthRepository {
  static const user = AuthUser(
    id: 'user-1',
    email: 'a@test.sk',
    displayName: 'A',
    role: UserRole.member,
  );

  @override
  Future<AuthUser> me(String token) async => user;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) => throw UnimplementedError();

  @override
  Future<void> logout(String token) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemorySetStore store;
  late FakeTrainingApi api;
  late StreamController<bool> network;
  late ProviderContainer container;

  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  setUp(() async {
    store = MemorySetStore();
    api = FakeTrainingApi();
    network = StreamController<bool>.broadcast();
    container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(_Tokens('token')),
        authRepositoryProvider.overrideWithValue(_Auth()),
        localSetStoreProvider.overrideWithValue(store),
        trainingApiProvider.overrideWithValue(api),
        connectivityProvider.overrideWithValue(network.stream),
      ],
    );
    container.listen(workoutLogProvider, (_, _) {});
    await settle();
    expect(container.read(authControllerProvider), isA<SignedIn>());
  });

  tearDown(() async {
    container.dispose();
    await network.close();
  });

  WorkoutLogController controller() =>
      container.read(workoutLogProvider.notifier);
  WorkoutLogState state() => container.read(workoutLogProvider);

  test('bez internetu sa séria uloží do telefónu a čaká', () async {
    await controller().addSet(exerciseId: _squat, reps: 5, weightKg: 100);
    await settle();

    expect(state().sets.single.state, SyncState.pending);
    expect(state().offline, isTrue);
    expect(state().pendingCount, 1);
    expect(store.data['user-1']!.single.reps, 5);
  });

  test('po pripojení sa čakajúce série samy odošlú', () async {
    await controller().addSet(exerciseId: _squat, reps: 5, weightKg: 100);
    await controller().addSet(exerciseId: _squat, reps: 3, weightKg: 110);
    await settle();
    expect(state().pendingCount, 2);

    api.online = true;
    network.add(true);
    await settle();

    expect(state().pendingCount, 0);
    expect(state().offline, isFalse);
    expect(api.received, hasLength(2));
    expect(
      store.data['user-1']!.every((s) => s.state == SyncState.synced),
      isTrue,
    );
  });

  test('odoslaná séria sa druhýkrát neposiela', () async {
    api.online = true;
    await controller().addSet(exerciseId: _squat, reps: 5, weightKg: 100);
    await settle();
    await controller().sync();
    await settle();
    expect(api.received, hasLength(1));
  });

  test('odmietnutá séria sa prestane posielať', () async {
    api.online = true;
    api.rejectIds.add('x');
    await controller().addSet(exerciseId: _squat, reps: 5, weightKg: 100);
    await settle();
    final id = state().sets.single.id;

    // Druhá séria s ID, ktoré server odmietne.
    api.rejectIds.add(id);
    await store.save('user-1', [
      state().sets.single.withState(SyncState.pending),
    ]);
    container.invalidate(workoutLogProvider);
    container.listen(workoutLogProvider, (_, _) {});
    await settle();

    expect(state().sets.single.state, SyncState.rejected);
    expect(state().pendingCount, 0);
  });

  test('čakajúcu sériu sa dá zmazať', () async {
    await controller().addSet(exerciseId: _squat, reps: 5, weightKg: 100);
    await settle();
    await controller().removePending(state().sets.single.id);
    expect(state().sets, isEmpty);
    expect(store.data['user-1'], isEmpty);
  });

  test('série sa po reštarte appky načítajú z telefónu', () async {
    await controller().addSet(exerciseId: _squat, reps: 8, weightKg: 60);
    await settle();

    container.invalidate(workoutLogProvider);
    container.listen(workoutLogProvider, (_, _) {});
    await settle();

    expect(state().sets.single.reps, 8);
    expect(state().loaded, isTrue);
  });

  test('čas série sa po uložení a načítaní nezmení', () {
    final at = DateTime(2026, 11, 12, 17, 58);
    final set = LoggedSet(
      id: 'x',
      exerciseId: _squat,
      reps: 5,
      weightKg: 100,
      performedAt: at,
    );
    final restored = LoggedSet.fromJson(set.toJson());
    expect(restored.performedAt.isUtc, isFalse);
    expect(restored.performedAt.hour, 17);
    expect(restored.performedAt, at);
  });

  group('nextDailyOccurrence', () {
    test('ešte dnes, ak čas nenastal', () {
      expect(
        nextDailyOccurrence(DateTime(2026, 11, 12, 9), 18, 0),
        DateTime(2026, 11, 12, 18),
      );
    });

    test('zajtra, ak čas už bol', () {
      expect(
        nextDailyOccurrence(DateTime(2026, 11, 12, 19), 18, 0),
        DateTime(2026, 11, 13, 18),
      );
      expect(
        nextDailyOccurrence(DateTime(2026, 11, 30, 18), 18, 0),
        DateTime(2026, 12, 1, 18),
      );
    });
  });
}
