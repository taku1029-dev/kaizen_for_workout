import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/exercise.dart';
import '../../models/muscle_group.dart';
import '../../providers/app_providers.dart';
import '../../services/database_service.dart';

class ExerciseManagerScreen extends ConsumerWidget {
  const ExerciseManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allExercisesAsync = ref.watch(allExercisesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Exercises')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddExercise(context),
        child: const Icon(Icons.add),
      ),
      body: allExercisesAsync.when(
        data: (exercises) {
          final grouped = <MuscleGroup, List<Exercise>>{};
          for (final e in exercises) {
            grouped.putIfAbsent(e.muscleGroup, () => []).add(e);
          }
          return ListView(
            children: [
              for (final group in MuscleGroup.values)
                if (grouped.containsKey(group)) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Row(
                      children: [
                        Icon(group.icon, size: 16),
                        const SizedBox(width: 6),
                        Text(group.label, style: Theme.of(context).textTheme.labelLarge),
                      ],
                    ),
                  ),
                  for (final exercise in grouped[group]!)
                    ListTile(
                      title: Text(
                        exercise.name,
                        style: exercise.isArchived
                            ? const TextStyle(color: Colors.grey)
                            : null,
                      ),
                      trailing: exercise.isArchived
                          ? const Chip(label: Text('Archived'))
                          : null,
                      onLongPress: () => _showOptions(context, exercise),
                    ),
                ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showOptions(BuildContext context, Exercise exercise) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(exercise.isArchived ? Icons.unarchive : Icons.archive),
              title: Text(exercise.isArchived ? 'Unarchive' : 'Archive'),
              onTap: () {
                exercise.isArchived = !exercise.isArchived;
                DatabaseService.saveExercise(exercise);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                DatabaseService.deleteExercise(exercise);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddExercise(BuildContext context) {
    final nameController = TextEditingController();
    MuscleGroup selectedGroup = MuscleGroup.chest;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New Exercise'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Exercise name',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<MuscleGroup>(
                initialValue: selectedGroup,
                decoration: const InputDecoration(
                  labelText: 'Muscle Group',
                  border: OutlineInputBorder(),
                ),
                items: MuscleGroup.values.map((g) {
                  return DropdownMenuItem(value: g, child: Text(g.label));
                }).toList(),
                onChanged: (g) => setState(() => selectedGroup = g!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final exercise = Exercise()
                  ..name = name
                  ..muscleGroup = selectedGroup;
                DatabaseService.saveExercise(exercise);
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
