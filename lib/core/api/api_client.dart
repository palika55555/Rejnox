import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Adresa servera. Pri builde sa dá zmeniť cez --dart-define=API_URL=...
const apiBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:8080',
);

/// Chyba zo servera alebo zo spojenia, so správou pre používateľa.
class ApiError implements Exception {
  const ApiError(this.status, this.code, this.message);

  const ApiError.network()
    : status = 0,
      code = 'network',
      message = 'Server je nedostupný. Skontroluj pripojenie.';

  /// HTTP kód, 0 pri výpadku spojenia.
  final int status;
  final String code;
  final String message;

  bool get isUnauthorized => status == 401;

  @override
  String toString() => 'ApiError($status, $code)';
}

class ApiClient {
  ApiClient({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  static const _timeout = Duration(seconds: 10);

  /// Pošle požiadavku a vráti JSON objekt (prázdny pri odpovedi bez tela).
  Future<Map<String, dynamic>> send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    if (token != null) request.headers['authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(_timeout),
      );
    } on Exception {
      throw const ApiError.network();
    }

    Map<String, dynamic> json = const {};
    if (response.bodyBytes.isNotEmpty) {
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) json = decoded;
      } on FormatException {
        // Odpoveď nie je JSON – ošetrí sa podľa HTTP kódu nižšie.
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return json;

    final error = json['error'];
    throw ApiError(
      response.statusCode,
      error is Map && error['code'] is String
          ? error['code'] as String
          : 'unknown',
      error is Map && error['message'] is String
          ? error['message'] as String
          : 'Niečo sa pokazilo.',
    );
  }
}

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(baseUrl: apiBaseUrl),
);
