import 'dart:convert';

import '../http/api_exception.dart';

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

const roles = {'member', 'trainer'};

String _requireString(Map<String, dynamic> body, String field) {
  final value = body[field];
  if (value is! String) {
    throw ApiException(400, 'invalid_$field', 'Chýba pole "$field".');
  }
  return value;
}

String validateEmail(Map<String, dynamic> body) {
  final email = _requireString(body, 'email').trim().toLowerCase();
  if (email.length > 254 || !_emailPattern.hasMatch(email)) {
    throw const ApiException(400, 'invalid_email', 'Zadaj platný e-mail.');
  }
  return email;
}

/// Heslo pri registrácii: 8 až 72 bajtov (viac bcrypt nespracuje).
String validateNewPassword(Map<String, dynamic> body) {
  final password = _requireString(body, 'password');
  final bytes = utf8.encode(password).length;
  if (password.length < 8 || bytes > 72) {
    throw const ApiException(
      400,
      'invalid_password',
      'Heslo musí mať 8 až 72 znakov.',
    );
  }
  return password;
}

/// Heslo pri prihlásení: len kontrola, že je rozumne dlhé.
String validateLoginPassword(Map<String, dynamic> body) {
  final password = _requireString(body, 'password');
  if (password.isEmpty || utf8.encode(password).length > 72) {
    throw const ApiException(
      401,
      'invalid_credentials',
      'Nesprávny e-mail alebo heslo.',
    );
  }
  return password;
}

String validateDisplayName(Map<String, dynamic> body) {
  final name = _requireString(body, 'displayName').trim();
  if (name.isEmpty || name.length > 60) {
    throw const ApiException(
      400,
      'invalid_displayName',
      'Meno musí mať 1 až 60 znakov.',
    );
  }
  return name;
}

String validateRole(Map<String, dynamic> body) {
  final role = body['role'] ?? 'member';
  if (role is! String || !roles.contains(role)) {
    throw const ApiException(400, 'invalid_role', 'Neplatná rola.');
  }
  return role;
}
