import 'exercise.dart';
import 'muscle_group.dart';

abstract final class SeedData {
  static List<Exercise> get exercises {
    final items = <(String, MuscleGroup)>[
      // Chest
      ('Bench Press',               MuscleGroup.chest),
      ('Incline Dumbbell Press',    MuscleGroup.chest),
      ('Cable Flyes',               MuscleGroup.chest),
      // Back
      ('Pull-Ups',                  MuscleGroup.back),
      ('Barbell Rows',              MuscleGroup.back),
      ('Lat Pulldowns',             MuscleGroup.back),
      // Shoulders (front / side / rear)
      ('Overhead Press',            MuscleGroup.shouldersFront),
      ('Front Raises',              MuscleGroup.shouldersFront),
      ('Lateral Raises',            MuscleGroup.shouldersSide),
      ('Rear Delt Flyes',           MuscleGroup.shouldersRear),
      // Biceps
      ('Bicep Curls',               MuscleGroup.biceps),
      ('Incline Dumbbell Curls',    MuscleGroup.biceps),
      // Triceps
      ('Cable Overhead Extensions', MuscleGroup.triceps),
      ('Tricep Pushdowns',          MuscleGroup.triceps),
      ('Skull Crushers',            MuscleGroup.triceps),
      // Forearms
      ('Wrist Curls',               MuscleGroup.forearms),
      ('Reverse Wrist Curls',       MuscleGroup.forearms),
      ('Hammer Curls',              MuscleGroup.forearms),
      // Quads
      ('Squats',                    MuscleGroup.quads),
      ('Leg Press',                 MuscleGroup.quads),
      ('Leg Extensions',            MuscleGroup.quads),
      // Hamstrings
      ('Romanian Deadlifts',        MuscleGroup.hamstrings),
      ('Leg Curls',                 MuscleGroup.hamstrings),
      // Glutes
      ('Hip Thrusts',               MuscleGroup.glutes),
      // Calves
      ('Calf Raises',               MuscleGroup.calves),
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
