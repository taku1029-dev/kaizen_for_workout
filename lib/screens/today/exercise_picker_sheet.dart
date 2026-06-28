import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/exercise.dart';
import '../../models/muscle_group.dart';
import '../../providers/app_providers.dart';
import '../../services/database_service.dart';

/// 検索・お気に入り・最近使った種目を備えた種目セレクター。
/// 選択された Exercise を Navigator.pop で返す。
class ExercisePickerSheet extends ConsumerStatefulWidget {
  const ExercisePickerSheet({super.key});

  @override
  ConsumerState<ExercisePickerSheet> createState() =>
      _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends ConsumerState<ExercisePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(exercisesProvider);
    final recentIds = ref.watch(recentExerciseIdsProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Text('Choose Exercise',
                        style: Theme.of(context).textTheme.titleLarge),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: 'Search exercises…',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: exercisesAsync.when(
                  data: (exercises) =>
                      _buildList(context, exercises, recentIds),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<Exercise> exercises,
    List<int> recentIds,
  ) {
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      final filtered =
          exercises.where((e) => e.name.toLowerCase().contains(q)).toList();
      if (filtered.isEmpty) {
        return const Center(
          child: Text('No matches', style: TextStyle(color: Colors.grey)),
        );
      }
      return ListView(
        children: [for (final e in filtered) _tile(context, e)],
      );
    }

    final byId = {for (final e in exercises) e.id: e};
    final favorites = exercises.where((e) => e.isFavorite).toList();
    final recent = recentIds
        .map((id) => byId[id])
        .whereType<Exercise>()
        .take(6)
        .toList();

    final grouped = <MuscleGroup, List<Exercise>>{};
    for (final e in exercises) {
      grouped.putIfAbsent(e.muscleGroup, () => []).add(e);
    }

    return ListView(
      children: [
        if (favorites.isNotEmpty) ...[
          _header(context, 'Favorites'),
          for (final e in favorites) _tile(context, e),
        ],
        if (recent.isNotEmpty) ...[
          _header(context, 'Recent'),
          for (final e in recent) _tile(context, e),
        ],
        for (final group in MuscleGroup.values)
          if (grouped.containsKey(group)) ...[
            _header(context, group.label),
            for (final e in grouped[group]!) _tile(context, e),
          ],
      ],
    );
  }

  Widget _header(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }

  Widget _tile(BuildContext context, Exercise e) {
    return ListTile(
      dense: true,
      leading: Icon(e.muscleGroup.icon, size: 20),
      title: Text(e.name),
      trailing: IconButton(
        icon: Icon(
          e.isFavorite ? Icons.star : Icons.star_border,
          color: e.isFavorite ? Colors.amber : Colors.grey,
          size: 20,
        ),
        onPressed: () {
          e.isFavorite = !e.isFavorite;
          DatabaseService.saveExercise(e);
        },
      ),
      onTap: () => Navigator.of(context).pop(e),
    );
  }
}
