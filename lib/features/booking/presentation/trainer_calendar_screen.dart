import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/tm_card.dart';
import '../../coaching/presentation/coaching_widgets.dart';
import '../application/booking_providers.dart';
import '../domain/booking_models.dart';
import 'calendar_widgets.dart';
import 'trainer_calendar_sheets.dart';

/// Kalendár trénera: vypísané termíny, tréningy klientov a žiadosti.
class TrainerCalendarScreen extends ConsumerStatefulWidget {
  const TrainerCalendarScreen({super.key});

  @override
  ConsumerState<TrainerCalendarScreen> createState() =>
      _TrainerCalendarScreenState();
}

class _TrainerCalendarScreenState extends ConsumerState<TrainerCalendarScreen> {
  DateTime _day = DateTime.now();

  DateTime get _monday => weekStart(_day);

  void _week(int delta) =>
      setState(() => _day = _day.add(Duration(days: 7 * delta)));

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final calendar = ref.watch(trainerCalendarProvider(_monday));
    final data = calendar.value;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: RefreshIndicator(
                onRefresh: () =>
                    ref.refresh(trainerCalendarProvider(_monday).future),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Späť',
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.go('/clients'),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        Expanded(
                          child: Text('KALENDÁR', style: text.headlineMedium),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: PrimaryButton(
                            label: 'Vypísať termín',
                            icon: Icons.event_available_rounded,
                            compact: true,
                            onPressed: () => showCalendarSheet<bool>(
                              context,
                              NewSlotSheet(day: _day),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: PrimaryButton(
                            label: 'Zapísať tréning',
                            icon: Icons.edit_calendar_rounded,
                            compact: true,
                            tone: ButtonTone.ghost,
                            onPressed: () => showCalendarSheet<bool>(
                              context,
                              TrainerBookingSheet(day: _day),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (data != null && data.pendingCount > 0) ...[
                      _PendingCard(
                        data.bookings.where((b) => b.isPending).toList(),
                      ),
                      const SizedBox(height: 14),
                    ],
                    WeekStrip(
                      monday: _monday,
                      selected: _day,
                      onSelect: (d) => setState(() => _day = d),
                      onWeek: _week,
                      marks: data == null ? const {} : _marks(data, _monday),
                    ),
                    const SizedBox(height: 14),
                    ...calendar.when(
                      skipLoadingOnReload: true,
                      loading: () => const [
                        Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ],
                      error: (e, _) => [
                        TmCard(
                          child: Column(
                            children: [
                              Text(errorText(e), textAlign: TextAlign.center),
                              TextButton(
                                onPressed: () => ref.invalidate(
                                  trainerCalendarProvider(_monday),
                                ),
                                child: const Text('Skúsiť znova'),
                              ),
                            ],
                          ),
                        ),
                      ],
                      data: (cal) => _dayItems(context, cal),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _dayItems(BuildContext context, TrainerCalendar cal) {
    final slots = cal.slots.where((s) => sameDay(s.startsAt, _day));
    final bookings = cal.bookings.where((b) => sameDay(b.startsAt, _day));
    final items = <(DateTime, Widget)>[
      for (final s in slots)
        (
          s.startsAt,
          CalendarEventTile(
            start: s.startsAt,
            end: s.endsAt,
            title: s.title,
            subtitle: s.bookings.isEmpty
                ? 'Zatiaľ nikto'
                : s.bookings.map((b) => b.clientName).join(', '),
            accent: s.bookings.isEmpty ? AppColors.info : AppColors.good,
            pill: AppPill(
              s.isFull
                  ? 'Plné ${s.taken}/${s.capacity}'
                  : 'Voľné ${s.free} z ${s.capacity}',
              tone: s.isFull ? PillTone.good : PillTone.info,
            ),
            onTap: () => showCalendarSheet<void>(context, SlotDetailSheet(s)),
          ),
        ),
      for (final b in bookings)
        (
          b.startsAt,
          CalendarEventTile(
            start: b.startsAt,
            end: b.endsAt,
            title: b.clientName,
            subtitle: [
              b.title ?? 'Osobný tréning',
              if (b.workoutTitle != null) 'plán ${b.workoutTitle}',
            ].join(' · '),
            accent: b.isPending ? AppColors.warn : AppColors.good,
            pill: b.isPending ? BookingStatusPill(b.status) : null,
            onTap: () =>
                showCalendarSheet<void>(context, TrainerBookingDetailSheet(b)),
          ),
        ),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    if (items.isEmpty) {
      return const [
        EmptyDay('V tento deň nič nemáš. Vypíš termín alebo zapíš tréning.'),
      ];
    }
    return [
      for (final i in items) ...[i.$2, const SizedBox(height: 10)],
    ];
  }
}

/// Koľko udalostí má ktorý deň týždňa (0 = pondelok).
/// Zelená = tréning s klientom, oranžová = žiadosť, sivá = termín bez klientov.
Map<int, Set<DayMark>> _marks(TrainerCalendar cal, DateTime monday) =>
    markDays(monday, [
      for (final s in cal.slots)
        (s.startsAt, s.bookings.isEmpty ? DayMark.open : DayMark.training),
      for (final b in cal.bookings) (b.startsAt, bookingMark(b)),
    ]);

/// Žiadosti klientov, ktoré čakajú na odpoveď (v zobrazenom týždni).
class _PendingCard extends StatelessWidget {
  const _PendingCard(this.pending);

  final List<Booking> pending;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return TmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(
            'Žiadosti o tréning (${pending.length})',
            icon: Icons.notifications_active_outlined,
            color: AppColors.warn,
          ),
          const SizedBox(height: 6),
          for (final b in pending)
            AppRow(
              title: b.clientName,
              subtitle:
                  '${weekdayShort(b.startsAt)} ${b.startsAt.day}. ${b.startsAt.month}. · '
                  '${timeRange(b.startsAt, b.endsAt)}'
                  '${b.note == null ? '' : ' · ${b.note}'}',
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.muted,
              ),
              onTap: () => showCalendarSheet<void>(
                context,
                TrainerBookingDetailSheet(b),
              ),
            ),
          if (pending.isEmpty) Text('Nič nečaká.', style: text.bodySmall),
        ],
      ),
    );
  }
}
