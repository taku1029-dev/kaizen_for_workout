import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/routine.dart';
import '../../providers/app_providers.dart';
import '../../services/database_service.dart';
import 'routine_editor_screen.dart';
import 'weekly_schedule_screen.dart';

class RoutineListScreen extends ConsumerWidget {
  const RoutineListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routinesAsync = ref.watch(routinesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Routines'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_view_week),
            tooltip: 'Weekly schedule',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const WeeklyScheduleScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RoutineEditorScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: routinesAsync.when(
        data: (routines) {
          if (routines.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.list_alt, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No routines yet', style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('Tap + to create a workout template',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              for (final r in routines) _routineTile(context, r),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _routineTile(BuildContext context, Routine r) {
    final groups = r.items.map((i) => i.muscleGroup.label).toSet().take(4);
    return Dismissible(
      key: ValueKey('routine-${r.id}'),
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
          title: const Text('Delete routine?'),
          content: Text('“${r.name}” will be removed from any schedule.'),
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
      onDismissed: (_) => DatabaseService.deleteRoutine(r.id),
      child: ListTile(
        title: Text(r.name),
        subtitle: Text(
          '${r.items.length} exercises'
          '${groups.isEmpty ? '' : '  ·  ${groups.join(', ')}'}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RoutineEditorScreen(existing: r),
          ),
        ),
      ),
    );
  }
}
