import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/embedded_set.dart';
import '../../models/muscle_group.dart';
import '../../models/workout_session.dart';
import '../../providers/app_providers.dart';
import '../../services/database_service.dart';
import '../today/add_set_sheet.dart';

class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({super.key, required this.sessionId});
  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsProvider);

    return sessionsAsync.when(
      data: (sessions) {
        final idx = sessions.indexWhere((s) => s.id == sessionId);
        if (idx == -1) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => Navigator.of(context).pop(),
          );
          return const Scaffold(body: SizedBox.shrink());
        }
        return _DetailBody(session: sessions[idx]);
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.session});
  final WorkoutSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.read(analyticsServiceProvider);
    final volumeByGroup = analytics.dailyVolume(session);

    final grouped = <MuscleGroup, List<(int, EmbeddedSet)>>{};
    for (var i = 0; i < session.sets.length; i++) {
      final s = session.sets[i];
      grouped.putIfAbsent(s.muscleGroup, () => []).add((i, s));
    }

    return Scaffold(
      appBar: AppBar(title: Text(DateFormat.yMMMd().format(session.date))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Summary',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _Row('Total sets', '${session.sets.length}'),
                  _Row('Total volume',
                      '${session.totalVolume.toStringAsFixed(1)} kg'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (volumeByGroup.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Volume by Muscle Group',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final entry in volumeByGroup.entries)
                      _Row(entry.key.label,
                          '${entry.value.toStringAsFixed(1)} kg'),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          for (final group in MuscleGroup.values)
            if (grouped.containsKey(group)) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                child: Row(
                  children: [
                    Icon(group.icon, size: 16),
                    const SizedBox(width: 6),
                    Text(group.label,
                        style: Theme.of(context).textTheme.labelLarge),
                  ],
                ),
              ),
              Card(
                child: Column(
                  children: [
                    for (final (idx, s) in grouped[group]!)
                      _SetTile(
                        set: s,
                        onEdit: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (_) => AddSetSheet(
                            session: session,
                            editIndex: idx,
                            editSet: s,
                          ),
                        ),
                        onDelete: () =>
                            DatabaseService.deleteSet(session, idx),
                      ),
                  ],
                ),
              ),
            ],
          const SizedBox(height: 24),
          // Hint text
          Center(
            child: Text(
              'Swipe right to edit · left to delete',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
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
      key: ValueKey('detail-${set.exerciseId}-${set.setNumber}-${set.weightKg}'),
      background: Container(
        color: Theme.of(context).colorScheme.primary,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.edit, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onEdit();
          return false;
        }
        return showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete set?'),
            content: Text('${set.exerciseName}  Set ${set.setNumber}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(),
      child: ListTile(
        title: Text(set.exerciseName),
        subtitle: Text('Set ${set.setNumber}'),
        trailing: Text(
          '${set.weightKg.toStringAsFixed(1)} kg × ${set.reps}',
          style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()]),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
