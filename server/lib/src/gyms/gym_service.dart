import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db.dart';
import '../http/api_exception.dart';
import '../http/middleware.dart';
import '../http/rate_limiter.dart';
import '../trainer/trainer_routes.dart' show RequireUser;
import '../trainer/trainer_validation.dart';

/// Najviac fitiek v jednej odpovedi (celá zemeguľa naraz).
const maxGymsPerList = 5000;

const _gymNotFound = ApiException(404, 'gym_not_found', 'Fitko sme nenašli.');

/// Spoločný SELECT: fitko, súhrn hodnotení a moje hodnotenie.
const _select = '''
  SELECT g.id::text, g.name, g.address, g.city, g.lat, g.lng,
         g.opening_hours, g.tags, g.website, g.photo_urls,
         coalesce(r.s1, 0), coalesce(r.s2, 0), coalesce(r.s3, 0),
         coalesce(r.s4, 0), coalesce(r.s5, 0),
         mine.stars
  FROM gyms g
  LEFT JOIN gym_rating_summary() r ON r.gym_id = g.id
  LEFT JOIN gym_reviews mine
    ON mine.gym_id = g.id AND mine.user_id = app_user_id()
''';

Map<String, dynamic> _gymJson(ResultRow r) => {
  'id': r[0],
  'name': r[1],
  'address': r[2],
  'city': r[3] ?? '',
  'lat': r[4],
  'lng': r[5],
  'openingHours': r[6],
  'tags': r[7] ?? const <String>[],
  'website': r[8],
  'photoUrls': r[9] ?? const <String>[],
  'rating': {
    'stars': [r[10], r[11], r[12], r[13], r[14]],
  },
  'myStars': r[15],
};

class GymService {
  GymService(this._db);

  final Database _db;

  /// Všetky fitká sveta zoradené podľa názvu.
  Future<List<Map<String, dynamic>>> list(String userId) =>
      _db.asUser(userId, (tx) async {
        final rows = await tx.execute(
          Sql.named('$_select ORDER BY g.name LIMIT @limit'),
          parameters: {'limit': maxGymsPerList},
        );
        return [for (final r in rows) _gymJson(r)];
      });

  Future<Map<String, dynamic>> detail(String userId, String gymId) =>
      _db.asUser(userId, (tx) => _one(tx, gymId));

  /// Uloží (alebo zmení) moje hodnotenie a vráti aktualizované fitko.
  Future<Map<String, dynamic>> rate(String userId, String gymId, int stars) =>
      _db.asUser(userId, (tx) async {
        try {
          await tx.execute(
            Sql.named('''
              INSERT INTO gym_reviews (gym_id, user_id, stars)
              VALUES (CAST(@gym AS uuid), CAST(@user AS uuid), @stars)
              ON CONFLICT (gym_id, user_id)
              DO UPDATE SET stars = EXCLUDED.stars, updated_at = now()
            '''),
            parameters: {'gym': gymId, 'user': userId, 'stars': stars},
          );
        } on ServerException catch (e) {
          if (e.code == '23503') throw _gymNotFound; // fitko neexistuje
          rethrow;
        }
        return _one(tx, gymId);
      });

  /// Zmaže moje hodnotenie a vráti aktualizované fitko.
  Future<Map<String, dynamic>> unrate(
    String userId,
    String gymId,
  ) => _db.asUser(userId, (tx) async {
    await tx.execute(
      Sql.named(
        'DELETE FROM gym_reviews '
        'WHERE gym_id = CAST(@gym AS uuid) AND user_id = CAST(@user AS uuid)',
      ),
      parameters: {'gym': gymId, 'user': userId},
    );
    return _one(tx, gymId);
  });

  Future<Map<String, dynamic>> _one(TxSession tx, String gymId) async {
    final rows = await tx.execute(
      Sql.named('$_select WHERE g.id = CAST(@gym AS uuid)'),
      parameters: {'gym': gymId},
    );
    if (rows.isEmpty) throw _gymNotFound;
    return _gymJson(rows.first);
  }
}

const _slowDown = ApiException(
  429,
  'too_many_requests',
  'Priveľa požiadaviek. Skús to o chvíľu.',
);

/// `GET /gyms`, `GET /gyms/<id>`, `PUT` a `DELETE /gyms/<id>/review`.
///
/// Limity na používateľa chránia databázu pred zahltením: zoznam vracia
/// až [maxGymsPerList] riadkov a hodnotenia by sa dali „klikať“ v slučke.
void addGymRoutes(
  Router router, {
  required GymService service,
  required RequireUser requireUser,
  RateLimiter? readLimiter,
  RateLimiter? writeLimiter,
}) {
  final reads =
      readLimiter ??
      RateLimiter(maxAttempts: 60, window: const Duration(minutes: 1));
  final writes =
      writeLimiter ??
      RateLimiter(maxAttempts: 30, window: const Duration(minutes: 1));

  Future<String> reader(Request request) async {
    final (_, user) = await requireUser(request);
    if (!reads.tryAcquire(user.id)) throw _slowDown;
    return user.id;
  }

  Future<String> writer(Request request) async {
    final (_, user) = await requireUser(request);
    if (!writes.tryAcquire(user.id)) throw _slowDown;
    return user.id;
  }

  router
    ..get('/gyms', (Request request) async {
      final userId = await reader(request);
      return jsonResponse(200, {'gyms': await service.list(userId)});
    })
    ..get('/gyms/<id>', (Request request, String id) async {
      final userId = await reader(request);
      return jsonResponse(200, await service.detail(userId, requireUuid(id)));
    })
    ..put('/gyms/<id>/review', (Request request, String id) async {
      final userId = await writer(request);
      final gymId = requireUuid(id);
      final body = await readJsonBody(request, maxBytes: 1024);
      final stars = requireInt(body['stars'], 'stars', min: 1, max: 5);
      return jsonResponse(200, await service.rate(userId, gymId, stars));
    })
    ..delete('/gyms/<id>/review', (Request request, String id) async {
      final userId = await writer(request);
      return jsonResponse(200, await service.unrate(userId, requireUuid(id)));
    });
}
