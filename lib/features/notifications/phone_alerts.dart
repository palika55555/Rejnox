import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Systémové upozornenie v telefóne (lišta, zamknutá obrazovka).
abstract interface class PhoneAlerts {
  /// Vypýta povolenie (raz). Vráti false, ak ho používateľ nedal.
  Future<bool> requestPermission();

  Future<void> show({
    required int id,
    required String title,
    String? body,
    bool message = false,
  });
}

class LocalPhoneAlerts implements PhoneAlerts {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _init() => _ready ??= _plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ),
  );

  @override
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    await _init();
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
  Future<void> show({
    required int id,
    required String title,
    String? body,
    bool message = false,
  }) async {
    if (!_supported) return;
    await _init();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: message
            ? const AndroidNotificationDetails(
                'chat_messages',
                'Správy',
                channelDescription: 'Nové správy od trénera alebo klienta',
                importance: Importance.high,
                priority: Priority.high,
              )
            : const AndroidNotificationDetails(
                'app_updates',
                'Upozornenia',
                channelDescription: 'Plány, rezervácie a spolupráca',
              ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}

final phoneAlertsProvider = Provider<PhoneAlerts>((ref) => LocalPhoneAlerts());
