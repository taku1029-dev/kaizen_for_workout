import 'package:isar/isar.dart';
import 'embedded_set.dart';

part 'workout_session.g.dart';

@collection
class WorkoutSession {
  Id id = Isar.autoIncrement;

  @Index()
  late DateTime date;

  List<EmbeddedSet> sets = [];

  /// ワークアウト単位のメモ（コンディション等）
  String? note;

  double get totalVolume => sets.fold(0.0, (sum, s) => sum + s.volume);
}
