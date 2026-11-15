import 'package:flutter_test/flutter_test.dart';
import 'package:rejnox/features/booking/domain/booking_models.dart';
import 'package:rejnox/features/booking/domain/calendar_period.dart';
import 'package:rejnox/features/booking/domain/my_training.dart';
import 'package:rejnox/features/booking/presentation/calendar_widgets.dart';

void main() {
  group('obdobie kalendára (5 týždňov)', () {
    final now = DateTime(2026, 11, 15, 18); // nedeľa

    test('dnešok je v prvom týždni obdobia', () {
      expect(periodStart(now, now), DateTime(2026, 11, 9));
      expect(periodStart(DateTime(2026, 12, 13), now), DateTime(2026, 11, 9));
    });

    test('ďalšie obdobie začína o 35 dní neskôr, predošlé skôr', () {
      expect(periodStart(DateTime(2026, 12, 14), now), DateTime(2026, 12, 14));
      expect(periodStart(DateTime(2026, 11, 8), now), DateTime(2026, 10, 5));
    });

    test('počet dní nepokazí zmena času', () {
      // 29. 3. 2026 sa v Európe posúva čas, deň má 23 hodín.
      expect(daysBetween(DateTime(2026, 3, 23), DateTime(2026, 4, 6)), 14);
    });

    test('bodky v celom období, mimo neho nič', () {
      final marks = markDays(DateTime(2026, 11, 9), [
        (DateTime(2026, 11, 9, 9), DayMark.training),
        (DateTime(2026, 12, 13, 20), DayMark.open),
        (DateTime(2026, 12, 14, 8), DayMark.pending),
      ], days: calendarDays);
      expect(marks, {
        0: {DayMark.training},
        34: {DayMark.open},
      });
    });
  });

  group('môj tréning', () {
    test('načíta čas, rozpis termínu aj plán s cvikmi', () {
      final t = MyTraining.fromJson({
        'id': 'b1',
        'linkId': 'l1',
        'trainerName': 'Marek',
        'startsAt': '2026-11-20T16:00:00.000Z',
        'endsAt': '2026-11-20T17:00:00.000Z',
        'status': 'confirmed',
        'inSlot': true,
        'title': 'Kruhový tréning',
        'note': null,
        'slotNote': 'Nohy a core',
        'workout': {
          'id': 'w1',
          'title': 'Nohy A',
          'scheduledOn': null,
          'trainerName': 'Marek',
          'exercises': [
            {
              'exerciseId': 'e1',
              'name': 'Drep',
              'muscleGroup': 'legs',
              'sets': 4,
              'reps': 8,
              'weightKg': 80,
              'note': null,
            },
          ],
        },
      });
      expect(t.displayTitle, 'Kruhový tréning');
      expect(t.slotNote, 'Nohy a core');
      expect(t.status, BookingStatus.confirmed);
      expect(t.plan!.items.single.scheme, '4×8 · 80 kg');
      expect(t.endsAt.difference(t.startsAt), const Duration(hours: 1));
    });

    test('bez plánu a názvu: osobný tréning', () {
      final t = MyTraining.fromJson({
        'id': 'b2',
        'linkId': 'l1',
        'startsAt': '2026-11-20T16:00:00.000Z',
        'endsAt': '2026-11-20T17:00:00.000Z',
        'status': 'requested',
        'inSlot': false,
      });
      expect(t.plan, isNull);
      expect(t.isPending, isTrue);
      expect(t.displayTitle, 'Osobný tréning');
    });

    test('dni: dnes, zajtra, inak dátum', () {
      final now = DateTime(2026, 11, 15, 10);
      expect(dayLabel(DateTime(2026, 11, 15, 18), now), 'Dnes');
      expect(dayLabel(DateTime(2026, 11, 16, 7), now), 'Zajtra');
      expect(dayLabel(DateTime(2026, 11, 20, 7), now), 'Pi 20. 11.');
    });
  });
}
