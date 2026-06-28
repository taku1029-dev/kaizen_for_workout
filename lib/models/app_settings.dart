import 'package:isar/isar.dart';

part 'app_settings.g.dart';

/// アプリ全体の設定（単一レコード, id=0 固定）。
@collection
class AppSettings {
  Id id = 0;

  /// 重量表示の単位。true なら lb、false なら kg。
  bool useLbs = false;
}
