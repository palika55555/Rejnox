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
import '../domain/calendar_period.dart';
import 'calendar_widgets.dart';
import 'month_grid.dart';
import 'trainer_calendar_sheets.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/skeleton.dart';

/// Kalendár trénera: vypísané termíny, tréningy klientov a žiadosti.
class TrainerCalendarScreen extends ConsumerStatefulWidget {
  const TrainerCalendarScreen({super.key});

  @override
  ConsumerState<TrainerCalendarScreen> createState() =>
      _TrainerCalendarScreenState();
}

class _TrainerCalendarScreenState extends ConsumerState<TrainerCalendarScreen> {
  DateTime _day = DateTime.now();
  CalendarView _view = CalendarView.day;

  /// Prvý pondelok zobrazeného obdobia (5 týždňov).
  DateTime get _monday => periodStart(_day);

  void _period(int delta) => setState(() {
    final start = _monday;
    _day = DateTime(start.year, start.month, start.day + delta * calendarDays);
  });

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
              child: RefreshIndicator.adaptive(
                onRefresh: () =>
                    ref.refresh(trainerCalendarProvider(_monday).future),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.xxxl,
                  ),
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
                    const SizedBox(height: AppSpacing.sm),
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
                        const SizedBox(width: AppSpacing.sm),
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
                    const SizedBox(height: AppSpacing.lg),
                    if (data != null && data.pendingCount > 0) ...[
                      _PendingCard(
                        data.bookings.where((b) => b.isPending).toList(),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    MonthGrid(
                      start: _monday,
                      selected: _day,
                      onSelect: (d) => setState(() {
                        _day = d;
                        _view = CalendarView.day;
                      }),
                      onPeriod: _period,
                      marks: data == null ? const {} : _marks(data, _monday),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CalendarViewToggle(
                      view: _view,
                      onChanged: (v) => setState(() => _view = v),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ...calendar.when(
                      skipLoadingOnReload: true,
                      loading: () => const [SkeletonList(count: 3)],
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
                      data: (cal) => _view == CalendarView.day
                          ? _dayItems(context, cal, _day)
                          : agendaItems(
                              _monday,
                              (d) => _dayItems(context, cal, d, empty: false),
                              empty: 'V tomto období nič nemáš.',
                            ),
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

  /// Udalosti dňa. Bez [empty] vráti pri prázdnom dni prázdny zoznam.
  List<Widget> _dayItems(
    BuildContext context,
    TrainerCalendar cal,
    DateTime day, {
    bool empty = true,
  }) {
    final slots = cal.slots.where((s) => sameDay(s.startsAt, day));
    final bookings = cal.bookings.where((b) => sameDay(b.startsAt, day));
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
      return [
        if (empty)
          const EmptyDay(
            'V tento deň nič nemáš. Vypíš termín alebo zapíš tréning.',
          ),
      ];
    }
    return [
      for (final i in items) ...[i.$2, const SizedBox(height: AppSpacing.sm)],
    ];
  }
}

/// Čo je v ktorý deň obdobia (0 = prvý pondelok).
/// Zelená = tréning s klientom, oranžová = žiadosť, sivá = termín bez klientov.
Map<int, Set<DayMark>> _marks(TrainerCalendar cal, DateTime monday) =>
    markDays(monday, [
      for (final s in cal.slots)
        (s.startsAt, s.bookings.isEmpty ? DayMark.open : DayMark.training),
      for (final b in cal.bookings) (b.startsAt, bookingMark(b)),
    ], days: calendarDays);

/// Žiadosti klientov, ktoré čakajú na odpoveď (v zobrazenom období).
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
          const SizedBox(height: AppSpacing.sm),
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
