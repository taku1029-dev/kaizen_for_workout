import 'package:flutter_test/flutter_test.dart';
import 'package:kaizen_for_workout/models/embedded_set.dart';
import 'package:kaizen_for_workout/models/exercise.dart';
import 'package:kaizen_for_workout/models/muscle_group.dart';
import 'package:kaizen_for_workout/models/workout_session.dart';
import 'package:kaizen_for_workout/services/analytics_service.dart';

void main() {
  const analytics = AnalyticsService();

  // MARK: - Helpers

  Exercise makeExercise({
    int id = 1,
    String name = 'Bicep Curls',
    MuscleGroup group = MuscleGroup.biceps,
  }) {
    return Exercise()
      ..id = id
      ..name = name
      ..muscleGroup = group;
  }

  EmbeddedSet makeSet({
    required Exercise exercise,
    required int reps,
    required double weightKg,
    int setNumber = 1,
  }) {
    return EmbeddedSet()
      ..exerciseId = exercise.id
      ..exerciseName = exercise.name
      ..muscleGroup = exercise.muscleGroup
      ..setNumber = setNumber
      ..reps = reps
      ..weightKg = weightKg;
  }

  WorkoutSession makeSession({
    DateTime? date,
    required List<EmbeddedSet> sets,
  }) {
    return WorkoutSession()
      ..date = date ?? DateTime.now()
      ..sets = sets;
  }

  // MARK: - EmbeddedSet.volume

  group('EmbeddedSet.volume', () {
    test('is weightKg × reps', () {
      final set = EmbeddedSet()
        ..weightKg = 20.0
        ..reps = 10;
      expect(set.volume, equals(200.0));
    });
  });

  // MARK: - dailyVolume

  group('dailyVolume', () {
    test('sums volume per muscle group', () {
      final arms = makeExercise(id: 1, group: MuscleGroup.biceps);
      final forearms = makeExercise(id: 2, name: 'Wrist Curls', group: MuscleGroup.forearms);

      final session = makeSession(sets: [
        makeSet(exercise: arms,     reps: 10, weightKg: 20.0), // 200
        makeSet(exercise: arms,     reps: 8,  weightKg: 22.5), // 180
        makeSet(exercise: forearms, reps: 12, weightKg: 10.0), // 120
      ]);

      final result = analytics.dailyVolume(session);

      expect(result[MuscleGroup.biceps],     closeTo(380.0, 0.001));
      expect(result[MuscleGroup.forearms], closeTo(120.0, 0.001));
      expect(result[MuscleGroup.chest],    isNull);
    });

    test('returns empty map for session with no sets', () {
      final session = makeSession(sets: []);
      expect(analytics.dailyVolume(session), isEmpty);
    });
  });

  // MARK: - weeklyGrowthRate

  group('weeklyGrowthRate', () {
    test('returns positive rate when volume increases', () {
      final arms = makeExercise(group: MuscleGroup.biceps);
      final today = DateTime.now();
      final lastWeek = today.subtract(const Duration(days: 7));

      final sessions = [
        makeSession(date: lastWeek, sets: [makeSet(exercise: arms, reps: 10, weightKg: 10.0)]), // 100
        makeSession(date: today,    sets: [makeSet(exercise: arms, reps: 10, weightKg: 12.0)]), // 120
      ];

      final rate = analytics.weeklyGrowthRate(sessions, MuscleGroup.biceps, referenceDate: today);
      expect(rate, isNotNull);
      expect(rate!, closeTo(20.0, 0.01)); // +20%
    });

    test('returns negative rate when volume decreases', () {
      final arms = makeExercise(group: MuscleGroup.biceps);
      final today = DateTime.now();
      final lastWeek = today.subtract(const Duration(days: 7));

      final sessions = [
        makeSession(date: lastWeek, sets: [makeSet(exercise: arms, reps: 10, weightKg: 20.0)]), // 200
        makeSession(date: today,    sets: [makeSet(exercise: arms, reps: 10, weightKg: 10.0)]), // 100
      ];

      final rate = analytics.weeklyGrowthRate(sessions, MuscleGroup.biceps, referenceDate: today);
      expect(rate, isNotNull);
      expect(rate!, closeTo(-50.0, 0.01)); // -50%
    });

    test('returns null when last week has no data', () {
      final arms = makeExercise(group: MuscleGroup.biceps);
      final sessions = [
        makeSession(sets: [makeSet(exercise: arms, reps: 10, weightKg: 20.0)]),
      ];

      final rate = analytics.weeklyGrowthRate(sessions, MuscleGroup.biceps);
      expect(rate, isNull);
    });
  });

  // MARK: - personalRecord

  group('personalRecord', () {
    test('returns max weight across all sessions', () {
      final exercise = makeExercise();
      final sessions = [
        makeSession(sets: [makeSet(exercise: exercise, reps: 10, weightKg: 20.0)]),
        makeSession(sets: [makeSet(exercise: exercise, reps: 8,  weightKg: 25.0)]),
        makeSession(sets: [makeSet(exercise: exercise, reps: 6,  weightKg: 22.5)]),
      ];

      expect(analytics.personalRecord(sessions, exercise), equals(25.0));
    });

    test('returns null when exercise has no sets', () {
      final exercise = makeExercise(id: 1);
      final other = makeExercise(id: 2, name: 'Other');
      final sessions = [
        makeSession(sets: [makeSet(exercise: other, reps: 10, weightKg: 20.0)]),
      ];

      expect(analytics.personalRecord(sessions, exercise), isNull);
    });
  });

  // MARK: - Frequency / streak

  group('frequency & streak', () {
    test('weeklyGroupFrequency counts distinct days per group', () {
      final biceps = makeExercise(id: 1, group: MuscleGroup.biceps);
      final chest = makeExercise(id: 2, name: 'Bench', group: MuscleGroup.chest);
      final monday = DateTime(2026, 6, 22); // a Monday
      final wednesday = DateTime(2026, 6, 24);

      final sessions = [
        makeSession(date: monday, sets: [
          makeSet(exercise: biceps, reps: 10, weightKg: 10),
          makeSet(exercise: chest, reps: 10, weightKg: 40),
        ]),
        makeSession(date: wednesday, sets: [
          makeSet(exercise: biceps, reps: 10, weightKg: 10),
        ]),
      ];

      final freq = analytics.weeklyGroupFrequency(sessions, monday);
      expect(freq[MuscleGroup.biceps], equals(2)); // Mon + Wed
      expect(freq[MuscleGroup.chest], equals(1)); // Mon only
    });

    test('currentStreakDays counts consecutive days ending today', () {
      final ex = makeExercise();
      final today = DateTime(2026, 6, 25);
      final sessions = [
        makeSession(date: today, sets: [makeSet(exercise: ex, reps: 1, weightKg: 1)]),
        makeSession(
            date: today.subtract(const Duration(days: 1)),
            sets: [makeSet(exercise: ex, reps: 1, weightKg: 1)]),
        makeSession(
            date: today.subtract(const Duration(days: 2)),
            sets: [makeSet(exercise: ex, reps: 1, weightKg: 1)]),
        // gap at day 3
        makeSession(
            date: today.subtract(const Duration(days: 4)),
            sets: [makeSet(exercise: ex, reps: 1, weightKg: 1)]),
      ];

      expect(analytics.currentStreakDays(sessions, today: today), equals(3));
    });

    test('currentStreakDays is 0 when no recent workout', () {
      final ex = makeExercise();
      final today = DateTime(2026, 6, 25);
      final sessions = [
        makeSession(
            date: today.subtract(const Duration(days: 5)),
            sets: [makeSet(exercise: ex, reps: 1, weightKg: 1)]),
      ];
      expect(analytics.currentStreakDays(sessions, today: today), equals(0));
    });
  });

  // MARK: - maxWeightHistory

  group('maxWeightHistory', () {
    test('returns sorted max weight per session', () {
      final exercise = makeExercise();
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final today = DateTime.now();

      final sessions = [
        makeSession(date: yesterday, sets: [
          makeSet(exercise: exercise, reps: 10, weightKg: 20.0, setNumber: 1),
          makeSet(exercise: exercise, reps: 8,  weightKg: 22.5, setNumber: 2),
        ]),
        makeSession(date: today, sets: [
          makeSet(exercise: exercise, reps: 10, weightKg: 25.0),
        ]),
      ];

      final history = analytics.maxWeightHistory(sessions, exercise);
      expect(history.length, equals(2));
      expect(history[0].maxWeightKg, equals(22.5));
      expect(history[1].maxWeightKg, equals(25.0));
      expect(history[0].date.isBefore(history[1].date), isTrue);
    });

    test('skips sessions with no sets for this exercise', () {
      final exercise = makeExercise(id: 1);
      final other = makeExercise(id: 2, name: 'Other');
      final sessions = [
        makeSession(sets: [makeSet(exercise: other, reps: 10, weightKg: 20.0)]),
        makeSession(sets: [makeSet(exercise: exercise, reps: 8, weightKg: 30.0)]),
      ];

      final history = analytics.maxWeightHistory(sessions, exercise);
      expect(history.length, equals(1));
      expect(history[0].maxWeightKg, equals(30.0));
    });
  });
}
