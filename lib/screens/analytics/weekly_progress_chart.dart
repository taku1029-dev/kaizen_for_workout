import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/exercise.dart';
import '../../models/workout_session.dart';
import '../../providers/app_providers.dart';

class WeeklyProgressChart extends ConsumerStatefulWidget {
  const WeeklyProgressChart({
    super.key,
    required this.sessions,
    required this.exercises,
  });

  final List<WorkoutSession> sessions;
  final List<Exercise> exercises;

  @override
  ConsumerState<WeeklyProgressChart> createState() => _WeeklyProgressChartState();
}

class _WeeklyProgressChartState extends ConsumerState<WeeklyProgressChart> {
  Exercise? _selected;

  @override
  void didUpdateWidget(WeeklyProgressChart old) {
    super.didUpdateWidget(old);
    if (widget.exercises != old.exercises) {
      _selected = widget.exercises.firstOrNull;
    }
  }

  @override
  void initState() {
    super.initState();
    _selected = widget.exercises.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final analytics = ref.read(analyticsServiceProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Max Weight Progress', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 12),
            if (widget.exercises.isEmpty)
              const Text('No exercises for this group.', style: TextStyle(color: Colors.grey))
            else ...[
              DropdownButton<Exercise>(
                value: _selected,
                isExpanded: true,
                items: widget.exercises.map((e) {
                  return DropdownMenuItem(value: e, child: Text(e.name));
                }).toList(),
                onChanged: (e) => setState(() => _selected = e),
              ),
              const SizedBox(height: 12),
              if (_selected != null) ...[
                Builder(builder: (context) {
                  final history = analytics.maxWeightHistory(widget.sessions, _selected!);
                  final pr = analytics.personalRecord(widget.sessions, _selected!);

                  if (history.isEmpty) {
                    return const Text('No data yet.', style: TextStyle(color: Colors.grey));
                  }

                  final spots = history.asMap().entries.map((e) {
                    return FlSpot(e.key.toDouble(), e.value.maxWeightKg);
                  }).toList();

                  return Column(
                    children: [
                      SizedBox(
                        height: 160,
                        child: LineChart(
                          LineChartData(
                            lineBarsData: [
                              LineChartBarData(
                                spots: spots,
                                isCurved: true,
                                color: colorScheme.primary,
                                dotData: const FlDotData(show: true),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: colorScheme.primary.withOpacity(0.12),
                                ),
                              ),
                            ],
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (v, _) {
                                    final idx = v.toInt();
                                    if (idx < 0 || idx >= history.length) return const SizedBox.shrink();
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        DateFormat.Md().format(history[idx].date),
                                        style: const TextStyle(fontSize: 9),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 36,
                                  getTitlesWidget: (v, _) => Text('${v.toInt()}kg', style: const TextStyle(fontSize: 9)),
                                ),
                              ),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: FlGridData(
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.withOpacity(0.2)),
                            ),
                            borderData: FlBorderData(show: false),
                          ),
                        ),
                      ),
                      if (pr != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
                            const SizedBox(width: 6),
                            const Text('Personal Record'),
                            const Spacer(),
                            Text(
                              '${pr.toStringAsFixed(1)} kg',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ],
                  );
                }),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
