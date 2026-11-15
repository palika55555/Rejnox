import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/training_models.dart';

/// Čo vieme o cviku zo zapísaných sérií: rekord a posledná séria.
class ExerciseHistory {
  const ExerciseHistory({this.bestKg, this.last});

  /// Najvyššia odcvičená váha (null = cvik ešte nebol).
  final double? bestKg;

  /// Posledná zapísaná séria.
  final LoggedSet? last;

  /// Zo série najnovšie hore (tak ich drží WorkoutLogState).
  static Map<String, ExerciseHistory> fromSets(List<LoggedSet> sets) {
    final out = <String, ExerciseHistory>{};
    for (final s in sets) {
      if (s.state == SyncState.rejected) continue;
      final prev = out[s.exerciseId];
      final best = prev?.bestKg;
      out[s.exerciseId] = ExerciseHistory(
        bestKg: best == null || s.weightKg > best ? s.weightKg : best,
        last: prev?.last ?? s,
      );
    }
    return out;
  }
}

/// Obľúbené cviky. Držia sa v telefóne.
class FavoriteExercises extends Notifier<Set<String>> {
  static const _key = 'favorite_exercises';

  @override
  Set<String> build() {
    _load();
    return const {};
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_key);
    if (saved != null && ref.mounted) state = {...state, ...saved};
  }

  Future<void> toggle(String exerciseId) async {
    final next = {...state};
    if (!next.remove(exerciseId)) next.add(exerciseId);
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, next.toList());
  }
}

final favoriteExercisesProvider =
    NotifierProvider<FavoriteExercises, Set<String>>(FavoriteExercises.new);

/// „1:05“, „12:40“, „1:02:07“.
String formatClock(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

/// Váha bez zbytočnej desatinnej čiarky: 100, 102,5.
String formatKg(double kg) => kg == kg.roundToDouble()
    ? kg.toInt().toString()
    : kg.toString().replaceAll('.', ',');
