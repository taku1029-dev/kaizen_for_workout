import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/embedded_set.dart';
import '../../models/muscle_group.dart';
import '../../models/workout_session.dart';
import '../../providers/app_providers.dart';
import '../../services/database_service.dart';
import 'add_set_sheet.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(todaySessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('EEE, MMM d').format(DateTime.now())),
      ),
      body: sessionAsync.when(
        data: (session) => _SessionBody(session: session),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: sessionAsync.maybeWhen(
        data: (session) => FloatingActionButton.extended(
          onPressed: () => _openSheet(context, session),
          icon: const Icon(Icons.add),
          label: const Text('Add Set'),
        ),
        orElse: () => null,
      ),
    );
  }

  void _openSheet(
    BuildContext context,
    WorkoutSession session, {
    int? editIndex,
    EmbeddedSet? editSet,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AddSetSheet(
        session: session,
        editIndex: editIndex,
        editSet: editSet,
      ),
    );
  }
}

class _SessionBody extends StatelessWidget {
  const _SessionBody({required this.session});
  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    if (session.sets.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No sets recorded yet', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 8),
            Text('Tap + to log your first set', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final grouped = <MuscleGroup, List<(int, EmbeddedSet)>>{};
    for (var i = 0; i < session.sets.length; i++) {
      final s = session.sets[i];
      grouped.putIfAbsent(s.muscleGroup, () => []).add((i, s));
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        _TotalVolumeTile(totalVolume: session.totalVolume),
        for (final group in MuscleGroup.values)
          if (grouped.containsKey(group))
            _MuscleGroupSection(
              group: group,
              indexedSets: grouped[group]!,
              session: session,
            ),
      ],
    );
  }
}

class _TotalVolumeTile extends StatelessWidget {
  const _TotalVolumeTile({required this.totalVolume});
  final double totalVolume;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Text('Total Volume', style: TextStyle(fontSize: 16)),
            const Spacer(),
            Text(
              '${totalVolume.toStringAsFixed(0)} kg',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _MuscleGroupSection extends StatelessWidget {
  const _MuscleGroupSection({
    required this.group,
    required this.indexedSets,
    required this.session,
  });

  final MuscleGroup group;
  final List<(int, EmbeddedSet)> indexedSets;
  final WorkoutSession session;

  void _openEditSheet(BuildContext context, int idx, EmbeddedSet set) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AddSetSheet(
        session: session,
        editIndex: idx,
        editSet: set,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Icon(group.icon, size: 16,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Text(group.label,
                  style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
        ),
        for (final (idx, set) in indexedSets)
          _SetTile(
            set: set,
            onEdit: () => _openEditSheet(context, idx, set),
            onDelete: () => DatabaseService.deleteSet(session, idx),
          ),
      ],
    );
  }
}

class _SetTile extends StatelessWidget {
  const _SetTile({
    required this.set,
    required this.onEdit,
    required this.onDelete,
  });

  final EmbeddedSet set;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('${set.exerciseId}-${set.setNumber}-${set.weightKg}'),
      // 右スワイプ → 編集
      background: Container(
        color: Theme.of(context).colorScheme.primary,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.edit, color: Colors.white),
      ),
      // 左スワイプ → 削除
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onEdit();
          return false; // タイルは消さない
        }
        return true; // 左スワイプは削除確定
      },
      onDismissed: (_) => onDelete(),
      child: ListTile(
        title: Text(set.exerciseName),
        subtitle: Text('Set ${set.setNumber}'),
        trailing: Text(
          '${set.weightKg.toStringAsFixed(1)} kg × ${set.reps}  '
          '(${set.volume.toStringAsFixed(0)})',
          style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()]),
        ),
      ),
    );
  }
}
