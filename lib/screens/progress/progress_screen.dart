import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/body_measurement.dart';
import '../../models/muscle_group.dart';
import '../../models/workout_session.dart';
import '../../providers/app_providers.dart';
import '../../services/database_service.dart';
import '../../utils/units.dart';
import 'body_measurement_sheet.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(sessionsProvider);
    final analytics = ref.read(analyticsServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          sessionsAsync.maybeWhen(
            data: (sessions) => _ConsistencyCard(
              sessions: sessions,
              analytics: analytics,
              visibleMonth: _visibleMonth,
              onMonthChanged: (m) => setState(() => _visibleMonth = m),
            ),
            orElse: () => const Card(
              child: SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
          const SizedBox(height: 12),
          sessionsAsync.maybeWhen(
            data: (sessions) =>
                _FrequencyCard(sessions: sessions, analytics: analytics),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          const _BodySection(),
        ],
      ),
    );
  }
}

// ─── Consistency: streak + month calendar ─────────────────────────

class _ConsistencyCard extends StatelessWidget {
  const _ConsistencyCard({
    required this.sessions,
    required this.analytics,
    required this.visibleMonth,
    required this.onMonthChanged,
  });

  final List<WorkoutSession> sessions;
  final dynamic analytics;
  final DateTime visibleMonth;
  final ValueChanged<DateTime> onMonthChanged;

  @override
  Widget build(BuildContext context) {
    final streakDays = analytics.currentStreakDays(sessions) as int;
    final weekStreak = analytics.currentWeekStreak(sessions) as int;
    final thisWeek = analytics.weeklyWorkoutDays(sessions, DateTime.now()) as int;

    // 日 → セット数 のマップ
    final setsByDay = <DateTime, int>{};
    for (final s in sessions) {
      if (s.sets.isEmpty) continue;
      final d = DateTime(s.date.year, s.date.month, s.date.day);
      setsByDay[d] = (setsByDay[d] ?? 0) + s.sets.length;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Consistency',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatBox(value: '$streakDays', label: 'Day streak', icon: Icons.local_fire_department),
                _StatBox(value: '$weekStreak', label: 'Week streak', icon: Icons.calendar_view_week),
                _StatBox(value: '$thisWeek', label: 'This week', icon: Icons.event_available),
              ],
            ),
            const SizedBox(height: 16),
            _MonthHeader(
              month: visibleMonth,
              onPrev: () => onMonthChanged(
                  DateTime(visibleMonth.year, visibleMonth.month - 1)),
              onNext: () {
                final now = DateTime.now();
                final next = DateTime(visibleMonth.year, visibleMonth.month + 1);
                if (next.isAfter(DateTime(now.year, now.month))) return;
                onMonthChanged(next);
              },
            ),
            const SizedBox(height: 8),
            _CalendarGrid(month: visibleMonth, setsByDay: setsByDay),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.value, required this.label, required this.icon});
  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrev,
          visualDensity: VisualDensity.compact,
        ),
        Text(DateFormat.yMMMM().format(month),
            style: Theme.of(context).textTheme.titleSmall),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({required this.month, required this.setsByDay});
  final DateTime month;
  final Map<DateTime, int> setsByDay;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = first.weekday % 7; // Sun=0
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    final cells = <Widget>[];
    for (final w in ['S', 'M', 'T', 'W', 'T', 'F', 'S']) {
      cells.add(Center(
        child: Text(w,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey)),
      ));
    }
    for (var i = 0; i < leadingBlanks; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final sets = setsByDay[date] ?? 0;
      final intensity = sets == 0
          ? 0.0
          : (0.25 + (sets / 30).clamp(0.0, 0.75)); // 0.25〜1.0
      final isToday = date == todayKey;
      cells.add(
        Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: sets > 0 ? primary.withValues(alpha: intensity) : null,
            borderRadius: BorderRadius.circular(8),
            border: isToday ? Border.all(color: primary, width: 1.5) : null,
          ),
          child: Center(
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 12,
                color: sets > 0 && intensity > 0.5 ? Colors.white : null,
                fontWeight: isToday ? FontWeight.bold : null,
              ),
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.1,
      children: cells,
    );
  }
}

// ─── Frequency: per-group weekly stimulation ──────────────────────

class _FrequencyCard extends StatelessWidget {
  const _FrequencyCard({required this.sessions, required this.analytics});
  final List<WorkoutSession> sessions;
  final dynamic analytics;

  @override
  Widget build(BuildContext context) {
    final freq = analytics.weeklyGroupFrequency(sessions, DateTime.now())
        as Map<MuscleGroup, int>;
    final entries = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weekly Frequency',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Days each muscle group was trained this week',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey)),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              const Text('No workouts this week yet',
                  style: TextStyle(color: Colors.grey))
            else
              for (final e in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(e.key.icon,
                          size: 15,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      SizedBox(width: 96, child: Text(e.key.label)),
                      // ドットで日数表示（最大5）
                      Row(
                        children: List.generate(5, (i) {
                          final filled = i < e.value;
                          return Padding(
                            padding: const EdgeInsets.only(right: 3),
                            child: Icon(
                              filled ? Icons.circle : Icons.circle_outlined,
                              size: 10,
                              color: filled
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.withValues(alpha: 0.4),
                            ),
                          );
                        }),
                      ),
                      const Spacer(),
                      Text('${e.value}×',
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

// ─── Body composition ─────────────────────────────────────────────

class _BodySection extends ConsumerWidget {
  const _BodySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final measurementsAsync = ref.watch(measurementsProvider);
    final unit = ref.watch(weightUnitProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Body', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _openSheet(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            measurementsAsync.when(
              data: (list) {
                if (list.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No measurements yet',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  );
                }
                final latest = list.first;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LatestRow(latest: latest, unit: unit),
                    const SizedBox(height: 12),
                    _WeightTrend(measurements: list, unit: unit),
                    const SizedBox(height: 8),
                    for (final m in list.take(8))
                      _MeasurementTile(measurement: m, unit: unit),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }

  void _openSheet(BuildContext context, {BodyMeasurement? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BodyMeasurementSheet(existing: existing),
    );
  }
}

class _LatestRow extends StatelessWidget {
  const _LatestRow({required this.latest, required this.unit});
  final BodyMeasurement latest;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (latest.weightKg != null)
          _Metric(
              label: 'Weight',
              value: formatWeight(latest.weightKg!, unit)),
        if (latest.bodyFatPercent != null)
          _Metric(
              label: 'Body fat',
              value: '${latest.bodyFatPercent!.toStringAsFixed(1)}%'),
        if (latest.waistCm != null)
          _Metric(
              label: 'Waist', value: '${latest.waistCm!.toStringAsFixed(1)} cm'),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _WeightTrend extends StatelessWidget {
  const _WeightTrend({required this.measurements, required this.unit});
  final List<BodyMeasurement> measurements;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    // 体重がある測定のみ、日付昇順
    final withWeight = measurements
        .where((m) => m.weightKg != null)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (withWeight.length < 2) return const SizedBox.shrink();

    final spots = withWeight.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), unit.fromKg(e.value.weightKg!));
    }).toList();
    final color = Theme.of(context).colorScheme.primary;

    return SizedBox(
      height: 120,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                  show: true, color: color.withValues(alpha: 0.12)),
            ),
          ],
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                getTitlesWidget: (v, _) =>
                    Text('${v.toInt()}', style: const TextStyle(fontSize: 9)),
              ),
            ),
            bottomTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}

class _MeasurementTile extends ConsumerWidget {
  const _MeasurementTile({required this.measurement, required this.unit});
  final BodyMeasurement measurement;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = measurement;
    final parts = <String>[
      if (m.weightKg != null) formatWeight(m.weightKg!, unit),
      if (m.bodyFatPercent != null) '${m.bodyFatPercent!.toStringAsFixed(1)}%',
    ];
    final hasPhoto = m.photoPath != null && File(m.photoPath!).existsSync();

    return Dismissible(
      key: ValueKey('bm-${m.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delete measurement?'),
          content: const Text('This cannot be undone.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete')),
          ],
        ),
      ),
      onDismissed: (_) => DatabaseService.deleteMeasurement(m.id),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: hasPhoto
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(m.photoPath!),
                    width: 44, height: 44, fit: BoxFit.cover),
              )
            : const SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.straighten, color: Colors.grey),
              ),
        title: Text(parts.isEmpty ? '—' : parts.join('  ·  ')),
        subtitle: Text(DateFormat.yMMMd().format(m.date)),
        trailing: hasPhoto ? const Icon(Icons.image, size: 16) : null,
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => BodyMeasurementSheet(existing: m),
        ),
      ),
    );
  }
}
