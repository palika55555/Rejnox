import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/tm_card.dart';
import '../../coaching/application/coaching_providers.dart';
import '../../coaching/domain/coaching_models.dart';
import '../../coaching/presentation/coaching_widgets.dart';
import '../application/booking_providers.dart';
import '../domain/booking_models.dart';
import 'calendar_widgets.dart';

/// Spoločný rám spodných panelov: nadpis, obsah, odsadenie nad klávesnicou.
class SheetFrame extends StatelessWidget {
  const SheetFrame({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      16,
      20,
      20 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );
}

Future<T?> showCalendarSheet<T>(BuildContext context, Widget sheet) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.sheet,
      builder: (_) => sheet,
    );

/// Spustí akciu, chybu ukáže v snackbare. Vráti true pri úspechu.
Future<bool> runAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
    return true;
  } on Object catch (e) {
    if (context.mounted) showError(context, e);
    return false;
  }
}

// ------------------------------------------------------------ nový termín

/// Tréner vypíše voľný termín, do ktorého sa klienti sami prihlásia.
class NewSlotSheet extends ConsumerStatefulWidget {
  const NewSlotSheet({super.key, required this.day});

  final DateTime day;

  @override
  ConsumerState<NewSlotSheet> createState() => _NewSlotSheetState();
}

class _NewSlotSheetState extends ConsumerState<NewSlotSheet> {
  final _title = TextEditingController(text: 'Osobný tréning');
  final _note = TextEditingController();
  late DateTime _start = _initialStart(widget.day);
  int _minutes = 60;
  int _capacity = 1;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      showMessage(context, 'Zadaj názov termínu.');
      return;
    }
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      () => ref
          .read(trainerCalendarActionsProvider)
          .addSlot(
            startsAt: _start,
            endsAt: _start.add(Duration(minutes: _minutes)),
            title: _title.text.trim(),
            capacity: _capacity,
            note: _note.text.trim(),
          ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SheetFrame(
      title: 'Vypísať termín',
      children: [
        Text(
          'Klienti uvidia termín vo tvojom kalendári a miesto si rezervujú sami.',
          style: text.bodySmall,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _title,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: 'Názov',
            counterText: '',
          ),
        ),
        const SizedBox(height: 14),
        TimeSlotPicker(
          start: _start,
          minutes: _minutes,
          onStart: (t) => setState(() => _start = t),
          onMinutes: (m) => setState(() => _minutes = m),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: Text('Počet miest', style: text.bodyLarge)),
            IconButton(
              tooltip: 'Menej miest',
              onPressed: _capacity > 1
                  ? () => setState(() => _capacity--)
                  : null,
              icon: const Icon(Icons.remove_circle_outline_rounded),
            ),
            Text('$_capacity', style: text.titleMedium),
            IconButton(
              tooltip: 'Viac miest',
              onPressed: _capacity < 50
                  ? () => setState(() => _capacity++)
                  : null,
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
          ],
        ),
        TextField(
          controller: _note,
          maxLength: 500,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Poznámka (napr. kde sa stretnete)',
            counterText: '',
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: _busy ? 'Ukladám…' : 'Vypísať',
          icon: Icons.event_available_rounded,
          onPressed: _busy ? null : _save,
        ),
      ],
    );
  }
}

/// Začiatok na zvolený deň: dnes najbližšia celá hodina, inak 9:00.
DateTime _initialStart(DateTime day) => sameDay(day, DateTime.now())
    ? nextFullHour()
    : DateTime(day.year, day.month, day.day, 9);

void showMessage(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));

// ---------------------------------------------------- tréning pre klienta

/// Tréner zapíše tréning konkrétnemu klientovi (aj odcvičený), voliteľne s plánom.
class TrainerBookingSheet extends ConsumerStatefulWidget {
  const TrainerBookingSheet({
    super.key,
    required this.day,
    this.slot,
    this.clientId,
  });

  final DateTime day;

  /// Ak je zadaný, klient dostane miesto v tomto termíne (čas je daný).
  final Slot? slot;
  final String? clientId;

  @override
  ConsumerState<TrainerBookingSheet> createState() =>
      _TrainerBookingSheetState();
}

class _TrainerBookingSheetState extends ConsumerState<TrainerBookingSheet> {
  final _title = TextEditingController();
  final _note = TextEditingController();
  late DateTime _start = _initialStart(widget.day);
  int _minutes = 60;
  late String? _clientId = widget.clientId;
  String? _planId;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final clientId = _clientId;
    if (clientId == null) {
      showMessage(context, 'Vyber klienta.');
      return;
    }
    final slot = widget.slot;
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      () => ref
          .read(trainerCalendarActionsProvider)
          .addBooking(
            clientId: clientId,
            slotId: slot?.id,
            startsAt: slot == null ? _start : null,
            endsAt: slot == null
                ? _start.add(Duration(minutes: _minutes))
                : null,
            title: _title.text.trim(),
            note: _note.text.trim(),
            workoutId: _planId,
          ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final clients = ref.watch(clientsProvider);
    final active = [
      for (final c in clients.value ?? const <ClientLink>[])
        if (c.isActive) c,
    ];
    final clientId = _clientId;
    final plans = clientId == null
        ? const <Plan>[]
        : ref.watch(clientDetailProvider(clientId)).value?.plans ??
              const <Plan>[];
    final slot = widget.slot;

    return SheetFrame(
      title: slot == null ? 'Zapísať tréning' : 'Pridať do termínu',
      children: [
        if (clients.isLoading && !clients.hasValue)
          const Center(child: CircularProgressIndicator())
        else if (active.isEmpty)
          Text(
            'Najprv si pridaj klienta v časti Klienti.',
            style: text.bodyMedium,
          )
        else
          DropdownButtonFormField<String>(
            initialValue: clientId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Klient'),
            items: [
              for (final c in active)
                DropdownMenuItem(value: c.id, child: Text(c.name)),
            ],
            onChanged: (id) => setState(() {
              _clientId = id;
              _planId = null;
            }),
          ),
        const SizedBox(height: 14),
        if (slot == null) ...[
          TimeSlotPicker(
            start: _start,
            minutes: _minutes,
            allowPast: true,
            onStart: (t) => setState(() => _start = t),
            onMinutes: (m) => setState(() => _minutes = m),
          ),
          const SizedBox(height: 6),
          Text(
            'Odcvičený tréning zapíšeš aj spätne (najviac 90 dní).',
            style: text.bodySmall,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _title,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Názov (napr. Nohy)',
              counterText: '',
            ),
          ),
        ] else
          Text(
            '${slot.title} · ${weekdayShort(slot.startsAt)} '
            '${slot.startsAt.day}. ${slot.startsAt.month}. · '
            '${timeRange(slot.startsAt, slot.endsAt)}',
            style: text.bodyLarge,
          ),
        if (plans.isNotEmpty) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            initialValue: _planId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Plán tréningu'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Bez plánu')),
              for (final p in plans)
                DropdownMenuItem(value: p.id, child: Text(p.title)),
            ],
            onChanged: (id) => setState(() => _planId = id),
          ),
        ],
        const SizedBox(height: 6),
        TextField(
          controller: _note,
          maxLength: 500,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Poznámka',
            counterText: '',
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: _busy ? 'Ukladám…' : 'Zapísať do kalendára',
          icon: Icons.check_rounded,
          onPressed: _busy || active.isEmpty ? null : _save,
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- detaily

/// Detail tréningu alebo žiadosti: potvrdiť, odmietnuť, otvoriť klienta.
class TrainerBookingDetailSheet extends ConsumerWidget {
  const TrainerBookingDetailSheet(this.booking, {super.key});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final actions = ref.read(trainerCalendarActionsProvider);
    final b = booking;

    Future<void> act(Future<void> Function() action) async {
      if (await runAction(context, action) && context.mounted) {
        Navigator.pop(context);
      }
    }

    return SheetFrame(
      title:
          b.title ?? (b.slotId == null ? 'Osobný tréning' : 'Miesto v termíne'),
      children: [
        Text(b.clientName, style: text.titleMedium),
        const SizedBox(height: 4),
        Text(
          '${weekdayShort(b.startsAt)} ${b.startsAt.day}. ${b.startsAt.month}. · '
          '${timeRange(b.startsAt, b.endsAt)}',
          style: text.bodyLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            BookingStatusPill(b.status),
            if (b.requestedByClient)
              const AppPill('Od klienta', tone: PillTone.info),
            if (b.workoutTitle != null)
              AppPill('Plán: ${b.workoutTitle}', tone: PillTone.accent),
          ],
        ),
        if (b.note != null) ...[
          const SizedBox(height: 10),
          Text('„${b.note}“', style: text.bodyMedium),
        ],
        const SizedBox(height: 18),
        if (b.isPending) ...[
          PrimaryButton(
            label: 'Potvrdiť',
            icon: Icons.check_rounded,
            onPressed: () => act(() => actions.confirm(b.id)),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            context.go('/clients/${b.clientId}');
          },
          icon: const Icon(Icons.trending_up_rounded),
          label: const Text('Klient: plány, zápis sérií a progres'),
        ),
        const SizedBox(height: 4),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          onPressed: () async {
            final ok = await confirmAction(
              context,
              title: b.isPending ? 'Odmietnuť žiadosť?' : 'Zrušiť tréning?',
              message: 'Klient uvidí, že termín je zrušený.',
              confirmLabel: b.isPending ? 'Odmietnuť' : 'Zrušiť tréning',
            );
            if (ok && context.mounted) await act(() => actions.cancel(b.id));
          },
          child: Text(b.isPending ? 'Odmietnuť' : 'Zrušiť tréning'),
        ),
      ],
    );
  }
}

/// Detail vypísaného termínu: kto má miesto, pridať klienta, zrušiť termín.
class SlotDetailSheet extends ConsumerWidget {
  const SlotDetailSheet(this.slot, {super.key});

  final Slot slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final actions = ref.read(trainerCalendarActionsProvider);
    return SheetFrame(
      title: slot.title,
      children: [
        Text(
          '${weekdayShort(slot.startsAt)} ${slot.startsAt.day}. ${slot.startsAt.month}. · '
          '${timeRange(slot.startsAt, slot.endsAt)}',
          style: text.bodyLarge,
        ),
        const SizedBox(height: 6),
        Text(
          'Obsadené ${slot.taken} z ${slot.capacity}',
          style: text.bodySmall,
        ),
        if (slot.note != null) ...[
          const SizedBox(height: 8),
          Text(slot.note!, style: text.bodyMedium),
        ],
        const SizedBox(height: 12),
        if (slot.bookings.isEmpty)
          Text('Zatiaľ sa nikto neprihlásil.', style: text.bodySmall),
        for (final b in slot.bookings)
          AppRow(
            title: b.clientName,
            subtitle: b.requestedByClient ? 'Rezervoval sám' : 'Pridal si ty',
            trailing: IconButton(
              tooltip: 'Zrušiť miesto',
              icon: const Icon(Icons.close_rounded, color: AppColors.muted),
              onPressed: () async {
                if (await runAction(context, () => actions.cancel(b.id)) &&
                    context.mounted) {
                  Navigator.pop(context);
                }
              },
            ),
            onTap: () {
              Navigator.pop(context);
              context.go('/clients/${b.clientId}');
            },
          ),
        const SizedBox(height: 14),
        if (!slot.isFull)
          PrimaryButton(
            label: 'Pridať klienta',
            icon: Icons.person_add_alt_1_rounded,
            onPressed: () {
              Navigator.pop(context);
              showCalendarSheet<bool>(
                context,
                TrainerBookingSheet(day: slot.startsAt, slot: slot),
              );
            },
          ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          onPressed: () async {
            final ok = await confirmAction(
              context,
              title: 'Zrušiť termín?',
              message: slot.taken == 0
                  ? 'Termín zmizne z kalendára.'
                  : 'Zrušia sa aj rezervácie ${slot.taken} klientov.',
              confirmLabel: 'Zrušiť termín',
            );
            if (ok &&
                context.mounted &&
                await runAction(context, () => actions.deleteSlot(slot.id)) &&
                context.mounted) {
              Navigator.pop(context);
            }
          },
          child: const Text('Zrušiť termín'),
        ),
      ],
    );
  }
}

class BookingStatusPill extends StatelessWidget {
  const BookingStatusPill(this.status, {super.key});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) => AppPill(
    status.label,
    tone: switch (status) {
      BookingStatus.confirmed => PillTone.good,
      BookingStatus.requested => PillTone.warn,
      BookingStatus.cancelled => PillTone.neutral,
    },
  );
}
