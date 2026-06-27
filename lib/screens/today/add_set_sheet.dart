import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/embedded_set.dart';
import '../../models/exercise.dart';
import '../../models/workout_session.dart';
import '../../providers/app_providers.dart';
import '../../services/database_service.dart';

enum _TimerState { idle, active, done }

class AddSetSheet extends ConsumerStatefulWidget {
  const AddSetSheet({
    super.key,
    required this.session,
    this.editIndex,
    this.editSet,
    this.lastSetEndedAt,
  });

  final WorkoutSession session;
  final int? editIndex;
  final EmbeddedSet? editSet;

  /// 前セットの終了時刻（休憩タイマー表示用）
  final DateTime? lastSetEndedAt;

  bool get isEditing => editIndex != null;

  @override
  ConsumerState<AddSetSheet> createState() => _AddSetSheetState();
}

class _AddSetSheetState extends ConsumerState<AddSetSheet> {
  Exercise? _selectedExercise;
  bool _autoSelectDone = false;
  late int _reps;
  late double _weightKg;
  late final TextEditingController _weightController;

  _TimerState _timerState = _TimerState.idle;
  DateTime? _startedAt;
  DateTime? _endedAt;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _reps = widget.editSet!.reps;
      _weightKg = widget.editSet!.weightKg;
      _weightController =
          TextEditingController(text: widget.editSet!.weightKg.toStringAsFixed(1));
    } else {
      _reps = 10;
      _weightKg = 20.0;
      _weightController = TextEditingController(text: '20.0');
      // 休憩・セットタイマーを毎秒再描画する
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _onExerciseChanged(Exercise? exercise) async {
    setState(() => _selectedExercise = exercise);
    if (exercise == null) return;

    final last = await DatabaseService.lastSetFor(exercise.id);
    if (last != null && mounted) {
      setState(() {
        _reps = last.reps;
        _weightKg = last.weightKg;
        _weightController.text = last.weightKg.toStringAsFixed(1);
      });
    }
  }

  void _onStart() {
    setState(() {
      _startedAt = DateTime.now();
      _timerState = _TimerState.active;
    });
  }

  void _onStop() {
    setState(() {
      _endedAt = DateTime.now();
      _timerState = _TimerState.done;
    });
  }

  Future<void> _save() async {
    try {
      if (widget.isEditing) {
        final updated = EmbeddedSet()
          ..exerciseId = widget.editSet!.exerciseId
          ..exerciseName = widget.editSet!.exerciseName
          ..muscleGroup = widget.editSet!.muscleGroup
          ..setNumber = widget.editSet!.setNumber
          ..reps = _reps
          ..weightKg = _weightKg
          ..startedAt = widget.editSet!.startedAt
          ..endedAt = widget.editSet!.endedAt;
        await DatabaseService.updateSet(widget.session, widget.editIndex!, updated);
      } else {
        final exercise = _selectedExercise;
        if (exercise == null) return;
        final count = widget.session.sets
            .where((s) => s.exerciseId == exercise.id)
            .length;
        final newSet = EmbeddedSet()
          ..exerciseId = exercise.id
          ..exerciseName = exercise.name
          ..muscleGroup = exercise.muscleGroup
          ..setNumber = count + 1
          ..reps = _reps
          ..weightKg = _weightKg
          ..startedAt = _startedAt
          ..endedAt = _endedAt;
        await DatabaseService.addSet(widget.session, newSet);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // 追加モード: exercises ロード後に最初の種目を自動選択
    if (!widget.isEditing && !_autoSelectDone) {
      ref.watch(exercisesProvider).whenData((exercises) {
        if (exercises.isNotEmpty) {
          _autoSelectDone = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedExercise == null) {
              _onExerciseChanged(exercises.first);
            }
          });
        }
      });
    }

    final now = DateTime.now();
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // タイトルバー
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Row(
                children: [
                  Text(
                    widget.isEditing ? 'Edit Set' : 'Add Set',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  // 種目: idle のみドロップダウン、active/done は固定表示
                  if (widget.isEditing)
                    _ExerciseNameTile(name: widget.editSet!.exerciseName)
                  else if (_timerState == _TimerState.idle)
                    _ExercisePicker(
                      selected: _selectedExercise,
                      onChanged: _onExerciseChanged,
                    )
                  else
                    _ExerciseNameTile(name: _selectedExercise?.name ?? ''),

                  const SizedBox(height: 16),

                  _WeightAndRepsRow(
                    weightController: _weightController,
                    reps: _reps,
                    onWeightChanged: (v) => setState(() => _weightKg = v),
                    onRepsChanged: (v) => setState(() => _reps = v),
                  ),

                  // ── タイマーセクション（追加モードのみ） ──────────────
                  if (!widget.isEditing) ...[
                    const SizedBox(height: 20),

                    if (_timerState == _TimerState.idle) ...[
                      // 前セット終了からの休憩表示
                      if (widget.lastSetEndedAt != null)
                        _TimerChip(
                          label: 'Rest',
                          duration: now.difference(widget.lastSetEndedAt!),
                          color: Colors.orange,
                        )
                      else
                        const SizedBox(height: 8),
                    ] else if (_timerState == _TimerState.active) ...[
                      // セット中: 大きなタイマー
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          _fmtTimer(now.difference(_startedAt!)),
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                fontFeatures: const [FontFeature.tabularFigures()],
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ] else ...[
                      // セット終了後: セット時間 + 休憩タイマー
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _TimerChip(
                            label: 'Set',
                            duration: _endedAt!.difference(_startedAt!),
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          _TimerChip(
                            label: 'Rest',
                            duration: now.difference(_endedAt!),
                            color: Colors.orange,
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 20),
                  ] else ...[
                    const SizedBox(height: 24),
                  ],

                  // アクションボタン
                  SizedBox(
                    width: double.infinity,
                    child: _buildActionButton(colorScheme),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(ColorScheme colorScheme) {
    if (widget.isEditing) {
      return FilledButton(
        onPressed: _save,
        child: const Text('Update Set'),
      );
    }

    return switch (_timerState) {
      _TimerState.idle => FilledButton.icon(
          onPressed: _selectedExercise != null ? _onStart : null,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start Set'),
        ),
      _TimerState.active => FilledButton.icon(
          onPressed: _onStop,
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          icon: const Icon(Icons.stop),
          label: const Text('Stop Set'),
        ),
      _TimerState.done => FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.check),
          label: const Text('Save Set'),
        ),
    };
  }
}

String _fmtTimer(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

// ─── サブウィジェット ────────────────────────────────────────────

class _TimerChip extends StatelessWidget {
  const _TimerChip({
    required this.label,
    required this.duration,
    required this.color,
  });

  final String label;
  final Duration duration;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          Text(
            _fmtTimer(duration),
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseNameTile extends StatelessWidget {
  const _ExerciseNameTile({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Exercise',
        border: OutlineInputBorder(),
      ),
      child: Text(name, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}

class _ExercisePicker extends ConsumerWidget {
  const _ExercisePicker({required this.selected, required this.onChanged});
  final Exercise? selected;
  final ValueChanged<Exercise?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercisesAsync = ref.watch(exercisesProvider);
    return exercisesAsync.when(
      data: (exercises) => DropdownButtonFormField<Exercise>(
        decoration: const InputDecoration(
          labelText: 'Exercise',
          border: OutlineInputBorder(),
        ),
        // ignore: deprecated_member_use
        value: selected,
        items: exercises
            .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
            .toList(),
        onChanged: onChanged,
      ),
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
    );
  }
}

class _WeightAndRepsRow extends StatelessWidget {
  const _WeightAndRepsRow({
    required this.weightController,
    required this.reps,
    required this.onWeightChanged,
    required this.onRepsChanged,
  });

  final TextEditingController weightController;
  final int reps;
  final ValueChanged<double> onWeightChanged;
  final ValueChanged<int> onRepsChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Weight (kg)',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) {
              final parsed = double.tryParse(v);
              if (parsed != null) onWeightChanged(parsed);
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reps', style: Theme.of(context).textTheme.bodySmall),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: reps > 1 ? () => onRepsChanged(reps - 1) : null,
                  ),
                  Text(
                    '$reps',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => onRepsChanged(reps + 1),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
