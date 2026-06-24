import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/muscle_group.dart';
import '../../providers/app_providers.dart';
import 'volume_chart.dart';
import 'weekly_progress_chart.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedMuscleGroupProvider);
    final sessionsAsync = ref.watch(sessionsProvider);
    final exercisesAsync = ref.watch(exercisesProvider);
    final analytics = ref.read(analyticsServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Muscle group picker
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: MuscleGroup.values.map((group) {
                final isSelected = group == selected;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: Icon(group.icon, size: 16),
                    label: Text(group.label),
                    selected: isSelected,
                    onSelected: (_) => ref.read(selectedMuscleGroupProvider.notifier).state = group,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Weekly growth badge
          sessionsAsync.maybeWhen(
            data: (sessions) {
              final rate = analytics.weeklyGrowthRate(sessions, selected);
              return _GrowthBadge(rate: rate);
            },
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),

          // Volume chart
          sessionsAsync.maybeWhen(
            data: (sessions) {
              final history = analytics.weeklyVolumeHistory(sessions, selected);
              return VolumeChart(muscleGroup: selected, history: history);
            },
            orElse: () => const CircularProgressIndicator(),
          ),
          const SizedBox(height: 16),

          // Per-exercise progress
          sessionsAsync.maybeWhen(
            data: (sessions) => exercisesAsync.maybeWhen(
              data: (exercises) {
                final filtered = exercises.where((e) => e.muscleGroup == selected).toList();
                return WeeklyProgressChart(
                  sessions: sessions,
                  exercises: filtered,
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _GrowthBadge extends StatelessWidget {
  const _GrowthBadge({required this.rate});
  final double? rate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Text('Weekly Growth', style: TextStyle(fontSize: 15)),
            const Spacer(),
            if (rate != null) ...[
              Icon(
                rate! >= 0 ? Icons.trending_up : Icons.trending_down,
                color: rate! >= 0 ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 4),
              Text(
                '${rate! >= 0 ? '+' : ''}${rate!.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: rate! >= 0 ? Colors.green : Colors.red,
                ),
              ),
            ] else
              const Text('No data for last week', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
