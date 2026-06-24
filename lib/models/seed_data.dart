import 'exercise.dart';
import 'muscle_group.dart';

abstract final class SeedData {
  static List<Exercise> get exercises {
    final items = <(String, MuscleGroup)>[
      // Forearms
      ('Wrist Curls',               MuscleGroup.forearms),
      ('Reverse Wrist Curls',       MuscleGroup.forearms),
      ('Hammer Curls',              MuscleGroup.forearms),
      // Arms
      ('Bicep Curls',               MuscleGroup.arms),
      ('Cable Overhead Extensions', MuscleGroup.arms),
      // Chest
      ('Bench Press',               MuscleGroup.chest),
      ('Incline Dumbbell Press',    MuscleGroup.chest),
      ('Cable Flyes',               MuscleGroup.chest),
      // Back
      ('Pull-Ups',                  MuscleGroup.back),
      ('Barbell Rows',              MuscleGroup.back),
      ('Lat Pulldowns',             MuscleGroup.back),
      // Shoulders
      ('Overhead Press',            MuscleGroup.shoulders),
      ('Lateral Raises',            MuscleGroup.shoulders),
      // Legs
      ('Squats',                    MuscleGroup.legs),
      ('Romanian Deadlifts',        MuscleGroup.legs),
      ('Leg Press',                 MuscleGroup.legs),
      // Core
      ('Plank',                     MuscleGroup.core),
      ('Cable Crunches',            MuscleGroup.core),
    ];

    return items.map((e) {
      return Exercise()
        ..name = e.$1
        ..muscleGroup = e.$2;
    }).toList();
  }
}
