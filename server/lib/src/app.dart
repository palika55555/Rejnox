import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'auth/auth_service.dart';
import 'auth/validators.dart';
import 'gyms/gym_service.dart';
import 'http/api_exception.dart';
import 'http/middleware.dart';
import 'http/rate_limiter.dart';
import 'trainer/trainer_routes.dart';
import 'trainer/trainer_service.dart';
import 'training/training_service.dart';

const _tooManyAttempts = ApiException(
  429,
  'too_many_attempts',
  'Priveľa pokusov. Skús to o chvíľu.',
);

const _unauthorized = ApiException(401, 'unauthorized', 'Prihlás sa, prosím.');

/// Poskladá celý server: cesty + ochranné vrstvy.
Handler buildApp({
  required AuthService auth,
  required TrainingService training,
  required TrainerService trainers,

  /// Mapa fitiek (/gyms). Testy iných častí ho nemusia zapájať.
  GymService? gyms,
  required Set<String> corsOrigins,
  Set<String> trustedProxies = const {},
  String? clientIpHeader,
  RateLimiter? loginLimiter,
  RateLimiter? loginEmailLimiter,
  RateLimiter? registerLimiter,
  RateLimiter? inviteLimiter,
  void Function(Object, StackTrace)? onError,
}) {
  final logins =
      loginLimiter ??
      RateLimiter(maxAttempts: 10, window: const Duration(minutes: 5));
  // Limit na samotný e-mail platí bez ohľadu na IP, takže ho neobíde ani
  // útočník, ktorý strieda (alebo podvrhuje) adresy.
  final emailLogins =
      loginEmailLimiter ??
      RateLimiter(maxAttempts: 30, window: const Duration(minutes: 15));
  final registrations =
      registerLimiter ??
      RateLimiter(maxAttempts: 20, window: const Duration(hours: 1));

  String ip(Request request) => clientAddress(
    request,
    trustedProxies: trustedProxies,
    ipHeader: clientIpHeader,
  );

  Future<(String, AuthUser)> requireUser(Request request) async {
    final token = bearerToken(request);
    final user = token == null ? null : await auth.userForToken(token);
    if (token == null || user == null) throw _unauthorized;
    return (token, user);
  }

  final router = Router()
    ..get('/health', (Request _) => jsonResponse(200, {'status': 'ok'}))
    ..post('/auth/register', (Request request) async {
      if (!registrations.tryAcquire(ip(request))) {
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
      final key = '${ip(request)}|$email';
      if (!logins.tryAcquire(key) || !emailLogins.tryAcquire(email)) {
        throw _tooManyAttempts;
      }
      final result = await auth.login(email: email, password: password);
      logins.reset(key);
      emailLogins.reset(email);
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
    ..get('/exercises', (Request request) async {
      final (_, user) = await requireUser(request);
      return jsonResponse(200, {
        'exercises': await training.exercises(user.id),
      });
    })
    ..post('/sets/sync', (Request request) async {
      final (_, user) = await requireUser(request);
      final body = await readJsonBody(request, maxBytes: 64 * 1024);
      final (sets, rejected) = parseSets(body);
      final result = await training.syncSets(user.id, sets, rejected);
      return jsonResponse(200, result.toJson());
    });

  addTrainerRoutes(
    router,
    service: trainers,
    requireUser: requireUser,
    inviteLimiter:
        inviteLimiter ??
        RateLimiter(maxAttempts: 10, window: const Duration(hours: 1)),
  );

  if (gyms != null) {
    addGymRoutes(router, service: gyms, requireUser: requireUser);
  }

  router.all(
    '/<ignored|.*>',
    (Request _) => throw const ApiException(404, 'not_found', 'Nenájdené.'),
  );

  return const Pipeline()
      .addMiddleware(securityHeaders(corsOrigins))
      .addMiddleware(errorHandler(onError: onError))
      .addHandler(router.call);
}
