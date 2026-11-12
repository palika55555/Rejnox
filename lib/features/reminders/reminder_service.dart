import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Najbližší výskyt času [hour]:[minute] od [now] (dnes, alebo zajtra ak už bol).
DateTime nextDailyOccurrence(DateTime now, int hour, int minute) {
  var next = DateTime(now.year, now.month, now.day, hour, minute);
  if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
  return next;
}

/// Plánovanie pripomienok v telefóne. Nepotrebuje internet ani server.
abstract interface class ReminderScheduler {
  /// Na webe a počítači pripomienky nie sú.
  bool get supported;

  /// Vypýta povolenie a naplánuje dennú pripomienku.
  /// Vráti false, ak používateľ notifikácie nepovolil.
  Future<bool> scheduleDaily(int hour, int minute);

  Future<void> cancel();
}

class LocalReminderScheduler implements ReminderScheduler {
  LocalReminderScheduler();

  static const _id = 1;
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;

  @override
  bool get supported =>
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
        // Povolenie sa pýta až keď si človek pripomienku zapne.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }();

  Future<bool> _requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(alert: true, sound: true) ?? false;
  }

  @override
  Future<bool> scheduleDaily(int hour, int minute) async {
    if (!supported) return false;
    await _init();
    if (!await _requestPermission()) return false;

    final next = nextDailyOccurrence(DateTime.now(), hour, minute);
    await _plugin.zonedSchedule(
      id: _id,
      scheduledDate: tz.TZDateTime(
        tz.local,
        next.year,
        next.month,
        next.day,
        hour,
        minute,
      ),
      title: 'Čas na tréning 💪',
      body: 'Tvoj dnešný tréning čaká. Zapíš si série v Rejnoxe.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'training_reminder',
          'Pripomienky tréningu',
          channelDescription: 'Denná pripomienka tréningu',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // Nepresné plánovanie nepotrebuje špeciálne povolenie na budíky.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    return true;
  }

  @override
  Future<void> cancel() async {
    if (!supported) return;
    await _init();
    await _plugin.cancel(id: _id);
  }
}

class ReminderSettings {
  const ReminderSettings({
    this.enabled = false,
    this.hour = 18,
    this.minute = 0,
  });

  final bool enabled;
  final int hour;
  final int minute;

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// Uloží nastavenie a podľa neho naplánuje alebo zruší pripomienku.
class ReminderController extends AsyncNotifier<ReminderSettings> {
  static const _enabledKey = 'rejnox_reminder_enabled';
  static const _timeKey = 'rejnox_reminder_minutes';

  ReminderScheduler get _scheduler => ref.read(reminderSchedulerProvider);

  @override
  Future<ReminderSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final minutes = prefs.getInt(_timeKey) ?? 18 * 60;
    return ReminderSettings(
      enabled: prefs.getBool(_enabledKey) ?? false,
      hour: minutes ~/ 60,
      minute: minutes % 60,
    );
  }

  /// Vráti false, ak si človek pripomienku zapol, ale notifikácie nepovolil.
  Future<bool> save({bool? enabled, int? hour, int? minute}) async {
    final current = state.value ?? const ReminderSettings();
    var next = ReminderSettings(
      enabled: enabled ?? current.enabled,
      hour: hour ?? current.hour,
      minute: minute ?? current.minute,
    );
    var allowed = true;
    if (next.enabled) {
      allowed = await _scheduler.scheduleDaily(next.hour, next.minute);
      if (!allowed) {
        next = ReminderSettings(hour: next.hour, minute: next.minute);
      }
    } else {
      await _scheduler.cancel();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, next.enabled);
    await prefs.setInt(_timeKey, next.hour * 60 + next.minute);
    state = AsyncData(next);
    return allowed;
  }
}

final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => LocalReminderScheduler(),
);

final reminderControllerProvider =
    AsyncNotifierProvider<ReminderController, ReminderSettings>(
      ReminderController.new,
    );
