# ADR-004: Technology Stack — Flutter + Dart

- **ステータス**: Accepted
- **日付**: 2026-06-23
- **決定者**: taku1029
- **Supersedes**: ADR-001

## コンテキスト

開発環境が macOS ではなく Linux (AMD Ryzen 7) であることが判明した。ADR-001 で採用した SwiftUI は macOS + Xcode が必須のため、Linux 環境ではソースファイルの編集はできてもビルド・実機確認ができない。iOS アプリの開発体験を改善するため、技術スタックの再選定を行った。

## 決定

**Flutter + Dart** を採用する。

## 理由

- Flutter は Linux を公式サポートしており、`flutter run -d linux` でデスクトップアプリとして UI を確認できる
- `flutter test` が Linux 上で実行できるため、ユニット・ウィジェットテストを CI なしでローカル完結できる
- Dart は静的型付けでリファクタリングが安全。`dart analyze` で型チェックが Linux 上で完結する
- iOS ビルド (`flutter build ios`) は macOS + Xcode が必要だが、GitHub Actions の macOS runner で対応できる — これは SwiftUI でも同様の制約であり、Flutter に切り替えることで Linux 側の開発体験が大きく向上する
- 将来 Android 対応が必要になった場合、追加コストが低い

## 却下した代替案

| 案 | 却下理由 |
|----|---------|
| SwiftUI のまま (ADR-001) | Linux では編集のみ可能でビルド・テスト・UI確認がすべてリモートCI依存になり開発体験が悪い |
| React Native + Expo | JS ランタイムのオーバーヘッド。iOS ネイティブ API との統合が Bridge 経由で複雑 |
| Kotlin Multiplatform Mobile | iOS UI は SwiftUI が必要になり Linux 問題が再発する |

## 結果

- **ポジティブ**: Linux 上で UI 確認・テスト・型チェックがすべてローカルで完結する
- **ネガティブ**: iOS ビルドは GitHub Actions (macOS runner) に依存する（SwiftUI と同じ制約）
- **制約**: `flutter build ios` は macOS + Xcode 環境が必要。ローカル iOS Simulator での確認は macOS が必要
- **CI 方針**: GitHub Actions で `runs-on: macos-latest` を使用して iOS ビルド・テストを実行する
