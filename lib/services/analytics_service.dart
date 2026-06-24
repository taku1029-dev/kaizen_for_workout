import '../models/muscle_group.dart';
import '../models/workout_session.dart';
import '../models/exercise.dart';

/// Pure Dart クラス。Isar に依存しないためユニットテストが容易。
class AnalyticsService {
  const AnalyticsService();

  // MARK: - Daily Volume

  /// 1日の部位別ボリューム (kg) = Σ(weightKg × reps)
  Map<MuscleGroup, double> dailyVolume(WorkoutSession session) {
    final result = <MuscleGroup, double>{};
    for (final set in session.sets) {
      result[set.muscleGroup] = (result[set.muscleGroup] ?? 0) + set.volume;
    }
    return result;
  }

  // MARK: - Weekly Volume

  Map<MuscleGroup, double> weeklyVolume(
    List<WorkoutSession> sessions,
    DateTime weekOf,
  ) {
    final inWeek = sessions.where((s) => _isSameWeek(s.date, weekOf));
    final result = <MuscleGroup, double>{};
    for (final session in inWeek) {
      for (final entry in dailyVolume(session).entries) {
        result[entry.key] = (result[entry.key] ?? 0) + entry.value;
      }
    }
    return result;
  }

  // MARK: - Weekly Growth Rate

  /// 週次成長率 (%) = (今週 - 先週) / 先週 × 100
  /// 先週ボリュームがゼロなら null
  double? weeklyGrowthRate(
    List<WorkoutSession> sessions,
    MuscleGroup muscleGroup, {
    DateTime? referenceDate,
  }) {
    final today = referenceDate ?? DateTime.now();
    final lastWeek = today.subtract(const Duration(days: 7));

    final thisWeekVol = weeklyVolume(sessions, today)[muscleGroup] ?? 0;
    final lastWeekVol = weeklyVolume(sessions, lastWeek)[muscleGroup] ?? 0;

    if (lastWeekVol == 0) return null;
    return (thisWeekVol - lastWeekVol) / lastWeekVol * 100;
  }

  // MARK: - Volume History (chart data)

  /// 過去 N 週分の週次ボリューム履歴
  List<({DateTime weekStart, double volume})> weeklyVolumeHistory(
    List<WorkoutSession> sessions,
    MuscleGroup muscleGroup, {
    int weeks = 8,
  }) {
    final today = DateTime.now();
    return List.generate(weeks, (i) {
      final weekOf = today.subtract(Duration(days: 7 * (weeks - 1 - i)));
      final weekStart = _startOfWeek(weekOf);
      final volume = weeklyVolume(sessions, weekOf)[muscleGroup] ?? 0;
      return (weekStart: weekStart, volume: volume);
    });
  }

  // MARK: - Max Weight History (progressive overload)

  List<({DateTime date, double maxWeightKg})> maxWeightHistory(
    List<WorkoutSession> sessions,
    Exercise exercise,
  ) {
    final result = <({DateTime date, double maxWeightKg})>[];
    for (final session in sessions) {
      final weights = session.sets
          .where((s) => s.exerciseId == exercise.id)
          .map((s) => s.weightKg);
      if (weights.isEmpty) continue;
      result.add((date: session.date, maxWeightKg: weights.reduce((a, b) => a > b ? a : b)));
    }
    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  // MARK: - Personal Record

  double? personalRecord(List<WorkoutSession> sessions, Exercise exercise) {
    final weights = sessions
        .expand((s) => s.sets)
        .where((s) => s.exerciseId == exercise.id)
        .map((s) => s.weightKg);
    if (weights.isEmpty) return null;
    return weights.reduce((a, b) => a > b ? a : b);
  }

  // MARK: - Helpers

  bool _isSameWeek(DateTime a, DateTime b) {
    final startA = _startOfWeek(a);
    final startB = _startOfWeek(b);
    return startA == startB;
  }

  DateTime _startOfWeek(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday % 7));
  }
}
