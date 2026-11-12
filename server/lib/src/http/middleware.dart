import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

import 'api_exception.dart';

const _maxBodyBytes = 16 * 1024;

Response jsonResponse(int status, Object? body) => Response(
  status,
  body: jsonEncode(body),
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Načíta telo požiadavky ako JSON objekt, s limitom veľkosti.
Future<Map<String, dynamic>> readJsonBody(
  Request request, {
  int maxBytes = _maxBodyBytes,
}) async {
  final bytes = <int>[];
  await for (final chunk in request.read()) {
    bytes.addAll(chunk);
    if (bytes.length > maxBytes) {
      throw const ApiException(
        413,
        'body_too_large',
        'Požiadavka je príliš veľká.',
      );
    }
  }
  try {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is Map<String, dynamic>) return decoded;
  } on FormatException {
    // Spadne na chybu nižšie.
  }
  throw const ApiException(400, 'invalid_json', 'Neplatné telo požiadavky.');
}

/// Token z hlavičky "Authorization: Bearer ...".
String? bearerToken(Request request) {
  final header = request.headers['authorization'];
  if (header == null || !header.startsWith('Bearer ')) return null;
  final token = header.substring(7).trim();
  return token.isEmpty ? null : token;
}

/// IP adresa klienta (pre obmedzenie počtu pokusov).
String clientAddress(Request request) {
  final info = request.context['shelf.io.connection_info'];
  return info is HttpConnectionInfo ? info.remoteAddress.address : 'unknown';
}

/// Chyby premení na JSON. Nečakané chyby zapíše do logu a klientovi nič neprezradí.
Middleware errorHandler({void Function(Object, StackTrace)? onError}) =>
    (inner) => (request) async {
      try {
        return await inner(request);
      } on ApiException catch (e) {
        return jsonResponse(e.status, {
          'error': {'code': e.code, 'message': e.message},
        });
      } catch (e, stack) {
        onError?.call(e, stack);
        return jsonResponse(500, {
          'error': {'code': 'internal', 'message': 'Niečo sa pokazilo.'},
        });
      }
    };

/// Bezpečnostné hlavičky a CORS len pre povolené adresy.
Middleware securityHeaders(Set<String> allowedOrigins) =>
    (inner) => (request) async {
      final origin = request.headers['origin'];
      final cors = <String, String>{
        if (origin != null && allowedOrigins.contains(origin)) ...{
          'access-control-allow-origin': origin,
          'access-control-allow-headers': 'authorization, content-type',
          'access-control-allow-methods': 'GET, POST, DELETE, OPTIONS',
          'vary': 'origin',
        },
      };
      if (request.method == 'OPTIONS') {
        return Response(204, headers: cors);
      }
      final response = await inner(request);
      return response.change(
        headers: {
          ...cors,
          'x-content-type-options': 'nosniff',
          'cache-control': 'no-store',
        },
      );
    };
