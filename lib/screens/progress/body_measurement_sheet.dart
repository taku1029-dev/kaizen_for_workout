import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/body_measurement.dart';
import '../../providers/app_providers.dart';
import '../../services/database_service.dart';
import '../../utils/units.dart';

/// 体組成・身体測定の追加/編集シート。
class BodyMeasurementSheet extends ConsumerStatefulWidget {
  const BodyMeasurementSheet({super.key, this.existing});

  final BodyMeasurement? existing;

  bool get isEditing => existing != null;

  @override
  ConsumerState<BodyMeasurementSheet> createState() =>
      _BodyMeasurementSheetState();
}

class _BodyMeasurementSheetState extends ConsumerState<BodyMeasurementSheet> {
  late final WeightUnit _unit;
  late DateTime _date;
  String? _photoPath;

  late final TextEditingController _weight;
  late final TextEditingController _bodyFat;
  late final TextEditingController _chest;
  late final TextEditingController _waist;
  late final TextEditingController _hips;
  late final TextEditingController _thigh;
  late final TextEditingController _arm;
  late final TextEditingController _calf;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _unit = ref.read(weightUnitProvider);
    final m = widget.existing;
    _date = m?.date ?? DateTime.now();
    _photoPath = m?.photoPath;

    String fmt(double? v) => v == null ? '' : v.toString();
    _weight = TextEditingController(
        text: m?.weightKg == null ? '' : _unit.fromKg(m!.weightKg!).toStringAsFixed(1));
    _bodyFat = TextEditingController(text: fmt(m?.bodyFatPercent));
    _chest = TextEditingController(text: fmt(m?.chestCm));
    _waist = TextEditingController(text: fmt(m?.waistCm));
    _hips = TextEditingController(text: fmt(m?.hipsCm));
    _thigh = TextEditingController(text: fmt(m?.thighCm));
    _arm = TextEditingController(text: fmt(m?.armCm));
    _calf = TextEditingController(text: fmt(m?.calfCm));
    _note = TextEditingController(text: m?.note ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _weight, _bodyFat, _chest, _waist, _hips, _thigh, _arm, _calf, _note,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _parse(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 85,
      );
      if (picked == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${dir.path}/progress_photos');
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }
      final dest = '${photosDir.path}/pm_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(picked.path).copy(dest);
      if (mounted) setState(() => _photoPath = dest);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo unavailable: $e')),
        );
      }
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from library'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            if (_photoPath != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove photo',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _photoPath = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final m = widget.existing ?? BodyMeasurement();
    m.date = _date;
    final w = _parse(_weight);
    m.weightKg = w == null ? null : _unit.toKg(w);
    m.bodyFatPercent = _parse(_bodyFat);
    m.chestCm = _parse(_chest);
    m.waistCm = _parse(_waist);
    m.hipsCm = _parse(_hips);
    m.thighCm = _parse(_thigh);
    m.armCm = _parse(_arm);
    m.calfCm = _parse(_calf);
    m.photoPath = _photoPath;
    final note = _note.text.trim();
    m.note = note.isEmpty ? null : note;
    await DatabaseService.saveMeasurement(m);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    widget.isEditing ? 'Edit Measurement' : 'New Measurement',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 日付
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2015),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(DateFormat.yMMMd().format(_date)),
                ),
              ),
              const SizedBox(height: 12),

              // 写真
              _PhotoPicker(photoPath: _photoPath, onTap: _showPhotoOptions),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _numField(_weight, 'Weight (${_unit.label})'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _numField(_bodyFat, 'Body fat (%)')),
                ],
              ),
              const SizedBox(height: 16),
              Text('Measurements (cm)',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _numField(_chest, 'Chest')),
                const SizedBox(width: 12),
                Expanded(child: _numField(_waist, 'Waist')),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _numField(_hips, 'Hips')),
                const SizedBox(width: 12),
                Expanded(child: _numField(_thigh, 'Thigh')),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _numField(_arm, 'Arm')),
                const SizedBox(width: 12),
                Expanded(child: _numField(_calf, 'Calf')),
              ]),
              const SizedBox(height: 16),
              TextField(
                controller: _note,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  border: OutlineInputBorder(),
                ),
                minLines: 1,
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: Text(widget.isEditing ? 'Update' : 'Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numField(TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({required this.photoPath, required this.onTap});
  final String? photoPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoPath != null && File(photoPath!).existsSync();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.4)),
          image: hasPhoto
              ? DecorationImage(
                  image: FileImage(File(photoPath!)), fit: BoxFit.cover)
              : null,
        ),
        child: hasPhoto
            ? null
            : const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_a_photo, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('Add progress photo',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
      ),
    );
  }
}
