import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Pauza medzi sériami mimo appky: odpočet na zamknutej obrazovke
/// (Android) a upozornenie, keď pauza skončí (Android aj iOS).
abstract interface class RestAlerts {
  /// Spustí alebo posunie odpočet do [end].
  Future<void> start(DateTime end);

  /// Zruší odpočet aj upozornenie (pauza zatvorená alebo skončená v appke).
  Future<void> cancel();
}

class LocalRestAlerts implements RestAlerts {
  static const _countdownId = 900;
  static const _doneId = 901;

  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _init() => _ready ??= () async {
    tz_data.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }();

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> start(DateTime end) async {
    if (!_supported) return;
    try {
      await _init();
      await _plugin.cancel(id: _doneId);
      final android = _android;
      if (android != null) {
        await _plugin.show(
          id: _countdownId,
          title: 'Pauza medzi sériami',
          body: 'Ďalšia séria o chvíľu',
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              'rest_countdown',
              'Odpočet pauzy',
              channelDescription: 'Odpočet pauzy počas tréningu',
              importance: Importance.low,
              priority: Priority.low,
              ongoing: true,
              autoCancel: false,
              onlyAlertOnce: true,
              showWhen: true,
              when: end.millisecondsSinceEpoch,
              usesChronometer: true,
              chronometerCountDown: true,
              timeoutAfter: end
                  .difference(DateTime.now())
                  .inMilliseconds
                  .clamp(1000, 3600000),
              category: AndroidNotificationCategory.stopwatch,
            ),
          ),
        );
      }
      final exact = await android?.canScheduleExactNotifications() ?? false;
      await _plugin.zonedSchedule(
        id: _doneId,
        scheduledDate: tz.TZDateTime.from(end, tz.local),
        title: 'Pauza skončila',
        body: 'Čas na ďalšiu sériu.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'rest_done',
            'Koniec pauzy',
            channelDescription: 'Upozornenie, že pauza medzi sériami skončila',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
          ),
          iOS: DarwinNotificationDetails(
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } on Exception catch (e) {
      // Odpočet v appke beží ďalej aj bez systémového upozornenia.
      debugPrint('RestAlerts.start zlyhalo: $e');
    }
  }

  @override
  Future<void> cancel() async {
    if (!_supported) return;
    try {
      await _init();
      await _plugin.cancel(id: _countdownId);
      await _plugin.cancel(id: _doneId);
    } on Exception catch (e) {
      debugPrint('RestAlerts.cancel zlyhalo: $e');
    }
  }
}

final restAlertsProvider = Provider<RestAlerts>((ref) => LocalRestAlerts());
