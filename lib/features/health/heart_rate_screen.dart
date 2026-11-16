import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/tm_card.dart';
import 'health_platform.dart';
import 'heart_rate_charts.dart';
import 'heart_rate_sections.dart';
import 'heart_rate_service.dart';
import 'heart_rate_stats.dart';
import 'watch_link.dart';
import '../../core/theme/app_spacing.dart';

enum _Tab { overview, zones, trends }

enum _Period {
  today('Dnes', Duration(hours: 24)),
  week('7 dní', Duration(days: 7)),
  month('30 dní', Duration(days: 30));

  const _Period(this.label, this.window);
  final String label;
  final Duration window;
}

/// Srdcový tep: prehľad, zóny a trendy z Apple Health, tep naživo
/// z Apple Watch počas tréningu. Kde zdravie nie je dostupné (web, PC),
/// ukáže prázdny stav namiesto vymyslených údajov.
class HeartRateScreen extends ConsumerStatefulWidget {
  const HeartRateScreen({super.key});

  @override
  ConsumerState<HeartRateScreen> createState() => _HeartRateScreenState();
}

class _HeartRateScreenState extends ConsumerState<HeartRateScreen>
    with WidgetsBindingObserver {
  static const _interval = Duration(seconds: 15);

  _Tab _tab = _Tab.overview;
  _Period _period = _Period.today;
  HeartRateHistory? _history;
  WatchHeartRate? _live;
  bool _connected = false;
  bool _loading = false;
  String? _status;
  Timer? _timer;
  StreamSubscription<WatchHeartRate>? _watchSub;

  HeartRateSource get _source => ref.read(heartRateSourceProvider);
  bool get _unsupported => !_source.supported;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!_unsupported) {
      _watchSub = ref.read(watchLinkProvider).heartRate.listen((m) {
        if (mounted) setState(() => _live = m.state == 'ended' ? null : m);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _watchSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _refresh());
  }

  Future<void> _connect() async {
    setState(() => _loading = true);
    try {
      if (!await _source.requestPermission()) {
        if (mounted) setState(() => _status = 'Žiadosť nebola dokončená');
        return;
      }
      _connected = true;
      await _refresh();
      _startTimer();
    } on Object {
      if (mounted) setState(() => _status = 'Chyba pri pripojení');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    if (_unsupported || !_connected) return;
    try {
      final h = await _source.history(_period.window);
      if (!mounted) return;
      setState(() {
        _history = h;
        _status = h.samples.isEmpty ? 'Žiadne merania za toto obdobie' : null;
      });
    } on Object {
      if (mounted) setState(() => _status = 'Nepodarilo sa načítať tep');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _connected) {
      _refresh();
      _startTimer();
    } else if (state != AppLifecycleState.resumed) {
      _timer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final history = _history;
    final latest = history?.latest;
    final liveBpm = _live?.bpm;
    final bpm = (liveBpm ?? latest?.bpm)?.round();
    final caption = liveBpm != null
        ? 'Naživo z ${ref.read(watchLinkProvider).name}'
        : latest == null
        ? (_status ?? 'Zatiaľ bez merania')
        : 'Posledné meranie\n${hhmm(latest.at)}';
    final samples = history?.samples ?? const <HrSample>[];

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: RefreshIndicator.adaptive(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xxxl,
              ),
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
                    const Expanded(
                      child: SectionLabel(
                        'Srdcový tep',
                        icon: Icons.favorite_rounded,
                      ),
                    ),
                  ],
                ),
                Text('Tvoj tep dnes', style: text.headlineLarge),
                Text('Zdravie · Výkon · Rovnováha', style: text.bodySmall),
                if (_unsupported) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TmCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'Tu zatiaľ nie sú žiadne merania. Tep z Apple Health / '
                      'Health Connect (a Apple Watch / Wear OS) uvidíš '
                      'v mobilnej appke.',
                      style: text.bodySmall,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: HeartRing(bpm: bpm, caption: caption),
                ),
                const SizedBox(height: AppSpacing.md),
                // Rejnox na hodinkách: Apple Watch (iPhone), Wear OS (Android).
                if (!_unsupported && ref.read(watchLinkProvider).supported)
                  Center(child: _WatchChip(live: liveBpm != null)),
                if (!_unsupported && !_connected) ...[
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: _loading ? 'Pripájam…' : 'Pripojiť $healthStoreName',
                    icon: Icons.favorite_border_rounded,
                    onPressed: _loading ? null : _connect,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Segments<_Tab>(
                  values: _Tab.values,
                  selected: _tab,
                  label: (t) => switch (t) {
                    _Tab.overview => 'Prehľad',
                    _Tab.zones => 'Zóny',
                    _Tab.trends => 'Trendy',
                  },
                  onChanged: (t) => setState(() => _tab = t),
                ),
                const SizedBox(height: AppSpacing.md),
                ...switch (_tab) {
                  _Tab.overview => [
                    Segments<_Period>(
                      values: _Period.values,
                      selected: _period,
                      label: (p) => p.label,
                      onChanged: (p) {
                        setState(() => _period = p);
                        _refresh();
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OverviewChartCard(
                      title: _period == _Period.today
                          ? 'Tvoj tep počas dňa'
                          : 'Tvoj tep za ${_period.label}',
                      samples: samples,
                      from: now.subtract(_period.window),
                      to: now,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    InsightCard(samples: samples),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            icon: Icons.favorite_border_rounded,
                            color: Plate.red.color,
                            label: 'HRV',
                            hint: 'variabilita tepu',
                            value: history?.hrvMs == null
                                ? '—'
                                : '${history!.hrvMs!.round()}',
                            unit: 'ms',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: StatTile(
                            icon: Icons.nightlight_round,
                            color: AppColors.accentDeep,
                            label: 'Pokojový tep',
                            hint: 'v pokoji',
                            value: history?.restingBpm == null
                                ? '—'
                                : '${history!.restingBpm!.round()}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (history != null)
                      RecentMeasurements(history: history, now: now),
                  ],
                  _Tab.zones => [
                    ZonesCard(
                      zones: zoneDurations(samples),
                      maxHr: defaultMaxHr,
                    ),
                  ],
                  _Tab.trends => [
                    OverviewChartCard(
                      title: 'Priemerný tep po dňoch',
                      samples: dailyAverages(samples),
                      from: now.subtract(_period.window),
                      to: now,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Obdobie zmeníš v Prehľade (Dnes / 7 dní / 30 dní).',
                      style: text.bodySmall,
                    ),
                  ],
                },
                const SizedBox(height: AppSpacing.lg),
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

class _WatchChip extends ConsumerWidget {
  const _WatchChip({required this.live});

  final bool live;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final status = ref.watch(watchStatusProvider).value;
    final name = ref.watch(watchLinkProvider).name;
    final (ok, label) = live
        ? (true, '$name · naživo')
        : status == null || !status.paired
        ? (false, 'Hodinky nie sú spárované')
        : !status.installed
        ? (false, 'Nainštaluj Rejnox na hodinky')
        : (true, 'Pripojené $name');
    final color = ok ? Plate.green.color : AppColors.muted;
    final canInstall = status != null && status.canInstall;
    final chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.sheet.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.watch_outlined, size: 16, color: color),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              label,
              style: text.bodySmall!.copyWith(color: AppColors.text),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (canInstall) ...[
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.download_rounded, size: 16, color: AppColors.accent),
          ],
        ],
      ),
    );
    if (!canInstall) return chip;
    return Semantics(
      button: true,
      label: 'Nainštalovať Rejnox na hodinky',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        onTap: () => ref.read(watchLinkProvider).openWatchApp(),
        child: chip,
      ),
    );
  }
}
