import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/booking_models.dart';
import '../domain/my_training.dart';

abstract interface class BookingApi {
  // Tréner.
  Future<TrainerCalendar> trainerCalendar(
    String token,
    DateTime from,
    DateTime to,
  );
  Future<Slot> addSlot(
    String token, {
    required DateTime startsAt,
    required DateTime endsAt,
    required String title,
    required int capacity,
    String? note,
  });
  Future<void> deleteSlot(String token, String slotId);
  Future<Booking> addTrainerBooking(
    String token, {
    required String clientId,
    String? slotId,
    DateTime? startsAt,
    DateTime? endsAt,
    String? title,
    String? note,
    String? workoutId,
  });
  Future<Booking> confirm(String token, String bookingId);

  /// Pripojí k tréningu plán klienta (`null` = odpojí).
  Future<Booking> setPlan(String token, String bookingId, String? workoutId);

  // Tréner aj klient.
  Future<void> cancel(String token, String bookingId);

  // Klient.
  Future<ClientCalendar> clientCalendar(
    String token,
    String linkId,
    DateTime from,
    DateTime to,
  );
  Future<Booking> bookSlot(String token, String linkId, String slotId);
  Future<Booking> request(
    String token,
    String linkId, {
    required DateTime startsAt,
    required DateTime endsAt,
    String? note,
  });

  /// Moje tréningy u trénerov na najbližších 30 dní.
  Future<List<MyTraining>> myTrainings(String token);
}

class HttpBookingApi implements BookingApi {
  const HttpBookingApi(this._api);

  final ApiClient _api;

  static String _iso(DateTime t) => t.toUtc().toIso8601String();

  static String _range(DateTime from, DateTime to) =>
      'from=${Uri.encodeQueryComponent(_iso(from))}'
      '&to=${Uri.encodeQueryComponent(_iso(to))}';

  @override
  Future<TrainerCalendar> trainerCalendar(
    String token,
    DateTime from,
    DateTime to,
  ) async => TrainerCalendar.fromJson(
    await _api.send('GET', '/calendar?${_range(from, to)}', token: token),
  );

  @override
  Future<Slot> addSlot(
    String token, {
    required DateTime startsAt,
    required DateTime endsAt,
    required String title,
    required int capacity,
    String? note,
  }) async => Slot.fromJson(
    await _api.send(
      'POST',
      '/calendar/slots',
      token: token,
      body: {
        'startsAt': _iso(startsAt),
        'endsAt': _iso(endsAt),
        'title': title,
        'capacity': capacity,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    ),
  );

  @override
  Future<void> deleteSlot(String token, String slotId) =>
      _api.send('DELETE', '/calendar/slots/$slotId', token: token);

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
  }) async => Booking.fromJson(
    await _api.send(
      'POST',
      '/calendar/bookings',
      token: token,
      body: {
        'clientId': clientId,
        'slotId': ?slotId,
        if (startsAt != null) 'startsAt': _iso(startsAt),
        if (endsAt != null) 'endsAt': _iso(endsAt),
        if (title != null && title.isNotEmpty) 'title': title,
        if (note != null && note.isNotEmpty) 'note': note,
        'workoutId': ?workoutId,
      },
    ),
  );

  @override
  Future<Booking> confirm(String token, String bookingId) async =>
      Booking.fromJson(
        await _api.send('POST', '/bookings/$bookingId/confirm', token: token),
      );

  @override
  Future<Booking> setPlan(
    String token,
    String bookingId,
    String? workoutId,
  ) async => Booking.fromJson(
    await _api.send(
      'PUT',
      '/bookings/$bookingId/plan',
      token: token,
      body: {'workoutId': workoutId},
    ),
  );

  @override
  Future<void> cancel(String token, String bookingId) =>
      _api.send('POST', '/bookings/$bookingId/cancel', token: token);

  @override
  Future<ClientCalendar> clientCalendar(
    String token,
    String linkId,
    DateTime from,
    DateTime to,
  ) async => ClientCalendar.fromJson(
    await _api.send(
      'GET',
      '/me/trainers/$linkId/calendar?${_range(from, to)}',
      token: token,
    ),
  );

  @override
  Future<Booking> bookSlot(String token, String linkId, String slotId) async =>
      Booking.fromJson(
        await _api.send(
          'POST',
          '/me/trainers/$linkId/bookings',
          token: token,
          body: {'slotId': slotId},
        ),
      );

  @override
  Future<Booking> request(
    String token,
    String linkId, {
    required DateTime startsAt,
    required DateTime endsAt,
    String? note,
  }) async => Booking.fromJson(
    await _api.send(
      'POST',
      '/me/trainers/$linkId/bookings',
      token: token,
      body: {
        'startsAt': _iso(startsAt),
        'endsAt': _iso(endsAt),
        if (note != null && note.isNotEmpty) 'note': note,
      },
    ),
  );

  @override
  Future<List<MyTraining>> myTrainings(String token) async {
    final json = await _api.send('GET', '/me/trainings', token: token);
    return [
      for (final t in json['trainings'] as List)
        MyTraining.fromJson(t as Map<String, dynamic>),
    ];
  }
}

final bookingApiProvider = Provider<BookingApi>(
  (ref) => HttpBookingApi(ref.watch(apiClientProvider)),
);
