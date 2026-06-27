import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/embedded_set.dart';
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
        data: (session) => _TimelineBody(session: session),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: sessionAsync.maybeWhen(
        data: (session) => FloatingActionButton.extended(
          onPressed: () => _openAddSheet(context, session),
          icon: const Icon(Icons.add),
          label: const Text('Add Set'),
        ),
        orElse: () => null,
      ),
    );
  }

  void _openAddSheet(BuildContext context, WorkoutSession session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AddSetSheet(session: session),
    );
  }
}

// ─── タイムライン本体 ────────────────────────────────────────────

class _TimelineBody extends StatelessWidget {
  const _TimelineBody({required this.session});
  final WorkoutSession session;

  void _openEditSheet(BuildContext context, int index, EmbeddedSet set) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AddSetSheet(
        session: session,
        editIndex: index,
        editSet: set,
      ),
    );
  }

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

    final sets = session.sets;
    return ListView(
      padding: const EdgeInsets.only(bottom: 96, top: 8, left: 16, right: 16),
      children: [
        _TotalVolumeTile(totalVolume: session.totalVolume),
        const SizedBox(height: 8),
        for (var i = 0; i < sets.length; i++) ...[
          if (i > 0) _RestGap(prev: sets[i - 1], next: sets[i]),
          _TimelineSetTile(
            index: i,
            set: sets[i],
            session: session,
            isLast: i == sets.length - 1,
            onEdit: () => _openEditSheet(context, i, sets[i]),
          ),
        ],
      ],
    );
  }
}

// ─── 合計ボリュームヘッダー ─────────────────────────────────────

class _TotalVolumeTile extends StatelessWidget {
  const _TotalVolumeTile({required this.totalVolume});
  final double totalVolume;

  @override
  Widget build(BuildContext context) {
    return Card(
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

// ─── セット間の休憩インジケータ ─────────────────────────────────

class _RestGap extends StatelessWidget {
  const _RestGap({required this.prev, required this.next});
  final EmbeddedSet prev;
  final EmbeddedSet next;

  @override
  Widget build(BuildContext context) {
    Duration? rest;
    if (prev.endedAt != null && next.startedAt != null) {
      final d = next.startedAt!.difference(prev.endedAt!);
      if (!d.isNegative) rest = d;
    }

    return SizedBox(
      height: rest != null ? 32 : 12,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(width: 48 + 4), // time col + gap
          SizedBox(
            width: 12,
            child: Center(
              child: Container(width: 2, color: Colors.grey.withValues(alpha: 0.25)),
            ),
          ),
          const SizedBox(width: 12),
          if (rest != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Rest  ${_formatDuration(rest)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── タイムラインのセットアイテム ───────────────────────────────

class _TimelineSetTile extends StatelessWidget {
  const _TimelineSetTile({
    required this.index,
    required this.set,
    required this.session,
    required this.isLast,
    required this.onEdit,
  });

  final int index;
  final EmbeddedSet set;
  final WorkoutSession session;
  final bool isLast;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final timeLabel = set.startedAt != null
        ? TimeOfDay.fromDateTime(set.startedAt!).format(context)
        : null;
    final duration = set.activeDuration;

    return Dismissible(
      key: ValueKey(
          'tl-${set.exerciseId}-${set.setNumber}-${set.startedAt?.millisecondsSinceEpoch ?? set.weightKg}'),
      background: Container(
        color: colorScheme.primary,
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
      onDismissed: (_) => DatabaseService.deleteSet(session, index),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 時刻ラベル (48px)
            SizedBox(
              width: 48,
              child: Padding(
                padding: const EdgeInsets.only(top: 10, right: 4),
                child: Text(
                  timeLabel ?? '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                        fontSize: 11,
                      ),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
            const SizedBox(width: 4),
            // ドット + 縦ライン (12px)
            Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primary,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(
                          width: 2, color: Colors.grey.withValues(alpha: 0.25)),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // セット情報
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      set.exerciseName,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'Set ${set.setNumber}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey),
                        ),
                        if (duration != null)
                          Text(
                            '  ·  ${_formatDuration(duration)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey),
                          ),
                        const Spacer(),
                        Text(
                          '${set.weightKg.toStringAsFixed(1)} kg × ${set.reps}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── ヘルパー ────────────────────────────────────────────────────

String _formatDuration(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  if (m == 0) return '${s}s';
  if (s == 0) return '${m}m';
  return '${m}m ${s}s';
}
