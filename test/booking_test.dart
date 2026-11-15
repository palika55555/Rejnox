import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rejnox/features/auth/domain/auth_models.dart';
import 'package:rejnox/features/auth/presentation/auth_controller.dart';
import 'package:rejnox/features/booking/data/booking_api.dart';
import 'package:rejnox/features/booking/domain/booking_models.dart';
import 'package:rejnox/features/booking/domain/my_training.dart';
import 'package:rejnox/features/booking/presentation/calendar_widgets.dart';
import 'package:rejnox/features/booking/presentation/client_calendar_screen.dart';
import 'package:rejnox/features/booking/presentation/trainer_calendar_screen.dart';

class _SignedIn extends AuthController {
  _SignedIn(this.role);

  final UserRole role;

  @override
  AuthState build() => SignedIn(
    user: AuthUser(
      id: 'u1',
      email: 'a@test.sk',
      displayName: 'Anna',
      role: role,
    ),
    token: 'ok',
  );
}

class FakeBookingApi implements BookingApi {
  FakeBookingApi({this.trainer, this.client});

  TrainerCalendar? trainer;
  ClientCalendar? client;
  final calls = <String>[];

  @override
  Future<TrainerCalendar> trainerCalendar(
    String token,
    DateTime from,
    DateTime to,
  ) async => trainer!;

  @override
  Future<ClientCalendar> clientCalendar(
    String token,
    String linkId,
    DateTime from,
    DateTime to,
  ) async => client!;

  @override
  Future<Booking> bookSlot(String token, String linkId, String slotId) async {
    calls.add('book $slotId');
    return _booking(slotId: slotId, status: 'confirmed');
  }

  @override
  Future<Booking> confirm(String token, String bookingId) async {
    calls.add('confirm $bookingId');
    return _booking();
  }

  @override
  Future<void> cancel(String token, String bookingId) async =>
      calls.add('cancel $bookingId');

  @override
  Future<Booking> setPlan(
    String token,
    String bookingId,
    String? workoutId,
  ) async {
    calls.add('plan $bookingId $workoutId');
    return _booking();
  }

  @override
  Future<List<MyTraining>> myTrainings(String token) async => const [];

  @override
  Future<Booking> request(
    String token,
    String linkId, {
    required DateTime startsAt,
    required DateTime endsAt,
    String? note,
  }) async {
    calls.add('request');
    return _booking();
  }

  @override
  Future<Slot> addSlot(
    String token, {
    required DateTime startsAt,
    required DateTime endsAt,
    required String title,
    required int capacity,
    String? note,
  }) async => throw UnimplementedError();

  @override
  Future<void> deleteSlot(String token, String slotId) async =>
      calls.add('delete $slotId');

  @override
  Future<Booking> addTrainerBooking(
    String token, {
    required String clientId,
    String? slotId,
    DateTime? startsAt,
    DateTime? endsAt,
    String? title,
    String? note,
    String? workoutId,
  }) async => throw UnimplementedError();
}

/// Zajtra o 10:00 (miestny čas), aby termín nebol v minulosti.
final _tomorrow = () {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + 1, 10);
}();

String _iso(DateTime t) => t.toUtc().toIso8601String();

Booking _booking({
  String id = 'b1',
  String? slotId,
  String status = 'requested',
  String? note,
}) => Booking.fromJson({
  'id': id,
  'startsAt': _iso(_tomorrow.add(const Duration(hours: 4))),
  'endsAt': _iso(_tomorrow.add(const Duration(hours: 5))),
  'status': status,
  'clientId': 'c1',
  'clientName': 'Anna',
  'requestedByClient': true,
  'slotId': slotId,
  'note': note,
});

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  FakeBookingApi api,
  UserRole role,
) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => _SignedIn(role)),
        bookingApiProvider.overrideWithValue(api),
      ],
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
  // Termíny sú zajtra, to je vždy v prvom zobrazenom období (5 týždňov).
  await tester.tap(find.text('${_tomorrow.day}').first);
  await tester.pumpAndSettle();
}

void main() {
  group('pomocné', () {
    test('bodky v týždni: každý druh raz, mimo týždňa nič', () {
      final monday = DateTime(2026, 11, 16);
      final marks = markDays(monday, [
        (DateTime(2026, 11, 16, 9), DayMark.training),
        (DateTime(2026, 11, 16, 18), DayMark.training),
        (DateTime(2026, 11, 16, 20), DayMark.pending),
        (DateTime(2026, 11, 22, 23, 30), DayMark.open),
        (DateTime(2026, 11, 23, 8), DayMark.training),
      ]);
      expect(marks, {
        0: {DayMark.training, DayMark.pending},
        6: {DayMark.open},
      });
    });

    test('týždeň začína pondelkom', () {
      expect(weekStart(DateTime(2026, 11, 15, 18)), DateTime(2026, 11, 9));
      expect(weekStart(DateTime(2026, 11, 16)), DateTime(2026, 11, 16));
    });

    test('dĺžka tréningu', () {
      expect(lengthLabel(45), '45 min');
      expect(lengthLabel(60), '1 h');
      expect(lengthLabel(90), '1,5 h');
    });

    test('voľné miesta v termíne', () {
      final slot = Slot.fromJson({
        'id': 's1',
        'startsAt': _iso(_tomorrow),
        'endsAt': _iso(_tomorrow.add(const Duration(hours: 1))),
        'title': 'Kruh',
        'capacity': 3,
        'taken': 3,
      });
      expect(slot.free, 0);
      expect(slot.isFull, isTrue);
    });
  });

  testWidgets('klient vidí voľný termín, obsadený čas a rezervuje miesto', (
    tester,
  ) async {
    final api = FakeBookingApi(
      client: ClientCalendar.fromJson({
        'trainerName': 'Marek',
        'slots': [
          {
            'id': 's1',
            'startsAt': _iso(_tomorrow),
            'endsAt': _iso(_tomorrow.add(const Duration(hours: 1))),
            'title': 'Kruhový tréning',
            'capacity': 4,
            'taken': 1,
          },
        ],
        'busy': [
          {
            'startsAt': _iso(_tomorrow.add(const Duration(hours: 2))),
            'endsAt': _iso(_tomorrow.add(const Duration(hours: 3))),
          },
        ],
        'bookings': [
          {
            'id': 'b9',
            'startsAt': _iso(_tomorrow.add(const Duration(hours: 4))),
            'endsAt': _iso(_tomorrow.add(const Duration(hours: 5))),
            'status': 'requested',
            'clientId': 'l1',
            'clientName': 'Anna',
            'requestedByClient': true,
          },
        ],
      }),
    );
    await _pump(
      tester,
      const ClientCalendarScreen(linkId: 'l1'),
      api,
      UserRole.member,
    );

    expect(find.text('u trénera Marek'), findsOneWidget);
    expect(find.text('Kruhový tréning'), findsOneWidget);
    expect(find.text('Voľné 3 z 4'), findsOneWidget);
    expect(find.text('Obsadené'), findsOneWidget);
    // Štítok pri žiadosti + legenda pod týždňom.
    expect(find.text('Čaká na potvrdenie'), findsNWidgets(2));
    // Deň s voľným miestom a mojou žiadosťou má sivú aj oranžovú bodku.
    expect(
      find.bySemanticsLabel(
        RegExp(
          '${_tomorrow.day}[.] ${_tomorrow.month}[.].*Čaká na potvrdenie, Voľný termín',
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Rezervovať'));
    await tester.pumpAndSettle();
    expect(api.calls, ['book s1']);
  });

  testWidgets('tréner vidí žiadosť a potvrdí ju', (tester) async {
    final api = FakeBookingApi(
      trainer: TrainerCalendar.fromJson({
        'slots': <Object>[],
        'bookings': [
          {
            'id': 'b1',
            'startsAt': _iso(_tomorrow),
            'endsAt': _iso(_tomorrow.add(const Duration(hours: 1))),
            'status': 'requested',
            'clientId': 'c1',
            'clientName': 'Anna',
            'requestedByClient': true,
            'note': 'Nohy',
          },
        ],
      }),
    );
    await _pump(tester, const TrainerCalendarScreen(), api, UserRole.trainer);

    expect(find.text('ŽIADOSTI O TRÉNING (1)'), findsOneWidget);
    await tester.tap(find.text('Anna').first);
    await tester.pumpAndSettle();
    expect(find.text('„Nohy“'), findsOneWidget);

    await tester.tap(find.text('Potvrdiť'));
    await tester.pumpAndSettle();
    expect(api.calls, ['confirm b1']);
  });
}
