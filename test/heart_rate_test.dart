import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:rejnox/core/theme/app_theme.dart';
import 'package:rejnox/features/health/health_summary.dart';
import 'package:rejnox/features/health/heart_rate_screen.dart';
import 'package:rejnox/features/health/heart_rate_service.dart';
import 'package:rejnox/features/health/heart_rate_stats.dart';
import 'package:rejnox/features/health/watch_link.dart';
import 'package:rejnox/features/health/wearable_sources.dart';
import 'package:rejnox/features/health/workout_heart_rate_card.dart';

HealthDataPoint _point({
  required num bpm,
  required DateTime at,
  DateTime? to,
  String source = 'Pavlove Apple Watch',
  String sourceId = 'com.apple.health',
  String device = '',
  RecordingMethod method = RecordingMethod.automatic,
  HealthDataType type = HealthDataType.HEART_RATE,
}) => HealthDataPoint(
  uuid: '$type-$bpm-$at',
  value: NumericHealthValue(numericValue: bpm),
  type: type,
  unit: HealthDataUnit.BEATS_PER_MINUTE,
  dateFrom: at,
  dateTo: to ?? at,
  sourcePlatform: HealthPlatformType.appleHealth,
  sourceDeviceId: device,
  sourceId: sourceId,
  sourceName: source,
  recordingMethod: method,
);

class _FakeSource implements HeartRateSource {
  _FakeSource({this.supported = true, this.granted = true});

  @override
  final bool supported;
  final bool granted;
  HeartRateHistory data = const HeartRateHistory(samples: []);
  int reads = 0;

  @override
  Future<bool> requestPermission() async => granted;

  @override
  Future<HeartRateReading?> latest() async => null;

  @override
  Future<HeartRateHistory> history(Duration window) async {
    reads++;
    return data;
  }
}

class _FakeWatch implements WatchLink {
  _FakeWatch({this.installed = true});

  final bool installed;
  final controller = StreamController<WatchHeartRate>.broadcast();
  final commands = <String>[];

  @override
  bool get supported => true;

  @override
  String get name => 'Apple Watch';

  @override
  String get installHint => 'Nainštaluj cez appku Watch.';

  @override
  Future<WatchStatus> status() async =>
      WatchStatus(paired: true, installed: installed);

  @override
  Stream<WatchHeartRate> get heartRate => controller.stream;

  @override
  Future<void> startWorkout() async {}

  @override
  Future<bool> stopWorkout() async => _log('stop');

  @override
  Future<bool> pauseWorkout() async => _log('pause');

  @override
  Future<bool> resumeWorkout() async => _log('resume');

  @override
  Future<bool> openWatchApp() async => _log('open');

  bool _log(String command) {
    commands.add(command);
    return true;
  }
}

Future<void> _pump(
  WidgetTester tester,
  HeartRateSource source, {
  WatchLink? watch,
}) async {
  tester.view.physicalSize = const Size(390, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        heartRateSourceProvider.overrideWithValue(source),
        watchLinkProvider.overrideWithValue(watch ?? _FakeWatch()),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(webFonts: false),
        home: const HeartRateScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Obrazovka tepu sa testuje ako na iPhone (Apple Health, Apple Watch).
void _iosTest(String description, WidgetTesterCallback body) => testWidgets(
  description,
  body,
  variant: TargetPlatformVariant.only(TargetPlatform.iOS),
);

void main() {
  group('pickLatestWatchReading', () {
    final t = DateTime(2026, 11, 12, 18);

    test('vyberie najnovšie meranie z hodiniek', () {
      final r = pickLatestWatchReading([
        _point(bpm: 70, at: t),
        _point(bpm: 82, at: t.add(const Duration(minutes: 5))),
        _point(bpm: 75, at: t.subtract(const Duration(minutes: 5))),
      ]);
      expect(r!.bpm, 82);
    });

    test('ignoruje ručné zápisy a iné zdroje', () {
      final r = pickLatestWatchReading([
        _point(bpm: 60, at: t),
        _point(
          bpm: 99,
          at: t.add(const Duration(hours: 1)),
          method: RecordingMethod.manual,
        ),
        _point(bpm: 98, at: t.add(const Duration(hours: 1)), source: 'iPhone'),
      ]);
      expect(r!.bpm, 60);
    });

    test('zdroj spozná aj podľa ID zariadenia, bez meraní vráti null', () {
      expect(
        pickLatestWatchReading([
          _point(bpm: 66, at: t, source: 'Zdravie', device: 'Watch7,1'),
        ])!.bpm,
        66,
      );
      expect(pickLatestWatchReading([]), isNull);
    });
  });

  test('Rejnox na hodinkách: Apple Watch na iPhone, Wear OS na Androide', () {
    final link = NativeWatchLink();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(link.supported, isTrue);
    expect(link.name, 'Wear OS');
    expect(link.installHint, contains('Obchod Play'));
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(link.name, 'Apple Watch');
    expect(link.installHint, contains('appku Watch'));
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(link.supported, isFalse);
    debugDefaultTargetPlatformOverride = null;
  });

  group('iné hodinky', () {
    final t = DateTime(2026, 11, 12, 18);

    test('rozpozná Garmin, Fitbit, Galaxy Watch, Polar podľa appky', () {
      final cases = {
        'com.garmin.android.apps.connectmobile': 'Garmin',
        'com.fitbit.FitbitMobile': 'Fitbit',
        'com.sec.android.app.shealth': 'Samsung Galaxy Watch',
        'fi.polar.polarflow': 'Polar',
        'com.huami.watch.hmwatchmanager': 'Amazfit',
      };
      for (final MapEntry(key: id, value: name) in cases.entries) {
        final p = _point(bpm: 90, at: t, source: 'Connect', sourceId: id);
        expect(wearableName(p), name, reason: id);
      }
    });

    test('telefón a ručný zápis nie sú hodinky', () {
      expect(wearableName(_point(bpm: 70, at: t, source: 'iPhone')), isNull);
      expect(
        wearableName(
          _point(
            bpm: 70,
            at: t,
            source: 'Garmin',
            method: RecordingMethod.manual,
          ),
        ),
        isNull,
      );
    });

    test('najnovšie meranie z Garminu nesie názov hodiniek', () {
      final r = pickLatestWatchReading([
        _point(bpm: 64, at: t),
        _point(
          bpm: 131,
          at: t.add(const Duration(minutes: 1)),
          source: 'Connect',
          sourceId: 'com.garmin.connect.mobile',
        ),
      ]);
      expect(r!.bpm, 131);
      expect(r.source, 'Garmin');
    });
  });

  group('výpočty tepu', () {
    final t = DateTime(2026, 11, 12, 10);
    final samples = [
      HrSample(t, 60),
      HrSample(t.add(const Duration(minutes: 5)), 120),
      HrSample(t.add(const Duration(minutes: 10)), 180),
      HrSample(t.add(const Duration(hours: 3)), 70),
    ];

    test('minimum, priemer, maximum', () {
      final s = heartRateStats(samples)!;
      expect(s.min, 60);
      expect(s.max, 180);
      expect(s.avg, 107.5);
      expect(heartRateStats([]), isNull);
    });

    test('zóny podľa max. tepu, dlhé medzery sa nepočítajú', () {
      final z = zoneDurations(samples, maxHr: 190);
      // 60 BPM 5 min + 70 BPM (posledné) 1 min.
      expect(z[HrZone.rest], const Duration(minutes: 6));
      // 120 BPM = 63 % → spaľovanie tukov, 5 min.
      expect(z[HrZone.fatBurn], const Duration(minutes: 5));
      // 180 BPM = 95 %, medzera 3 h sa skráti na 10 min.
      expect(z[HrZone.max], const Duration(minutes: 10));
      expect(z[HrZone.aerobic], Duration.zero);
    });

    test('štítky meraní', () {
      expect(
        measurementTag(HrSample(DateTime(2026, 1, 1, 17), 130)),
        'Tréning',
      );
      expect(
        measurementTag(HrSample(DateTime(2026, 1, 1, 7), 62), restingBpm: 58),
        'Po prebudení',
      );
      expect(measurementTag(HrSample(DateTime(2026, 1, 1, 14), 72)), 'Pokoj');
    });

    test('denné priemery', () {
      final d = dailyAverages([
        HrSample(DateTime(2026, 1, 2, 8), 60),
        HrSample(DateTime(2026, 1, 1, 8), 80),
        HrSample(DateTime(2026, 1, 2, 9), 70),
      ]);
      expect(d.map((s) => s.bpm), [80, 65]);
      expect(d.first.at, DateTime(2026, 1, 1));
    });

    test('história z Apple Health: bez ručných, s HRV a pokojovým tepom', () {
      final h = buildHistory([
        _point(bpm: 75, at: DateTime(2026, 11, 12, 9)),
        _point(
          bpm: 99,
          at: DateTime(2026, 11, 12, 8),
          method: RecordingMethod.manual,
        ),
        _point(bpm: 50, at: DateTime(2026, 11, 11, 9)),
        _point(
          bpm: 61,
          at: DateTime(2026, 11, 10),
          type: HealthDataType.HEART_RATE_VARIABILITY_SDNN,
        ),
        _point(
          bpm: 58,
          at: DateTime(2026, 11, 11),
          type: HealthDataType.RESTING_HEART_RATE,
        ),
        _point(
          bpm: 57,
          at: DateTime(2026, 11, 9),
          type: HealthDataType.RESTING_HEART_RATE,
        ),
      ], DateTime(2026, 11, 12));
      expect(h.samples.map((s) => s.bpm), [75]);
      expect(h.hrvMs, 61);
      expect(h.restingBpm, 58);
    });
  });

  test('čas merania: pred X s / min / h', () {
    final now = DateTime(2026, 11, 12, 18);
    expect(
      agoLabel(now.subtract(const Duration(seconds: 40)), now),
      'pred 40 s',
    );
    expect(
      agoLabel(now.subtract(const Duration(minutes: 3)), now),
      'pred 3 min',
    );
    expect(agoLabel(now.subtract(const Duration(hours: 2)), now), 'pred 2 h');
    expect(agoLabel(now.add(const Duration(seconds: 2)), now), 'pred 0 s');
  });

  test('váha: posledné meranie', () {
    final s = summarize([
      _point(bpm: 82.4, at: DateTime(2026, 11, 1), type: HealthDataType.WEIGHT),
      _point(
        bpm: 81.7,
        at: DateTime(2026, 11, 10),
        type: HealthDataType.WEIGHT,
      ),
    ], now: DateTime(2026, 11, 12, 15));
    expect(s.weightKg, closeTo(81.7, 0.001));
    expect(s.isEmpty, isFalse);
  });

  group('súhrn zdravia', () {
    final now = DateTime(2026, 11, 12, 15);

    test('kalórie dnes, spánok minulú noc, pokojový tep, kroky', () {
      final s = summarize(
        [
          _point(
            bpm: 120,
            at: DateTime(2026, 11, 12, 10),
            type: HealthDataType.ACTIVE_ENERGY_BURNED,
          ),
          _point(
            bpm: 80,
            at: DateTime(2026, 11, 12, 12),
            type: HealthDataType.ACTIVE_ENERGY_BURNED,
          ),
          _point(
            bpm: 500,
            at: DateTime(2026, 11, 11, 12),
            type: HealthDataType.ACTIVE_ENERGY_BURNED,
          ),
          // Spánok: hodnotu (minúty) počíta balík z dĺžky záznamu.
          _point(
            bpm: 0,
            at: DateTime(2026, 11, 12, 1),
            to: DateTime(2026, 11, 12, 4, 20),
            type: HealthDataType.SLEEP_LIGHT,
          ),
          _point(
            bpm: 0,
            at: DateTime(2026, 11, 12, 4, 20),
            to: DateTime(2026, 11, 12, 5, 50),
            type: HealthDataType.SLEEP_DEEP,
          ),
          _point(
            bpm: 59,
            at: DateTime(2026, 11, 12, 7),
            type: HealthDataType.RESTING_HEART_RATE,
          ),
          _point(bpm: 71, at: DateTime(2026, 11, 12, 14)),
        ],
        now: now,
        steps: 8421,
      );
      expect(s.activeKcal, 200);
      expect(s.sleep, const Duration(minutes: 290));
      expect(s.restingBpm, 59);
      expect(s.heartRate!.bpm, 71);
      expect(s.steps, 8421);
    });

    test('saturácia v % z Apple Health aj Health Connect, dýchanie', () {
      final ios = summarize([
        _point(bpm: 0.97, at: now, type: HealthDataType.BLOOD_OXYGEN),
        _point(bpm: 15, at: now, type: HealthDataType.RESPIRATORY_RATE),
      ], now: now);
      expect(ios.bloodOxygen, closeTo(97, 0.001));
      expect(ios.respiratoryRate, 15);
      expect(ios.isEmpty, isFalse);

      final android = summarize([
        _point(bpm: 96, at: now, type: HealthDataType.BLOOD_OXYGEN),
      ], now: now);
      expect(android.bloodOxygen, 96);
    });

    test('bez údajov je prázdny', () {
      expect(summarize([], now: now).isEmpty, isTrue);
    });
  });

  _iosTest('po pripojení ukáže tep, štatistiky a merania', (tester) async {
    final now = DateTime.now();
    final source = _FakeSource()
      ..data = HeartRateHistory(
        samples: [
          HrSample(now.subtract(const Duration(hours: 2)), 64),
          HrSample(now.subtract(const Duration(hours: 1)), 130),
          HrSample(now.subtract(const Duration(minutes: 5)), 76),
        ],
        hrvMs: 62,
        restingBpm: 58,
      );
    await _pump(tester, source);
    expect(find.text('Pripojené Apple Watch'), findsOneWidget);

    await tester.tap(find.text('Pripojiť Apple Health'));
    await tester.pumpAndSettle();

    expect(find.text('76'), findsOneWidget); // kruh
    // Maximum v dlaždici aj v zozname posledných meraní.
    expect(find.text('130 BPM', findRichText: true), findsNWidgets(2));
    expect(find.text('62 ms', findRichText: true), findsOneWidget); // HRV
    expect(find.text('Tréning'), findsOneWidget);

    // Obnovuje sa každých 15 s.
    final before = source.reads;
    await tester.pump(const Duration(seconds: 15));
    expect(source.reads, before + 1);
  });

  _iosTest('tep naživo z hodiniek prepíše posledné meranie', (tester) async {
    final watch = _FakeWatch();
    await _pump(tester, _FakeSource(), watch: watch);

    watch.controller.add(
      WatchHeartRate(state: 'running', bpm: 142, at: DateTime.now()),
    );
    await tester.pumpAndSettle();
    expect(find.text('142'), findsOneWidget);
    expect(find.text('Naživo z Apple Watch'), findsOneWidget);
    expect(find.text('Apple Watch · naživo'), findsOneWidget);

    watch.controller.add(WatchHeartRate(state: 'ended', at: DateTime.now()));
    await tester.pumpAndSettle();
    expect(find.text('142'), findsNothing);
  });

  _iosTest('nenainštalovaný Rejnox na hodinkách sa dá doinštalovať', (
    tester,
  ) async {
    final watch = _FakeWatch(installed: false);
    await _pump(tester, _FakeSource(), watch: watch);
    expect(find.text('Nainštaluj Rejnox na hodinky'), findsOneWidget);

    await tester.tap(find.text('Nainštaluj Rejnox na hodinky'));
    await tester.pumpAndSettle();
    expect(watch.commands, ['open']);
  });

  testWidgets(
    'karta tréningu: pauza a kalórie z hodiniek',
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    (tester) async {
      final watch = _FakeWatch();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            heartRateSourceProvider.overrideWithValue(_FakeSource()),
            watchLinkProvider.overrideWithValue(watch),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(webFonts: false),
            home: const Scaffold(
              body: SingleChildScrollView(child: WorkoutHeartRateCard()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      watch.controller.add(
        WatchHeartRate(
          state: 'running',
          bpm: 120,
          kcal: 85,
          at: DateTime.now(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('85 kcal'), findsOneWidget);
      await tester.tap(find.text('Pozastaviť'));
      await tester.pumpAndSettle();

      watch.controller.add(
        WatchHeartRate(state: 'paused', bpm: 118, at: DateTime.now()),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('pozastavené'), findsOneWidget);
      await tester.tap(find.text('Pokračovať'));
      await tester.pumpAndSettle();
      expect(watch.commands, ['pause', 'resume']);
    },
  );

  testWidgets(
    'karta tréningu ponúkne inštaláciu na spárované hodinky',
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    (tester) async {
      final watch = _FakeWatch(installed: false);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            heartRateSourceProvider.overrideWithValue(_FakeSource()),
            watchLinkProvider.overrideWithValue(watch),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(webFonts: false),
            home: const Scaffold(
              body: SingleChildScrollView(child: WorkoutHeartRateCard()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nainštalovať Rejnox na hodinky'));
      await tester.pumpAndSettle();
      expect(watch.commands, ['open']);
      expect(find.text('Spustiť tréning na hodinkách'), findsNothing);
    },
  );

  _iosTest('zamietnuté povolenie', (tester) async {
    await _pump(tester, _FakeSource(granted: false));
    await tester.tap(find.text('Pripojiť Apple Health'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Žiadosť nebola dokončená'), findsOneWidget);
  });

  _iosTest('mimo mobilu ukáže prázdny stav bez vymyslených údajov', (
    tester,
  ) async {
    await _pump(tester, _FakeSource(supported: false));
    expect(
      find.textContaining('Tu zatiaľ nie sú žiadne merania'),
      findsOneWidget,
    );
    expect(find.text('Zatiaľ bez merania'), findsOneWidget);
    expect(find.text('Pripojiť Apple Health'), findsNothing);

    await tester.tap(find.text('Zóny'));
    await tester.pumpAndSettle();
    expect(find.text('Tepové zóny'), findsOneWidget);
    expect(find.textContaining('Spaľovanie tukov'), findsOneWidget);
  });
}
