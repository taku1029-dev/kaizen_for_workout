import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/workout_session.dart';
import '../../providers/app_providers.dart';
import '../../services/database_service.dart';
import '../../utils/units.dart';
import 'session_detail_screen.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
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
    final unit = ref.watch(weightUnitProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: sessionsAsync.when(
        data: (sessions) {
          if (sessions.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_month, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No workouts yet', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          // 日 → セッション。1日1セッション前提だが複数あれば最初を採用。
          final byDay = <DateTime, WorkoutSession>{};
          for (final s in sessions) {
            if (s.sets.isEmpty) continue;
            final d = DateTime(s.date.year, s.date.month, s.date.day);
            byDay.putIfAbsent(d, () => s);
          }
          final maxVol = byDay.values.isEmpty
              ? 1.0
              : byDay.values
                  .map((s) => s.totalVolume)
                  .reduce((a, b) => a > b ? a : b);

          // 表示中の月の集計
          final monthSessions = byDay.values.where((s) =>
              s.date.year == _visibleMonth.year &&
              s.date.month == _visibleMonth.month);
          final monthCount = monthSessions.length;
          final monthVolume =
              monthSessions.fold<double>(0, (sum, s) => sum + s.totalVolume);

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _MonthHeader(
                month: _visibleMonth,
                onPrev: () => setState(() => _visibleMonth =
                    DateTime(_visibleMonth.year, _visibleMonth.month - 1)),
                onNext: () {
                  final now = DateTime.now();
                  final next =
                      DateTime(_visibleMonth.year, _visibleMonth.month + 1);
                  if (next.isAfter(DateTime(now.year, now.month))) return;
                  setState(() => _visibleMonth = next);
                },
              ),
              const SizedBox(height: 4),
              Text(
                monthCount == 0
                    ? 'No workouts this month'
                    : '$monthCount workout${monthCount == 1 ? '' : 's'} · ${formatVolume(monthVolume, unit)}',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              _HistoryCalendar(
                month: _visibleMonth,
                byDay: byDay,
                maxVol: maxVol,
                onTapDay: (session) => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        SessionDetailScreen(sessionId: session.id),
                  ),
                ),
                onLongPressDay: (session) => _confirmDelete(context, session),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Tap a highlighted day to view · long-press to delete',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WorkoutSession session) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete session?'),
        content: Text(
            '${DateFormat.yMMMd().format(session.date)} · ${session.sets.length} sets\nThis cannot be undone.'),
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
    );
    if (ok == true) {
      await DatabaseService.deleteSession(session);
    }
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
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev),
        Text(DateFormat.yMMMM().format(month),
            style: Theme.of(context).textTheme.titleMedium),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
      ],
    );
  }
}

class _HistoryCalendar extends StatelessWidget {
  const _HistoryCalendar({
    required this.month,
    required this.byDay,
    required this.maxVol,
    required this.onTapDay,
    required this.onLongPressDay,
  });

  final DateTime month;
  final Map<DateTime, WorkoutSession> byDay;
  final double maxVol;
  final ValueChanged<WorkoutSession> onTapDay;
  final ValueChanged<WorkoutSession> onLongPressDay;

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
      final session = byDay[date];
      final vol = session?.totalVolume ?? 0;
      final intensity =
          vol <= 0 ? 0.0 : (0.3 + 0.7 * (vol / maxVol)).clamp(0.0, 1.0);
      final isToday = date == todayKey;
      final hasWorkout = session != null;

      cells.add(
        GestureDetector(
          onTap: hasWorkout ? () => onTapDay(session) : null,
          onLongPress: hasWorkout ? () => onLongPressDay(session) : null,
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: hasWorkout ? primary.withValues(alpha: intensity) : null,
              borderRadius: BorderRadius.circular(8),
              border:
                  isToday ? Border.all(color: primary, width: 1.5) : null,
            ),
            child: Center(
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 13,
                  color: hasWorkout && intensity > 0.5 ? Colors.white : null,
                  fontWeight:
                      isToday || hasWorkout ? FontWeight.bold : null,
                ),
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
      childAspectRatio: 1.0,
      children: cells,
    );
  }
}
