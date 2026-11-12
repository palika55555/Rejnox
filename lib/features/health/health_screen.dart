import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/tm_card.dart';
import 'health_platform.dart';
import 'health_summary.dart';

/// Sekcia Zdravie: prehľad z Apple Health (len čítanie, údaje ostávajú
/// v telefóne).
class HealthScreen extends ConsumerStatefulWidget {
  const HealthScreen({super.key});

  @override
  ConsumerState<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends ConsumerState<HealthScreen> {
  HealthSummary? _summary;
  bool _loading = false;
  String? _message;

  HealthSummarySource get _source => ref.read(healthSummarySourceProvider);

  Future<void> _connect() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      if (!await _source.requestAccess()) {
        if (mounted) setState(() => _message = 'Žiadosť nebola dokončená.');
        return;
      }
      await _load();
    } on Object {
      if (mounted) setState(() => _message = 'Chyba pri pripojení.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _load() async {
    try {
      final summary = await _source.load();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _message = summary.isEmpty
            ? '$healthStoreName zatiaľ nemá údaje, alebo si niektoré '
                  'povolenia nezapol. Povolenia zmeníš v nastaveniach '
                  '$healthStoreName.'
            : null;
      });
    } on Object {
      if (mounted) setState(() => _message = 'Údaje sa nepodarilo načítať.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final supported = _source.supported;
    final s = _summary;
    final hr = s?.heartRate;
    String hm(Duration d) => '${d.inHours} h ${d.inMinutes % 60} min';

    return AppBackground(
      child: Scaffold(
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: s == null ? () async {} : _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Späť',
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/profile'),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    Text('ZDRAVIE', style: text.headlineMedium),
                  ],
                ),
                const SizedBox(height: 12),
                if (!supported)
                  TmCard(
                    child: Text(
                      'Zdravotné údaje z Apple Health alebo Health Connect '
                      'sú dostupné v mobilnej appke.',
                      style: text.bodyMedium,
                    ),
                  )
                else ...[
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.35,
                    children: [
                      _Metric(
                        icon: Icons.favorite_rounded,
                        color: AppColors.violet,
                        label: 'Tep',
                        value: hr == null ? '—' : '${hr.bpm.round()}',
                        unit: 'BPM',
                        note: hr == null
                            ? null
                            : 'o ${hr.measuredAt.hour}:${hr.measuredAt.minute.toString().padLeft(2, '0')}',
                      ),
                      _Metric(
                        icon: Icons.bedtime_outlined,
                        color: AppColors.blue,
                        label: 'Pokojový tep',
                        value: s?.restingBpm == null
                            ? '—'
                            : '${s!.restingBpm!.round()}',
                        unit: 'BPM',
                      ),
                      _Metric(
                        icon: Icons.directions_walk_rounded,
                        color: Plate.green.color,
                        label: 'Kroky dnes',
                        value: s?.steps == null ? '—' : '${s!.steps}',
                      ),
                      _Metric(
                        icon: Icons.local_fire_department_rounded,
                        color: AppColors.flame,
                        label: 'Aktívne kalórie',
                        value: s?.activeKcal == null
                            ? '—'
                            : '${s!.activeKcal!.round()}',
                        unit: 'kcal',
                      ),
                      _Metric(
                        icon: Icons.nightlight_round,
                        color: AppColors.accent,
                        label: 'Spánok',
                        value: s?.sleep == null ? '—' : hm(s!.sleep!),
                        note: 'minulá noc',
                      ),
                      _Metric(
                        icon: Icons.monitor_weight_outlined,
                        color: AppColors.muted,
                        label: 'Váha',
                        value: s?.weightKg == null
                            ? '—'
                            : s!.weightKg!
                                  .toStringAsFixed(1)
                                  .replaceAll('.', ','),
                        unit: 'kg',
                        note: 'posledné meranie',
                      ),
                    ],
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Text(_message!, style: text.bodySmall),
                  ],
                  const SizedBox(height: 16),
                  if (s == null)
                    PrimaryButton(
                      label: _loading
                          ? 'Pripájam…'
                          : 'Pripojiť $healthStoreName',
                      icon: Icons.health_and_safety_outlined,
                      onPressed: _loading ? null : _connect,
                    )
                  else
                    PrimaryButton(
                      label: 'Sledovať tep naživo',
                      icon: Icons.monitor_heart_outlined,
                      onPressed: () => context.push('/heart-rate'),
                    ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Rejnox údaje zo zdravia len číta. Ostávajú v telefóne '
                  'a na server sa neposielajú.',
                  style: text.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.unit,
    this.note,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? unit;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return TmCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  style: text.labelSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                text: value,
                style: text.headlineMedium,
                children: [
                  if (unit != null)
                    TextSpan(text: ' $unit', style: text.bodySmall),
                ],
              ),
            ),
          ),
          Text(note ?? '', style: text.bodySmall),
        ],
      ),
    );
  }
}
