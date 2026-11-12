import '../../training/domain/training_models.dart';

enum LinkStatus {
  recordOnly('record_only', 'Bez appky'),
  invited('invited', 'Pozvaný'),
  linked('linked', 'Prepojený'),
  ended('ended', 'Ukončené');

  const LinkStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static LinkStatus fromApi(Object? value) => values.firstWhere(
    (s) => s.apiValue == value,
    orElse: () => LinkStatus.recordOnly,
  );
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;

/// Klient trénera.
class ClientLink {
  const ClientLink({
    required this.id,
    required this.name,
    required this.status,
    required this.hasAccount,
    this.note,
    this.inviteExpiresAt,
  });

  factory ClientLink.fromJson(Map<String, dynamic> json) => ClientLink(
    id: json['id'] as String,
    name: json['name'] as String,
    note: json['note'] as String?,
    status: LinkStatus.fromApi(json['status']),
    hasAccount: json['hasAccount'] as bool? ?? false,
    inviteExpiresAt: _date(json['inviteExpiresAt']),
  );

  final String id;
  final String name;
  final String? note;
  final LinkStatus status;
  final bool hasAccount;
  final DateTime? inviteExpiresAt;

  bool get canInvite =>
      !hasAccount &&
      (status == LinkStatus.recordOnly || status == LinkStatus.invited);
  bool get isActive => status != LinkStatus.ended;
}

class PlanItem {
  const PlanItem({
    required this.exerciseId,
    required this.name,
    required this.group,
    required this.sets,
    required this.reps,
    this.weightKg,
    this.note,
  });

  factory PlanItem.fromJson(Map<String, dynamic> json) => PlanItem(
    exerciseId: json['exerciseId'] as String,
    name: json['name'] as String? ?? 'Cvik',
    group: MuscleGroup.fromApi(json['muscleGroup']),
    sets: json['sets'] as int,
    reps: json['reps'] as int,
    weightKg: (json['weightKg'] as num?)?.toDouble(),
    note: json['note'] as String?,
  );

  final String exerciseId;
  final String name;
  final MuscleGroup group;
  final int sets;
  final int reps;
  final double? weightKg;
  final String? note;

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'name': name,
    'muscleGroup': group.apiValue,
    'sets': sets,
    'reps': reps,
    'weightKg': weightKg,
    'note': note,
  };

  String get scheme {
    final w = weightKg;
    final weight = w == null
        ? ''
        : ' · ${w == w.roundToDouble() ? w.toInt() : w.toString().replaceAll('.', ',')} kg';
    return '$sets×$reps$weight';
  }
}

/// Tréningový plán od trénera.
class Plan {
  const Plan({
    required this.id,
    required this.title,
    required this.trainerName,
    required this.items,
    this.scheduledOn,
  });

  factory Plan.fromJson(Map<String, dynamic> json) => Plan(
    id: json['id'] as String,
    title: json['title'] as String,
    trainerName: json['trainerName'] as String? ?? '',
    scheduledOn: json['scheduledOn'] is String
        ? DateTime.tryParse(json['scheduledOn'] as String)
        : null,
    items: [
      for (final e in json['exercises'] as List? ?? const [])
        PlanItem.fromJson(e as Map<String, dynamic>),
    ],
  );

  final String id;
  final String title;
  final String trainerName;
  final DateTime? scheduledOn;
  final List<PlanItem> items;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'trainerName': trainerName,
    'scheduledOn': scheduledOn == null
        ? null
        : '${scheduledOn!.year.toString().padLeft(4, '0')}-'
              '${scheduledOn!.month.toString().padLeft(2, '0')}-'
              '${scheduledOn!.day.toString().padLeft(2, '0')}',
    'exercises': [for (final i in items) i.toJson()],
  };
}

/// Séria, ktorú klientovi zapísal tréner.
class ClientSet {
  const ClientSet({
    required this.id,
    required this.name,
    required this.reps,
    required this.weightKg,
    required this.performedAt,
  });

  factory ClientSet.fromJson(Map<String, dynamic> json) => ClientSet(
    id: json['id'] as String,
    name: json['name'] as String,
    reps: json['reps'] as int,
    weightKg: (json['weightKg'] as num).toDouble(),
    performedAt: _date(json['performedAt']) ?? DateTime.now(),
  );

  final String id;
  final String name;
  final int reps;
  final double weightKg;
  final DateTime performedAt;
}

class ClientDetail {
  const ClientDetail({
    required this.client,
    required this.plans,
    required this.sets,
  });

  factory ClientDetail.fromJson(Map<String, dynamic> json) => ClientDetail(
    client: ClientLink.fromJson(json),
    plans: [
      for (final p in json['workouts'] as List? ?? const [])
        Plan.fromJson(p as Map<String, dynamic>),
    ],
    sets: [
      for (final s in json['sets'] as List? ?? const [])
        ClientSet.fromJson(s as Map<String, dynamic>),
    ],
  );

  final ClientLink client;
  final List<Plan> plans;
  final List<ClientSet> sets;
}

/// Môj tréner (pohľad klienta).
class MyTrainer {
  const MyTrainer({
    required this.linkId,
    required this.trainerName,
    required this.status,
  });

  factory MyTrainer.fromJson(Map<String, dynamic> json) => MyTrainer(
    linkId: json['linkId'] as String,
    trainerName: json['trainerName'] as String,
    status: LinkStatus.fromApi(json['status']),
  );

  final String linkId;
  final String trainerName;
  final LinkStatus status;
}

class InviteCode {
  const InviteCode({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;
}
