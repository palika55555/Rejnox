import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/plate_ring.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/tm_card.dart';
import '../../../coaching/application/coaching_providers.dart';
import '../../../coaching/domain/coaching_models.dart';
import '../../../training/application/exercise_stats.dart';
import '../../../training/application/workout_log_controller.dart';
import '../../../training/domain/training_models.dart';
import '../../application/body_weight.dart';
import '../../domain/home_overview.dart';
import 'stat_cards.dart';
import '../../../../core/theme/app_spacing.dart';

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _plural(int n, String one, String few, String many) => switch (n) {
  1 => one,
  >= 2 && <= 4 => few,
  _ => many,
};

/// Tento týždeň: pásik dní (odcvičené, naplánované, dnes) a týždenný cieľ.
class WeekSection extends ConsumerWidget {
  const WeekSection({
    super.key,
    required this.goal,
    required this.streakDays,
    this.now,
  });

  final WeeklyGoal goal;
  final int streakDays;

  /// Pre testy; inak aktuálny čas.
  final DateTime? now;

  static const _days = ['Po', 'Ut', 'St', 'Št', 'Pi', 'So', 'Ne'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final today = now ?? DateTime.now();
    final monday = DateTime(
      today.year,
      today.month,
      today.day - today.weekday + 1,
    );
    final sets = ref.watch(workoutLogProvider).sets;
    final plans = ref.watch(myPlansProvider).value?.plans ?? const <Plan>[];

    return AppSection(
      title: 'Tento týždeň',
      child: TmCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: _Day(
                      label: _days[i],
                      date: DateTime(monday.year, monday.month, monday.day + i),
                      today: today,
                      done: sets.any(
                        (s) =>
                            s.state != SyncState.rejected &&
                            _sameDay(
                              s.performedAt.toLocal(),
                              DateTime(
                                monday.year,
                                monday.month,
                                monday.day + i,
                              ),
                            ),
                      ),
                      planned: plans.any(
                        (p) =>
                            p.scheduledOn != null &&
                            _sameDay(
                              p.scheduledOn!,
                              DateTime(
                                monday.year,
                                monday.month,
                                monday.day + i,
                              ),
                            ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                PlateRing(done: goal.done, total: goal.total, size: 52),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${goal.done} z ${goal.total} tréningov',
                        style: text.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        streakDays == 0
                            ? 'Každý tréning sa počíta'
                            : '$streakDays '
                                  '${_plural(streakDays, 'deň', 'dni', 'dní')} v rade',
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${goal.percent}%',
                  style: text.headlineLarge!.copyWith(
                    color: goal.reached ? AppColors.good : AppColors.accent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({
    required this.label,
    required this.date,
    required this.today,
    required this.done,
    required this.planned,
  });

  final String label;
  final DateTime date;
  final DateTime today;
  final bool done;
  final bool planned;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isToday = _sameDay(date, today);
    final state = done
        ? 'odcvičené'
        : planned
        ? 'naplánované'
        : 'voľno';
    return Semantics(
      label: '$label ${date.day}. $state${isToday ? ', dnes' : ''}',
      excludeSemantics: true,
      child: Column(
        children: [
          Text(
            label,
            style: text.bodySmall!.copyWith(
              fontWeight: FontWeight.w700,
              color: isToday ? AppColors.accent : AppColors.muted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done
                  ? AppColors.good
                  : (isToday ? AppColors.accent : null),
              border: done
                  ? null
                  : Border.all(
                      color: planned || isToday
                          ? AppColors.accent
                          : AppColors.border,
                      width: 1.5,
                    ),
            ),
            child: done
                ? const Icon(Icons.check_rounded, size: 18, color: AppColors.bg)
                : Text(
                    '${date.day}',
                    style: text.bodyMedium!.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isToday
                          ? AppColors.onAccent
                          : (planned ? AppColors.accent : AppColors.ink2),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// S trénerom: prepojený tréner alebo pozvánka nájsť si ho.
class TrainerSection extends ConsumerWidget {
  const TrainerSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainers = ref.watch(myTrainersProvider).value ?? const [];
    final linked = [
      for (final t in trainers)
        if (t.status == LinkStatus.linked || t.status == LinkStatus.invited) t,
    ];
    return AppSection(
      title: 'S trénerom',
      child: AppList(
        children: [
          if (linked.isEmpty)
            AppRow(
              leading: const _ColorIcon(
                Icons.sports_outlined,
                AppColors.accent,
              ),
              title: 'Nájdi si trénera',
              subtitle: 'Kód od trénera zadáš v profile',
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.muted,
              ),
              onTap: () => context.go('/profile'),
            )
          else
            for (final t in linked)
              AppRow(
                leading: _Initial(t.trainerName),
                title: t.trainerName,
                subtitle: t.status == LinkStatus.linked
                    ? 'Tvoj tréner · plány nájdeš v Tréningu'
                    : 'Čaká na prepojenie',
                trailing: t.status == LinkStatus.linked
                    ? IconButton(
                        tooltip: 'Napísať trénerovi',
                        onPressed: () => context.go('/chat'),
                        icon: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: AppColors.accent,
                        ),
                      )
                    : const AppPill('Pozvaný', tone: PillTone.warn),
              ),
        ],
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.accentSoft,
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
          color: AppColors.accent,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Dostupné akcie priamo v prehľade.
class DashboardActions extends ConsumerWidget {
  const DashboardActions({super.key});

  static const _heartRed = AppColors.heart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth / MediaQuery.textScalerOf(context).scale(1) <
            290;
        final width = stacked
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: width,
              child: _QuickAction(
                label: 'Zapísať váhu',
                detail: 'Sleduj svoj progres',
                icon: const Icon(
                  Icons.monitor_weight_outlined,
                  color: AppColors.accent,
                  size: 22,
                ),
                color: AppColors.accent,
                onTap: () => showWeightSheet(context, ref),
              ),
            ),
            SizedBox(
              width: width,
              child: _QuickAction(
                label: 'Zdravie a aktivita',
                detail: 'Tvoje telo v číslach',
                icon: const _PumpingHeart(color: _heartRed),
                color: _heartRed,
                onTap: () => context.push('/health'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.detail,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final String detail;
  final Widget icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.xl);
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withValues(alpha: 0.09), AppColors.surface],
            ),
            border: Border.all(color: AppColors.border),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: icon,
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_outward_rounded, color: color, size: 18),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(label, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(detail, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PumpingHeart extends StatefulWidget {
  const _PumpingHeart({required this.color});

  final Color color;

  @override
  State<_PumpingHeart> createState() => _PumpingHeartState();
}

class _PumpingHeartState extends State<_PumpingHeart>
    with SingleTickerProviderStateMixin {
  static final _rhythm = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.28,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 18,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.28,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 26,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.16,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 16,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.16,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 40,
    ),
  ]);

  late final _beat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 640),
  );
  late final _scale = _beat.drive(_rhythm);
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) || !TickerMode.of(context)) {
      _timer?.cancel();
      _timer = null;
      _beat.reset();
    } else if (_timer == null) {
      _beat.forward(from: 0);
      _timer = Timer.periodic(
        const Duration(seconds: 4),
        (_) => _beat.forward(from: 0),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: _scale,
    child: Icon(Icons.favorite_rounded, color: widget.color, size: 22),
  );
}

/// Pripravované funkcie nezaberajú priestor aktívnym údajom.
class UpcomingSection extends StatelessWidget {
  const UpcomingSection({super.key});

  @override
  Widget build(BuildContext context) {
    return TmCard(
      child: Row(
        children: [
          const _ColorIcon(Icons.auto_awesome_outlined, AppColors.accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pripravujeme',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Jedálniček a tréningový asistent',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorIcon extends StatelessWidget {
  const _ColorIcon(this.icon, this.color);
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.17),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Icon(icon, color: color, size: 22),
  );
}

/// Telo: posledné váženie, krivka a zmena za 30 dní; pod tým odkaz na
/// rozmery tela.
class BodySection extends ConsumerWidget {
  const BodySection({
    super.key,
    this.title = 'Telo',
    this.showMeasurementsLink = true,
  });

  final String title;
  final bool showMeasurementsLink;

  /// Váha a pod ňou (voliteľne) odkaz na rozmery.
  Widget _withLink(BuildContext context, Widget weight) {
    if (!showMeasurementsLink) return weight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        weight,
        const SizedBox(height: AppSpacing.sm),
        AppList(
          children: [
            AppRow(
              leading: const Icon(
                Icons.accessibility_new_rounded,
                color: AppColors.accent,
              ),
              title: 'Rozmery tela',
              subtitle: 'Pás, brucho, hrudník, obvody rúk a nôh',
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.muted,
              ),
              onTap: () => context.push('/body'),
            ),
          ],
        ),
      ],
    );
  }

  static String _when(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = DateTime.utc(
      today.year,
      today.month,
      today.day,
    ).difference(DateTime.utc(date.year, date.month, date.day)).inDays;
    return switch (days) {
      0 => 'dnes',
      1 => 'včera',
      _ => '${date.day}. ${date.month}.',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final entries = ref.watch(bodyWeightProvider);
    void add() => showWeightSheet(context, ref);

    if (entries.isEmpty) {
      return AppSection(
        title: title,
        child: _withLink(
          context,
          AppList(
            children: [
              AppRow(
                leading: const Icon(
                  Icons.monitor_weight_outlined,
                  color: AppColors.ink2,
                ),
                title: 'Zapíš si váhu',
                subtitle: 'Uvidíš, ako sa mení týždeň po týždni',
                trailing: const Icon(
                  Icons.add_rounded,
                  color: AppColors.accent,
                ),
                onTap: add,
              ),
            ],
          ),
        ),
      );
    }

    final last = entries.last;
    final change = weightChange(entries);
    return AppSection(
      title: title,
      trailing: TextButton(
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(48, 48),
        ),
        onPressed: add,
        child: const Text('+ Váženie'),
      ),
      child: _withLink(
        context,
        TmCard(
          onTap: add,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Váha · ${_when(last.date)}', style: text.bodySmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text.rich(
                      TextSpan(
                        text: formatKg(last.kg),
                        children: [
                          TextSpan(
                            text: ' kg',
                            style: text.bodySmall!.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                      style: text.displaySmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (entries.length > 1)
                    SizedBox(
                      width: 84,
                      height: 30,
                      child: CustomPaint(
                        painter: SparklinePainter([
                          for (final e
                              in entries.reversed.take(8).toList().reversed)
                            e.kg,
                        ]),
                      ),
                    ),
                  if (change != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    AppPill(
                      '${change > 0
                          ? '+'
                          : change < 0
                          ? '−'
                          : ''}'
                      '${formatKg((change.abs() * 10).roundToDouble() / 10)} kg '
                      'za 30 dní',
                      tone: PillTone.neutral,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Spodný panel na zápis váhy.
Future<void> showWeightSheet(BuildContext context, WidgetRef ref) async {
  final kg = await showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _WeightSheet(),
  );
  if (kg != null) await ref.read(bodyWeightProvider.notifier).add(kg);
}

class _WeightSheet extends StatefulWidget {
  const _WeightSheet();

  @override
  State<_WeightSheet> createState() => _WeightSheetState();
}

class _WeightSheetState extends State<_WeightSheet> {
  final _form = GlobalKey<FormState>();
  final _kg = TextEditingController();

  static double? _parse(String v) =>
      double.tryParse(v.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    _kg.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, _parse(_kg.text));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        22,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 22,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'DNEŠNÉ VÁŽENIE',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _kg,
              autofocus: true,
              textInputAction: TextInputAction.done,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Váha',
                suffixText: 'kg',
              ),
              validator: (v) {
                final kg = _parse(v ?? '');
                if (kg == null || !kg.isFinite || kg < 20 || kg > 400) {
                  return 'Zadaj váhu 20 až 400 kg.';
                }
                return null;
              },
              onFieldSubmitted: (_) => _save(),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(label: 'Uložiť', onPressed: _save),
          ],
        ),
      ),
    );
  }
}
