import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/embedded_set.dart';
import '../../models/exercise.dart';
import '../../models/workout_session.dart';
import '../../providers/app_providers.dart';
import '../../services/database_service.dart';

class AddSetSheet extends ConsumerStatefulWidget {
  const AddSetSheet({
    super.key,
    required this.session,
    this.editIndex,
    this.editSet,
  });

  final WorkoutSession session;

  /// 非 null のとき編集モード
  final int? editIndex;
  final EmbeddedSet? editSet;

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
  DateTime? _startedAt;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _reps = widget.editSet!.reps;
      _weightKg = widget.editSet!.weightKg;
      _weightController =
          TextEditingController(text: widget.editSet!.weightKg.toStringAsFixed(1));
    } else {
      _startedAt = DateTime.now();
      _reps = 10;
      _weightKg = 20.0;
      _weightController = TextEditingController(text: '20.0');
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _onExerciseChanged(Exercise? exercise) async {
    setState(() => _selectedExercise = exercise);
    if (exercise == null) return;

    // 前回値を取得して重量・レップ数に反映する
    final last = await DatabaseService.lastSetFor(exercise.id);
    if (last != null && mounted) {
      setState(() {
        _reps = last.reps;
        _weightKg = last.weightKg;
        _weightController.text = last.weightKg.toStringAsFixed(1);
      });
    }
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
          ..endedAt = DateTime.now();
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
    // 追加モード: exercises が読み込まれたら最初の種目を自動選択する
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
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 編集モード: 種目名を固定表示 / 追加モード: ドロップダウン
                  if (widget.isEditing)
                    _ExerciseNameTile(name: widget.editSet!.exerciseName)
                  else
                    _ExercisePicker(
                      selected: _selectedExercise,
                      onChanged: _onExerciseChanged,
                    ),

                  const SizedBox(height: 16),
                  _WeightAndRepsRow(
                    weightController: _weightController,
                    reps: _reps,
                    onWeightChanged: (v) => setState(() => _weightKg = v),
                    onRepsChanged: (v) => setState(() => _reps = v),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed:
                          (widget.isEditing || _selectedExercise != null) ? _save : null,
                      child: Text(widget.isEditing ? 'Update Set' : 'Save Set'),
                    ),
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
}

// ─── サブウィジェット ────────────────────────────────────────────

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
