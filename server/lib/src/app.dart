import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'auth/auth_service.dart';
import 'auth/validators.dart';
import 'http/api_exception.dart';
import 'http/middleware.dart';
import 'http/rate_limiter.dart';

const _tooManyAttempts = ApiException(
  429,
  'too_many_attempts',
  'Priveľa pokusov. Skús to o chvíľu.',
);

const _unauthorized = ApiException(401, 'unauthorized', 'Prihlás sa, prosím.');

/// Poskladá celý server: cesty + ochranné vrstvy.
Handler buildApp({
  required AuthService auth,
  required Set<String> corsOrigins,
  RateLimiter? loginLimiter,
  RateLimiter? registerLimiter,
  void Function(Object, StackTrace)? onError,
}) {
  final logins =
      loginLimiter ??
      RateLimiter(maxAttempts: 10, window: const Duration(minutes: 5));
  final registrations =
      registerLimiter ??
      RateLimiter(maxAttempts: 20, window: const Duration(hours: 1));

  Future<(String, AuthUser)> requireUser(Request request) async {
    final token = bearerToken(request);
    final user = token == null ? null : await auth.userForToken(token);
    if (token == null || user == null) throw _unauthorized;
    return (token, user);
  }

  final router = Router()
    ..get('/health', (Request _) => jsonResponse(200, {'status': 'ok'}))
    ..post('/auth/register', (Request request) async {
      if (!registrations.tryAcquire(clientAddress(request))) {
        throw _tooManyAttempts;
      }
      final body = await readJsonBody(request);
      final result = await auth.register(
        email: validateEmail(body),
        password: validateNewPassword(body),
        displayName: validateDisplayName(body),
        role: validateRole(body),
      );
      return jsonResponse(201, result.toJson());
    })
    ..post('/auth/login', (Request request) async {
      final body = await readJsonBody(request);
      final email = validateEmail(body);
      final password = validateLoginPassword(body);
      final key = '${clientAddress(request)}|$email';
      if (!logins.tryAcquire(key)) throw _tooManyAttempts;
      final result = await auth.login(email: email, password: password);
      logins.reset(key);
      return jsonResponse(200, result.toJson());
    })
    ..post('/auth/logout', (Request request) async {
      final token = bearerToken(request);
      if (token != null) await auth.logout(token);
      return Response(204);
    })
    ..get('/me', (Request request) async {
      final (_, user) = await requireUser(request);
      return jsonResponse(200, user.toJson());
    })
    ..delete('/me', (Request request) async {
      final (_, user) = await requireUser(request);
      await auth.deleteAccount(user.id);
      return Response(204);
    })
    ..all(
      '/<ignored|.*>',
      (Request _) => throw const ApiException(404, 'not_found', 'Nenájdené.'),
    );

  return const Pipeline()
      .addMiddleware(securityHeaders(corsOrigins))
      .addMiddleware(errorHandler(onError: onError))
      .addHandler(router.call);
}
