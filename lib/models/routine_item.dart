import 'package:isar/isar.dart';
import 'muscle_group.dart';

part 'routine_item.g.dart';

/// ルーティン内の 1 種目。目標セット数・レップ・重量を保持する。
/// EmbeddedSet 同様、種目名・部位を非正規化して保持する。
@embedded
class RoutineItem {
  int exerciseId = 0;
  String exerciseName = '';

  @enumerated
  MuscleGroup muscleGroup = MuscleGroup.chest;

  int targetSets = 3;
  int targetReps = 10;

  /// 目標重量 (kg)。未設定なら適用時に既定値を使う。
  double? targetWeightKg;
}
