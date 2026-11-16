import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/meal_plan.dart';

abstract interface class NutritionApi {
  /// Odoslané jedálničky od mojich trénerov, najnovší prvý.
  Future<List<MealPlan>> myMealPlans(String token);

  /// Odškrtne (alebo zruší) zjedené jedlo v daný deň.
  Future<void> setEaten(
    String token,
    String itemId,
    DateTime date, {
    required bool eaten,
  });
}

class HttpNutritionApi implements NutritionApi {
  const HttpNutritionApi(this._api);

  final ApiClient _api;

  @override
  Future<List<MealPlan>> myMealPlans(String token) async {
    final json = await _api.send('GET', '/me/meal-plans', token: token);
    return [
      for (final p in json['mealPlans'] as List)
        MealPlan.fromJson(p as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> setEaten(
    String token,
    String itemId,
    DateTime date, {
    required bool eaten,
  }) => _api.send(
    eaten ? 'PUT' : 'DELETE',
    '/me/meal-items/$itemId/checks/${dayKey(date)}',
    token: token,
  );
}

final nutritionApiProvider = Provider<NutritionApi>(
  (ref) => HttpNutritionApi(ref.watch(apiClientProvider)),
);
