import 'package:flutter/material.dart';

enum MuscleGroup {
  forearms,
  arms,
  chest,
  back,
  shoulders,
  legs,
  core;

  String get label {
    switch (this) {
      case MuscleGroup.forearms:  return 'Forearms';
      case MuscleGroup.arms:      return 'Arms';
      case MuscleGroup.chest:     return 'Chest';
      case MuscleGroup.back:      return 'Back';
      case MuscleGroup.shoulders: return 'Shoulders';
      case MuscleGroup.legs:      return 'Legs';
      case MuscleGroup.core:      return 'Core';
    }
  }

  IconData get icon {
    switch (this) {
      case MuscleGroup.forearms:  return Icons.back_hand;
      case MuscleGroup.arms:      return Icons.fitness_center;
      case MuscleGroup.chest:     return Icons.favorite;
      case MuscleGroup.back:      return Icons.straighten;
      case MuscleGroup.shoulders: return Icons.sports_gymnastics;
      case MuscleGroup.legs:      return Icons.directions_run;
      case MuscleGroup.core:      return Icons.circle_outlined;
    }
  }
}
