/// Údaje komunity zo servera (/api/community/...).
library;

DateTime _time(Object? value) => DateTime.parse(value as String).toLocal();

class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.authorName,
    required this.body,
    required this.createdAt,
    required this.likes,
    required this.comments,
    required this.likedByMe,
    required this.mine,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> json) => CommunityPost(
    id: json['id'] as String,
    authorName: json['authorName'] as String? ?? 'Používateľ',
    body: json['body'] as String,
    createdAt: _time(json['createdAt']),
    likes: json['likes'] as int? ?? 0,
    comments: json['comments'] as int? ?? 0,
    likedByMe: json['likedByMe'] as bool? ?? false,
    mine: json['mine'] as bool? ?? false,
  );

  final String id;
  final String authorName;
  final String body;
  final DateTime createdAt;
  final int likes;
  final int comments;
  final bool likedByMe;
  final bool mine;

  CommunityPost copyWith({int? likes, int? comments, bool? likedByMe}) =>
      CommunityPost(
        id: id,
        authorName: authorName,
        body: body,
        createdAt: createdAt,
        likes: likes ?? this.likes,
        comments: comments ?? this.comments,
        likedByMe: likedByMe ?? this.likedByMe,
        mine: mine,
      );
}

class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.authorName,
    required this.body,
    required this.createdAt,
    required this.mine,
  });

  factory CommunityComment.fromJson(Map<String, dynamic> json) =>
      CommunityComment(
        id: json['id'] as String,
        authorName: json['authorName'] as String? ?? 'Používateľ',
        body: json['body'] as String,
        createdAt: _time(json['createdAt']),
        mine: json['mine'] as bool? ?? false,
      );

  final String id;
  final String authorName;
  final String body;
  final DateTime createdAt;
  final bool mine;
}

/// Niekto hľadá parťáka na spoločný tréning.
class BuddyRequest {
  const BuddyRequest({
    required this.id,
    required this.hostName,
    required this.startsAt,
    required this.place,
    required this.focus,
    required this.note,
    required this.members,
    required this.joined,
    required this.mine,
  });

  factory BuddyRequest.fromJson(Map<String, dynamic> json) => BuddyRequest(
    id: json['id'] as String,
    hostName: json['hostName'] as String? ?? 'Používateľ',
    startsAt: _time(json['startsAt']),
    place: json['place'] as String?,
    focus: json['focus'] as String?,
    note: json['note'] as String?,
    members: json['members'] as int? ?? 0,
    joined: json['joined'] as bool? ?? false,
    mine: json['mine'] as bool? ?? false,
  );

  final String id;
  final String hostName;
  final DateTime startsAt;
  final String? place;
  final String? focus;
  final String? note;
  final int members;
  final bool joined;
  final bool mine;
}

class CommunityEvent {
  const CommunityEvent({
    required this.id,
    required this.title,
    required this.place,
    required this.description,
    required this.startsAt,
    required this.organizerName,
    required this.attendees,
    required this.joined,
    required this.mine,
  });

  factory CommunityEvent.fromJson(Map<String, dynamic> json) => CommunityEvent(
    id: json['id'] as String,
    title: json['title'] as String,
    place: json['place'] as String,
    description: json['description'] as String?,
    startsAt: _time(json['startsAt']),
    organizerName: json['organizerName'] as String? ?? 'Používateľ',
    attendees: json['attendees'] as int? ?? 0,
    joined: json['joined'] as bool? ?? false,
    mine: json['mine'] as bool? ?? false,
  );

  final String id;
  final String title;
  final String place;
  final String? description;
  final DateTime startsAt;
  final String organizerName;
  final int attendees;
  final bool joined;
  final bool mine;
}

/// Výzva: cieľ je počet dní s tréningom medzi začiatkom a koncom.
class Challenge {
  const Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.goalDays,
    required this.startsOn,
    required this.endsOn,
    required this.members,
    required this.joined,
    required this.mine,
    required this.myDays,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) => Challenge(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    goalDays: json['goalDays'] as int,
    startsOn: DateTime.parse(json['startsOn'] as String),
    endsOn: DateTime.parse(json['endsOn'] as String),
    members: json['members'] as int? ?? 0,
    joined: json['joined'] as bool? ?? false,
    mine: json['mine'] as bool? ?? false,
    myDays: json['myDays'] as int?,
  );

  final String id;
  final String title;
  final String? description;
  final int goalDays;
  final DateTime startsOn;
  final DateTime endsOn;
  final int members;
  final bool joined;
  final bool mine;

  /// Moje dni s tréningom vo výzve (null, keď nie som členom).
  final int? myDays;

  double get progress =>
      myDays == null ? 0 : (myDays! / goalDays).clamp(0, 1).toDouble();
  bool get completed => myDays != null && myDays! >= goalDays;
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.name,
    required this.city,
    required this.days,
    required this.me,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        name: json['name'] as String? ?? 'Používateľ',
        city: json['city'] as String?,
        days: json['days'] as int? ?? 0,
        me: json['me'] as bool? ?? false,
      );

  final String name;
  final String? city;
  final int days;
  final bool me;
}

/// Týždenný rebríček aktivity; ukazuje len tých, čo si ho zapli.
class Leaderboard {
  const Leaderboard({required this.optedIn, required this.entries});

  factory Leaderboard.fromJson(Map<String, dynamic> json) => Leaderboard(
    optedIn: json['optedIn'] as bool? ?? false,
    entries: [
      for (final e in json['entries'] as List? ?? const [])
        LeaderboardEntry.fromJson(e as Map<String, dynamic>),
    ],
  );

  final bool optedIn;
  final List<LeaderboardEntry> entries;
}
