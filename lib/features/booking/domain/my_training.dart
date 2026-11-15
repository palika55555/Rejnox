import '../../coaching/domain/coaching_models.dart';
import 'booking_models.dart';

/// Môj rezervovaný tréning u trénera: kedy, čo a podľa akého plánu.
class MyTraining {
  const MyTraining({
    required this.id,
    required this.linkId,
    required this.trainerName,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.inSlot,
    this.title,
    this.note,
    this.slotNote,
    this.plan,
  });

  factory MyTraining.fromJson(Map<String, dynamic> json) {
    final workout = json['workout'] as Map<String, dynamic>?;
    return MyTraining(
      id: json['id'] as String,
      linkId: json['linkId'] as String,
      trainerName: json['trainerName'] as String? ?? '',
      startsAt: DateTime.parse(json['startsAt'] as String).toLocal(),
      endsAt: DateTime.parse(json['endsAt'] as String).toLocal(),
      status: BookingStatus.fromApi(json['status']),
      inSlot: json['inSlot'] as bool? ?? false,
      title: json['title'] as String?,
      note: json['note'] as String?,
      slotNote: json['slotNote'] as String?,
      plan: workout == null ? null : Plan.fromJson(workout),
    );
  }

  final String id;

  /// Spolupráca s trénerom (na otvorenie jeho kalendára).
  final String linkId;
  final String trainerName;
  final DateTime startsAt;
  final DateTime endsAt;
  final BookingStatus status;

  /// Miesto vo vypísanom termíne (napr. skupinový tréning).
  final bool inSlot;
  final String? title;

  /// Moja poznámka alebo poznámka trénera k tréningu.
  final String? note;

  /// Popis vypísaného termínu od trénera (čo sa bude robiť).
  final String? slotNote;

  /// Rozpis cvikov, ak ho tréner k tréningu pripojil.
  final Plan? plan;

  String get displayTitle =>
      title ?? (inSlot ? 'Tréning v termíne' : 'Osobný tréning');

  bool get isPending => status == BookingStatus.requested;
}

/// „Dnes“, „Zajtra“ alebo „Št 20. 11.“.
String dayLabel(DateTime day, [DateTime? now]) {
  final today = now ?? DateTime.now();
  if (sameDay(day, today)) return 'Dnes';
  if (sameDay(day, today.add(const Duration(days: 1)))) return 'Zajtra';
  return '${weekdayShort(day)} ${day.day}. ${day.month}.';
}
