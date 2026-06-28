import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/exercise.dart';
import '../../models/routine.dart';
import '../../models/routine_item.dart';
import '../../providers/app_providers.dart';
import '../../services/database_service.dart';
import '../../utils/units.dart';
import '../today/exercise_picker_sheet.dart';

/// ルーティンの新規作成 / 編集画面。
class RoutineEditorScreen extends ConsumerStatefulWidget {
  const RoutineEditorScreen({super.key, this.existing});

  /// null なら新規作成。
  final Routine? existing;

  @override
  ConsumerState<RoutineEditorScreen> createState() =>
      _RoutineEditorScreenState();
}

class _RoutineEditorScreenState extends ConsumerState<RoutineEditorScreen> {
  late final TextEditingController _nameController;
  late List<RoutineItem> _items;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _items = [
      for (final i in widget.existing?.items ?? const <RoutineItem>[])
        RoutineItem()
          ..exerciseId = i.exerciseId
          ..exerciseName = i.exerciseName
          ..muscleGroup = i.muscleGroup
          ..targetSets = i.targetSets
          ..targetReps = i.targetReps
          ..targetWeightKg = i.targetWeightKg,
    ];
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(weightUnitProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New Routine' : 'Edit Routine'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Routine name',
              hintText: 'e.g. Push Day',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Exercises',
                  style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              Text('${_items.length}',
                  style: const TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 4),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No exercises yet',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            for (var i = 0; i < _items.length; i++)
              _itemTile(i, _items[i], unit),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addExercise,
            icon: const Icon(Icons.add),
            label: const Text('Add exercise'),
          ),
        ],
      ),
    );
  }

  Widget _itemTile(int index, RoutineItem item, WeightUnit unit) {
    final weightLabel = item.targetWeightKg != null
        ? formatWeight(item.targetWeightKg!, unit)
        : '—';
    return Card(
      child: ListTile(
        leading: Icon(item.muscleGroup.icon),
        title: Text(item.exerciseName),
        subtitle: Text(
            '${item.targetSets} × ${item.targetReps}  ·  $weightLabel'),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => setState(() => _items.removeAt(index)),
        ),
        onTap: () => _editItem(index),
      ),
    );
  }

  Future<void> _addExercise() async {
    final exercise = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const ExercisePickerSheet(),
    );
    if (exercise == null) return;
    final item = RoutineItem()
      ..exerciseId = exercise.id
      ..exerciseName = exercise.name
      ..muscleGroup = exercise.muscleGroup;
    final configured = await _showItemDialog(item);
    if (configured != null) {
      setState(() => _items.add(configured));
    }
  }

  Future<void> _editItem(int index) async {
    final configured = await _showItemDialog(_items[index]);
    if (configured != null) {
      setState(() => _items[index] = configured);
    }
  }

  Future<RoutineItem?> _showItemDialog(RoutineItem item) {
    final unit = ref.read(weightUnitProvider);
    final setsCtrl = TextEditingController(text: '${item.targetSets}');
    final repsCtrl = TextEditingController(text: '${item.targetReps}');
    final weightCtrl = TextEditingController(
      text: item.targetWeightKg != null
          ? unit.fromKg(item.targetWeightKg!).toStringAsFixed(1)
          : '',
    );

    return showDialog<RoutineItem>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.exerciseName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: setsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Sets', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: repsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Reps', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: weightCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Target weight (${unit.label})',
                hintText: 'optional',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final sets = int.tryParse(setsCtrl.text.trim()) ?? item.targetSets;
              final reps = int.tryParse(repsCtrl.text.trim()) ?? item.targetReps;
              final wText = weightCtrl.text.trim();
              final wVal = double.tryParse(wText);
              final result = RoutineItem()
                ..exerciseId = item.exerciseId
                ..exerciseName = item.exerciseName
                ..muscleGroup = item.muscleGroup
                ..targetSets = sets.clamp(1, 20)
                ..targetReps = reps.clamp(1, 100)
                ..targetWeightKg = wVal != null ? unit.toKg(wVal) : null;
              Navigator.pop(context, result);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a routine name')),
      );
      return;
    }
    final routine = Routine()
      ..name = name
      ..items = _items;
    // 既存ルーティンは id を引き継いで上書き、新規は autoIncrement のまま。
    if (widget.existing != null) routine.id = widget.existing!.id;
    await DatabaseService.saveRoutine(routine);
    if (mounted) Navigator.pop(context);
  }
}
