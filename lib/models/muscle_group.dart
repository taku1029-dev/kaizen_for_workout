import 'package:flutter/material.dart';

/// 部位（主要筋群を細分化）。
/// 注意: @enumerated は ordinal（定義順のインデックス）で永続化されるため、
/// 既存データがある場合に値の並び替え・削除をすると過去レコードの部位がずれる。
enum MuscleGroup {
  chest,
  back,
  shouldersFront,
  shouldersSide,
  shouldersRear,
  biceps,
  triceps,
  forearms,
  quads,
  hamstrings,
  glutes,
  calves,
  core;

  String get label {
    switch (this) {
      case MuscleGroup.chest:          return 'Chest';
      case MuscleGroup.back:           return 'Back';
      case MuscleGroup.shouldersFront: return 'Front Delts';
      case MuscleGroup.shouldersSide:  return 'Side Delts';
      case MuscleGroup.shouldersRear:  return 'Rear Delts';
      case MuscleGroup.biceps:         return 'Biceps';
      case MuscleGroup.triceps:        return 'Triceps';
      case MuscleGroup.forearms:       return 'Forearms';
      case MuscleGroup.quads:          return 'Quads';
      case MuscleGroup.hamstrings:     return 'Hamstrings';
      case MuscleGroup.glutes:         return 'Glutes';
      case MuscleGroup.calves:         return 'Calves';
      case MuscleGroup.core:           return 'Core';
    }
  }

  IconData get icon {
    switch (this) {
      case MuscleGroup.chest:          return Icons.favorite;
      case MuscleGroup.back:           return Icons.straighten;
      case MuscleGroup.shouldersFront: return Icons.sports_gymnastics;
      case MuscleGroup.shouldersSide:  return Icons.open_with;
      case MuscleGroup.shouldersRear:  return Icons.sync;
      case MuscleGroup.biceps:         return Icons.fitness_center;
      case MuscleGroup.triceps:        return Icons.sports_martial_arts;
      case MuscleGroup.forearms:       return Icons.back_hand;
      case MuscleGroup.quads:          return Icons.directions_run;
      case MuscleGroup.hamstrings:     return Icons.directions_walk;
      case MuscleGroup.glutes:         return Icons.chair;
      case MuscleGroup.calves:         return Icons.directions_bike;
      case MuscleGroup.core:           return Icons.circle_outlined;
    }
  }
}
