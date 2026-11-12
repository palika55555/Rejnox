import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/tm_card.dart';
import '../../training/data/exercise_catalog.dart';
import '../../training/presentation/workout_log_widgets.dart';
import '../application/coaching_providers.dart';
import '../domain/coaching_models.dart';
import 'coaching_widgets.dart';

String _kg(double w) => w == w.roundToDouble()
    ? '${w.toInt()} kg'
    : '${w.toString().replaceAll('.', ',')} kg';

/// Tréner zapisuje sériu klientovi (napr. počas osobného tréningu).
class LogClientSetCard extends ConsumerStatefulWidget {
  const LogClientSetCard({super.key, required this.clientId});

  final String clientId;

  @override
  ConsumerState<LogClientSetCard> createState() => _LogClientSetCardState();
}

class _LogClientSetCardState extends ConsumerState<LogClientSetCard> {
  final _form = GlobalKey<FormState>();
  final _reps = TextEditingController(text: '8');
  final _weight = TextEditingController(text: '20');
  String _exerciseId = exerciseCatalog.first.id;
  bool _busy = false;

  @override
  void dispose() {
    _reps.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(clientActionsProvider(widget.clientId))
          .logSet(
            exerciseId: _exerciseId,
            reps: NumberStepper.parse(_reps.text)!.toInt(),
            weightKg: NumberStepper.parse(_weight.text)!,
          );
    } on Object catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TmCard(
      grid: true,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionLabel(
              'Zapísať sériu klientovi',
              icon: Icons.add_circle_outline_rounded,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _exerciseId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Cvik'),
              items: [
                for (final e in exerciseCatalog)
                  DropdownMenuItem(value: e.id, child: Text(e.name)),
              ],
              onChanged: (id) {
                if (id != null) setState(() => _exerciseId = id);
              },
            ),
            const SizedBox(height: 10),
            NumberStepper(
              label: 'Opakovania',
              controller: _reps,
              step: 1,
              validator: (v) {
                final n = NumberStepper.parse(v ?? '');
                return n == null || n != n.roundToDouble() || n < 1 || n > 1000
                    ? 'Zadaj 1 až 1000.'
                    : null;
              },
            ),
            const SizedBox(height: 10),
            NumberStepper(
              label: 'Váha (kg)',
              controller: _weight,
              step: 2.5,
              decimal: true,
              validator: (v) {
                final n = NumberStepper.parse(v ?? '');
                return n == null || n < 0 || n > 1000
                    ? 'Zadaj 0 až 1000.'
                    : null;
              },
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: _busy ? 'Ukladám…' : 'Zapísať',
              icon: Icons.check_rounded,
              onPressed: _busy ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// Posledné série klienta zapísané trénerom.
class ClientProgressCard extends StatelessWidget {
  const ClientProgressCard(this.sets, {super.key});

  final List<ClientSet> sets;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return TmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Progres', icon: Icons.trending_up_rounded),
          const SizedBox(height: 6),
          if (sets.isEmpty)
            Text('Zatiaľ žiadne zapísané série.', style: text.bodySmall),
          for (final s in sets.take(30))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name, style: text.bodyLarge),
                        Text(formatDay(s.performedAt), style: text.bodySmall),
                      ],
                    ),
                  ),
                  Text(
                    '${s.reps} × ${_kg(s.weightKg)}',
                    style: text.bodyLarge!.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
