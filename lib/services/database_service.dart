import 'dart:io';

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/exercise.dart';
import '../models/embedded_set.dart';
import '../models/workout_session.dart';
import '../models/seed_data.dart';

class DatabaseService {
  DatabaseService._();

  static late Isar _db;

  static Isar get db => _db;

  static Future<void> init() async {
    // Linux デスクトップ開発時はプロジェクトルート、iOS は app support dir を使う
    final dirPath = Platform.isLinux
        ? Directory.current.path
        : (await getApplicationSupportDirectory()).path;
    _db = await Isar.open(
      [WorkoutSessionSchema, ExerciseSchema],
      directory: dirPath,
    );
    await _seedIfNeeded();
  }

  static Future<void> _seedIfNeeded() async {
    final count = await _db.exercises.count();
    if (count == 0) {
      await _db.writeTxn(() async {
        await _db.exercises.putAll(SeedData.exercises);
      });
    }
  }

  // MARK: - WorkoutSession

  static Future<WorkoutSession> getOrCreateTodaySession() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    final existing = await _db.workoutSessions
        .filter()
        .dateBetween(start, end)
        .findFirst();

    if (existing != null) return existing;

    final session = WorkoutSession()..date = now;
    await _db.writeTxn(() async {
      await _db.workoutSessions.put(session);
    });
    return session;
  }

  static Future<void> addSet(WorkoutSession session, EmbeddedSet set) async {
    session.sets.add(set);
    await _db.writeTxn(() async {
      await _db.workoutSessions.put(session);
    });
  }

  static Future<void> deleteSet(WorkoutSession session, int index) async {
    session.sets.removeAt(index);
    // Renumber each exercise's sets sequentially after deletion
    final counters = <int, int>{};
    for (final s in session.sets) {
      counters[s.exerciseId] = (counters[s.exerciseId] ?? 0) + 1;
      s.setNumber = counters[s.exerciseId]!;
    }
    await _db.writeTxn(() async {
      await _db.workoutSessions.put(session);
    });
  }

  static Future<void> updateSet(
    WorkoutSession session,
    int index,
    EmbeddedSet updated,
  ) async {
    session.sets[index] = updated;
    await _db.writeTxn(() async {
      await _db.workoutSessions.put(session);
    });
  }

  /// 指定種目の直近セットを返す（前回値引き継ぎ用）
  static Future<EmbeddedSet?> lastSetFor(int exerciseId) async {
    final sessions = await _db.workoutSessions.where().findAll();
    sessions.sort((a, b) => b.date.compareTo(a.date));
    for (final session in sessions) {
      final matches = session.sets.where((s) => s.exerciseId == exerciseId);
      if (matches.isNotEmpty) return matches.last;
    }
    return null;
  }

  static Future<void> deleteSession(WorkoutSession session) async {
    await _db.writeTxn(() async {
      await _db.workoutSessions.delete(session.id);
    });
  }

  // MARK: - Exercise

  static Future<void> saveExercise(Exercise exercise) async {
    await _db.writeTxn(() async {
      await _db.exercises.put(exercise);
    });
  }

  static Future<void> deleteExercise(Exercise exercise) async {
    await _db.writeTxn(() async {
      await _db.exercises.delete(exercise.id);
    });
  }
}
