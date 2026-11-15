enum BookingStatus {
  requested('requested', 'Čaká na potvrdenie'),
  confirmed('confirmed', 'Potvrdené'),
  cancelled('cancelled', 'Zrušené');

  const BookingStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static BookingStatus fromApi(Object? value) => values.firstWhere(
    (s) => s.apiValue == value,
    orElse: () => BookingStatus.requested,
  );
}

DateTime _time(Object? value) => DateTime.parse(value as String).toLocal();

/// Rezervácia: miesto vo vypísanom termíne, osobný tréning alebo žiadosť klienta.
class Booking {
  const Booking({
    required this.id,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.clientId,
    required this.clientName,
    required this.requestedByClient,
    this.slotId,
    this.title,
    this.note,
    this.workoutId,
    this.workoutTitle,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    final workout = json['workout'] as Map<String, dynamic>?;
    return Booking(
      id: json['id'] as String,
      startsAt: _time(json['startsAt']),
      endsAt: _time(json['endsAt']),
      status: BookingStatus.fromApi(json['status']),
      clientId: json['clientId'] as String,
      clientName: json['clientName'] as String? ?? '',
      requestedByClient: json['requestedByClient'] as bool? ?? false,
      slotId: json['slotId'] as String?,
      title: json['title'] as String?,
      note: json['note'] as String?,
      workoutId: workout?['id'] as String?,
      workoutTitle: workout?['title'] as String?,
    );
  }

  final String id;
  final DateTime startsAt;
  final DateTime endsAt;
  final BookingStatus status;

  /// ID spolupráce (trainer_clients), rovnaké ako ID klienta u trénera.
  final String clientId;
  final String clientName;
  final bool requestedByClient;
  final String? slotId;
  final String? title;
  final String? note;
  final String? workoutId;
  final String? workoutTitle;

  bool get isPending => status == BookingStatus.requested;
}

/// Vypísaný termín trénera (napr. skupinový tréning s počtom miest).
class Slot {
  const Slot({
    required this.id,
    required this.startsAt,
    required this.endsAt,
    required this.title,
    required this.capacity,
    required this.taken,
    this.note,
    this.bookings = const [],
  });

  factory Slot.fromJson(Map<String, dynamic> json) {
    final bookings = [
      for (final b in json['bookings'] as List? ?? const [])
        Booking.fromJson(b as Map<String, dynamic>),
    ];
    return Slot(
      id: json['id'] as String,
      startsAt: _time(json['startsAt']),
      endsAt: _time(json['endsAt']),
      title: json['title'] as String? ?? 'Termín',
      note: json['note'] as String?,
      capacity: json['capacity'] as int? ?? 1,
      // Tréner dostane zoznam rezervácií, klient len počet.
      taken: json['taken'] as int? ?? bookings.length,
      bookings: bookings,
    );
  }

  final String id;
  final DateTime startsAt;
  final DateTime endsAt;
  final String title;
  final String? note;
  final int capacity;
  final int taken;

  /// Kto má miesto (len pre trénera).
  final List<Booking> bookings;

  int get free => (capacity - taken).clamp(0, capacity);
  bool get isFull => free == 0;
}

/// Čas, keď má tréner iný tréning (klient nevidí s kým).
class BusyTime {
  const BusyTime(this.startsAt, this.endsAt);

  factory BusyTime.fromJson(Map<String, dynamic> json) =>
      BusyTime(_time(json['startsAt']), _time(json['endsAt']));

  final DateTime startsAt;
  final DateTime endsAt;
}

/// Kalendár trénera (jeho vlastný pohľad).
class TrainerCalendar {
  const TrainerCalendar({required this.slots, required this.bookings});

  factory TrainerCalendar.fromJson(Map<String, dynamic> json) =>
      TrainerCalendar(
        slots: [
          for (final s in json['slots'] as List)
            Slot.fromJson(s as Map<String, dynamic>),
        ],
        bookings: [
          for (final b in json['bookings'] as List)
            Booking.fromJson(b as Map<String, dynamic>),
        ],
      );

  final List<Slot> slots;

  /// Osobné tréningy a žiadosti mimo vypísaných termínov.
  final List<Booking> bookings;

  int get pendingCount => bookings.where((b) => b.isPending).length;
}

/// Kalendár trénera, ako ho vidí klient.
class ClientCalendar {
  const ClientCalendar({
    required this.trainerName,
    required this.slots,
    required this.busy,
    required this.bookings,
  });

  factory ClientCalendar.fromJson(Map<String, dynamic> json) => ClientCalendar(
    trainerName: json['trainerName'] as String? ?? '',
    slots: [
      for (final s in json['slots'] as List)
        Slot.fromJson(s as Map<String, dynamic>),
    ],
    busy: [
      for (final b in json['busy'] as List)
        BusyTime.fromJson(b as Map<String, dynamic>),
    ],
    bookings: [
      for (final b in json['bookings'] as List)
        Booking.fromJson(b as Map<String, dynamic>),
    ],
  );

  final String trainerName;
  final List<Slot> slots;
  final List<BusyTime> busy;

  /// Moje rezervácie u tohto trénera.
  final List<Booking> bookings;

  /// Moja rezervácia v danom termíne, ak ju mám.
  Booking? myBookingIn(Slot slot) {
    for (final b in bookings) {
      if (b.slotId == slot.id) return b;
    }
    return null;
  }
}

// ------------------------------------------------------------------ dni

/// Pondelok týždňa, do ktorého patrí deň (o polnoci, miestny čas).
DateTime weekStart(DateTime day) {
  final d = DateTime(day.year, day.month, day.day);
  return d.subtract(Duration(days: d.weekday - DateTime.monday));
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

const _weekdays = ['Po', 'Ut', 'St', 'Št', 'Pi', 'So', 'Ne'];

String weekdayShort(DateTime d) => _weekdays[d.weekday - 1];

String hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String timeRange(DateTime start, DateTime end) =>
    '${hhmm(start)} – ${hhmm(end)}';
