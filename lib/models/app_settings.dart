import 'package:isar/isar.dart';

part 'app_settings.g.dart';

/// アプリ全体の設定（単一レコード, id=0 固定）。
@collection
class AppSettings {
  Id id = 0;

  /// 重量表示の単位。true なら lb、false なら kg。
  bool useLbs = false;

  /// 曜日ごとの週間スケジュール（index 0=月曜 .. 6=日曜）。
  /// 値: 0 = 未設定 / -1 = 休養日（Day Streak を継続させる） / >0 = Routine の id。
  List<int> weeklySchedule = [0, 0, 0, 0, 0, 0, 0];
}
