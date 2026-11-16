import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Produkčné API (Next.js vo webapp/ na Cloudflare nad Supabase).
const productionApiUrl = 'https://rejnox.sk/api';

/// Lokálny vývoj: `npm run dev` vo webapp/.
const _localApiUrl = 'http://localhost:3000/api';

const _apiUrlOverride = String.fromEnvironment('API_URL');

/// Adresa API (cesty pod /api). Dá sa zadať pri builde cez
/// `--dart-define=API_URL=...`. Bez nej ide release build vždy na produkciu,
/// localhost používa len debug/profile build pri vývoji.
const apiBaseUrl = _apiUrlOverride != ''
    ? _apiUrlOverride
    : (kReleaseMode ? productionApiUrl : _localApiUrl);

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

  /// Nahrávanie fotky na pomalom mobilnom pripojení trvá dlhšie.
  static const _uploadTimeout = Duration(seconds: 60);

  /// Pošle požiadavku a vráti JSON objekt (prázdny pri odpovedi bez tela).
  /// [bytes] je surové telo (napr. fotka) s typom [contentType].
  Future<Map<String, dynamic>> send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
    List<int>? bytes,
    String? contentType,
  }) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    if (token != null) request.headers['authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    } else if (bytes != null) {
      request.headers['content-type'] =
          contentType ?? 'application/octet-stream';
      request.bodyBytes = bytes;
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client
            .send(request)
            .timeout(bytes == null ? _timeout : _uploadTimeout),
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
