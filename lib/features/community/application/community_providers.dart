import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../home/data/home_repository.dart';
import '../data/community_api.dart';
import '../domain/community_models.dart';

const _signedOut = ApiError(401, 'unauthorized', 'Prihlás sa, prosím.');

String _authToken(Ref ref) => switch (ref.read(authControllerProvider)) {
  SignedIn(:final token) => token,
  _ => throw _signedOut,
};

CommunityApi _api(Ref ref) {
  ref.watch(authControllerProvider);
  return ref.read(communityApiProvider);
}

final communityPostsProvider = FutureProvider.autoDispose<List<CommunityPost>>(
  (ref) => _api(ref).posts(_authToken(ref)),
);

final postCommentsProvider = FutureProvider.autoDispose
    .family<List<CommunityComment>, String>(
      (ref, postId) => _api(ref).comments(_authToken(ref), postId),
    );

final buddyRequestsProvider = FutureProvider.autoDispose<List<BuddyRequest>>(
  (ref) => _api(ref).buddies(_authToken(ref)),
);

final communityEventsProvider =
    FutureProvider.autoDispose<List<CommunityEvent>>(
      (ref) => _api(ref).events(_authToken(ref)),
    );

final challengesProvider = FutureProvider.autoDispose<List<Challenge>>(
  (ref) => _api(ref).challenges(_authToken(ref)),
);

final leaderboardProvider = FutureProvider.autoDispose<Leaderboard>(
  (ref) => _api(ref).leaderboard(_authToken(ref)),
);

/// Zápisy do komunity. Po každom sa obnoví dotknutý zoznam
/// (a domovská obrazovka, keď sa jej to týka).
class CommunityActions {
  CommunityActions(this._ref);

  final Ref _ref;

  CommunityApi get _api => _ref.read(communityApiProvider);
  String get _token => _authToken(_ref);

  void _refreshHome() => _ref.invalidate(homeOverviewProvider);

  Future<void> createPost(String body) async {
    await _api.createPost(_token, body);
    _ref.invalidate(communityPostsProvider);
  }

  Future<void> deletePost(String id) async {
    await _api.deletePost(_token, id);
    _ref.invalidate(communityPostsProvider);
  }

  /// Vráti príspevok s novým počtom lajkov.
  Future<CommunityPost> setLike(String postId, bool liked) =>
      _api.setLike(_token, postId, liked);

  Future<void> addComment(String postId, String body) async {
    await _api.addComment(_token, postId, body);
    _ref
      ..invalidate(postCommentsProvider(postId))
      ..invalidate(communityPostsProvider);
  }

  Future<void> deleteComment(String postId, String commentId) async {
    await _api.deleteComment(_token, commentId);
    _ref
      ..invalidate(postCommentsProvider(postId))
      ..invalidate(communityPostsProvider);
  }

  Future<void> createBuddy({
    required DateTime startsAt,
    required String place,
    String? focus,
    String? note,
  }) async {
    await _api.createBuddy(
      _token,
      startsAt: startsAt,
      place: place,
      focus: focus,
      note: note,
    );
    _ref.invalidate(buddyRequestsProvider);
  }

  Future<void> deleteBuddy(String id) async {
    await _api.deleteBuddy(_token, id);
    _ref.invalidate(buddyRequestsProvider);
  }

  Future<void> joinBuddy(String id, bool join) async {
    await _api.joinBuddy(_token, id, join);
    _ref.invalidate(buddyRequestsProvider);
    _refreshHome();
  }

  Future<void> createEvent({
    required String title,
    required String place,
    required DateTime startsAt,
    String? description,
  }) async {
    await _api.createEvent(
      _token,
      title: title,
      place: place,
      startsAt: startsAt,
      description: description,
    );
    _ref.invalidate(communityEventsProvider);
  }

  Future<void> deleteEvent(String id) async {
    await _api.deleteEvent(_token, id);
    _ref.invalidate(communityEventsProvider);
  }

  Future<void> joinEvent(String id, bool join) async {
    await _api.joinEvent(_token, id, join);
    _ref.invalidate(communityEventsProvider);
  }

  Future<void> createChallenge({
    required String title,
    required int goalDays,
    required DateTime startsOn,
    required DateTime endsOn,
    String? description,
  }) async {
    await _api.createChallenge(
      _token,
      title: title,
      goalDays: goalDays,
      startsOn: startsOn,
      endsOn: endsOn,
      description: description,
    );
    _ref.invalidate(challengesProvider);
  }

  Future<void> deleteChallenge(String id) async {
    await _api.deleteChallenge(_token, id);
    _ref.invalidate(challengesProvider);
  }

  Future<void> joinChallenge(String id, bool join) async {
    await _api.joinChallenge(_token, id, join);
    _ref.invalidate(challengesProvider);
  }

  Future<void> setLeaderboardOptIn(bool enabled) async {
    await _api.setLeaderboardOptIn(_token, enabled);
    _ref.invalidate(leaderboardProvider);
    _refreshHome();
  }
}

final communityActionsProvider = Provider<CommunityActions>(
  CommunityActions.new,
);
