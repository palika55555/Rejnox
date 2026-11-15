import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/plate_chip.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/tm_card.dart';
import '../../domain/home_overview.dart';

/// Invertovaná (tmavá) plocha – na obrazovke je vždy len jedna.
class HeroPanel extends StatelessWidget {
  const HeroPanel({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(28)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.heroLine),
          ),
          child: CustomPaint(
            painter: const _TrainingAura(),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(height: 18),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Jemné obrysy kotúča, kreslené bez animácie a ďalšieho rozmazávania.
class _TrainingAura extends CustomPainter {
  const _TrainingAura();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width + 12, 80);
    final paint = Paint()..style = PaintingStyle.stroke;
    for (final radius in [62.0, 90.0, 118.0, 146.0]) {
      paint
        ..strokeWidth = radius == 90 ? 12 : 1
        ..color = AppColors.accent.withValues(
          alpha: radius == 90 ? 0.035 : 0.07,
        );
      canvas.drawCircle(center, radius, paint);
    }
    paint
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = AppColors.accent.withValues(alpha: 0.55);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 118),
      math.pi * 0.62,
      math.pi * 0.16,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_TrainingAura oldDelegate) => false;
}

/// Eyebrow a veľký nadpis v hero ploche.
class HeroTitle extends StatelessWidget {
  const HeroTitle({super.key, required this.eyebrow, required this.title});

  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.heroLine),
          ),
          child: SectionLabel(
            eyebrow,
            icon: Icons.bolt_rounded,
            color: AppColors.onHero2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title.toUpperCase(),
          style: text.headlineLarge!.copyWith(
            fontSize: 46,
            fontWeight: FontWeight.w900,
            height: 0.92,
            color: AppColors.onHero,
          ),
        ),
      ],
    );
  }
}

class HeroMeta extends StatelessWidget {
  const HeroMeta(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
        color: AppColors.onHero2,
      ),
    );
  }
}

/// Dnešný tréning: názov, rozsah, nálož na tyči a hlavné tlačidlo.
class TodayWorkoutHero extends StatelessWidget {
  const TodayWorkoutHero(this.workout, {super.key, required this.onStart});

  final Workout workout;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final trainer = workout.trainerName;
    final count = workout.exercises.length;
    final sets = workout.exercises.fold(0, (n, e) => n + e.sets);
    // Odhad ~3 min na sériu vrátane pauzy, zaokrúhlený na 5 min.
    final minutes = workout.minutes ?? ((sets * 3.1 / 5).round() * 5);
    final loaded = workout.exercises
        .where((e) => (e.weightKg ?? 0) >= 20)
        .firstOrNull;

    return HeroPanel(
      children: [
        HeroTitle(
          eyebrow: trainer == null
              ? 'Dnešný tréning'
              : 'Dnešný tréning · od trénera $trainer',
          title: workout.title,
        ),
        HeroMeta(
          '$count ${_word(count, 'cvik', 'cviky', 'cvikov')} · '
          '$sets ${_word(sets, 'séria', 'série', 'sérií')} · asi $minutes min',
        ),
        if (loaded != null) _HeroLoad(loaded),
        PrimaryButton(
          label: 'Začať tréning',
          icon: Icons.play_arrow_rounded,
          tone: ButtonTone.onHero,
          onPressed: onStart,
        ),
      ],
    );
  }
}

/// Na dnes nie je plán od trénera – dá sa cvičiť aj voľne.
class RestDayHero extends StatelessWidget {
  const RestDayHero({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return HeroPanel(
      children: [
        const HeroTitle(eyebrow: 'Dnes voľno', title: 'Oddych'),
        const HeroMeta('Na dnes nemáš naplánovaný tréning'),
        PrimaryButton(
          label: 'Voľný tréning',
          icon: Icons.play_arrow_rounded,
          tone: ButtonTone.ghostOnHero,
          onPressed: onStart,
        ),
      ],
    );
  }
}

/// Prvý cvik s tyčou: kotúče na jednu stranu a váha.
class _HeroLoad extends StatelessWidget {
  const _HeroLoad(this.exercise);

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final kg = exercise.weightKg ?? 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.heroLine),
      ),
      child: Row(
        children: [
          BarbellLoad(weightKg: kg, height: 60),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: exercise.weightLabel?.replaceAll(' kg', ''),
                    children: [
                      TextSpan(
                        text: ' kg',
                        style: text.bodySmall!.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.onHero2,
                        ),
                      ),
                    ],
                  ),
                  style: text.headlineLarge!.copyWith(
                    fontSize: 28,
                    color: AppColors.onHero,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${exercise.name} · ${exercise.sets} × ${exercise.reps}',
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall!.copyWith(color: AppColors.onHero2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kotúče na tyči (jedna strana) vo farbách podľa pravidiel vzpierania.
class BarbellLoad extends StatelessWidget {
  const BarbellLoad({super.key, required this.weightKg, this.height = 72});

  final double weightKg;
  final double height;

  /// Kotúče na jednu stranu pri 20 kg tyči, od najťažšieho.
  static List<double> plates(double weightKg, {double bar = 20}) {
    var side = ((weightKg - bar) / 2).clamp(0, double.infinity);
    final out = <double>[];
    for (final p in _specs) {
      while (side >= p.kg - 1e-9) {
        out.add(p.kg);
        side -= p.kg;
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final load = plates(weightKg);
    final width = _BarbellPainter.widthFor(load);
    return Semantics(
      label: load.isEmpty
          ? 'Prázdna tyč'
          : 'Na jednu stranu: ${load.map(_fmt).join(' + ')} kg',
      child: CustomPaint(
        size: Size(width, height),
        painter: _BarbellPainter(load),
      ),
    );
  }

  static String _fmt(double v) => v == v.roundToDouble()
      ? v.toInt().toString()
      : v.toString().replaceAll('.', ',');
}

typedef _PlateSpec = ({double kg, Color color, double scale});

const List<_PlateSpec> _specs = [
  (kg: 25, color: Color(0xFFD8362B), scale: 1),
  (kg: 20, color: Color(0xFF2A5BD7), scale: 1),
  (kg: 15, color: Color(0xFFF0BE2E), scale: .9),
  (kg: 10, color: Color(0xFF2F9E5C), scale: .8),
  (kg: 5, color: Color(0xFFF3F3EE), scale: .62),
  (kg: 2.5, color: Color(0xFF8E97A3), scale: .5),
  (kg: 1.25, color: Color(0xFF8E97A3), scale: .4),
];

class _BarbellPainter extends CustomPainter {
  _BarbellPainter(this.load);

  final List<double> load;

  static double _plateWidth(double kg) => kg >= 10 ? 13 : (kg >= 5 ? 9 : 6);
  static double _tail(int n) => (44 - n * 6).clamp(12, 44).toDouble();

  static double widthFor(List<double> load) =>
      53 +
      load.fold(0.0, (w, k) => w + _plateWidth(k) + 2) +
      _tail(load.length);

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final steel = Paint()..color = AppColors.steel;
    RRect r(double x, double y, double w, double h, double rad) =>
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h),
          Radius.circular(rad),
        );

    canvas.drawRRect(r(0, cy - 3, 44, 6, 3), steel);
    canvas.drawRRect(r(44, cy - 10, 7, 20, 2), steel);
    var x = 53.0;
    for (final kg in load) {
      final spec = _specs.firstWhere((s) => s.kg == kg);
      final w = _plateWidth(kg);
      final h = size.height * spec.scale;
      final rect = r(x, cy - h / 2, w, h, 3);
      canvas.drawRRect(rect, Paint()..color = spec.color);
      if (kg == 5) {
        canvas.drawRRect(
          rect,
          Paint()
            ..color = AppColors.steel
            ..style = PaintingStyle.stroke,
        );
      }
      x += w + 2;
    }
    canvas.drawRRect(r(x, cy - 5, _tail(load.length), 10, 2), steel);
  }

  @override
  bool shouldRepaint(_BarbellPainter old) => old.load.join() != load.join();
}

/// Riadky cvikov dnešného tréningu.
class ExerciseList extends StatelessWidget {
  const ExerciseList(this.workout, {super.key});

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth / MediaQuery.textScalerOf(context).scale(1) <
            340;
        return AppList(
          children: [
            for (final e in workout.exercises)
              AppRow(
                leading: PlateDot(e.plate, size: 10),
                title: e.name,
                subtitle: compact
                    ? '${e.note}\n${[e.scheme, ?e.weightLabel].join(' · ')}'
                    : e.note,
                trailing: compact
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (e.isPr) ...[
                            const AppPill('Rekord', tone: PillTone.accent),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            [e.scheme, ?e.weightLabel].join(' · '),
                            style: text.bodyLarge!.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
          ],
        );
      },
    );
  }
}

String _word(int n, String one, String few, String many) => switch (n) {
  1 => one,
  >= 2 && <= 4 => few,
  _ => many,
};
