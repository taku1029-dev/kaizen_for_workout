import 'package:isar/isar.dart';
import 'routine_item.dart';

part 'routine.g.dart';

/// 再利用可能なワークアウトテンプレート（例: Push Day）。
@collection
class Routine {
  Id id = Isar.autoIncrement;

  late String name;

  List<RoutineItem> items = [];
}
