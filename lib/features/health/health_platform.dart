import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

bool get _isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// Zdravotné údaje: iPhone (Apple Health) a Android (Health Connect).
bool get healthPlatformSupported => _isIOS || _isAndroid;

/// Názov úložiska zdravia na tomto telefóne (do textov v appke).
String get healthStoreName => _isAndroid ? 'Health Connect' : 'Apple Health';

/// Len typy, ktoré dané úložisko pozná (napr. HRV je na iPhone SDNN,
/// na Androide RMSSD). Žiadosť o nepodporovaný typ by zlyhala.
List<HealthDataType> availableTypes(
  Health health,
  List<HealthDataType> types,
) => types.where(health.isDataTypeAvailable).toList();

/// Na Androide musí byť nainštalovaný Health Connect. Ak nie je,
/// ponúkne inštaláciu a vráti false.
Future<bool> ensureHealthStore(Health health) async {
  if (!_isAndroid) return true;
  final status = await health.getHealthConnectSdkStatus();
  if (status == HealthConnectSdkStatus.sdkAvailable) return true;
  await health.installHealthConnect();
  return false;
}
