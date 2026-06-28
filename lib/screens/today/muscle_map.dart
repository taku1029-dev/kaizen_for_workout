import 'package:flutter/material.dart';

import '../../models/muscle_group.dart';

/// 今日トレーニングした部位を、人体（前面 / 背面）の色で視覚化するウィジェット。
/// [intensities] は MuscleGroup → 0..1 の刺激強度（その日の最大ボリュームを 1 とする相対値）。
class MuscleMapView extends StatelessWidget {
  const MuscleMapView({super.key, required this.intensities});

  final Map<MuscleGroup, double> intensities;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final untrained = dark ? const Color(0xFF3A3A3A) : const Color(0xFFE4E4E4);
    final base = dark ? const Color(0xFF2C2C2C) : const Color(0xFFEFEFEF);
    final outline = dark ? const Color(0xFF555555) : const Color(0xFFCFCFCF);
    final labelColor = scheme.onSurfaceVariant;

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.7,
          child: Row(
            children: [
              Expanded(
                child: _Figure(
                  label: 'Front',
                  isFront: true,
                  intensities: intensities,
                  untrained: untrained,
                  base: base,
                  outline: outline,
                  labelColor: labelColor,
                ),
              ),
              Expanded(
                child: _Figure(
                  label: 'Back',
                  isFront: false,
                  intensities: intensities,
                  untrained: untrained,
                  base: base,
                  outline: outline,
                  labelColor: labelColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _Legend(labelColor: labelColor, untrained: untrained),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.isFront,
    required this.intensities,
    required this.untrained,
    required this.base,
    required this.outline,
    required this.labelColor,
  });

  final String label;
  final bool isFront;
  final Map<MuscleGroup, double> intensities;
  final Color untrained;
  final Color base;
  final Color outline;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: CustomPaint(
            size: Size.infinite,
            painter: _MuscleMapPainter(
              isFront: isFront,
              intensities: intensities,
              untrained: untrained,
              base: base,
              outline: outline,
            ),
          ),
        ),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: labelColor, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.labelColor, required this.untrained});
  final Color labelColor;
  final Color untrained;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Low', style: TextStyle(fontSize: 10, color: labelColor)),
        const SizedBox(width: 6),
        Container(
          width: 80,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: const LinearGradient(
              colors: [Color(0xFFFFCC80), Color(0xFFD32F2F)],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('High', style: TextStyle(fontSize: 10, color: labelColor)),
        const SizedBox(width: 14),
        Container(
          width: 12,
          height: 8,
          decoration: BoxDecoration(
            color: untrained,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text('Rest', style: TextStyle(fontSize: 10, color: labelColor)),
      ],
    );
  }
}

/// 正規化座標 (0..1) で定義したひとつの筋部位の描画領域。
class _Region {
  const _Region(this.group, this.rect, {this.oval = true});
  final MuscleGroup group;
  final Rect rect;
  final bool oval;
}

class _MuscleMapPainter extends CustomPainter {
  _MuscleMapPainter({
    required this.isFront,
    required this.intensities,
    required this.untrained,
    required this.base,
    required this.outline,
  });

  final bool isFront;
  final Map<MuscleGroup, double> intensities;
  final Color untrained;
  final Color base;
  final Color outline;

  // ─── 正規化レイアウト（0..1） ────────────────────────────────
  static const _head = Rect.fromLTRB(0.43, 0.02, 0.57, 0.15);
  static const _baseShapes = [
    // shoulders bridge
    Rect.fromLTRB(0.22, 0.17, 0.78, 0.25),
    // torso
    Rect.fromLTRB(0.35, 0.17, 0.65, 0.53),
    // arms
    Rect.fromLTRB(0.16, 0.19, 0.30, 0.52),
    Rect.fromLTRB(0.70, 0.19, 0.84, 0.52),
    // legs
    Rect.fromLTRB(0.36, 0.52, 0.49, 0.96),
    Rect.fromLTRB(0.51, 0.52, 0.64, 0.96),
  ];

  static const _front = [
    _Region(MuscleGroup.shouldersFront, Rect.fromLTRB(0.27, 0.17, 0.37, 0.25)),
    _Region(MuscleGroup.shouldersFront, Rect.fromLTRB(0.63, 0.17, 0.73, 0.25)),
    _Region(MuscleGroup.shouldersSide, Rect.fromLTRB(0.17, 0.18, 0.27, 0.27)),
    _Region(MuscleGroup.shouldersSide, Rect.fromLTRB(0.73, 0.18, 0.83, 0.27)),
    _Region(MuscleGroup.chest, Rect.fromLTRB(0.37, 0.25, 0.50, 0.34), oval: false),
    _Region(MuscleGroup.chest, Rect.fromLTRB(0.50, 0.25, 0.63, 0.34), oval: false),
    _Region(MuscleGroup.biceps, Rect.fromLTRB(0.18, 0.28, 0.29, 0.39)),
    _Region(MuscleGroup.biceps, Rect.fromLTRB(0.71, 0.28, 0.82, 0.39)),
    _Region(MuscleGroup.forearms, Rect.fromLTRB(0.17, 0.40, 0.28, 0.51)),
    _Region(MuscleGroup.forearms, Rect.fromLTRB(0.72, 0.40, 0.83, 0.51)),
    _Region(MuscleGroup.core, Rect.fromLTRB(0.42, 0.35, 0.58, 0.51), oval: false),
    _Region(MuscleGroup.quads, Rect.fromLTRB(0.37, 0.55, 0.48, 0.76), oval: false),
    _Region(MuscleGroup.quads, Rect.fromLTRB(0.52, 0.55, 0.63, 0.76), oval: false),
  ];

  static const _back = [
    _Region(MuscleGroup.shouldersRear, Rect.fromLTRB(0.27, 0.17, 0.37, 0.25)),
    _Region(MuscleGroup.shouldersRear, Rect.fromLTRB(0.63, 0.17, 0.73, 0.25)),
    _Region(MuscleGroup.shouldersSide, Rect.fromLTRB(0.17, 0.18, 0.27, 0.27)),
    _Region(MuscleGroup.shouldersSide, Rect.fromLTRB(0.73, 0.18, 0.83, 0.27)),
    _Region(MuscleGroup.back, Rect.fromLTRB(0.37, 0.25, 0.63, 0.46), oval: false),
    _Region(MuscleGroup.triceps, Rect.fromLTRB(0.18, 0.28, 0.29, 0.39)),
    _Region(MuscleGroup.triceps, Rect.fromLTRB(0.71, 0.28, 0.82, 0.39)),
    _Region(MuscleGroup.forearms, Rect.fromLTRB(0.17, 0.40, 0.28, 0.51)),
    _Region(MuscleGroup.forearms, Rect.fromLTRB(0.72, 0.40, 0.83, 0.51)),
    _Region(MuscleGroup.glutes, Rect.fromLTRB(0.37, 0.52, 0.50, 0.61), oval: false),
    _Region(MuscleGroup.glutes, Rect.fromLTRB(0.50, 0.52, 0.63, 0.61), oval: false),
    _Region(MuscleGroup.hamstrings, Rect.fromLTRB(0.37, 0.62, 0.48, 0.79), oval: false),
    _Region(MuscleGroup.hamstrings, Rect.fromLTRB(0.52, 0.62, 0.63, 0.79), oval: false),
    _Region(MuscleGroup.calves, Rect.fromLTRB(0.37, 0.81, 0.48, 0.95)),
    _Region(MuscleGroup.calves, Rect.fromLTRB(0.52, 0.81, 0.63, 0.95)),
  ];

  Rect _scale(Rect r, Size s) => Rect.fromLTRB(
        r.left * s.width,
        r.top * s.height,
        r.right * s.width,
        r.bottom * s.height,
      );

  Color _colorFor(MuscleGroup g) {
    final v = (intensities[g] ?? 0).clamp(0.0, 1.0);
    if (v <= 0) return untrained;
    return Color.lerp(const Color(0xFFFFCC80), const Color(0xFFD32F2F), v)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()..color = base;
    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = outline;

    // 1) ベースシルエット
    canvas.drawOval(_scale(_head, size), basePaint);
    for (final r in _baseShapes) {
      final rect = _scale(r, size);
      final rr = RRect.fromRectAndRadius(rect, const Radius.circular(8));
      canvas.drawRRect(rr, basePaint);
    }

    // 2) 筋部位（刺激強度で着色）
    final regions = isFront ? _front : _back;
    for (final region in regions) {
      final rect = _scale(region.rect, size);
      final paint = Paint()..color = _colorFor(region.group);
      if (region.oval) {
        canvas.drawOval(rect, paint);
        canvas.drawOval(rect, outlinePaint);
      } else {
        final rr = RRect.fromRectAndRadius(
            rect, Radius.circular(0.025 * size.width));
        canvas.drawRRect(rr, paint);
        canvas.drawRRect(rr, outlinePaint);
      }
    }
  }

  @override
  bool shouldRepaint(_MuscleMapPainter old) =>
      old.isFront != isFront ||
      old.untrained != untrained ||
      old.base != base ||
      !_mapEquals(old.intensities, intensities);

  static bool _mapEquals(Map<MuscleGroup, double> a, Map<MuscleGroup, double> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }
}
