import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/api_client.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/set_storage.dart';
import '../domain/training_models.dart';

class WorkoutLogState {
  const WorkoutLogState({
    this.sets = const [],
    this.loaded = false,
    this.syncing = false,
    this.offline = false,
  });

  /// Najnovšie hore.
  final List<LoggedSet> sets;
  final bool loaded;
  final bool syncing;

  /// Posledný pokus o odoslanie zlyhal na spojení.
  final bool offline;

  int get pendingCount =>
      sets.where((s) => s.state == SyncState.pending).length;

  WorkoutLogState copyWith({
    List<LoggedSet>? sets,
    bool? loaded,
    bool? syncing,
    bool? offline,
  }) => WorkoutLogState(
    sets: sets ?? this.sets,
    loaded: loaded ?? this.loaded,
    syncing: syncing ?? this.syncing,
    offline: offline ?? this.offline,
  );
}

/// Pripojenie k sieti (true = pripojené). Dá sa nahradiť v testoch.
final connectivityProvider = Provider<Stream<bool>>(
  (ref) => Connectivity().onConnectivityChanged
      .map((results) => !results.contains(ConnectivityResult.none))
      // Bez sledovania siete appka funguje ďalej (skúša odoslať každých 30 s).
      .handleError((Object _) {}),
);

/// Zápis tréningu: najprv do telefónu, potom na server, keď je spojenie.
class WorkoutLogController extends Notifier<WorkoutLogState> {
  static const _retryEvery = Duration(seconds: 30);
  static const _batchSize = 200;

  String? _userId;
  String? _token;
  bool _syncing = false;
  bool _syncAgain = false;

  LocalSetStore get _store => ref.read(localSetStoreProvider);
  TrainingApi get _api => ref.read(trainingApiProvider);

  @override
  WorkoutLogState build() {
    final auth = ref.watch(authControllerProvider);
    if (auth is! SignedIn) {
      _userId = null;
      _token = null;
      return const WorkoutLogState();
    }
    _userId = auth.user.id;
    _token = auth.token;

    final retry = Timer.periodic(_retryEvery, (_) {
      if (state.pendingCount > 0) sync();
    });
    final online = ref.read(connectivityProvider).listen((connected) {
      if (connected) sync();
    });
    final lifecycle = AppLifecycleListener(onResume: sync);
    ref.onDispose(() {
      retry.cancel();
      online.cancel();
      lifecycle.dispose();
    });

    _load(auth.user.id);
    return const WorkoutLogState();
  }

  /// Uloží série do telefónu. Chyba úložiska nesmie zastaviť odosielanie.
  Future<void> _persist(String userId) async {
    try {
      await _store.save(userId, state.sets);
    } on Object catch (e, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: stack, library: 'rejnox'),
      );
    }
  }

  Future<void> _load(String userId) async {
    List<LoggedSet> sets;
    try {
      sets = await _store.load(userId);
    } on Object {
      sets = [];
    }
    if (_userId != userId) return;
    sets.sort((a, b) => b.performedAt.compareTo(a.performedAt));
    state = state.copyWith(sets: sets, loaded: true);
    await sync();
  }

  /// Zapíše sériu. Uloží sa okamžite do telefónu, aj bez internetu.
  Future<void> addSet({
    required String exerciseId,
    required int reps,
    required double weightKg,
  }) async {
    final userId = _userId;
    if (userId == null) return;
    final set = LoggedSet(
      id: const Uuid().v4(),
      exerciseId: exerciseId,
      reps: reps,
      weightKg: weightKg,
      performedAt: DateTime.now(),
    );
    state = state.copyWith(sets: [set, ...state.sets]);
    await _persist(userId);
    unawaited(sync());
  }

  /// Zmazať sa dá len séria, ktorá ešte neodišla na server.
  Future<void> removePending(String id) async {
    final userId = _userId;
    if (userId == null) return;
    state = state.copyWith(
      sets: [
        for (final s in state.sets)
          if (!(s.id == id && s.state == SyncState.pending)) s,
      ],
    );
    await _persist(userId);
  }

  /// Pošle čakajúce série na server. Bezpečné volať kedykoľvek a opakovane.
  Future<void> sync() async {
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    final userId = _userId;
    final token = _token;
    if (userId == null || token == null) return;

    final pending = state.sets
        .where((s) => s.state == SyncState.pending)
        .take(_batchSize)
        .toList();
    if (pending.isEmpty) {
      if (state.offline) state = state.copyWith(offline: false);
      return;
    }

    _syncing = true;
    state = state.copyWith(syncing: true);
    try {
      final result = await _api.syncSets(token, pending);
      if (_userId != userId) return;
      state = state.copyWith(
        offline: false,
        sets: [
          for (final s in state.sets)
            if (result.accepted.contains(s.id))
              s.withState(SyncState.synced)
            else if (result.rejected.contains(s.id))
              s.withState(SyncState.rejected)
            else
              s,
        ],
      );
      await _persist(userId);
      // Ak čakalo viac ako jedna dávka, pošle sa ďalšia.
      if (state.pendingCount > 0 && result.accepted.isNotEmpty) {
        _syncAgain = true;
      }
    } on ApiError catch (e) {
      // Série ostávajú v telefóne a pošlú sa pri ďalšom pokuse.
      if (_userId == userId) {
        state = state.copyWith(offline: e.code == 'network');
      }
    } finally {
      _syncing = false;
      if (_userId == userId) state = state.copyWith(syncing: false);
      if (_syncAgain) {
        _syncAgain = false;
        unawaited(sync());
      }
    }
  }
}

final workoutLogProvider =
    NotifierProvider<WorkoutLogController, WorkoutLogState>(
      WorkoutLogController.new,
    );
