import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/presentation/auth_controller.dart';
import '../domain/body_measurements.dart';

/// Rozmery tela, zoradené od najstaršieho. Držia sa v telefóne (ako váha);
/// za jeden deň platí pre každú časť posledné zadané číslo.
class BodyMeasurementsLog extends Notifier<List<Measurement>> {
  String? _userId;

  String _key(String userId) => 'body_measurements_$userId';

  @override
  List<Measurement> build() {
    final auth = ref.watch(authControllerProvider);
    _userId = auth is SignedIn ? auth.user.id : null;
    final userId = _userId;
    if (userId != null) _load(userId);
    return const [];
  }

  Future<void> _load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    if (raw == null) return;
    List<Measurement> entries;
    try {
      entries = [
        for (final e in jsonDecode(raw) as List)
          Measurement.fromJson(e as Map<String, dynamic>),
      ];
    } on Object {
      // Poškodené dáta nesmú zablokovať appku.
      return;
    }
    if (!ref.mounted || _userId != userId || state.isNotEmpty) return;
    state = List.unmodifiable(entries);
  }

  Future<void> add(BodyPart part, double cm, {DateTime? on}) async {
    final userId = _userId;
    if (userId == null) return;
    final now = on ?? DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final next = [
      for (final m in state)
        if (m.part != part || m.date != day) m,
      Measurement(date: day, part: part, cm: cm),
    ]..sort((a, b) => a.date.compareTo(b.date));
    state = List.unmodifiable(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(userId),
      jsonEncode([for (final m in next) m.toJson()]),
    );
  }
}

final bodyMeasurementsProvider =
    NotifierProvider<BodyMeasurementsLog, List<Measurement>>(
      BodyMeasurementsLog.new,
    );
