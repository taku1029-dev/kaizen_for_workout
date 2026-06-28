import 'package:isar/isar.dart';
import 'muscle_group.dart';

part 'embedded_set.g.dart';

/// セット情報を WorkoutSession に埋め込む。
/// exerciseName / muscleGroup を非正規化して保持することで、
/// 種目が後でアーカイブ・リネームされても履歴が変わらない。
@embedded
class EmbeddedSet {
  int exerciseId = 0;
  String exerciseName = '';

  @enumerated
  MuscleGroup muscleGroup = MuscleGroup.chest;

  int setNumber = 1;
  int reps = 10;
  double weightKg = 20.0;
  DateTime? startedAt;
  DateTime? endedAt;

  /// 種目単位のメモ（フォームの気づき等）
  String? note;

  double get volume => weightKg * reps;

  @ignore
  Duration? get activeDuration {
    if (startedAt == null || endedAt == null) return null;
    final d = endedAt!.difference(startedAt!);
    return d.isNegative ? null : d;
  }
}
