import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/community_models.dart';

/// API komunity: príspevky, parťáci, udalosti, výzvy a rebríček.
abstract interface class CommunityApi {
  Future<List<CommunityPost>> posts(String token, {DateTime? before});
  Future<CommunityPost> createPost(String token, String body);
  Future<void> deletePost(String token, String postId);
  Future<CommunityPost> setLike(String token, String postId, bool liked);
  Future<List<CommunityComment>> comments(String token, String postId);
  Future<CommunityComment> addComment(String token, String postId, String body);
  Future<void> deleteComment(String token, String commentId);

  Future<List<BuddyRequest>> buddies(String token);
  Future<BuddyRequest> createBuddy(
    String token, {
    required DateTime startsAt,
    required String place,
    String? focus,
    String? note,
  });
  Future<void> deleteBuddy(String token, String id);
  Future<BuddyRequest> joinBuddy(String token, String id, bool join);

  Future<List<CommunityEvent>> events(String token);
  Future<CommunityEvent> createEvent(
    String token, {
    required String title,
    required String place,
    required DateTime startsAt,
    String? description,
  });
  Future<void> deleteEvent(String token, String id);
  Future<CommunityEvent> joinEvent(String token, String id, bool join);

  Future<List<Challenge>> challenges(String token);
  Future<Challenge> createChallenge(
    String token, {
    required String title,
    required int goalDays,
    required DateTime startsOn,
    required DateTime endsOn,
    String? description,
  });
  Future<void> deleteChallenge(String token, String id);
  Future<Challenge> joinChallenge(String token, String id, bool join);

  Future<Leaderboard> leaderboard(String token);
  Future<Leaderboard> setLeaderboardOptIn(String token, bool enabled);
}

String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class HttpCommunityApi implements CommunityApi {
  const HttpCommunityApi(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> _get(String token, String path) =>
      _api.send('GET', '/community$path', token: token);

  Future<Map<String, dynamic>> _post(
    String token,
    String path,
    Map<String, dynamic> body,
  ) => _api.send('POST', '/community$path', token: token, body: body);

  Future<Map<String, dynamic>> _toggle(String token, String path, bool on) =>
      _api.send(on ? 'PUT' : 'DELETE', '/community$path', token: token);

  Future<void> _delete(String token, String path) =>
      _api.send('DELETE', '/community$path', token: token);

  List<T> _list<T>(
    Map<String, dynamic> json,
    String key,
    T Function(Map<String, dynamic>) parse,
  ) => [for (final e in json[key] as List) parse(e as Map<String, dynamic>)];

  @override
  Future<List<CommunityPost>> posts(String token, {DateTime? before}) async {
    final query = before == null
        ? ''
        : '?before=${Uri.encodeQueryComponent(before.toUtc().toIso8601String())}';
    return _list(
      await _get(token, '/posts$query'),
      'posts',
      CommunityPost.fromJson,
    );
  }

  @override
  Future<CommunityPost> createPost(String token, String body) async =>
      CommunityPost.fromJson(await _post(token, '/posts', {'body': body}));

  @override
  Future<void> deletePost(String token, String postId) =>
      _delete(token, '/posts/$postId');

  @override
  Future<CommunityPost> setLike(
    String token,
    String postId,
    bool liked,
  ) async => CommunityPost.fromJson(
    await _toggle(token, '/posts/$postId/like', liked),
  );

  @override
  Future<List<CommunityComment>> comments(String token, String postId) async =>
      _list(
        await _get(token, '/posts/$postId/comments'),
        'comments',
        CommunityComment.fromJson,
      );

  @override
  Future<CommunityComment> addComment(
    String token,
    String postId,
    String body,
  ) async => CommunityComment.fromJson(
    await _post(token, '/posts/$postId/comments', {'body': body}),
  );

  @override
  Future<void> deleteComment(String token, String commentId) =>
      _delete(token, '/comments/$commentId');

  @override
  Future<List<BuddyRequest>> buddies(String token) async =>
      _list(await _get(token, '/buddies'), 'buddies', BuddyRequest.fromJson);

  @override
  Future<BuddyRequest> createBuddy(
    String token, {
    required DateTime startsAt,
    required String place,
    String? focus,
    String? note,
  }) async => BuddyRequest.fromJson(
    await _post(token, '/buddies', {
      'startsAt': startsAt.toUtc().toIso8601String(),
      'place': place,
      'focus': ?focus,
      'note': ?note,
    }),
  );

  @override
  Future<void> deleteBuddy(String token, String id) =>
      _delete(token, '/buddies/$id');

  @override
  Future<BuddyRequest> joinBuddy(String token, String id, bool join) async =>
      BuddyRequest.fromJson(await _toggle(token, '/buddies/$id/join', join));

  @override
  Future<List<CommunityEvent>> events(String token) async =>
      _list(await _get(token, '/events'), 'events', CommunityEvent.fromJson);

  @override
  Future<CommunityEvent> createEvent(
    String token, {
    required String title,
    required String place,
    required DateTime startsAt,
    String? description,
  }) async => CommunityEvent.fromJson(
    await _post(token, '/events', {
      'title': title,
      'place': place,
      'startsAt': startsAt.toUtc().toIso8601String(),
      'description': ?description,
    }),
  );

  @override
  Future<void> deleteEvent(String token, String id) =>
      _delete(token, '/events/$id');

  @override
  Future<CommunityEvent> joinEvent(String token, String id, bool join) async =>
      CommunityEvent.fromJson(await _toggle(token, '/events/$id/join', join));

  @override
  Future<List<Challenge>> challenges(String token) async =>
      _list(await _get(token, '/challenges'), 'challenges', Challenge.fromJson);

  @override
  Future<Challenge> createChallenge(
    String token, {
    required String title,
    required int goalDays,
    required DateTime startsOn,
    required DateTime endsOn,
    String? description,
  }) async => Challenge.fromJson(
    await _post(token, '/challenges', {
      'title': title,
      'goalDays': goalDays,
      'startsOn': _date(startsOn),
      'endsOn': _date(endsOn),
      'description': ?description,
    }),
  );

  @override
  Future<void> deleteChallenge(String token, String id) =>
      _delete(token, '/challenges/$id');

  @override
  Future<Challenge> joinChallenge(String token, String id, bool join) async =>
      Challenge.fromJson(await _toggle(token, '/challenges/$id/join', join));

  @override
  Future<Leaderboard> leaderboard(String token) async =>
      Leaderboard.fromJson(await _get(token, '/leaderboard'));

  @override
  Future<Leaderboard> setLeaderboardOptIn(String token, bool enabled) async =>
      Leaderboard.fromJson(
        await _api.send(
          'PUT',
          '/community/leaderboard/opt-in',
          token: token,
          body: {'enabled': enabled},
        ),
      );
}

final communityApiProvider = Provider<CommunityApi>(
  (ref) => HttpCommunityApi(ref.watch(apiClientProvider)),
);
