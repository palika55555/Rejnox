import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WatchStatus {
  const WatchStatus({
    this.paired = false,
    this.installed = false,
    this.reachable = false,
  });

  final bool paired;
  final bool installed;
  final bool reachable;

  bool get ready => paired && installed;
}

/// Správa z hodiniek: stav tréningu a tep.
class WatchHeartRate {
  const WatchHeartRate({required this.state, required this.at, this.bpm});

  factory WatchHeartRate.fromMap(Map<Object?, Object?> map) => WatchHeartRate(
    state: map['state'] as String? ?? 'running',
    bpm: (map['bpm'] as num?)?.toDouble(),
    at: DateTime.fromMillisecondsSinceEpoch(
      (((map['at'] as num?) ?? 0) * 1000).round(),
    ),
  );

  /// started / running / ended
  final String state;
  final double? bpm;
  final DateTime at;
}

/// Spojenie s Rejnoxom na Apple Watch (cez appku pre iPhone).
abstract interface class WatchLink {
  bool get supported;
  Future<WatchStatus> status();
  Stream<WatchHeartRate> get heartRate;

  /// Spustí tréning na hodinkách (otvorí Rejnox na hodinkách).
  Future<void> startWorkout();

  /// Vráti false, ak hodinky práve nie sú v dosahu.
  Future<bool> stopWorkout();
}

class NativeWatchLink implements WatchLink {
  static const _methods = MethodChannel('rejnox/watch');
  static const _events = EventChannel('rejnox/watch_heart_rate');

  @override
  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<WatchStatus> status() async {
    if (!supported) return const WatchStatus();
    try {
      final map = await _methods.invokeMapMethod<String, Object?>('status');
      return WatchStatus(
        paired: map?['paired'] == true,
        installed: map?['installed'] == true,
        reachable: map?['reachable'] == true,
      );
    } on PlatformException {
      return const WatchStatus();
    } on MissingPluginException {
      return const WatchStatus();
    }
  }

  @override
  Stream<WatchHeartRate> get heartRate => supported
      ? _events
            .receiveBroadcastStream()
            .where((e) => e is Map)
            .map((e) => WatchHeartRate.fromMap(e as Map<Object?, Object?>))
            .handleError((Object _) {})
      : const Stream.empty();

  @override
  Future<void> startWorkout() => _methods.invokeMethod<void>('startWorkout');

  @override
  Future<bool> stopWorkout() async =>
      await _methods.invokeMethod<bool>('stopWorkout') ?? false;
}

final watchLinkProvider = Provider<WatchLink>((ref) => NativeWatchLink());

final watchStatusProvider = FutureProvider.autoDispose<WatchStatus>(
  (ref) => ref.watch(watchLinkProvider).status(),
);
