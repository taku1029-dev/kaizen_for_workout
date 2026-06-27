import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../models/exercise.dart';
import '../models/muscle_group.dart';
import '../models/workout_session.dart';
import '../services/analytics_service.dart';
import '../services/database_service.dart';

// MARK: - Database

final isarProvider = Provider<Isar>((_) => DatabaseService.db);

// MARK: - Sessions (reactive stream)
// where().sortByDateDesc() returns QAfterSortBy which has no watch(),
// so use watchLazy() + asyncMap() to get reactive sorted results.

final sessionsProvider = StreamProvider<List<WorkoutSession>>((ref) {
  final isar = ref.watch(isarProvider);
  return isar.workoutSessions
      .watchLazy(fireImmediately: true)
      .asyncMap((_) => isar.workoutSessions.where().sortByDateDesc().findAll());
});

// MARK: - Today's session (reactive: rebuilds when any session changes in Isar)

final todaySessionProvider = StreamProvider<WorkoutSession>((ref) {
  final isar = ref.watch(isarProvider);
  return isar.workoutSessions
      .watchLazy(fireImmediately: true)
      .asyncMap((_) => DatabaseService.getOrCreateTodaySession());
});

// MARK: - Exercises (active only, reactive stream)

final exercisesProvider = StreamProvider<List<Exercise>>((ref) {
  final isar = ref.watch(isarProvider);
  return isar.exercises
      .watchLazy(fireImmediately: true)
      .asyncMap((_) => isar.exercises
          .filter()
          .isArchivedEqualTo(false)
          .sortByName()
          .findAll());
});

// MARK: - All exercises including archived (for ExerciseManagerScreen)

final allExercisesProvider = StreamProvider<List<Exercise>>((ref) {
  final isar = ref.watch(isarProvider);
  return isar.exercises
      .watchLazy(fireImmediately: true)
      .asyncMap((_) => isar.exercises.where().sortByName().findAll());
});

// MARK: - Analytics

final analyticsServiceProvider = Provider<AnalyticsService>(
  (_) => const AnalyticsService(),
);

final selectedMuscleGroupProvider = StateProvider<MuscleGroup>(
  (_) => MuscleGroup.chest,
);
