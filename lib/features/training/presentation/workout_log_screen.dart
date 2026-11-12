import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/plate_chip.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/tm_card.dart';
import '../../coaching/presentation/trainer_plans_section.dart';
import '../application/workout_log_controller.dart';
import '../data/exercise_catalog.dart';
import '../domain/training_models.dart';
import 'workout_log_widgets.dart';

/// Zápis tréningu. Funguje aj bez internetu.
class WorkoutLogScreen extends ConsumerStatefulWidget {
  const WorkoutLogScreen({super.key});

  @override
  ConsumerState<WorkoutLogScreen> createState() => _WorkoutLogScreenState();
}

class _WorkoutLogScreenState extends ConsumerState<WorkoutLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reps = TextEditingController(text: '8');
  final _weight = TextEditingController(text: '20');
  String _exerciseId = exerciseCatalog.first.id;

  @override
  void dispose() {
    _reps.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(workoutLogProvider.notifier)
        .addSet(
          exerciseId: _exerciseId,
          reps: NumberStepper.parse(_reps.text)!.toInt(),
          weightKg: NumberStepper.parse(_weight.text)!,
        );
  }

  static String? _validateReps(String? value) {
    final n = NumberStepper.parse(value ?? '');
    if (n == null || n != n.roundToDouble() || n < 1 || n > 1000) {
      return 'Zadaj 1 až 1000.';
    }
    return null;
  }

  static String? _validateWeight(String? value) {
    final n = NumberStepper.parse(value ?? '');
    if (n == null || n < 0 || n > 1000) return 'Zadaj 0 až 1000.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final log = ref.watch(workoutLogProvider);
    final now = DateTime.now();
    bool isToday(DateTime d) =>
        d.year == now.year && d.month == now.month && d.day == now.day;
    final today = log.sets.where((s) => isToday(s.performedAt)).toList();
    final earlier = log.sets.where((s) => !isToday(s.performedAt)).toList();

    Widget row(LoggedSet s) => LoggedSetRow(
      s,
      onDelete: s.state == SyncState.pending
          ? () => ref.read(workoutLogProvider.notifier).removePending(s.id)
          : null,
    );

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('TRÉNING', style: text.headlineMedium)),
                SyncStatusPill(log),
              ],
            ),
            if (log.offline && log.pendingCount > 0) ...[
              const SizedBox(height: 12),
              OfflineBanner(pending: log.pendingCount),
            ],
            const SizedBox(height: 16),
            const TrainerPlansSection(),
            TmCard(
              grid: true,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionLabel(
                      'Nová séria',
                      icon: Icons.add_circle_outline_rounded,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _exerciseId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Cvik'),
                      items: [
                        for (final e in exerciseCatalog)
                          DropdownMenuItem(
                            value: e.id,
                            child: Row(
                              children: [
                                PlateDot(e.group.plate, size: 9),
                                const SizedBox(width: 10),
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
                        if (id != null) setState(() => _exerciseId = id);
                      },
                    ),
                    const SizedBox(height: 12),
                    NumberStepper(
                      label: 'Opakovania',
                      controller: _reps,
                      step: 1,
                      validator: _validateReps,
                    ),
                    const SizedBox(height: 12),
                    NumberStepper(
                      label: 'Váha (kg)',
                      controller: _weight,
                      step: 2.5,
                      decimal: true,
                      validator: _validateWeight,
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Zapísať sériu',
                      icon: Icons.check_rounded,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (log.loaded && log.sets.isEmpty)
              Text(
                'Zatiaľ žiadne série. Prvú zapíšeš hore, aj bez internetu.',
                style: text.bodyMedium,
                textAlign: TextAlign.center,
              ),
            if (today.isNotEmpty)
              TmCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionLabel('Dnes · ${today.length} sérií'),
                    const SizedBox(height: 4),
                    for (final s in today) row(s),
                  ],
                ),
              ),
            if (earlier.isNotEmpty) ...[
              const SizedBox(height: 12),
              TmCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Posledné dni'),
                    const SizedBox(height: 4),
                    for (final s in earlier.take(30)) row(s),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
