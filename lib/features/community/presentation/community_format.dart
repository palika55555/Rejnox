import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';

const _weekdays = ['po', 'ut', 'st', 'št', 'pi', 'so', 'ne'];

String _hhmm(DateTime t) => '${t.hour}:${t.minute.toString().padLeft(2, '0')}';

/// „dnes 18:00“, „zajtra 7:30“ alebo „pi 21. 11. · 18:00“.
String whenLabel(DateTime at, {DateTime? now}) {
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final day = DateUtils.dateOnly(at);
  final diff = day.difference(today).inDays;
  final time = _hhmm(at);
  return switch (diff) {
    0 => 'dnes $time',
    1 => 'zajtra $time',
    -1 => 'včera $time',
    _ => '${_weekdays[at.weekday - 1]} ${at.day}. ${at.month}. · $time',
  };
}

/// „pred chvíľou“, „pred 5 min“, „pred 3 h“, inak dátum.
String agoLabel(DateTime at, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(at);
  if (diff.inMinutes < 1) return 'pred chvíľou';
  if (diff.inMinutes < 60) return 'pred ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'pred ${diff.inHours} h';
  return '${at.day}. ${at.month}. ${at.year}';
}

String dayLabel(DateTime d) => '${d.day}. ${d.month}.';

/// Tvar slova podľa počtu: 1 deň, 2 dni, 5 dní.
String plural(int n, String one, String few, String many) =>
    n == 1 ? one : (n >= 2 && n <= 4 ? few : many);

/// Správa o chybe pre používateľa.
String errorText(Object error, String fallback) =>
    error is ApiError ? error.message : fallback;

void showCommunityError(BuildContext context, Object error, String fallback) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(errorText(error, fallback))));
}

/// Potvrdenie pred zmazaním. Vráti true, keď používateľ súhlasí.
Future<bool> confirmDelete(BuildContext context, String what) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Zmazať $what?'),
      content: const Text('Toto sa nedá vrátiť späť.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Zrušiť'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Zmazať'),
        ),
      ],
    ),
  );
  return ok ?? false;
}
