import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tm_card.dart';
import '../../coaching/application/coaching_providers.dart';
import '../../coaching/domain/coaching_models.dart';
import '../../booking/application/booking_providers.dart';
import '../../booking/presentation/upcoming_trainings_section.dart';
import '../../coaching/presentation/trainer_plans_section.dart';
import '../../health/workout_heart_rate_card.dart';
import '../application/exercise_stats.dart';
import '../application/rest_alerts.dart';
import '../application/workout_log_controller.dart';
import '../application/workout_session.dart';
import '../data/exercise_catalog.dart';
import '../domain/training_models.dart';
import 'exercise_picker_sheet.dart';
import 'set_logger_widgets.dart';
import 'workout_log_widgets.dart';
import 'workout_session_widgets.dart';
import '../../../core/theme/app_spacing.dart';

/// Zápis tréningu. Funguje aj bez internetu.
class WorkoutLogScreen extends ConsumerStatefulWidget {
  const WorkoutLogScreen({super.key});

  @override
  ConsumerState<WorkoutLogScreen> createState() => _WorkoutLogScreenState();
}

class _WorkoutLogScreenState extends ConsumerState<WorkoutLogScreen> {
  static const _defaultRest = Duration(seconds: 90);

  final _formKey = GlobalKey<FormState>();
  final _scroll = ScrollController();
  bool _submitting = false;
  final _reps = TextEditingController(text: '8');
  final _weight = TextEditingController(text: '20');
  String _exerciseId = exerciseCatalog.first.id;
  SetKind _kind = SetKind.working;

  /// Koniec pauzy medzi sériami (null = pauza nebeží).
  DateTime? _restEnd;
  Duration _restTotal = _defaultRest;

  /// Každú sekundu prekreslí hodiny tréningu a pauzy.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    ref.listenManual(workoutSessionProvider.select((state) => state.active), (
      _,
      active,
    ) {
      if (active != null && active.plan.isNotEmpty) {
        final next = active
            .progressFrom(ref.read(workoutLogProvider).sets)
            .next;
        if (next != null) {
          _applyTarget(next);
          if (_scroll.hasClients) _scroll.jumpTo(0);
        }
      }
    }, fireImmediately: true);
    ref.listenManual(workoutLogProvider.select((state) => state.loaded), (
      previous,
      loaded,
    ) {
      final active = ref.read(workoutSessionProvider).active;
      if (previous == false &&
          loaded &&
          active != null &&
          active.plan.isNotEmpty) {
        final next = active
            .progressFrom(ref.read(workoutLogProvider).sets)
            .next;
        if (next != null) _applyTarget(next);
      }
    });
  }

  /// Nastaví koniec pauzy a zosúladí systémový odpočet mimo appky.
  void _setRest(DateTime? end, {bool notify = true}) {
    setState(() => _restEnd = end);
    if (!notify) return;
    final alerts = ref.read(restAlertsProvider);
    unawaited(end == null ? alerts.cancel() : alerts.start(end));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _scroll.dispose();
    _reps.dispose();
    _weight.dispose();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    final end = _restEnd;
    if (end != null && !DateTime.now().isBefore(end)) {
      HapticFeedback.heavyImpact();
      _setRest(null);
      return;
    }
    // Hodiny tréningu tikajú samy (LiveElapsed), tu len pauza.
    if (end != null) setState(() {});
  }

  List<LoggedSet> _todaySets() {
    final now = DateTime.now();
    return [
      for (final s in ref.read(workoutLogProvider).sets)
        if (s.performedAt.year == now.year &&
            s.performedAt.month == now.month &&
            s.performedAt.day == now.day)
          s,
    ];
  }

  Future<void> _submit(String exerciseId) async {
    if (_submitting ||
        !ref.read(workoutLogProvider).loaded ||
        !_formKey.currentState!.validate()) {
      return;
    }
    final reps = MetricStepper.parse(_reps.text)!.toInt();
    final weight = MetricStepper.parse(_weight.text)!;
    final kind = _kind;
    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();
    try {
      final starting = ref.read(workoutSessionProvider.notifier).start();
      final active = ref.read(workoutSessionProvider).active;
      await starting;
      if (!mounted ||
          active == null ||
          !identical(active, ref.read(workoutSessionProvider).active)) {
        return;
      }
      final before = active
          .progressFrom(ref.read(workoutLogProvider).sets)
          .next;
      final previousBest = ExerciseHistory.fromSets(
        ref.read(workoutLogProvider).sets,
      )[exerciseId]?.bestKg;
      await ref
          .read(workoutLogProvider.notifier)
          .addSet(
            exerciseId: exerciseId,
            reps: reps,
            weightKg: weight,
            kind: kind,
          );
      if (!mounted ||
          !identical(active, ref.read(workoutSessionProvider).active)) {
        return;
      }
      final next = active.progressFrom(ref.read(workoutLogProvider).sets).next;
      if (next != null &&
          !identical(before, next) &&
          before?.exerciseId == exerciseId &&
          _exerciseId == exerciseId) {
        _applyTarget(next);
      }
      if (previousBest != null && weight > previousBest) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Nový osobný rekord: ${formatKg(weight)} kg'),
            ),
          );
      }
      _restTotal = _defaultRest;
      _setRest(DateTime.now().add(_defaultRest));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _applyTarget(PlanItem item) {
    final last = ExerciseHistory.fromSets(
      ref.read(workoutLogProvider).sets,
    )[item.exerciseId]?.last;
    setState(() {
      _exerciseId = item.exerciseId;
      _kind = SetKind.working;
      _reps.text = '${item.reps}';
      _weight.text = formatKg(item.weightKg ?? last?.weightKg ?? 0);
    });
  }

  Future<void> _startPlan(Plan plan) => ref
      .read(workoutSessionProvider.notifier)
      .start(title: plan.title, plan: plan.items);

  Exercise _exerciseFor(ActiveWorkout? active) {
    final planned = active?.plan
        .where((item) => item.exerciseId == _exerciseId)
        .firstOrNull;
    return exerciseById(_exerciseId) ??
        (planned == null
            ? exerciseCatalog.first
            : Exercise(
                id: planned.exerciseId,
                name: planned.name,
                group: planned.group,
              ));
  }

  void _adjustRest(int seconds) {
    final end = _restEnd;
    if (end == null) return;
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    final next = end.add(Duration(seconds: seconds));
    if (!next.isAfter(now)) {
      _setRest(null);
      return;
    }
    final left = next.difference(now);
    if (left > _restTotal) _restTotal = left;
    _setRest(next);
  }

  /// Predvyplní opakovania a váhu podľa poslednej série cviku.
  void _useLast(ExerciseHistory? history) {
    final last = history?.last;
    if (last == null) return;
    _reps.text = '${last.reps}';
    _weight.text = formatKg(last.weightKg);
  }

  void _addWeight(double kg) {
    final current = MetricStepper.parse(_weight.text) ?? 0;
    _weight.text = formatKg((current + kg).clamp(0, 1000).toDouble());
  }

  Future<void> _pickExercise(Map<String, ExerciseHistory> history) async {
    final picked = await showExercisePicker(
      context,
      selectedId: _exerciseId,
      history: history,
    );
    if (picked == null || !mounted) return;
    HapticFeedback.selectionClick();
    setState(() => _exerciseId = picked.id);
    _useLast(history[picked.id]);
  }

  static String? _validateReps(String? value) {
    final n = MetricStepper.parse(value ?? '');
    if (n == null ||
        !n.isFinite ||
        n != n.roundToDouble() ||
        n < 1 ||
        n > 1000) {
      return 'Zadaj 1 až 1000.';
    }
    return null;
  }

  static String? _validateWeight(String? value) {
    final n = MetricStepper.parse(value ?? '');
    if (n == null || !n.isFinite || n < 0 || n > 1000) {
      return 'Zadaj 0 až 1000.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final log = ref.watch(workoutLogProvider);
    final hasPlans =
        ref.watch(myPlansProvider).value?.plans.isNotEmpty ?? false;
    final hasTrainings =
        ref.watch(myTrainingsProvider).value?.isNotEmpty ?? false;
    final history = ExerciseHistory.fromSets(log.sets);
    final today = _todaySets();
    final todayIds = {for (final s in today) s.id};
    final earlier = [
      for (final s in log.sets)
        if (!todayIds.contains(s.id)) s,
    ];
    final volume = today.fold(0.0, (v, s) => v + s.volumeKg);
    final active = ref.watch(workoutSessionProvider).active;
    final sessionSets = active?.setsFrom(log.sets) ?? const <LoggedSet>[];
    final progress = active?.progressFrom(log.sets);
    final exercise = _exerciseFor(active);
    final restEnd = _restEnd;
    final restLeft = restEnd?.difference(DateTime.now());

    Widget row(LoggedSet s) {
      final pending = s.state == SyncState.pending;
      final notifier = ref.read(workoutLogProvider.notifier);
      final tile = LoggedSetRow(
        s,
        onDelete: pending ? () => notifier.removePending(s.id) : null,
      );
      if (!pending) return tile;
      // Neodoslanú sériu možno zmazať aj potiahnutím doľava.
      return Dismissible(
        key: ValueKey(s.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => notifier.removePending(s.id),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: AppSpacing.xl),
          color: AppColors.error,
          child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
        ),
        child: tile,
      );
    }

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          Column(
            children: [
              ScreenHeader(
                'Tréning',
                subtitle: active == null
                    ? null
                    : '${active.title} · ${sessionProgressLabel(sessionSets.length, sessionSets.fold(0.0, (v, s) => v + s.volumeKg))}',
                trailing: [
                  if (active != null) _ClockPill(since: active.startedAt),
                  SyncStatusPill(log),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    restLeft == null ? 96 : 172,
                  ),
                  child: SectionStack(
                    children: [
                      if (log.offline && log.pendingCount > 0)
                        OfflineBanner(pending: log.pendingCount),
                      if (hasTrainings)
                        UpcomingTrainingsSection(
                          onStart: active == null && !_submitting
                              ? _startPlan
                              : null,
                        ),
                      AppSection(
                        title: 'Nová séria',
                        trailing: SetKindPicker(
                          selected: _kind,
                          onChanged: (k) => setState(() => _kind = k),
                        ),
                        child: _form(
                          history,
                          exercise,
                          progress,
                          canSubmit: log.loaded && !_submitting,
                        ),
                      ),
                      if (log.loaded && log.sets.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                          ),
                          child: Text(
                            'Zatiaľ žiadne série. Prvú zapíšeš hore, '
                            'aj bez internetu.',
                            style: text.bodyMedium!.copyWith(
                              color: AppColors.ink2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      if (today.isNotEmpty)
                        AppSection(
                          title: 'Dnes · ${today.length} sérií',
                          trailing: Text(
                            'Objem ${formatKg(volume.roundToDouble())} kg',
                            style: text.bodySmall!.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink2,
                            ),
                          ),
                          child: AppList(
                            children: [for (final s in today) row(s)],
                          ),
                        ),
                      const WorkoutHeartRateCard(),
                      if (hasPlans)
                        TrainerPlansSection(
                          onStart: active == null && !_submitting
                              ? _startPlan
                              : null,
                        ),
                      if (earlier.isNotEmpty)
                        AppSection(
                          title: 'Posledné dni',
                          child: AppList(
                            children: [
                              for (final s in earlier.take(30)) row(s),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (restLeft != null) ...[
                  RestTimerBar(
                    remaining: restLeft.isNegative ? Duration.zero : restLeft,
                    total: _restTotal,
                    onAdjust: _adjustRest,
                    onClose: () => _setRest(null),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (active == null)
                  PrimaryButton(
                    label: 'Začať tréning',
                    icon: Icons.play_arrow_rounded,
                    tone: ButtonTone.accent,
                    onPressed: () =>
                        ref.read(workoutSessionProvider.notifier).start(),
                  )
                else
                  PrimaryButton(
                    label: 'Ukončiť tréning',
                    icon: Icons.flag_outlined,
                    tone: ButtonTone.ink,
                    onPressed: _submitting
                        ? null
                        : () async {
                            if (await confirmFinishWorkout(context, ref) &&
                                mounted) {
                              _setRest(null);
                            }
                          },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _form(
    Map<String, ExerciseHistory> history,
    Exercise exercise,
    PlanProgress? progress, {
    required bool canSubmit,
  }) {
    final last = history[exercise.id]?.last;
    return TmCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExerciseSelector(
              exercise: exercise,
              history: history[exercise.id],
              onTap: () => _pickExercise(history),
            ),
            if (progress != null && progress.total > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                progress.next == null
                    ? 'Plán splnený · ${progress.done} z ${progress.total} sérií'
                    : 'Plán · ${progress.done} z ${progress.total} sérií',
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: progress.next == null
                      ? AppColors.good
                      : AppColors.ink2,
                ),
              ),
              if (progress.next case final next?
                  when next.exerciseId != exercise.id)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => _applyTarget(next),
                    child: Text('Ďalší z plánu: ${next.name}'),
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: MetricStepper(
                    label: 'Opakovania',
                    unit: 'opak.',
                    controller: _reps,
                    step: 1,
                    validator: _validateReps,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: MetricStepper(
                    label: 'Váha',
                    unit: 'kg',
                    controller: _weight,
                    step: 2.5,
                    decimal: true,
                    validator: _validateWeight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (last != null)
                  QuickChip(
                    label:
                        'Minule ${last.reps} × ${formatKg(last.weightKg)} kg',
                    onTap: () => _useLast(history[exercise.id]),
                  ),
                for (final kg in const [2.5, 5.0, 10.0])
                  QuickChip(
                    label: '+${formatKg(kg)} kg',
                    onTap: () => _addWeight(kg),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            ListenableBuilder(
              listenable: Listenable.merge([_reps, _weight]),
              builder: (context, _) => PrimaryButton(
                label:
                    'Zapísať sériu · ${_reps.text.trim()} × '
                    '${_weight.text.trim()} kg',
                icon: Icons.check_rounded,
                onPressed: canSubmit ? () => _submit(exercise.id) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hodiny prebiehajúceho tréningu v hlavičke.
class _ClockPill extends StatelessWidget {
  const _ClockPill({required this.since});

  final DateTime since;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 13, color: AppColors.accent),
          const SizedBox(width: AppSpacing.xs),
          LiveElapsed(
            since: since,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
