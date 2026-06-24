import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/embedded_set.dart';
import '../../models/exercise.dart';
import '../../models/workout_session.dart';
import '../../providers/app_providers.dart';
import '../../services/database_service.dart';

class AddSetSheet extends ConsumerStatefulWidget {
  const AddSetSheet({super.key, required this.session});
  final WorkoutSession session;

  @override
  ConsumerState<AddSetSheet> createState() => _AddSetSheetState();
}

class _AddSetSheetState extends ConsumerState<AddSetSheet> {
  Exercise? _selectedExercise;
  int _reps = 10;
  double _weightKg = 20.0;
  final _weightController = TextEditingController(text: '20.0');

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(exercisesProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Row(
                children: [
                  Text('Add Set', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(),
            exercisesAsync.when(
              data: (exercises) => _Form(
                exercises: exercises,
                selectedExercise: _selectedExercise,
                reps: _reps,
                weightKg: _weightKg,
                weightController: _weightController,
                onExerciseChanged: (e) => setState(() => _selectedExercise = e),
                onRepsChanged: (v) => setState(() => _reps = v),
                onWeightChanged: (v) => setState(() => _weightKg = v),
                onSave: _save,
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
              error: (e, _) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final exercise = _selectedExercise;
    if (exercise == null) return;

    final currentCount = widget.session.sets
        .where((s) => s.exerciseId == exercise.id)
        .length;

    final set = EmbeddedSet()
      ..exerciseId = exercise.id
      ..exerciseName = exercise.name
      ..muscleGroup = exercise.muscleGroup
      ..setNumber = currentCount + 1
      ..reps = _reps
      ..weightKg = _weightKg;

    DatabaseService.addSet(widget.session, set);
    Navigator.of(context).pop();
  }
}

class _Form extends StatelessWidget {
  const _Form({
    required this.exercises,
    required this.selectedExercise,
    required this.reps,
    required this.weightKg,
    required this.weightController,
    required this.onExerciseChanged,
    required this.onRepsChanged,
    required this.onWeightChanged,
    required this.onSave,
  });

  final List<Exercise> exercises;
  final Exercise? selectedExercise;
  final int reps;
  final double weightKg;
  final TextEditingController weightController;
  final ValueChanged<Exercise?> onExerciseChanged;
  final ValueChanged<int> onRepsChanged;
  final ValueChanged<double> onWeightChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          DropdownButtonFormField<Exercise>(
            decoration: const InputDecoration(labelText: 'Exercise', border: OutlineInputBorder()),
            initialValue: selectedExercise,
            items: exercises.map((e) {
              return DropdownMenuItem(value: e, child: Text(e.name));
            }).toList(),
            onChanged: onExerciseChanged,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Weight (kg)', border: OutlineInputBorder()),
                  onChanged: (v) {
                    final parsed = double.tryParse(v);
                    if (parsed != null) onWeightChanged(parsed);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reps: $reps', style: Theme.of(context).textTheme.bodyMedium),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: reps > 1 ? () => onRepsChanged(reps - 1) : null,
                        ),
                        Text('$reps'),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => onRepsChanged(reps + 1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: selectedExercise != null ? onSave : null,
              child: const Text('Save Set'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
