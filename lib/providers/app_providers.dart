import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../models/app_settings.dart';
import '../models/body_measurement.dart';
import '../models/exercise.dart';
import '../models/muscle_group.dart';
import '../models/routine.dart';
import '../models/workout_session.dart';
import '../services/analytics_service.dart';
import '../services/database_service.dart';
import '../utils/units.dart';

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

// MARK: - Weight unit (kg / lb)
// 起動時に DatabaseService がキャッシュした値で初期化し、Settings から更新する。

final weightUnitProvider = StateProvider<WeightUnit>(
  (_) => DatabaseService.cachedUseLbs ? WeightUnit.lb : WeightUnit.kg,
);

// MARK: - Body measurements (reactive stream, newest first)

final measurementsProvider = StreamProvider<List<BodyMeasurement>>((ref) {
  final isar = ref.watch(isarProvider);
  return isar.bodyMeasurements
      .watchLazy(fireImmediately: true)
      .asyncMap((_) => isar.bodyMeasurements.where().sortByDateDesc().findAll());
});

// MARK: - App settings (reactive stream)

final settingsProvider = StreamProvider<AppSettings>((ref) {
  final isar = ref.watch(isarProvider);
  return isar.appSettings
      .watchLazy(fireImmediately: true)
      .asyncMap((_) => DatabaseService.getSettings());
});

/// 休養日に設定された曜日（1=月 .. 7=日, DateTime.weekday 準拠）。
final restWeekdaysProvider = Provider<Set<int>>((ref) {
  final settingsAsync = ref.watch(settingsProvider);
  return settingsAsync.maybeWhen(
    data: (s) {
      final result = <int>{};
      for (var i = 0; i < s.weeklySchedule.length && i < 7; i++) {
        if (s.weeklySchedule[i] == -1) result.add(i + 1); // index0=月→weekday1
      }
      return result;
    },
    orElse: () => const <int>{},
  );
});

// MARK: - Routines (reactive stream)

final routinesProvider = StreamProvider<List<Routine>>((ref) {
  final isar = ref.watch(isarProvider);
  return isar.routines
      .watchLazy(fireImmediately: true)
      .asyncMap((_) => isar.routines.where().sortByName().findAll());
});

/// 今日の曜日にスケジュールされた Routine（無ければ null）。
final todayScheduledRoutineProvider = Provider<Routine?>((ref) {
  final settingsAsync = ref.watch(settingsProvider);
  final routinesAsync = ref.watch(routinesProvider);
  return settingsAsync.maybeWhen(
    data: (s) => routinesAsync.maybeWhen(
      data: (routines) {
        final idx = DateTime.now().weekday - 1; // 0=月 .. 6=日
        if (idx < 0 || idx >= s.weeklySchedule.length) return null;
        final value = s.weeklySchedule[idx];
        if (value <= 0) return null;
        for (final r in routines) {
          if (r.id == value) return r;
        }
        return null;
      },
      orElse: () => null,
    ),
    orElse: () => null,
  );
});

// MARK: - Recently used exercise ids (most recent first, derived from sessions)

final recentExerciseIdsProvider = Provider<List<int>>((ref) {
  final sessionsAsync = ref.watch(sessionsProvider);
  return sessionsAsync.maybeWhen(
    data: (sessions) {
      // sessions は date 降順。出現順に重複排除する。
      final seen = <int>{};
      final ordered = <int>[];
      for (final session in sessions) {
        for (final set in session.sets) {
          if (seen.add(set.exerciseId)) ordered.add(set.exerciseId);
        }
      }
      return ordered;
    },
    orElse: () => const <int>[],
  );
});
