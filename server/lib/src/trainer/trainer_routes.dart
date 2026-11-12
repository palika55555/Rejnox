import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_service.dart';
import '../http/api_exception.dart';
import '../http/middleware.dart';
import '../http/rate_limiter.dart';
import 'trainer_service.dart';
import 'trainer_validation.dart';

typedef RequireUser = Future<(String, AuthUser)> Function(Request request);

const _trainersOnly = ApiException(
  403,
  'trainers_only',
  'Táto časť je len pre trénerov.',
);

/// Cesty pre trénera (/clients) a pre klienta (/invites, /me/trainers, /me/plans).
void addTrainerRoutes(
  Router router, {
  required TrainerService service,
  required RequireUser requireUser,
  required RateLimiter inviteLimiter,
}) {
  Future<AuthUser> trainer(Request request) async {
    final (_, user) = await requireUser(request);
    if (user.role != 'trainer') throw _trainersOnly;
    return user;
  }

  router
    // ------------------------------------------------------------ tréner
    ..get('/clients', (Request request) async {
      final me = await trainer(request);
      return jsonResponse(200, {'clients': await service.listClients(me.id)});
    })
    ..post('/clients', (Request request) async {
      final me = await trainer(request);
      final body = await readJsonBody(request);
      final client = await service.addClient(
        me.id,
        name: requireText(body, 'name', max: 60, label: 'Meno'),
        note: optionalText(body, 'note', max: 500),
      );
      return jsonResponse(201, client);
    })
    ..get('/clients/<id>', (Request request, String id) async {
      final me = await trainer(request);
      return jsonResponse(
        200,
        await service.clientDetail(me.id, requireUuid(id)),
      );
    })
    ..delete('/clients/<id>', (Request request, String id) async {
      final me = await trainer(request);
      await service.deleteClient(me.id, requireUuid(id));
      return Response(204);
    })
    ..post('/clients/<id>/invite', (Request request, String id) async {
      final me = await trainer(request);
      return jsonResponse(201, await service.invite(me.id, requireUuid(id)));
    })
    ..post('/clients/<id>/end', (Request request, String id) async {
      final me = await trainer(request);
      await service.endLink(me.id, requireUuid(id));
      return Response(204);
    })
    ..post('/clients/<id>/workouts', (Request request, String id) async {
      final me = await trainer(request);
      final body = await readJsonBody(request, maxBytes: 32 * 1024);
      final raw = body['exercises'];
      if (raw is! List || raw.isEmpty || raw.length > 30) {
        throw const ApiException(
          400,
          'invalid_exercises',
          'Plán musí mať 1 až 30 cvikov.',
        );
      }
      final workout = await service.addWorkout(
        me.id,
        requireUuid(id),
        title: requireText(body, 'title', max: 120, label: 'Názov'),
        scheduledOn: optionalDate(body, 'scheduledOn'),
        exercises: [for (final e in raw) PlanExercise.fromJson(e)],
      );
      return jsonResponse(201, workout);
    })
    ..delete('/clients/<id>/workouts/<wid>', (
      Request request,
      String id,
      String wid,
    ) async {
      final me = await trainer(request);
      await service.deleteWorkout(me.id, requireUuid(id), requireUuid(wid));
      return Response(204);
    })
    ..post('/clients/<id>/sets', (Request request, String id) async {
      final me = await trainer(request);
      final body = await readJsonBody(request);
      final at = body['performedAt'];
      final performedAt = at is String ? DateTime.tryParse(at)?.toUtc() : null;
      if (performedAt != null &&
          performedAt.isAfter(
            DateTime.now().toUtc().add(const Duration(days: 1)),
          )) {
        throw const ApiException(400, 'invalid_time', 'Neplatný čas.');
      }
      final result = await service.logSet(
        me.id,
        requireUuid(id),
        id: requireUuid('${body['id']}'),
        exerciseId: requireUuid('${body['exerciseId']}', 'exerciseId'),
        reps: requireInt(body['reps'], 'reps', min: 1, max: 1000),
        weightKg: requireWeight(body['weightKg']),
        performedAt: performedAt,
      );
      return jsonResponse(201, result);
    })
    // ------------------------------------------------------------ klient
    ..post('/invites/accept', (Request request) async {
      final (_, user) = await requireUser(request);
      if (!inviteLimiter.tryAcquire(user.id)) {
        throw const ApiException(
          429,
          'too_many_attempts',
          'Priveľa pokusov. Skús to o chvíľu.',
        );
      }
      final body = await readJsonBody(request);
      final code = normalizeInviteCode(body['code']);
      final link = await service.acceptInvite(user.id, code);
      inviteLimiter.reset(user.id);
      return jsonResponse(200, link);
    })
    ..get('/me/trainers', (Request request) async {
      final (_, user) = await requireUser(request);
      return jsonResponse(200, {'trainers': await service.myTrainers(user.id)});
    })
    ..post('/me/trainers/<id>/end', (Request request, String id) async {
      final (_, user) = await requireUser(request);
      await service.endLink(user.id, requireUuid(id));
      return Response(204);
    })
    ..get('/me/plans', (Request request) async {
      final (_, user) = await requireUser(request);
      return jsonResponse(200, {'plans': await service.myPlans(user.id)});
    });
}
