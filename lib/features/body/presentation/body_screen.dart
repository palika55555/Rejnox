import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tm_card.dart';
import '../../home/presentation/widgets/dashboard_sections.dart';
import '../../home/presentation/widgets/stat_cards.dart';
import '../application/body_measurements_log.dart';
import '../domain/body_measurements.dart';
import 'body_figure.dart';

/// Telo: váha a rozmery (pás, brucho, obvody) zapisované na postave.
class BodyScreen extends ConsumerWidget {
  const BodyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(bodyMeasurementsProvider);
    final latest = latestByPart(all);
    final text = Theme.of(context).textTheme;
    void open(BodyPart part) => showMeasurementSheet(context, ref, part);

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  ScreenHeader(
                    'Telo',
                    subtitle: 'Váha a rozmery v čase',
                    onBack: () => context.pop(),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                      children: [
                        SectionStack(
                          children: [
                            const BodySection(
                              title: 'Váha',
                              showMeasurementsLink: false,
                            ),
                            AppSection(
                              title: 'Rozmery',
                              child: TmCard(
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  14,
                                  10,
                                  12,
                                ),
                                child: Column(
                                  children: [
                                    BodyFigure(latest: latest, onTap: open),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Ťukni na časť tela a zapíš obvod v cm.',
                                      style: text.bodySmall,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (latest.isNotEmpty)
                              AppSection(
                                title: 'Zmena za 30 dní',
                                child: AppList(
                                  children: [
                                    for (final part in BodyPart.values)
                                      if (latest[part] != null)
                                        _PartRow(
                                          part: part,
                                          history: historyOf(all, part),
                                          onTap: () => open(part),
                                        ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Riadok časti tela: posledný rozmer, krivka a zmena za 30 dní.
class _PartRow extends StatelessWidget {
  const _PartRow({
    required this.part,
    required this.history,
    required this.onTap,
  });

  final BodyPart part;
  final List<Measurement> history;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final last = history.last;
    final change = measurementChange(history);
    return AppRow(
      title: part.label,
      subtitle: '${formatCm(last.cm)} cm · ${shortDay(last.date)}',
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (history.length > 1)
            SizedBox(
              width: 56,
              height: 26,
              child: CustomPaint(
                painter: SparklinePainter([
                  for (final m in history.reversed.take(8).toList().reversed)
                    m.cm,
                ]),
              ),
            ),
          if (change != null) ...[
            const SizedBox(width: 8),
            AppPill('${formatCmChange(change)} cm'),
          ],
        ],
      ),
    );
  }
}

/// „dnes“, „včera“, „3. 11.“
String shortDay(DateTime date) {
  final now = DateTime.now();
  final days = DateTime.utc(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime.utc(date.year, date.month, date.day)).inDays;
  return switch (days) {
    0 => 'dnes',
    1 => 'včera',
    _ => '${date.day}. ${date.month}.',
  };
}

/// Spodný panel na zápis rozmeru jednej časti tela.
Future<void> showMeasurementSheet(
  BuildContext context,
  WidgetRef ref,
  BodyPart part,
) async {
  final history = historyOf(ref.read(bodyMeasurementsProvider), part);
  final cm = await showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _MeasurementSheet(part: part, history: history),
  );
  if (cm != null) {
    await ref.read(bodyMeasurementsProvider.notifier).add(part, cm);
  }
}

class _MeasurementSheet extends StatefulWidget {
  const _MeasurementSheet({required this.part, required this.history});

  final BodyPart part;
  final List<Measurement> history;

  @override
  State<_MeasurementSheet> createState() => _MeasurementSheetState();
}

class _MeasurementSheetState extends State<_MeasurementSheet> {
  final _form = GlobalKey<FormState>();
  final _cm = TextEditingController();

  static double? _parse(String v) =>
      double.tryParse(v.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    _cm.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, _parse(_cm.text));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final part = widget.part;
    final recent = widget.history.reversed.take(5).toList();
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
            Text(part.label.toUpperCase(), style: text.headlineMedium),
            const SizedBox(height: 4),
            Text(part.hint, style: text.bodySmall),
            const SizedBox(height: 14),
            TextFormField(
              controller: _cm,
              autofocus: true,
              textInputAction: TextInputAction.done,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Obvod',
                suffixText: 'cm',
                hintText: recent.isEmpty ? null : formatCm(recent.first.cm),
              ),
              validator: (v) {
                final cm = _parse(v ?? '');
                if (cm == null ||
                    !cm.isFinite ||
                    cm < part.minCm ||
                    cm > part.maxCm) {
                  return 'Zadaj ${formatCm(part.minCm)} až '
                      '${formatCm(part.maxCm)} cm.';
                }
                return null;
              },
              onFieldSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 14),
            PrimaryButton(label: 'Uložiť', onPressed: _save),
            if (recent.isNotEmpty) ...[
              const SizedBox(height: 18),
              const SectionLabel('Posledné merania'),
              const SizedBox(height: 6),
              for (final m in recent)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(shortDay(m.date), style: text.bodyMedium),
                      ),
                      Text(
                        '${formatCm(m.cm)} cm',
                        style: text.bodyLarge!.copyWith(color: AppColors.text),
                      ),
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
