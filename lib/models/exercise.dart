import 'package:isar/isar.dart';
import 'muscle_group.dart';

part 'exercise.g.dart';

@collection
class Exercise {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  late String name;

  @enumerated
  late MuscleGroup muscleGroup;

  bool isArchived = false;
  bool isFavorite = false;
}
