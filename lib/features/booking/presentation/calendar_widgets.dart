import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/tm_card.dart';
import '../domain/booking_models.dart';
import '../domain/calendar_period.dart';

/// Čo je v daný deň v kalendári (farebná bodka pod dňom).
enum DayMark {
  training(AppColors.good, 'Tréning'),
  pending(AppColors.warn, 'Čaká na potvrdenie'),
  open(AppColors.info, 'Voľný termín');

  const DayMark(this.color, this.label);

  final Color color;
  final String label;
}

/// Zoskupí udalosti po dňoch od [monday] (0 = pondelok); udalosti mimo
/// obdobia [days] dní sa ignorujú.
Map<int, Set<DayMark>> markDays(
  DateTime monday,
  Iterable<(DateTime, DayMark)> events, {
  int days = 7,
}) {
  final marks = <int, Set<DayMark>>{};
  for (final (time, mark) in events) {
    final i = daysBetween(monday, DateTime(time.year, time.month, time.day));
    if (i >= 0 && i < days) (marks[i] ??= {}).add(mark);
  }
  return marks;
}

DayMark bookingMark(Booking b) =>
    b.isPending ? DayMark.pending : DayMark.training;

/// Vysvetlivky k bodkám.
class CalendarLegend extends StatelessWidget {
  const CalendarLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 4,
      children: [
        for (final m in DayMark.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Dot(m.color),
              const SizedBox(width: 5),
              Text(m.label, style: style),
            ],
          ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

class DayChip extends StatelessWidget {
  const DayChip({
    super.key,
    required this.day,
    required this.selected,
    required this.today,
    required this.marks,
    required this.onTap,
    this.showWeekday = true,
  });

  final DateTime day;
  final bool selected;
  final bool today;

  /// V mriežke mesiaca sú dni týždňa v hlavičke, nie pri každom dni.
  final bool showWeekday;
  final Set<DayMark> marks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final described = [
      for (final m in DayMark.values)
        if (marks.contains(m)) m.label,
    ];
    return Semantics(
      selected: selected,
      button: true,
      label:
          '${weekdayShort(day)} ${day.day}. ${day.month}.'
          '${described.isEmpty ? ', nič' : ', ${described.join(', ')}'}',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            // Vybraný deň len podfarbený, aby bolo vidno farebné bodky.
            color: selected ? AppColors.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.accent : Colors.transparent,
            ),
          ),
          child: Column(
            children: [
              if (showWeekday) ...[
                Text(
                  weekdayShort(day),
                  style: text.bodySmall!.copyWith(
                    color: today ? AppColors.accent : AppColors.muted,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Text(
                '${day.day}',
                style: text.titleMedium!.copyWith(
                  color: today ? AppColors.accent : AppColors.text,
                  fontWeight: today || selected ? FontWeight.w800 : null,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 7,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final m in DayMark.values)
                      if (marks.contains(m))
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1.5),
                          child: _Dot(m.color),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Riadok udalosti v kalendári: čas vľavo, obsah vpravo.
class CalendarEventTile extends StatelessWidget {
  const CalendarEventTile({
    super.key,
    required this.start,
    required this.end,
    required this.title,
    this.subtitle,
    this.pill,
    this.accent = AppColors.accent,
    this.onTap,
    this.trailing,
  });

  final DateTime start;
  final DateTime end;
  final String title;
  final String? subtitle;
  final Widget? pill;
  final Color accent;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return TmCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 44,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 52,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hhmm(start), style: text.titleMedium),
                Text(hhmm(end), style: text.bodySmall),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.bodyLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: text.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (pill case final pill?) ...[
                  const SizedBox(height: 4),
                  // Dlhý štítok sa radšej zmenší, než aby pretiekol.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: pill,
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Výber dňa, začiatku a dĺžky tréningu (spoločné pre trénera aj klienta).
class TimeSlotPicker extends StatelessWidget {
  const TimeSlotPicker({
    super.key,
    required this.start,
    required this.minutes,
    required this.onStart,
    required this.onMinutes,
    this.allowPast = false,
  });

  final DateTime start;
  final int minutes;
  final ValueChanged<DateTime> onStart;
  final ValueChanged<int> onMinutes;
  final bool allowPast;

  static const lengths = [30, 45, 60, 90, 120];

  Future<void> _pickDay(BuildContext context) async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: allowPast
          ? now.subtract(const Duration(days: 90))
          : DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (day != null) {
      onStart(DateTime(day.year, day.month, day.day, start.hour, start.minute));
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(start),
    );
    if (time != null) {
      onStart(
        DateTime(start.year, start.month, start.day, time.hour, time.minute),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickDay(context),
                icon: const Icon(Icons.event_rounded, size: 18),
                label: Text(
                  '${weekdayShort(start)} ${start.day}. ${start.month}.',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickTime(context),
                icon: const Icon(Icons.schedule_rounded, size: 18),
                label: Text(hhmm(start)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            for (final m in lengths)
              ChoiceChip(
                label: Text(lengthLabel(m)),
                selected: minutes == m,
                onSelected: (_) => onMinutes(m),
              ),
          ],
        ),
      ],
    );
  }
}

/// „45 min“, „1 h“, „1,5 h“.
String lengthLabel(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  return minutes % 60 == 0 ? '$hours h' : '$hours,${minutes % 60 * 10 ~/ 60} h';
}

/// Najbližšia celá hodina od teraz (predvolený začiatok nového tréningu).
DateTime nextFullHour([DateTime? from]) {
  final now = from ?? DateTime.now();
  return DateTime(now.year, now.month, now.day, now.hour + 1);
}

/// Prázdny deň.
class EmptyDay extends StatelessWidget {
  const EmptyDay(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}
