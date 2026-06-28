/// 重量の表示単位。内部表現は常に kg、表示・入力時のみ変換する。
enum WeightUnit {
  kg,
  lb;

  String get label => this == WeightUnit.kg ? 'kg' : 'lb';

  static const double _lbPerKg = 2.2046226218;

  /// kg → 表示単位の数値
  double fromKg(double kg) => this == WeightUnit.kg ? kg : kg * _lbPerKg;

  /// 表示単位の数値 → kg
  double toKg(double value) => this == WeightUnit.kg ? value : value / _lbPerKg;
}

/// 重量を "20.0 kg" / "44.1 lb" 形式に整形する。
String formatWeight(double kg, WeightUnit unit, {int decimals = 1}) {
  return '${unit.fromKg(kg).toStringAsFixed(decimals)} ${unit.label}';
}

/// ボリューム（kg·reps）を表示単位で整形する。重量と同じ係数で線形変換できる。
String formatVolume(double volumeKg, WeightUnit unit, {int decimals = 0}) {
  return '${unit.fromKg(volumeKg).toStringAsFixed(decimals)} ${unit.label}';
}
