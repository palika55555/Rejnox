import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/primary_button.dart';
import '../../coaching/application/coaching_providers.dart';
import '../../coaching/domain/coaching_models.dart';
import '../../coaching/presentation/coaching_widgets.dart';
import '../application/booking_providers.dart';
import '../domain/booking_models.dart';
import 'trainer_calendar_sheets.dart';

/// Tréner pripojí k tréningu plán klienta, aby klient vedel, čo sa bude robiť.
class BookingPlanSheet extends ConsumerStatefulWidget {
  const BookingPlanSheet(this.booking, {super.key});

  final Booking booking;

  @override
  ConsumerState<BookingPlanSheet> createState() => _BookingPlanSheetState();
}

class _BookingPlanSheetState extends ConsumerState<BookingPlanSheet> {
  late String? _planId = widget.booking.workoutId;
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      () => ref
          .read(trainerCalendarActionsProvider)
          .setPlan(widget.booking.id, _planId),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.pop(context, true);
      showMessage(
        context,
        _planId == null
            ? 'Plán je odpojený.'
            : 'Plán je pripojený. Klient dostal upozornenie.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final b = widget.booking;
    final detail = ref.watch(clientDetailProvider(b.clientId));
    final plans = detail.value?.plans ?? const <Plan>[];
    final selected = plans.where((p) => p.id == _planId).firstOrNull;

    return SheetFrame(
      title: 'Rozpis tréningu',
      children: [
        Text(
          '${b.clientName} · ${weekdayShort(b.startsAt)} '
          '${b.startsAt.day}. ${b.startsAt.month}. · '
          '${timeRange(b.startsAt, b.endsAt)}',
          style: text.bodyLarge,
        ),
        const SizedBox(height: 14),
        if (detail.isLoading && !detail.hasValue)
          const Center(child: CircularProgressIndicator())
        else if (detail.hasError && !detail.hasValue)
          Text(errorText(detail.error!), style: text.bodySmall)
        else if (plans.isEmpty) ...[
          Text(
            'Klient zatiaľ nemá žiadny plán. Vytvor ho v detaile klienta '
            'a potom ho sem pripoj.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              context.go('/clients/${b.clientId}');
            },
            icon: const Icon(Icons.assignment_rounded),
            label: const Text('Vytvoriť plán'),
          ),
        ] else ...[
          DropdownButtonFormField<String?>(
            initialValue: plans.any((p) => p.id == _planId) ? _planId : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Plán tréningu'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Bez plánu')),
              for (final p in plans)
                DropdownMenuItem(value: p.id, child: Text(p.title)),
            ],
            onChanged: (id) => setState(() => _planId = id),
          ),
          if (selected != null) ...[
            const SizedBox(height: 12),
            PlanCard(selected),
          ],
          const SizedBox(height: 16),
          PrimaryButton(
            label: _busy ? 'Ukladám…' : 'Uložiť',
            icon: Icons.check_rounded,
            onPressed: _busy || _planId == b.workoutId ? null : _save,
          ),
        ],
      ],
    );
  }
}
