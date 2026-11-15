import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/booking_api.dart';
import '../domain/booking_models.dart';
import '../domain/calendar_period.dart';
import '../domain/my_training.dart';

const _signedOut = ApiError(401, 'unauthorized', 'Prihlás sa, prosím.');

String _token(AuthState auth) =>
    auth is SignedIn ? auth.token : throw _signedOut;

/// Kalendár sa načítava po obdobiach 5 týždňov (od pondelka, miestny čas).
({DateTime from, DateTime to}) _week(DateTime monday) => (
  from: monday,
  to: DateTime(monday.year, monday.month, monday.day + calendarDays),
);

// ------------------------------------------------------------------ tréner

/// Obdobie v kalendári trénera; kľúč je jeho prvý pondelok.
final trainerCalendarProvider = FutureProvider.autoDispose
    .family<TrainerCalendar, DateTime>((ref, monday) {
      final week = _week(monday);
      return ref
          .watch(bookingApiProvider)
          .trainerCalendar(
            _token(ref.watch(authControllerProvider)),
            week.from,
            week.to,
          );
    });

class TrainerCalendarActions {
  TrainerCalendarActions(this._ref);

  final Ref _ref;

  BookingApi get _api => _ref.read(bookingApiProvider);
  String get _t => _token(_ref.read(authControllerProvider));

  void _refresh() => _ref.invalidate(trainerCalendarProvider);

  Future<void> addSlot({
    required DateTime startsAt,
    required DateTime endsAt,
    required String title,
    required int capacity,
    String? note,
  }) async {
    await _api.addSlot(
      _t,
      startsAt: startsAt,
      endsAt: endsAt,
      title: title,
      capacity: capacity,
      note: note,
    );
    _refresh();
  }

  Future<void> deleteSlot(String slotId) async {
    await _api.deleteSlot(_t, slotId);
    _refresh();
  }

  Future<void> addBooking({
    required String clientId,
    String? slotId,
    DateTime? startsAt,
    DateTime? endsAt,
    String? title,
    String? note,
    String? workoutId,
  }) async {
    await _api.addTrainerBooking(
      _t,
      clientId: clientId,
      slotId: slotId,
      startsAt: startsAt,
      endsAt: endsAt,
      title: title,
      note: note,
      workoutId: workoutId,
    );
    _refresh();
  }

  Future<void> confirm(String bookingId) async {
    await _api.confirm(_t, bookingId);
    _refresh();
  }

  Future<void> setPlan(String bookingId, String? workoutId) async {
    await _api.setPlan(_t, bookingId, workoutId);
    _refresh();
  }

  Future<void> cancel(String bookingId) async {
    await _api.cancel(_t, bookingId);
    _refresh();
  }
}

// Bez autoDispose: akcie musia prežiť čakanie na server.
final trainerCalendarActionsProvider = Provider<TrainerCalendarActions>(
  TrainerCalendarActions.new,
);

// ------------------------------------------------------------------ klient

typedef ClientWeek = ({String linkId, DateTime monday});

/// Kalendár môjho trénera na obdobie (5 týždňov).
final clientCalendarProvider = FutureProvider.autoDispose
    .family<ClientCalendar, ClientWeek>((ref, key) {
      final week = _week(key.monday);
      return ref
          .watch(bookingApiProvider)
          .clientCalendar(
            _token(ref.watch(authControllerProvider)),
            key.linkId,
            week.from,
            week.to,
          );
    });

class ClientCalendarActions {
  ClientCalendarActions(this._ref, this.linkId);

  final Ref _ref;
  final String linkId;

  BookingApi get _api => _ref.read(bookingApiProvider);
  String get _t => _token(_ref.read(authControllerProvider));

  void _refresh() => _ref
    ..invalidate(clientCalendarProvider)
    ..invalidate(myTrainingsProvider);

  Future<void> bookSlot(String slotId) async {
    await _api.bookSlot(_t, linkId, slotId);
    _refresh();
  }

  Future<void> request({
    required DateTime startsAt,
    required DateTime endsAt,
    String? note,
  }) async {
    await _api.request(
      _t,
      linkId,
      startsAt: startsAt,
      endsAt: endsAt,
      note: note,
    );
    _refresh();
  }

  Future<void> cancel(String bookingId) async {
    await _api.cancel(_t, bookingId);
    _refresh();
  }
}

final clientCalendarActionsProvider =
    Provider.family<ClientCalendarActions, String>(ClientCalendarActions.new);

/// Moje tréningy u trénerov na najbližších 30 dní (s rozpisom a plánom).
final myTrainingsProvider = FutureProvider.autoDispose<List<MyTraining>>(
  (ref) => ref
      .watch(bookingApiProvider)
      .myTrainings(_token(ref.watch(authControllerProvider))),
);
