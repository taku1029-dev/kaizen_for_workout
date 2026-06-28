import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/routine.dart';
import '../../providers/app_providers.dart';
import '../../services/database_service.dart';

/// 曜日ごとに「休養日 / ルーティン / 未設定」を割り当てる週間スケジュール。
/// 休養日は Day Streak を途切れさせない。
class WeeklyScheduleScreen extends ConsumerWidget {
  const WeeklyScheduleScreen({super.key});

  static const _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final routinesAsync = ref.watch(routinesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Schedule')),
      body: settingsAsync.when(
        data: (settings) {
          final routines = routinesAsync.valueOrNull ?? const <Routine>[];
          final schedule = [
            for (var i = 0; i < 7; i++)
              i < settings.weeklySchedule.length ? settings.weeklySchedule[i] : 0
          ];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.local_fire_department, color: Colors.deepOrange),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Days marked “Rest” keep your day streak going even '
                          'without a workout. A scheduled routine appears on '
                          'Today with a one-tap Start.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < 7; i++)
                _dayRow(context, i, schedule[i], routines),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _dayRow(
      BuildContext context, int index, int value, List<Routine> routines) {
    // value が削除済みルーティンを指している場合は未設定扱い。
    final validRoutineIds = routines.map((r) => r.id).toSet();
    final effective =
        (value > 0 && !validRoutineIds.contains(value)) ? 0 : value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(_dayNames[index],
                style: Theme.of(context).textTheme.bodyLarge),
          ),
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: effective,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: 0, child: Text('— None —')),
                const DropdownMenuItem(
                  value: -1,
                  child: Row(
                    children: [
                      Icon(Icons.hotel, size: 16, color: Colors.grey),
                      SizedBox(width: 6),
                      Text('Rest day'),
                    ],
                  ),
                ),
                for (final r in routines)
                  DropdownMenuItem(value: r.id, child: Text(r.name)),
              ],
              onChanged: (v) {
                if (v == null) return;
                DatabaseService.setScheduleForWeekday(index, v);
              },
            ),
          ),
        ],
      ),
    );
  }
}
