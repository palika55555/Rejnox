import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/tm_card.dart';
import '../application/exercise_stats.dart';
import '../application/workout_log_controller.dart';
import '../application/workout_session.dart';

/// Čas od [since], prekresľuje sa sám každú sekundu.
class LiveElapsed extends StatefulWidget {
  const LiveElapsed({super.key, required this.since, this.style});

  final DateTime since;
  final TextStyle? style;

  @override
  State<LiveElapsed> createState() => _LiveElapsedState();
}

class _LiveElapsedState extends State<LiveElapsed> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.since);
    return Text(
      formatClock(elapsed.isNegative ? Duration.zero : elapsed),
      style: widget.style,
    );
  }
}

/// „3 série · 1 250 kg“ pre prebiehajúci tréning.
String sessionProgressLabel(int sets, double volumeKg) {
  final word = switch (sets) {
    1 => 'séria',
    >= 2 && <= 4 => 'série',
    _ => 'sérií',
  };
  return '$sets $word · ${formatKg(volumeKg.roundToDouble())} kg';
}

/// Opýta sa na ukončenie tréningu a ukáže súhrn. Vráti true, ak skončil.
Future<bool> confirmFinishWorkout(BuildContext context, WidgetRef ref) async {
  final finished = await showModalBottomSheet<bool>(
    context: context,
    builder: (_) => const _FinishSheet(),
  );
  if (finished != true) return false;
  final summary = await ref.read(workoutSessionProvider.notifier).finish();
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          summary == null
              ? 'Tréning bez sérií sa zahodil.'
              : 'Tréning uložený · ${formatClock(summary.duration)} · '
                    '${sessionProgressLabel(summary.sets, summary.volumeKg)}',
        ),
      ),
    );
  }
  return true;
}

class _FinishSheet extends ConsumerWidget {
  const _FinishSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final active = ref.watch(workoutSessionProvider).active;
    if (active == null) return const SizedBox.shrink();
    final sets = active.setsFrom(ref.watch(workoutLogProvider).sets);
    final volume = sets.fold(0.0, (v, s) => v + s.volumeKg);
    final exercises = {for (final s in sets) s.exerciseId}.length;

    Widget tile(String label, Widget value) => Expanded(
      child: Container(
        padding: const EdgeInsets.only(top: 9),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.text, width: 2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(label),
            const SizedBox(height: 6),
            DefaultTextStyle.merge(
              style: text.headlineLarge!.copyWith(fontSize: 28),
              child: value,
            ),
          ],
        ),
      ),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('UKONČIŤ TRÉNING?', style: text.headlineMedium),
            const SizedBox(height: 4),
            Text(active.title, style: text.bodySmall),
            const SizedBox(height: 18),
            Row(
              children: [
                tile(
                  'Čas',
                  LiveElapsed(
                    since: active.startedAt,
                    style: text.headlineLarge!.copyWith(fontSize: 28),
                  ),
                ),
                const SizedBox(width: 12),
                tile('Série', Text('${sets.length}')),
                const SizedBox(width: 12),
                tile('Objem', Text(formatKg(volume.roundToDouble()))),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              sets.isEmpty
                  ? 'Zatiaľ si nezapísal žiadnu sériu, tréning sa neuloží.'
                  : '$exercises ${exercises == 1 ? 'cvik' : 'cviky'} · '
                        'objem v kg',
              style: text.bodySmall,
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: sets.isEmpty ? 'Zahodiť tréning' : 'Ukončiť a uložiť',
              icon: Icons.flag_outlined,
              tone: ButtonTone.ink,
              onPressed: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 10),
            PrimaryButton(
              label: 'Pokračovať v tréningu',
              tone: ButtonTone.ghost,
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pásik nad spodnou lištou: tréning beží, ťuknutím sa vrátiš.
class ResumeWorkoutBar extends StatelessWidget {
  const ResumeWorkoutBar({
    super.key,
    required this.workout,
    required this.onTap,
  });

  final ActiveWorkout workout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final style = text.bodyMedium!.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 14.5,
    );
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  workout.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
              Text(' · ', style: style),
              LiveElapsed(since: workout.startedAt, style: style),
              const Spacer(),
              Text(
                'Pokračovať',
                style: style.copyWith(color: AppColors.accent),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
