import 'dart:math';

import '../http/api_exception.dart';

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

/// Bez 0/O, 1/I/L, aby sa kód dal ľahko prepísať.
const _codeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

String requireUuid(String value, [String field = 'id']) {
  if (!_uuid.hasMatch(value)) {
    throw ApiException(400, 'invalid_$field', 'Neplatné ID.');
  }
  return value;
}

String requireText(
  Map<String, dynamic> body,
  String field, {
  required int max,
  String label = 'Pole',
}) {
  final value = body[field];
  final text = value is String ? value.trim() : '';
  if (text.isEmpty || text.length > max) {
    throw ApiException(
      400,
      'invalid_$field',
      '$label musí mať 1 až $max znakov.',
    );
  }
  return text;
}

String? optionalText(
  Map<String, dynamic> body,
  String field, {
  required int max,
}) {
  final value = body[field];
  if (value == null) return null;
  final text = value is String ? value.trim() : '';
  if (text.length > max) {
    throw ApiException(400, 'invalid_$field', 'Text je príliš dlhý.');
  }
  return text.isEmpty ? null : text;
}

int requireInt(
  Object? value,
  String field, {
  required int min,
  required int max,
}) {
  if (value is! int || value < min || value > max) {
    throw ApiException(400, 'invalid_$field', 'Zadaj $min až $max.');
  }
  return value;
}

double requireWeight(Object? value, {String field = 'weightKg'}) {
  if (value is! num || value < 0 || value > 1000) {
    throw ApiException(400, 'invalid_$field', 'Váha musí byť 0 až 1000 kg.');
  }
  return value.toDouble();
}

/// Dátum v tvare RRRR-MM-DD.
DateTime? optionalDate(Map<String, dynamic> body, String field) {
  final value = body[field];
  if (value == null) return null;
  final parsed = value is String && value.length == 10
      ? DateTime.tryParse(value)
      : null;
  if (parsed == null) {
    throw ApiException(400, 'invalid_$field', 'Neplatný dátum.');
  }
  return DateTime.utc(parsed.year, parsed.month, parsed.day);
}

/// Nový pozývací kód, napr. "K7QM-4XPA" (~40 bitov náhody).
String newInviteCode([Random? random]) {
  final r = random ?? Random.secure();
  final chars = List.generate(
    8,
    (_) => _codeAlphabet[r.nextInt(_codeAlphabet.length)],
  ).join();
  return '${chars.substring(0, 4)}-${chars.substring(4)}';
}

/// Kód tak, ako sa hashuje: veľké písmená, bez pomlčiek a medzier.
String normalizeInviteCode(Object? value) {
  final code = value is String
      ? value.toUpperCase().replaceAll(RegExp(r'[\s-]'), '')
      : '';
  if (code.length != 8 ||
      code.split('').any((c) => !_codeAlphabet.contains(c))) {
    throw const ApiException(400, 'invalid_code', 'Kód má tvar XXXX-XXXX.');
  }
  return code;
}
