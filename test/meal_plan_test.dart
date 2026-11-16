import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rejnox/core/api/api_client.dart';
import 'package:rejnox/features/auth/domain/auth_models.dart';
import 'package:rejnox/features/auth/presentation/auth_controller.dart';
import 'package:rejnox/features/nutrition/data/nutrition_api.dart';
import 'package:rejnox/features/nutrition/domain/meal_plan.dart';
import 'package:rejnox/features/nutrition/presentation/meal_plan_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _planJson({
  List<Map<String, dynamic>> checks = const [],
}) => {
  'id': 'p1',
  'title': 'Redukcia – týždeň 1',
  'note': 'Pi veľa vody.',
  'trainerName': 'Marek',
  'targets': {'kcal': 1900, 'proteinG': 140},
  'sentAt': '2026-11-15T10:00:00Z',
  'items': [
    {
      'id': 'a',
      'day': 0,
      'meal': 'Raňajky',
      'name': 'Ovsená kaša',
      'amount': '80 g',
      'kcal': 400,
      'proteinG': 15,
      'carbsG': 70,
      'fatG': 8,
    },
    {
      'id': 'b',
      'day': 0,
      'meal': 'Obed',
      'name': 'Kura s ryžou',
      'kcal': 650,
      'proteinG': 48.5,
      'carbsG': 75,
      'fatG': 12,
    },
    {
      'id': 'c',
      'day': 1,
      'meal': 'Obed',
      'name': 'Losos',
      'kcal': 560,
      'proteinG': 34,
      'carbsG': 45,
      'fatG': 24,
    },
  ],
  'checks': checks,
};

class FakeNutritionApi implements NutritionApi {
  FakeNutritionApi(this.plans);

  List<MealPlan> plans;
  bool fail = false;
  final calls = <String>[];

  @override
  Future<List<MealPlan>> myMealPlans(String token) async => plans;

  @override
  Future<void> setEaten(
    String token,
    String itemId,
    DateTime date, {
    required bool eaten,
  }) async {
    calls.add('${eaten ? 'PUT' : 'DELETE'} $itemId ${dayKey(date)}');
    if (fail) throw const ApiError(404, 'not_found', 'Jedlo sa nenašlo.');
  }
}

class _SignedInAuth extends AuthController {
  @override
  AuthState build() => const SignedIn(
    user: AuthUser(
      id: 'u1',
      email: 'jana@test.local',
      displayName: 'Jana',
      role: UserRole.member,
    ),
    token: 't',
  );
}

void main() {
  final monday = DateTime(2026, 11, 16, 9);

  group('jedálniček – dni a odškrtávanie', () {
    test('pondelok je 0 a deň v týždni sa dopočíta okolo dneška', () {
      expect(weekdayIndex(monday), 0);
      expect(dateInWeek(DateTime(2026, 11, 18), 0), DateTime(2026, 11, 16));
      expect(dateInWeek(DateTime(2026, 11, 18), 6), DateTime(2026, 11, 22));
    });

    test('odškrtnúť sa dá dnešok a 7 dní dozadu, nie budúcnosť', () {
      expect(canCheckOn(monday, monday), isTrue);
      expect(canCheckOn(DateTime(2026, 11, 9), monday), isTrue);
      expect(canCheckOn(DateTime(2026, 11, 8), monday), isFalse);
      expect(canCheckOn(DateTime(2026, 11, 17), monday), isFalse);
    });

    test('načíta jedálniček so zjedenými jedlami a spočíta makrá', () {
      final plan = MealPlan.fromJson(
        _planJson(
          checks: [
            {'itemId': 'a', 'eatenOn': '2026-11-16'},
          ],
        ),
      );
      expect(plan.itemsFor(0).map((i) => i.name), [
        'Ovsená kaša',
        'Kura s ryžou',
      ]);
      expect(plan.planned(0).kcal, 1050);
      expect(plan.planned(0).proteinG, 63.5);
      expect(plan.eaten(0, monday).kcal, 400);
      expect(plan.isEaten('a', monday), isTrue);
      expect(plan.isEaten('a', DateTime(2026, 11, 23)), isFalse);
    });

    test('odškrtnutie vytvorí novú kópiu a pôvodný plán nezmení', () {
      final plan = MealPlan.fromJson(_planJson());
      final checked = plan.withCheck('b', monday, eaten: true);
      expect(checked.isEaten('b', monday), isTrue);
      expect(plan.isEaten('b', monday), isFalse);
      expect(
        checked.withCheck('b', monday, eaten: false).isEaten('b', monday),
        isFalse,
      );
    });

    test('jedálniček prežije uloženie do telefónu a späť', () {
      final plan = MealPlan.fromJson(
        _planJson(
          checks: [
            {'itemId': 'a', 'eatenOn': '2026-11-16'},
          ],
        ),
      );
      final again = MealPlan.fromJson(plan.toJson());
      expect(again.items.length, 3);
      expect(again.targets.kcal, 1900);
      expect(again.isEaten('a', monday), isTrue);
    });
  });

  group('obrazovka jedálnička', () {
    late FakeNutritionApi api;

    Future<void> pump(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(_SignedInAuth.new),
            nutritionApiProvider.overrideWithValue(api),
          ],
          child: MaterialApp(home: MealPlanScreen(now: monday)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('ukáže dnešné jedlá a po ťuknutí ich odškrtne', (tester) async {
      api = FakeNutritionApi([MealPlan.fromJson(_planJson())]);
      await pump(tester);

      expect(find.text('Redukcia – týždeň 1'), findsOneWidget);
      expect(find.text('Ovsená kaša'), findsOneWidget);
      expect(find.text('Losos'), findsNothing);

      await tester.tap(find.text('Ovsená kaša'));
      await tester.pumpAndSettle();
      expect(api.calls, ['PUT a 2026-11-16']);
      expect(find.text('400'), findsOneWidget);
    });

    testWidgets('keď server odmietne, odškrtnutie sa vráti späť', (
      tester,
    ) async {
      api = FakeNutritionApi([MealPlan.fromJson(_planJson())])..fail = true;
      await pump(tester);

      await tester.tap(find.text('Kura s ryžou'));
      await tester.pumpAndSettle();
      expect(api.calls, ['PUT b 2026-11-16']);
      expect(find.text('Jedlo sa nenašlo.'), findsOneWidget);
      final box = tester.widget<Checkbox>(find.byType(Checkbox).last);
      expect(box.value, isFalse);
    });

    testWidgets('budúci deň sa odškrtnúť nedá', (tester) async {
      api = FakeNutritionApi([MealPlan.fromJson(_planJson())]);
      await pump(tester);

      await tester.tap(find.text('Ut'));
      await tester.pumpAndSettle();
      expect(find.text('Losos'), findsOneWidget);
      await tester.tap(find.text('Losos'));
      await tester.pumpAndSettle();
      expect(api.calls, isEmpty);
    });

    testWidgets('bez jedálnička vysvetlí, kde ho nájde', (tester) async {
      api = FakeNutritionApi([]);
      await pump(tester);
      expect(
        find.textContaining('Zatiaľ ti tréner neposlal jedálniček'),
        findsOneWidget,
      );
    });
  });
}
