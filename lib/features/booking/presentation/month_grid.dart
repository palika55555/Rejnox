import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/tm_card.dart';
import '../domain/booking_models.dart';
import '../domain/calendar_period.dart';
import 'calendar_widgets.dart';

/// Mriežka 5 týždňov s bodkami udalostí. `marks` = čo je v ktorý deň
/// (0 = prvý pondelok obdobia).
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.start,
    required this.selected,
    required this.onSelect,
    required this.onPeriod,
    this.marks = const {},
  });

  final DateTime start;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  /// -1 = predošlých 5 týždňov, +1 = ďalších.
  final ValueChanged<int> onPeriod;
  final Map<int, Set<DayMark>> marks;

  DateTime _day(int i) => DateTime(start.year, start.month, start.day + i);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final last = _day(calendarDays - 1);
    final today = DateTime.now();
    return TmCard(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Predošlé obdobie',
                onPressed: () => onPeriod(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  '${start.day}. ${start.month}. – '
                  '${last.day}. ${last.month}. ${last.year}',
                  style: text.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                tooltip: 'Ďalšie obdobie',
                onPressed: () => onPeriod(1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Text(
                    weekdayShort(_day(i)),
                    textAlign: TextAlign.center,
                    style: text.bodySmall!.copyWith(color: AppColors.muted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var w = 0; w < calendarWeeks; w++)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  for (var d = 0; d < 7; d++)
                    Expanded(
                      child: DayChip(
                        day: _day(w * 7 + d),
                        selected: sameDay(_day(w * 7 + d), selected),
                        today: sameDay(_day(w * 7 + d), today),
                        marks: marks[w * 7 + d] ?? const {},
                        showWeekday: false,
                        onTap: () => onSelect(_day(w * 7 + d)),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          const CalendarLegend(),
        ],
      ),
    );
  }
}

/// Zobrazenie pod mriežkou: vybraný deň alebo všetko v období pod sebou.
enum CalendarView { day, list }

class CalendarViewToggle extends StatelessWidget {
  const CalendarViewToggle({
    super.key,
    required this.view,
    required this.onChanged,
  });

  final CalendarView view;
  final ValueChanged<CalendarView> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<CalendarView>(
    segments: const [
      ButtonSegment(
        value: CalendarView.day,
        label: Text('Vybraný deň'),
        icon: Icon(Icons.today_rounded),
      ),
      ButtonSegment(
        value: CalendarView.list,
        label: Text('Všetko (35 dní)'),
        icon: Icon(Icons.view_agenda_rounded),
      ),
    ],
    selected: {view},
    showSelectedIcon: false,
    onSelectionChanged: (s) => onChanged(s.first),
  );
}

/// Nadpis dňa v zozname.
class AgendaDayHeader extends StatelessWidget {
  const AgendaDayHeader(this.day, {super.key});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final today = sameDay(day, DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Text(
        '${today ? 'Dnes · ' : ''}${weekdayShort(day)} ${day.day}. ${day.month}.',
        style: Theme.of(context).textTheme.titleMedium!.copyWith(
          color: today ? AppColors.accent : AppColors.text,
        ),
      ),
    );
  }
}

/// Dni obdobia, ktoré majú aspoň jednu udalosť, s ich položkami.
/// [itemsFor] vráti položky dňa (prázdny zoznam = deň sa vynechá).
List<Widget> agendaItems(
  DateTime start,
  List<Widget> Function(DateTime day) itemsFor, {
  required String empty,
}) {
  final out = <Widget>[];
  for (var i = 0; i < calendarDays; i++) {
    final day = DateTime(start.year, start.month, start.day + i);
    final items = itemsFor(day);
    if (items.isEmpty) continue;
    out
      ..add(AgendaDayHeader(day))
      ..addAll(items);
  }
  return out.isEmpty ? [EmptyDay(empty)] : out;
}
