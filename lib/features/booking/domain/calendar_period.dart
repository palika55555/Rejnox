import 'booking_models.dart';

/// Kalendár sa zobrazuje po 5 týždňoch (35 dní od pondelka), aby bol
/// prehľad aspoň na 30 dní dopredu.
const calendarWeeks = 5;
const calendarDays = calendarWeeks * 7;

/// Počet kalendárnych dní medzi dvoma polnocami (odolné voči zmene času).
int daysBetween(DateTime from, DateTime to) =>
    (to.difference(from).inHours / 24).round();

/// Prvý deň obdobia, do ktorého patrí [day]: obdobia idú za sebou od
/// pondelka aktuálneho týždňa, takže dnešok je vždy v prvom týždni.
DateTime periodStart(DateTime day, [DateTime? now]) {
  final first = weekStart(now ?? DateTime.now());
  final periods = (daysBetween(first, weekStart(day)) / calendarDays).floor();
  return DateTime(first.year, first.month, first.day + periods * calendarDays);
}
