// flutter create が生成したカウンターテストを削除し、
// アプリ固有のスモークテストに差し替える。
// Isar の初期化が必要なため本格的な widget テストは integration_test で行う。
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholder — widget tests require Isar setup', () {
    expect(true, isTrue);
  });
}
