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

/// Kalendár môjho trénera: voľné termíny, rezervácia miesta a žiadosť o tréning.
class ClientCalendarScreen extends ConsumerStatefulWidget {
  const ClientCalendarScreen({super.key, required this.linkId});

  /// ID spolupráce s trénerom.
  final String linkId;

  @override
  ConsumerState<ClientCalendarScreen> createState() =>
      _ClientCalendarScreenState();
}

class _ClientCalendarScreenState extends ConsumerState<ClientCalendarScreen> {
  DateTime _day = DateTime.now();

  ClientWeek get _key => (linkId: widget.linkId, monday: weekStart(_day));

  ClientCalendarActions get _actions =>
      ref.read(clientCalendarActionsProvider(widget.linkId));

  Future<void> _book(Slot slot) async {
    if (await runAction(context, () => _actions.bookSlot(slot.id)) && mounted) {
      showMessage(
        context,
        'Miesto je tvoje: ${slot.title}, ${hhmm(slot.startsAt)}.',
      );
    }
  }

  Future<void> _cancel(Booking b) async {
    final ok = await confirmAction(
      context,
      title: b.isPending ? 'Stiahnuť žiadosť?' : 'Zrušiť rezerváciu?',
      message: 'Tréner uvidí, že termín je zrušený.',
      confirmLabel: b.isPending ? 'Stiahnuť' : 'Zrušiť',
    );
    if (ok && mounted) await runAction(context, () => _actions.cancel(b.id));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final calendar = ref.watch(clientCalendarProvider(_key));
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
                    ref.refresh(clientCalendarProvider(_key).future),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Späť',
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.go('/profile'),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('TRÉNINGY', style: text.headlineMedium),
                              if (data != null)
                                Text(
                                  'u trénera ${data.trainerName}',
                                  style: text.bodySmall,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    PrimaryButton(
                      label: 'Požiadať o tréning',
                      icon: Icons.edit_calendar_rounded,
                      onPressed: () => showCalendarSheet<bool>(
                        context,
                        RequestTrainingSheet(
                          linkId: widget.linkId,
                          day: _day,
                          busy: data?.busy ?? const [],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    WeekStrip(
                      monday: _key.monday,
                      selected: _day,
                      onSelect: (d) => setState(() => _day = d),
                      onWeek: (delta) => setState(
                        () => _day = _day.add(Duration(days: 7 * delta)),
                      ),
                      marks: data == null
                          ? const {}
                          : _marks(data, _key.monday),
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
                                  clientCalendarProvider(_key),
                                ),
                                child: const Text('Skúsiť znova'),
                              ),
                            ],
                          ),
                        ),
                      ],
                      data: _dayItems,
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

  List<Widget> _dayItems(ClientCalendar cal) {
    final now = DateTime.now();
    final items = <(DateTime, Widget)>[
      for (final s in cal.slots.where((s) => sameDay(s.startsAt, _day)))
        (s.startsAt, _slotTile(cal, s, now)),
      for (final b in cal.bookings.where(
        (b) => b.slotId == null && sameDay(b.startsAt, _day),
      ))
        (
          b.startsAt,
          CalendarEventTile(
            start: b.startsAt,
            end: b.endsAt,
            title: b.title ?? 'Osobný tréning',
            subtitle: [
              if (b.workoutTitle != null) 'Plán: ${b.workoutTitle}',
              if (b.note != null) b.note!,
            ].join(' · ').ifEmpty(null),
            accent: b.isPending ? AppColors.warn : AppColors.good,
            pill: BookingStatusPill(b.status),
            trailing: b.endsAt.isAfter(now) ? _cancelButton(b) : null,
          ),
        ),
      for (final busy in cal.busy.where((t) => sameDay(t.startsAt, _day)))
        (
          busy.startsAt,
          CalendarEventTile(
            start: busy.startsAt,
            end: busy.endsAt,
            title: 'Obsadené',
            subtitle: 'Tréner má v tomto čase iný tréning.',
            accent: AppColors.border,
          ),
        ),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    if (items.isEmpty) {
      return const [
        EmptyDay(
          'Tréner na tento deň nevypísal termín. Môžeš ho požiadať o vlastný čas.',
        ),
      ];
    }
    return [
      for (final i in items) ...[i.$2, const SizedBox(height: 10)],
    ];
  }

  Widget _slotTile(ClientCalendar cal, Slot s, DateTime now) {
    final mine = cal.myBookingIn(s);
    final past = !s.startsAt.isAfter(now);
    return CalendarEventTile(
      start: s.startsAt,
      end: s.endsAt,
      title: s.title,
      subtitle: s.note,
      accent: mine != null ? AppColors.good : AppColors.info,
      pill: mine != null
          ? const AppPill(
              'Máš miesto',
              tone: PillTone.good,
              icon: Icons.check_rounded,
            )
          : AppPill(
              s.isFull ? 'Plné' : 'Voľné ${s.free} z ${s.capacity}',
              tone: s.isFull ? PillTone.neutral : PillTone.info,
            ),
      trailing: mine != null
          ? (past ? null : _cancelButton(mine))
          : (past || s.isFull
                ? null
                : PrimaryButton(
                    label: 'Rezervovať',
                    compact: true,
                    onPressed: () => _book(s),
                  )),
    );
  }

  Widget _cancelButton(Booking b) => IconButton(
    tooltip: b.isPending ? 'Stiahnuť žiadosť' : 'Zrušiť rezerváciu',
    onPressed: () => _cancel(b),
    icon: const Icon(Icons.close_rounded, color: AppColors.muted),
  );
}

extension on String {
  String? ifEmpty(String? fallback) => isEmpty ? fallback : this;
}

/// Zelená = môj tréning, oranžová = moja žiadosť, sivá = voľné miesto u trénera.
Map<int, Set<DayMark>> _marks(ClientCalendar cal, DateTime monday) {
  final now = DateTime.now();
  return markDays(monday, [
    for (final s in cal.slots)
      if (cal.myBookingIn(s) != null)
        (s.startsAt, DayMark.training)
      else if (!s.isFull && s.startsAt.isAfter(now))
        (s.startsAt, DayMark.open),
    for (final b in cal.bookings.where((b) => b.slotId == null))
      (b.startsAt, bookingMark(b)),
  ]);
}

/// Klient požiada trénera o tréning vo vlastnom čase.
class RequestTrainingSheet extends ConsumerStatefulWidget {
  const RequestTrainingSheet({
    super.key,
    required this.linkId,
    required this.day,
    this.busy = const [],
  });

  final String linkId;
  final DateTime day;

  /// Obsadené časy trénera v zobrazenom týždni (na upozornenie vopred).
  final List<BusyTime> busy;

  @override
  ConsumerState<RequestTrainingSheet> createState() =>
      _RequestTrainingSheetState();
}

class _RequestTrainingSheetState extends ConsumerState<RequestTrainingSheet> {
  final _note = TextEditingController();
  late DateTime _start =
      sameDay(widget.day, DateTime.now()) || widget.day.isBefore(DateTime.now())
      ? nextFullHour()
      : DateTime(widget.day.year, widget.day.month, widget.day.day, 17);
  int _minutes = 60;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _collides {
    final end = _start.add(Duration(minutes: _minutes));
    return widget.busy.any(
      (t) => t.startsAt.isBefore(end) && _start.isBefore(t.endsAt),
    );
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      () => ref
          .read(clientCalendarActionsProvider(widget.linkId))
          .request(
            startsAt: _start,
            endsAt: _start.add(Duration(minutes: _minutes)),
            note: _note.text.trim(),
          ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.pop(context, true);
      showMessage(context, 'Žiadosť je odoslaná. Tréner ju potvrdí.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SheetFrame(
      title: 'Požiadať o tréning',
      children: [
        Text(
          'Vyber čas, ktorý ti vyhovuje. Tréner žiadosť potvrdí alebo odmietne.',
          style: text.bodySmall,
        ),
        const SizedBox(height: 14),
        TimeSlotPicker(
          start: _start,
          minutes: _minutes,
          onStart: (t) => setState(() => _start = t),
          onMinutes: (m) => setState(() => _minutes = m),
        ),
        if (_collides) ...[
          const SizedBox(height: 8),
          Text(
            'V tomto čase má tréner iný tréning, vyber iný čas.',
            style: text.bodySmall!.copyWith(color: AppColors.warn),
          ),
        ],
        const SizedBox(height: 10),
        TextField(
          controller: _note,
          maxLength: 500,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Správa trénerovi (napr. čo chceš cvičiť)',
            counterText: '',
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: _busy ? 'Odosielam…' : 'Odoslať žiadosť',
          icon: Icons.send_rounded,
          onPressed: _busy || _collides ? null : _send,
        ),
      ],
    );
  }
}
