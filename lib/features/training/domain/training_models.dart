import '../../../core/theme/app_colors.dart';

enum MuscleGroup {
  legs('nohy', 'Nohy', Plate.red),
  back('chrbat', 'Chrbát', Plate.blue),
  chest('hrudnik', 'Hrudník', Plate.yellow),
  shoulders('ramena', 'Ramená', Plate.green),
  arms('ruky', 'Ruky', Plate.green);

  const MuscleGroup(this.apiValue, this.label, this.plate);

  final String apiValue;
  final String label;
  final Plate plate;

  static MuscleGroup fromApi(Object? value) => values.firstWhere(
    (g) => g.apiValue == value,
    orElse: () => MuscleGroup.legs,
  );
}

class Exercise {
  const Exercise({required this.id, required this.name, required this.group});

  final String id;
  final String name;
  final MuscleGroup group;
}

enum SyncState {
  /// Uložené len v telefóne, čaká na odoslanie.
  pending,

  /// Server sériu prijal.
  synced,

  /// Server sériu odmietol (napr. neplatné údaje); už sa neposiela.
  rejected,
}

/// Jedna odcvičená séria. ID vzniká v telefóne, takže opakované odoslanie
/// na server nič nezdvojí.
class LoggedSet {
  const LoggedSet({
    required this.id,
    required this.exerciseId,
    required this.reps,
    required this.weightKg,
    required this.performedAt,
    this.state = SyncState.pending,
  });

  factory LoggedSet.fromJson(Map<String, dynamic> json) => LoggedSet(
    id: json['id'] as String,
    exerciseId: json['exerciseId'] as String,
    reps: json['reps'] as int,
    weightKg: (json['weightKg'] as num).toDouble(),
    // Ukladá sa v UTC, zobrazuje sa v miestnom čase.
    performedAt: DateTime.parse(json['performedAt'] as String).toLocal(),
    state: SyncState.values.byName(json['state'] as String? ?? 'pending'),
  );

  final String id;
  final String exerciseId;
  final int reps;
  final double weightKg;
  final DateTime performedAt;
  final SyncState state;

  LoggedSet withState(SyncState state) => LoggedSet(
    id: id,
    exerciseId: exerciseId,
    reps: reps,
    weightKg: weightKg,
    performedAt: performedAt,
    state: state,
  );

  /// Tvar pre server.
  Map<String, dynamic> toApiJson() => {
    'id': id,
    'exerciseId': exerciseId,
    'reps': reps,
    'weightKg': weightKg,
    'performedAt': performedAt.toUtc().toIso8601String(),
  };

  /// Tvar pre lokálne úložisko (aj so stavom).
  Map<String, dynamic> toJson() => {...toApiJson(), 'state': state.name};

  String get weightLabel => weightKg == weightKg.roundToDouble()
      ? '${weightKg.toInt()} kg'
      : '${weightKg.toString().replaceAll('.', ',')} kg';
}
