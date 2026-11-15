import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/presentation/auth_controller.dart';

/// Jedno váženie.
class WeightEntry {
  const WeightEntry({required this.date, required this.kg});

  factory WeightEntry.fromJson(Map<String, dynamic> json) => WeightEntry(
    date: DateTime.parse(json['date'] as String),
    kg: (json['kg'] as num).toDouble(),
  );

  /// Deň váženia (bez času).
  final DateTime date;
  final double kg;

  Map<String, dynamic> toJson() => {
    'date':
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}',
    'kg': kg,
  };
}

/// Zmena váhy za posledných [days] dní: od najstaršieho váženia v tom
/// období po posledné. Null, ak na porovnanie nie sú aspoň dve váženia.
double? weightChange(List<WeightEntry> entries, {int days = 30}) {
  if (entries.length < 2) return null;
  final last = entries.last;
  final from = last.date.subtract(Duration(days: days));
  final base = entries.firstWhere(
    (e) => !e.date.isBefore(from),
    orElse: () => entries.first,
  );
  if (identical(base, last)) return null;
  return last.kg - base.kg;
}

/// Váženia používateľa, zoradené od najstaršieho. Držia sa v telefóne;
/// za jeden deň platí posledné zadané.
class BodyWeightLog extends Notifier<List<WeightEntry>> {
  String? _userId;

  String _key(String userId) => 'body_weight_$userId';

  @override
  List<WeightEntry> build() {
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
    List<WeightEntry> entries;
    try {
      entries = [
        for (final e in jsonDecode(raw) as List)
          WeightEntry.fromJson(e as Map<String, dynamic>),
      ];
    } on FormatException {
      return;
    }
    if (!ref.mounted || _userId != userId || state.isNotEmpty) return;
    state = List.unmodifiable(entries);
  }

  Future<void> add(double kg, {DateTime? on}) async {
    final userId = _userId;
    if (userId == null) return;
    final now = on ?? DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final next = [
      for (final e in state)
        if (e.date != day) e,
      WeightEntry(date: day, kg: kg),
    ]..sort((a, b) => a.date.compareTo(b.date));
    state = List.unmodifiable(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(userId),
      jsonEncode([for (final e in next) e.toJson()]),
    );
  }
}

final bodyWeightProvider = NotifierProvider<BodyWeightLog, List<WeightEntry>>(
  BodyWeightLog.new,
);
