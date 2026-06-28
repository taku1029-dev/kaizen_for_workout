import 'package:isar/isar.dart';

part 'body_measurement.g.dart';

/// 体組成・身体測定の記録。重量は kg を正規形として保持する。
@collection
class BodyMeasurement {
  Id id = Isar.autoIncrement;

  @Index()
  late DateTime date;

  double? weightKg;
  double? bodyFatPercent;

  // 部位サイズ (cm)
  double? chestCm;
  double? waistCm;
  double? hipsCm;
  double? thighCm;
  double? armCm;
  double? calfCm;

  /// 進捗写真の保存パス（アプリのドキュメントディレクトリ内）
  String? photoPath;

  String? note;
}
