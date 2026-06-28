import 'dart:io';

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_settings.dart';
import '../models/body_measurement.dart';
import '../models/exercise.dart';
import '../models/embedded_set.dart';
import '../models/muscle_group.dart';
import '../models/routine.dart';
import '../models/routine_item.dart';
import '../models/workout_session.dart';
import '../models/seed_data.dart';

class DatabaseService {
  DatabaseService._();

  static late Isar _db;

  static Isar get db => _db;

  /// 起動時に読み込む単位設定のキャッシュ（同期アクセス用）。
  static bool cachedUseLbs = false;

  /// 起動時に読み込む週間スケジュールのキャッシュ（index 0=月 .. 6=日）。
  static List<int> cachedWeeklySchedule = [0, 0, 0, 0, 0, 0, 0];

  static Future<void> init() async {
    // Linux デスクトップ開発時はプロジェクトルート、iOS は app support dir を使う
    final dirPath = Platform.isLinux
        ? Directory.current.path
        : (await getApplicationSupportDirectory()).path;
    _db = await Isar.open(
      [
        WorkoutSessionSchema,
        ExerciseSchema,
        BodyMeasurementSchema,
        AppSettingsSchema,
        RoutineSchema,
      ],
      directory: dirPath,
    );
    await _seedIfNeeded();
    final settings = await getSettings();
    cachedUseLbs = settings.useLbs;
    cachedWeeklySchedule = _normalizeSchedule(settings.weeklySchedule);
  }

  /// スケジュールを必ず長さ 7 に揃える（古いレコード対策）。
  static List<int> _normalizeSchedule(List<int> raw) {
    final out = List<int>.filled(7, 0);
    for (var i = 0; i < 7 && i < raw.length; i++) {
      out[i] = raw[i];
    }
    return out;
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
    session.sets = [...session.sets, set];
    await _db.writeTxn(() async {
      await _db.workoutSessions.put(session);
    });
  }

  static Future<void> deleteSet(WorkoutSession session, int index) async {
    final mutable = List<EmbeddedSet>.from(session.sets)..removeAt(index);
    // Renumber each exercise's sets sequentially after deletion
    final counters = <int, int>{};
    for (final s in mutable) {
      counters[s.exerciseId] = (counters[s.exerciseId] ?? 0) + 1;
      s.setNumber = counters[s.exerciseId]!;
    }
    session.sets = mutable;
    await _db.writeTxn(() async {
      await _db.workoutSessions.put(session);
    });
  }

  static Future<void> updateSet(
    WorkoutSession session,
    int index,
    EmbeddedSet updated,
  ) async {
    final mutable = List<EmbeddedSet>.from(session.sets);
    mutable[index] = updated;
    session.sets = mutable;
    await _db.writeTxn(() async {
      await _db.workoutSessions.put(session);
    });
  }

  static Future<void> saveSessionNote(WorkoutSession session, String? note) async {
    session.note = note;
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

  // MARK: - Demo data

  /// グループ別の基準重量 (kg)。デモデータ生成のベース。
  static const Map<MuscleGroup, double> _demoBaseWeight = {
    MuscleGroup.chest: 40,
    MuscleGroup.back: 45,
    MuscleGroup.shouldersFront: 30,
    MuscleGroup.shouldersSide: 12,
    MuscleGroup.shouldersRear: 10,
    MuscleGroup.biceps: 14,
    MuscleGroup.triceps: 18,
    MuscleGroup.forearms: 12,
    MuscleGroup.quads: 70,
    MuscleGroup.hamstrings: 50,
    MuscleGroup.glutes: 60,
    MuscleGroup.calves: 80,
    MuscleGroup.core: 25,
  };

  /// 過去 8 週分の Push/Pull/Legs スプリットを progressive overload で生成する。
  /// 週次成長率・最大重量推移チャートの動作確認用。
  /// 戻り値: 生成したセッション数。
  static Future<int> loadDemoData() async {
    final exercises = await _db.exercises.where().findAll();
    final byGroup = <MuscleGroup, List<Exercise>>{};
    for (final e in exercises) {
      byGroup.putIfAbsent(e.muscleGroup, () => []).add(e);
    }

    const push = [
      MuscleGroup.chest,
      MuscleGroup.shouldersFront,
      MuscleGroup.shouldersSide,
      MuscleGroup.triceps,
    ];
    const pull = [
      MuscleGroup.back,
      MuscleGroup.shouldersRear,
      MuscleGroup.biceps,
      MuscleGroup.forearms,
    ];
    const legs = [
      MuscleGroup.quads,
      MuscleGroup.hamstrings,
      MuscleGroup.glutes,
      MuscleGroup.calves,
      MuscleGroup.core,
    ];
    const split = [(push, 0), (pull, 2), (legs, 4)];

    final today = DateTime.now();
    const weeks = 8;
    final sessions = <WorkoutSession>[];

    for (var w = 0; w < weeks; w++) {
      final weeksAgo = weeks - 1 - w; // w=0 が最古
      final factor = 1 + 0.025 * w; // 毎週 +2.5%
      for (final (groups, dayOffset) in split) {
        final date = today.subtract(Duration(days: weeksAgo * 7 + (6 - dayOffset)));
        if (date.isAfter(today)) continue;

        final sets = <EmbeddedSet>[];
        final counters = <int, int>{};
        for (final g in groups) {
          final base = _demoBaseWeight[g] ?? 20;
          for (final ex in byGroup[g] ?? const <Exercise>[]) {
            for (var s = 0; s < 3; s++) {
              counters[ex.id] = (counters[ex.id] ?? 0) + 1;
              sets.add(EmbeddedSet()
                ..exerciseId = ex.id
                ..exerciseName = ex.name
                ..muscleGroup = g
                ..setNumber = counters[ex.id]!
                ..reps = 8 + s
                ..weightKg = (base * factor * 2).round() / 2);
            }
          }
        }
        if (sets.isEmpty) continue;
        sessions.add(WorkoutSession()
          ..date = DateTime(date.year, date.month, date.day, 18)
          ..sets = sets);
      }
    }

    // 体組成のデモ: 8週かけて体重・体脂肪・ウエストが緩やかに減少
    final measurements = <BodyMeasurement>[];
    for (var w = 0; w < weeks; w++) {
      final weeksAgo = weeks - 1 - w;
      final date = today.subtract(Duration(days: weeksAgo * 7));
      measurements.add(BodyMeasurement()
        ..date = DateTime(date.year, date.month, date.day, 7)
        ..weightKg = 75.0 - w * 0.3
        ..bodyFatPercent = 18.0 - w * 0.4
        ..waistCm = 84.0 - w * 0.4
        ..armCm = 36.0 + w * 0.1);
    }

    await _db.writeTxn(() async {
      await _db.workoutSessions.putAll(sessions);
      await _db.bodyMeasurements.putAll(measurements);
    });

    // デモ用ルーティン + 週間スケジュール（routine / rest-day streak のプレビュー用）。
    // 既にルーティンがある場合は重複を避けてスキップ。
    if (await _db.routines.count() == 0) {
      RoutineItem item(Exercise e) => RoutineItem()
        ..exerciseId = e.id
        ..exerciseName = e.name
        ..muscleGroup = e.muscleGroup
        ..targetSets = 3
        ..targetReps = 10
        ..targetWeightKg = _demoBaseWeight[e.muscleGroup];
      Routine routine(String name, List<MuscleGroup> groups) => Routine()
        ..name = name
        ..items = [
          for (final g in groups)
            for (final e in byGroup[g] ?? const <Exercise>[]) item(e),
        ];
      final pushR = routine('Push Day', push);
      final pullR = routine('Pull Day', pull);
      final legsR = routine('Leg Day', legs);
      await _db.writeTxn(() async {
        await _db.routines.putAll([pushR, pullR, legsR]);
      });
      // Mon=Push, Wed=Pull, Fri=Legs, 他は休養日。
      final schedule = <int>[pushR.id, -1, pullR.id, -1, legsR.id, -1, -1];
      final settings = await getSettings();
      settings.weeklySchedule = schedule;
      cachedWeeklySchedule = schedule;
      await _db.writeTxn(() async {
        await _db.appSettings.put(settings);
      });
    }

    return sessions.length;
  }

  /// 全ワークアウトセッションを削除する（種目マスタは残す）。
  static Future<void> clearAllSessions() async {
    await _db.writeTxn(() async {
      await _db.workoutSessions.clear();
    });
  }

  /// 種目マスタを初期シードに戻す。
  /// enum 細分化前の古い種目データを持つ既存インストールの修復用。
  static Future<void> resetExercisesToDefaults() async {
    await _db.writeTxn(() async {
      await _db.exercises.clear();
      await _db.exercises.putAll(SeedData.exercises);
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

  // MARK: - App settings

  static Future<AppSettings> getSettings() async {
    final existing = await _db.appSettings.get(0);
    if (existing != null) return existing;
    final fresh = AppSettings()..id = 0;
    await _db.writeTxn(() async {
      await _db.appSettings.put(fresh);
    });
    return fresh;
  }

  static Future<void> setUseLbs(bool useLbs) async {
    final settings = await getSettings();
    settings.useLbs = useLbs;
    cachedUseLbs = useLbs;
    await _db.writeTxn(() async {
      await _db.appSettings.put(settings);
    });
  }

  /// 指定曜日（index 0=月 .. 6=日）のスケジュールを設定する。
  /// value: 0 = 未設定 / -1 = 休養日 / >0 = Routine の id。
  static Future<void> setScheduleForWeekday(int weekdayIndex, int value) async {
    final settings = await getSettings();
    final schedule = _normalizeSchedule(settings.weeklySchedule);
    schedule[weekdayIndex] = value;
    settings.weeklySchedule = schedule;
    cachedWeeklySchedule = schedule;
    await _db.writeTxn(() async {
      await _db.appSettings.put(settings);
    });
  }

  // MARK: - Routines

  static Future<List<Routine>> getRoutines() =>
      _db.routines.where().findAll();

  static Future<Routine?> getRoutine(int id) => _db.routines.get(id);

  static Future<void> saveRoutine(Routine routine) async {
    await _db.writeTxn(() async {
      await _db.routines.put(routine);
    });
  }

  static Future<void> deleteRoutine(int id) async {
    await _db.writeTxn(() async {
      await _db.routines.delete(id);
    });
    // スケジュールから当該ルーティンを外す
    final schedule = List<int>.from(cachedWeeklySchedule);
    var changed = false;
    for (var i = 0; i < schedule.length; i++) {
      if (schedule[i] == id) {
        schedule[i] = 0;
        changed = true;
      }
    }
    if (changed) {
      final settings = await getSettings();
      settings.weeklySchedule = schedule;
      cachedWeeklySchedule = schedule;
      await _db.writeTxn(() async {
        await _db.appSettings.put(settings);
      });
    }
  }

  /// ルーティンの種目を今日のセッションにセットとして展開する。
  /// 目標セット数だけ展開し、setNumber は既存セットの続きから採番する。
  static Future<void> applyRoutineToToday(Routine routine) async {
    final session = await getOrCreateTodaySession();
    final counters = <int, int>{};
    for (final s in session.sets) {
      counters[s.exerciseId] = (counters[s.exerciseId] ?? 0) + 1;
    }
    final newSets = List<EmbeddedSet>.from(session.sets);
    for (final item in routine.items) {
      for (var i = 0; i < item.targetSets; i++) {
        counters[item.exerciseId] = (counters[item.exerciseId] ?? 0) + 1;
        newSets.add(EmbeddedSet()
          ..exerciseId = item.exerciseId
          ..exerciseName = item.exerciseName
          ..muscleGroup = item.muscleGroup
          ..setNumber = counters[item.exerciseId]!
          ..reps = item.targetReps
          ..weightKg = item.targetWeightKg ?? 20.0);
      }
    }
    session.sets = newSets;
    await _db.writeTxn(() async {
      await _db.workoutSessions.put(session);
    });
  }

  // MARK: - Body measurements

  static Future<void> saveMeasurement(BodyMeasurement m) async {
    await _db.writeTxn(() async {
      await _db.bodyMeasurements.put(m);
    });
  }

  static Future<void> deleteMeasurement(int id) async {
    await _db.writeTxn(() async {
      await _db.bodyMeasurements.delete(id);
    });
  }
}
