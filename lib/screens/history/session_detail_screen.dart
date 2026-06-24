import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/muscle_group.dart';
import '../../models/workout_session.dart';
import '../../providers/app_providers.dart';

class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({super.key, required this.session});
  final WorkoutSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.read(analyticsServiceProvider);
    final volumeByGroup = analytics.dailyVolume(session);

    final grouped = <MuscleGroup, List<dynamic>>{};
    for (final s in session.sets) {
      grouped.putIfAbsent(s.muscleGroup, () => []).add(s);
    }

    return Scaffold(
      appBar: AppBar(title: Text(DateFormat.yMMMd().format(session.date))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Summary card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Summary', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _Row('Total sets', '${session.sets.length}'),
                  _Row('Total volume', '${session.totalVolume.toStringAsFixed(1)} kg'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Volume by group card
          if (volumeByGroup.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Volume by Muscle Group', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final entry in volumeByGroup.entries)
                      _Row(entry.key.label, '${entry.value.toStringAsFixed(1)} kg'),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          // Sets by group
          for (final group in MuscleGroup.values)
            if (grouped.containsKey(group)) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                child: Row(
                  children: [
                    Icon(group.icon, size: 16),
                    const SizedBox(width: 6),
                    Text(group.label, style: Theme.of(context).textTheme.labelLarge),
                  ],
                ),
              ),
              Card(
                child: Column(
                  children: [
                    for (final s in grouped[group]!)
                      ListTile(
                        title: Text(s.exerciseName),
                        subtitle: Text('Set ${s.setNumber}'),
                        trailing: Text(
                          '${s.weightKg.toStringAsFixed(1)} kg × ${s.reps}',
                          style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                        ),
                      ),
                  ],
                ),
              ),
            ],
        ],
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
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
