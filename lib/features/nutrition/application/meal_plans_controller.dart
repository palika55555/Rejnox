import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/nutrition_api.dart';
import '../domain/meal_plan.dart';

class MyMealPlans {
  const MyMealPlans(this.plans, {required this.offline});

  /// Najnovší prvý.
  final List<MealPlan> plans;

  /// Zobrazené z pamäte telefónu, nie čerstvé zo servera.
  final bool offline;

  MealPlan? get current => plans.isEmpty ? null : plans.first;
}

const _signedOut = ApiError(401, 'unauthorized', 'Prihlás sa, prosím.');

/// Jedálničky od trénera. Posledné načítané sa pamätajú v telefóne.
class MealPlansController extends AsyncNotifier<MyMealPlans> {
  NutritionApi get _api => ref.read(nutritionApiProvider);

  ({String userId, String token}) _session({bool watch = false}) {
    final auth = watch
        ? ref.watch(authControllerProvider)
        : ref.read(authControllerProvider);
    if (auth is! SignedIn) throw _signedOut;
    return (userId: auth.user.id, token: auth.token);
  }

  String _cacheKey(String userId) => 'rejnox_meal_plans_v1_$userId';

  @override
  Future<MyMealPlans> build() async {
    final session = _session(watch: true);
    final prefs = await SharedPreferences.getInstance();
    final key = _cacheKey(session.userId);
    try {
      final plans = await _api.myMealPlans(session.token);
      await prefs.setString(
        key,
        jsonEncode([for (final p in plans) p.toJson()]),
      );
      return MyMealPlans(plans, offline: false);
    } on ApiError catch (e) {
      if (e.code != 'network') rethrow;
      final raw = prefs.getString(key);
      return MyMealPlans([
        if (raw != null)
          for (final p in jsonDecode(raw) as List)
            MealPlan.fromJson(p as Map<String, dynamic>),
      ], offline: true);
    }
  }

  /// Odškrtne jedlo hneď v appke; keď server odmietne, vráti to späť.
  Future<void> toggle(
    String planId,
    MealItem item,
    DateTime date, {
    required bool eaten,
  }) async {
    final before = state.value;
    if (before == null) return;
    MyMealPlans apply(bool value) => MyMealPlans([
      for (final p in before.plans)
        p.id == planId ? p.withCheck(item.id, date, eaten: value) : p,
    ], offline: before.offline);

    state = AsyncData(apply(eaten));
    try {
      await _api.setEaten(_session().token, item.id, date, eaten: eaten);
    } on ApiError {
      state = AsyncData(apply(!eaten));
      rethrow;
    }
  }
}

final mealPlansProvider =
    AsyncNotifierProvider<MealPlansController, MyMealPlans>(
      MealPlansController.new,
    );
