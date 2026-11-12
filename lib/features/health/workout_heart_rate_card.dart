import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/tm_card.dart';
import 'health_platform.dart';
import 'heart_rate_service.dart';
import 'heart_rate_stats.dart';
import 'watch_link.dart';

/// „pred 40 s“, „pred 3 min“, „pred 2 h“.
String agoLabel(DateTime at, DateTime now) {
  final d = now.difference(at);
  if (d.inSeconds < 60) return 'pred ${d.inSeconds.clamp(0, 59)} s';
  if (d.inMinutes < 60) return 'pred ${d.inMinutes} min';
  return 'pred ${d.inHours} h';
}

/// Karta Tréning: tep počas tréningu.
/// - s Apple Watch: spustí tréning na hodinkách, tep naživo každú sekundu,
/// - bez hodiniek: posledné meranie z Apple Health / Health Connect
///   (oneskorené o sekundy až minúty, preto ukazuje čas merania).
class WorkoutHeartRateCard extends ConsumerStatefulWidget {
  const WorkoutHeartRateCard({super.key});

  @override
  ConsumerState<WorkoutHeartRateCard> createState() =>
      _WorkoutHeartRateCardState();
}

class _WorkoutHeartRateCardState extends ConsumerState<WorkoutHeartRateCard>
    with WidgetsBindingObserver {
  static const _interval = Duration(seconds: 15);

  StreamSubscription<WatchHeartRate>? _sub;
  WatchHeartRate? _last;
  bool _starting = false;

  // Bez hodiniek: čítanie zo zdravia.
  HrSample? _healthSample;
  bool _healthOn = false;
  String? _healthMessage;
  Timer? _timer;
  Timer? _clock;

  WatchLink get _watch => ref.read(watchLinkProvider);
  HeartRateSource get _health => ref.read(heartRateSourceProvider);
  bool get _running => _last != null && _last!.state != 'ended';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sub = _watch.heartRate.listen((m) {
      if (mounted) setState(() => _last = m);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    _clock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_healthOn) return;
    if (state == AppLifecycleState.resumed) {
      _readHealth();
      _startTimers();
    } else {
      _timer?.cancel();
      _clock?.cancel();
    }
  }

  void _startTimers() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _readHealth());
    // Prepočet „pred X s“ aj medzi meraniami.
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _healthSample != null) setState(() {});
    });
  }

  /// Povolenie sa pýta až po ťuknutí používateľa.
  Future<void> _enableHealth() async {
    try {
      if (!await _health.requestPermission()) {
        if (mounted) {
          setState(
            () => _healthMessage =
                'Bez povolenia tep nezobrazíme. Povoliť ho môžeš v '
                'nastaveniach $healthStoreName.',
          );
        }
        return;
      }
      _healthOn = true;
      await _readHealth();
      _startTimers();
    } on Object {
      if (mounted) setState(() => _healthMessage = 'Pripojenie zlyhalo.');
    }
  }

  Future<void> _readHealth() async {
    try {
      final h = await _health.history(const Duration(hours: 2));
      if (!mounted) return;
      setState(() {
        _healthSample = h.latest;
        _healthMessage = h.latest == null
            ? 'Za posledné 2 hodiny nie je žiadne meranie tepu.'
            : null;
      });
    } on Object {
      if (mounted) {
        setState(() => _healthMessage = 'Tep sa nepodarilo načítať.');
      }
    }
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    try {
      await _watch.startWorkout();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tréning na hodinkách sa nespustil. Je Rejnox na hodinkách '
              'nainštalovaný?',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _stop() async {
    final sent = await _watch.stopWorkout();
    if (!sent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hodinky nie sú v dosahu, ukonči tréning na nich.'),
        ),
      );
    }
  }

  Widget _bigBpm(TextTheme text, int? bpm, String note) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      const Icon(Icons.favorite_rounded, color: AppColors.violet, size: 30),
      const SizedBox(width: 10),
      Semantics(
        liveRegion: true,
        child: Text(
          bpm == null ? '—' : '$bpm',
          style: text.headlineLarge!.copyWith(fontSize: 48),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 6),
        child: Text('BPM', style: text.bodySmall),
      ),
      const Spacer(),
      Flexible(
        child: Text(note, style: text.bodySmall, textAlign: TextAlign.end),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final watchSupported = _watch.supported;
    final status = watchSupported ? ref.watch(watchStatusProvider).value : null;
    final watchReady = status != null && status.ready;
    final sample = _healthSample;

    final List<Widget> body;
    if (_running) {
      body = [
        _bigBpm(text, _last?.bpm?.round(), 'naživo z Apple Watch'),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: _stop,
          style: OutlinedButton.styleFrom(
            foregroundColor: Plate.red.color,
            side: BorderSide(color: Plate.red.color.withValues(alpha: 0.6)),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text('Ukončiť tréning na hodinkách'),
        ),
      ];
    } else if (!healthPlatformSupported) {
      body = [
        Text(
          'V mobilnej appke tu uvidíš tep počas tréningu z Apple Health, '
          'Health Connect alebo naživo z Apple Watch.',
          style: text.bodySmall,
        ),
      ];
    } else {
      body = [
        if (_healthOn && sample != null)
          _bigBpm(
            text,
            sample.bpm.round(),
            'meranie ${agoLabel(sample.at, DateTime.now())}\n'
            'z $healthStoreName',
          ),
        if (_healthMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_healthMessage!, style: text.bodySmall),
          ),
        if (!_healthOn) ...[
          Text(
            watchReady
                ? 'Spusti tréning na hodinkách pre tep naživo, alebo zobraz '
                      'posledné meranie z $healthStoreName.'
                : 'Zobraz posledné meranie tepu z $healthStoreName. '
                      'Môže byť oneskorené o sekundy až minúty.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 10),
        ],
        if (watchReady) ...[
          const SizedBox(height: 6),
          PrimaryButton(
            label: _starting ? 'Spúšťam…' : 'Spustiť tréning na hodinkách',
            icon: Icons.watch_outlined,
            onPressed: _starting ? null : _start,
          ),
          const SizedBox(height: 8),
        ],
        if (!_healthOn)
          OutlinedButton.icon(
            onPressed: _enableHealth,
            icon: const Icon(Icons.favorite_border_rounded, size: 18),
            label: Text('Zobraziť tep z $healthStoreName'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.text,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
      ];
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TmCard(
        grid: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: SectionLabel(
                    'Tep počas tréningu',
                    icon: Icons.monitor_heart_outlined,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/heart-rate'),
                  child: const Text('Detail'),
                ),
              ],
            ),
            ...body,
          ],
        ),
      ),
    );
  }
}
