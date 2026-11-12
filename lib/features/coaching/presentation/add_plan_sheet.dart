import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/plate_chip.dart';
import '../../../core/widgets/primary_button.dart';
import '../../training/data/exercise_catalog.dart';
import '../../training/presentation/workout_log_widgets.dart';
import '../application/coaching_providers.dart';
import '../data/coaching_api.dart';
import 'coaching_widgets.dart';

/// Formulár trénera na nový plán pre klienta.
class AddPlanSheet extends ConsumerStatefulWidget {
  const AddPlanSheet({super.key, required this.clientId});

  final String clientId;

  @override
  ConsumerState<AddPlanSheet> createState() => _AddPlanSheetState();
}

class _Row {
  _Row(this.exerciseId);

  String exerciseId;
  final sets = TextEditingController(text: '3');
  final reps = TextEditingController(text: '10');
  final weight = TextEditingController();

  void dispose() {
    sets.dispose();
    reps.dispose();
    weight.dispose();
  }
}

class _AddPlanSheetState extends ConsumerState<AddPlanSheet> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _rows = [_Row(exerciseCatalog.first.id)];
  DateTime? _date;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  static String? _intIn(String? v, int max) {
    final n = int.tryParse((v ?? '').trim());
    return n == null || n < 1 || n > max ? '1–$max' : null;
  }

  static String? _weight(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final n = NumberStepper.parse(t);
    return n == null || n < 0 || n > 1000 ? '0–1000' : null;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(clientActionsProvider(widget.clientId))
          .addPlan(
            title: _title.text.trim(),
            scheduledOn: _date,
            items: [
              for (final r in _rows)
                NewPlanItem(
                  exerciseId: r.exerciseId,
                  sets: int.parse(r.sets.text.trim()),
                  reps: int.parse(r.reps.text.trim()),
                  weightKg: r.weight.text.trim().isEmpty
                      ? null
                      : NumberStepper.parse(r.weight.text),
                ),
            ],
          );
      if (mounted) Navigator.pop(context, true);
    } on Object catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _form,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          children: [
            Text('NOVÝ PLÁN', style: text.headlineMedium),
            const SizedBox(height: 14),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Názov',
                hintText: 'Napr. Nohy A',
              ),
              validator: (v) {
                final t = (v ?? '').trim();
                return t.isEmpty || t.length > 120 ? 'Zadaj názov.' : null;
              },
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event_rounded, size: 18),
              label: Text(
                _date == null ? 'Dátum (nepovinné)' : formatDay(_date!),
              ),
            ),
            const SizedBox(height: 4),
            for (var i = 0; i < _rows.length; i++) _rowEditor(i),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _rows.length >= 30
                    ? null
                    : () => setState(
                        () => _rows.add(_Row(exerciseCatalog.first.id)),
                      ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Pridať cvik'),
              ),
            ),
            const SizedBox(height: 10),
            PrimaryButton(
              label: _busy ? 'Ukladám…' : 'Uložiť plán',
              onPressed: _busy ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowEditor(int i) {
    final row = _rows[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: row.exerciseId,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: 'Cvik ${i + 1}'),
                  items: [
                    for (final e in exerciseCatalog)
                      DropdownMenuItem(
                        value: e.id,
                        child: Row(
                          children: [
                            PlateDot(e.group.plate, size: 9),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                e.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (id) {
                    if (id != null) setState(() => row.exerciseId = id);
                  },
                ),
              ),
              if (_rows.length > 1)
                IconButton(
                  tooltip: 'Odobrať cvik',
                  onPressed: () => setState(() => _rows.removeAt(i).dispose()),
                  icon: const Icon(Icons.close_rounded, color: AppColors.muted),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: row.sets,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Série'),
                  validator: (v) => _intIn(v, 20),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: row.reps,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Opak.'),
                  validator: (v) => _intIn(v, 1000),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: row.weight,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'kg'),
                  validator: _weight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
