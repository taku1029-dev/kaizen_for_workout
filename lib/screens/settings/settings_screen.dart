import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../services/database_service.dart';
import '../../utils/units.dart';
import '../routines/routine_list_screen.dart';
import '../routines/weekly_schedule_screen.dart';
import 'exercise_manager_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _loadDemoData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Load demo data?'),
        content: const Text(
          'Adds 8 weeks of sample workouts (Push/Pull/Legs with progressive '
          'overload) so you can preview weekly growth and max-weight charts. '
          'Existing sessions are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Load'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final count = await DatabaseService.loadDemoData();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added $count demo sessions')),
      );
    }
  }

  Future<void> _clearSessions(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all sessions?'),
        content: const Text(
          'Deletes every recorded workout session. Exercises are kept. '
          'This cannot be undone.',
        ),
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
    if (confirmed != true) return;

    await DatabaseService.clearAllSessions();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All sessions cleared')),
      );
    }
  }

  Future<void> _resetExercises(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset exercises?'),
        content: const Text(
          'Replaces the exercise list with the built-in defaults (refined '
          'muscle groups). Custom exercises you added will be removed. '
          'Recorded sessions are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await DatabaseService.resetExercisesToDefaults();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exercises reset to defaults')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(weightUnitProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Units'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Expanded(child: Text('Weight unit')),
                SegmentedButton<WeightUnit>(
                  segments: const [
                    ButtonSegment(value: WeightUnit.kg, label: Text('kg')),
                    ButtonSegment(value: WeightUnit.lb, label: Text('lb')),
                  ],
                  selected: {unit},
                  onSelectionChanged: (s) {
                    final next = s.first;
                    ref.read(weightUnitProvider.notifier).state = next;
                    DatabaseService.setUseLbs(next == WeightUnit.lb);
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          const _SectionHeader('Planning'),
          ListTile(
            leading: const Icon(Icons.list_alt),
            title: const Text('Routines'),
            subtitle: const Text('Reusable workout templates'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RoutineListScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_view_week),
            title: const Text('Weekly Schedule'),
            subtitle: const Text('Assign routines & rest days'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WeeklyScheduleScreen()),
            ),
          ),
          const Divider(),
          const _SectionHeader('Data'),
          ListTile(
            leading: const Icon(Icons.fitness_center),
            title: const Text('Manage Exercises'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ExerciseManagerScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: const Text('Reset exercises to defaults'),
            subtitle: const Text('Apply refined muscle groups'),
            onTap: () => _resetExercises(context),
          ),
          const Divider(),
          const _SectionHeader('Demo'),
          ListTile(
            leading: const Icon(Icons.auto_graph),
            title: const Text('Load demo data'),
            subtitle: const Text('8 weeks of sample workouts'),
            onTap: () => _loadDemoData(context),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep, color: Colors.red),
            title: const Text('Clear all sessions',
                style: TextStyle(color: Colors.red)),
            onTap: () => _clearSessions(context),
          ),
          const Divider(),
          const _SectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Version'),
            trailing: Text('1.0.0'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.grey)),
    );
  }
}
