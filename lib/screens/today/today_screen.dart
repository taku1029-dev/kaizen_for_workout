import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/embedded_set.dart';
import '../../models/muscle_group.dart';
import '../../models/routine.dart';
import '../../models/workout_session.dart';
import '../../providers/app_providers.dart';
import '../../services/database_service.dart';
import '../../utils/units.dart';
import 'add_set_sheet.dart';
import 'muscle_map.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(todaySessionProvider);
    final routines = ref.watch(routinesProvider).valueOrNull ?? const <Routine>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('EEE, MMM d').format(DateTime.now())),
        actions: [
          if (routines.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.playlist_add),
              tooltip: 'Apply routine',
              onPressed: () => _openRoutinePicker(context, routines),
            ),
        ],
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

  void _openRoutinePicker(BuildContext context, List<Routine> routines) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.playlist_add_check),
                  SizedBox(width: 8),
                  Text('Apply a routine', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
            for (final r in routines)
              ListTile(
                title: Text(r.name),
                subtitle: Text('${r.items.length} exercises'),
                trailing: const Icon(Icons.add),
                onTap: () async {
                  Navigator.pop(context);
                  await DatabaseService.applyRoutineToToday(r);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added “${r.name}”')),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  void _openAddSheet(BuildContext context, WorkoutSession session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AddSetSheet(
        session: session,
        lastSetEndedAt: session.sets.isNotEmpty ? session.sets.last.endedAt : null,
      ),
    );
  }
}

// ─── タイムライン本体 ────────────────────────────────────────────

class _TimelineBody extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduled = ref.watch(todayScheduledRoutineProvider);

    if (session.sets.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 96, top: 8, left: 16, right: 16),
        children: [
          if (scheduled != null) _ScheduledRoutineBanner(routine: scheduled),
          const SizedBox(height: 80),
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fitness_center, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No sets recorded yet',
                    style: TextStyle(color: Colors.grey)),
                SizedBox(height: 8),
                Text('Tap + to log your first set',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ],
      );
    }

    final sets = session.sets;
    return ListView(
      padding: const EdgeInsets.only(bottom: 96, top: 8, left: 16, right: 16),
      children: [
        if (scheduled != null) _ScheduledRoutineBanner(routine: scheduled),
        _MuscleMapCard(session: session),
        const SizedBox(height: 8),
        _VolumeBreakdownCard(session: session),
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

// ─── スケジュールされたルーティンのバナー ───────────────────────

class _ScheduledRoutineBanner extends StatelessWidget {
  const _ScheduledRoutineBanner({required this.routine});
  final Routine routine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(Icons.event_available, color: scheme.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Today’s routine',
                      style: TextStyle(
                          fontSize: 12,
                          color: scheme.onPrimaryContainer
                              .withValues(alpha: 0.7))),
                  Text(routine.name,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: scheme.onPrimaryContainer)),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () async {
                await DatabaseService.applyRoutineToToday(routine);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Started “${routine.name}”')),
                  );
                }
              },
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Start'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 筋部位マップカード ─────────────────────────────────────────

class _MuscleMapCard extends StatelessWidget {
  const _MuscleMapCard({required this.session});
  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final byGroup = <MuscleGroup, double>{};
    for (final s in session.sets) {
      byGroup[s.muscleGroup] = (byGroup[s.muscleGroup] ?? 0) + s.volume;
    }
    final maxVol =
        byGroup.values.isEmpty ? 1.0 : byGroup.values.reduce((a, b) => a > b ? a : b);
    final intensities = <MuscleGroup, double>{
      for (final e in byGroup.entries) e.key: maxVol == 0 ? 0 : e.value / maxVol,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Muscles Worked',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            MuscleMapView(intensities: intensities),
          ],
        ),
      ),
    );
  }
}

// ─── 合計ボリュームヘッダー ─────────────────────────────────────

/// 合計ボリューム + 部位別ブレイクダウン（多い順、ミニバー付き）
class _VolumeBreakdownCard extends ConsumerWidget {
  const _VolumeBreakdownCard({required this.session});
  final WorkoutSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(weightUnitProvider);
    final byGroup = <MuscleGroup, double>{};
    for (final s in session.sets) {
      byGroup[s.muscleGroup] = (byGroup[s.muscleGroup] ?? 0) + s.volume;
    }
    final entries = byGroup.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxVol = entries.isEmpty ? 1.0 : entries.first.value;
    final total = session.totalVolume;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Total Volume', style: TextStyle(fontSize: 16)),
                const Spacer(),
                Text(
                  formatVolume(total, unit),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (entries.isNotEmpty) ...[
              const Divider(height: 20),
              for (final e in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(e.key.icon, size: 15, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 96,
                        child: Text(
                          e.key.label,
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: maxVol == 0 ? 0 : e.value / maxVol,
                            minHeight: 6,
                            backgroundColor:
                                colorScheme.primary.withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 56,
                        child: Text(
                          formatVolume(e.value, unit),
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
            ],
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

class _TimelineSetTile extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(weightUnitProvider);
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
                          '${formatWeight(set.weightKg, unit)} × ${set.reps}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    if (set.note != null && set.note!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.sticky_note_2_outlined,
                              size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              set.note!.trim(),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.grey.shade600,
                                    fontStyle: FontStyle.italic,
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
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
