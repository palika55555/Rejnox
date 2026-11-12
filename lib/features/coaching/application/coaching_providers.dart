import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/api_client.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/coaching_api.dart';
import '../domain/coaching_models.dart';

const _signedOut = ApiError(401, 'unauthorized', 'Prihlás sa, prosím.');

({String userId, String token}) _fromAuth(AuthState auth) {
  if (auth is! SignedIn) throw _signedOut;
  return (userId: auth.user.id, token: auth.token);
}

/// Prihlásený používateľ pri načítaní dát (sleduje zmenu prihlásenia).
({String userId, String token}) _session(Ref ref) =>
    _fromAuth(ref.watch(authControllerProvider));

/// Prihlásený používateľ pri akcii (kliknutí); nesleduje, len prečíta.
({String userId, String token}) _current(Ref ref) =>
    _fromAuth(ref.read(authControllerProvider));

// ------------------------------------------------------------------ tréner

/// Zoznam klientov trénera.
class ClientsController extends AsyncNotifier<List<ClientLink>> {
  CoachingApi get _api => ref.read(coachingApiProvider);

  @override
  Future<List<ClientLink>> build() =>
      ref.read(coachingApiProvider).clients(_session(ref).token);

  Future<ClientLink> add({required String name, String? note}) async {
    final client = await _api.addClient(
      _current(ref).token,
      name: name,
      note: note,
    );
    ref.invalidateSelf();
    return client;
  }
}

final clientsProvider =
    AsyncNotifierProvider<ClientsController, List<ClientLink>>(
      ClientsController.new,
    );

/// Detail klienta a akcie trénera nad ním.
final clientDetailProvider = FutureProvider.autoDispose
    .family<ClientDetail, String>(
      (ref, id) =>
          ref.watch(coachingApiProvider).client(_session(ref).token, id),
    );

class ClientActions {
  ClientActions(this._ref, this.clientId);

  final Ref _ref;
  final String clientId;

  CoachingApi get _api => _ref.read(coachingApiProvider);
  String get _token => _current(_ref).token;

  void _refresh() {
    _ref.invalidate(clientDetailProvider(clientId));
    _ref.invalidate(clientsProvider);
  }

  Future<InviteCode> invite() async {
    final code = await _api.invite(_token, clientId);
    _refresh();
    return code;
  }

  Future<void> end() async {
    await _api.endClient(_token, clientId);
    _refresh();
  }

  Future<void> delete() async {
    await _api.deleteClient(_token, clientId);
    _ref.invalidate(clientsProvider);
  }

  Future<void> addPlan({
    required String title,
    DateTime? scheduledOn,
    required List<NewPlanItem> items,
  }) async {
    await _api.addPlan(
      _token,
      clientId,
      title: title,
      scheduledOn: scheduledOn,
      items: items,
    );
    _refresh();
  }

  Future<void> deletePlan(String planId) async {
    await _api.deletePlan(_token, clientId, planId);
    _refresh();
  }

  Future<void> logSet({
    required String exerciseId,
    required int reps,
    required double weightKg,
  }) async {
    await _api.logSet(
      _token,
      clientId,
      id: const Uuid().v4(),
      exerciseId: exerciseId,
      reps: reps,
      weightKg: weightKg,
    );
    _refresh();
  }
}

// Bez autoDispose: akcie sa čítajú pri kliknutí (ref.read) a musia prežiť
// celé čakanie na server.
final clientActionsProvider = Provider.family<ClientActions, String>(
  ClientActions.new,
);

// ------------------------------------------------------------------ klient

class MyTrainersController extends AsyncNotifier<List<MyTrainer>> {
  CoachingApi get _api => ref.read(coachingApiProvider);

  @override
  Future<List<MyTrainer>> build() =>
      ref.read(coachingApiProvider).myTrainers(_session(ref).token);

  Future<MyTrainer> acceptCode(String code) async {
    final trainer = await _api.acceptInvite(_current(ref).token, code);
    ref.invalidateSelf();
    ref.invalidate(myPlansProvider);
    return trainer;
  }

  Future<void> end(String linkId) async {
    await _api.endTrainer(_current(ref).token, linkId);
    ref.invalidateSelf();
  }
}

final myTrainersProvider =
    AsyncNotifierProvider<MyTrainersController, List<MyTrainer>>(
      MyTrainersController.new,
    );

/// Plány od trénera. Posledné načítané sa pamätajú v telefóne,
/// takže ich klient vidí aj vo fitku bez signálu.
final myPlansProvider = FutureProvider<MyPlans>((ref) async {
  final session = _session(ref);
  final key = 'rejnox_plans_v1_${session.userId}';
  final prefs = await SharedPreferences.getInstance();
  try {
    final plans = await ref.read(coachingApiProvider).myPlans(session.token);
    await prefs.setString(key, jsonEncode([for (final p in plans) p.toJson()]));
    return MyPlans(plans, offline: false);
  } on ApiError catch (e) {
    if (e.code != 'network') rethrow;
    final raw = prefs.getString(key);
    final cached = raw == null
        ? <Plan>[]
        : [
            for (final p in jsonDecode(raw) as List)
              Plan.fromJson(p as Map<String, dynamic>),
          ];
    return MyPlans(cached, offline: true);
  }
});

class MyPlans {
  const MyPlans(this.plans, {required this.offline});

  final List<Plan> plans;

  /// Zobrazené z pamäte telefónu, nie čerstvé zo servera.
  final bool offline;
}
