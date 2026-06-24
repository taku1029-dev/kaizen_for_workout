# ADR-001: Technology Stack — SwiftUI + Swift 6

- **ステータス**: Superseded by ADR-004
- **日付**: 2026-06-23
- **決定者**: taku1029

## コンテキスト

iPhone 向け筋トレ記録アプリを新規構築するにあたり、UI フレームワークと言語を選定する必要があった。選択肢は SwiftUI (純正 iOS)、React Native + Expo、Flutter の 3 つ。

## 決定

**SwiftUI + Swift 6** を採用する。

## 理由

- Apple 純正フレームワークのため、iOS の新機能（HealthKit, Live Activities, Widgets）との統合が最も容易
- SwiftData・CloudKit・Swift Charts など今回必要な周辺ライブラリがすべて Apple 純正で一貫した API を持つ
- Swift 6 の strict concurrency により、ランタイムのデータ競合を型レベルで排除できる
- サードパーティ依存ゼロで長期メンテナンスコストが低い

## 却下した代替案

| 案 | 却下理由 |
|----|---------|
| React Native + Expo | JavaScript ランタイムのオーバーヘッド。SwiftData / CloudKit との統合に Bridge が必要でコードが複雑化する |
| Flutter | Dart エコシステムは Apple API との相性が悪く、iCloud 同期の実装難度が高い |

## 結果

- **ポジティブ**: ネイティブパフォーマンス、Apple エコシステムとの深い統合、将来の HealthKit 連携が容易
- **ネガティブ**: macOS での開発環境（Xcode）が必須。Android 展開不可。
- **制約**: iOS 17+ が最小サポートバージョンとなる（SwiftData, Swift Charts の安定版が iOS 17 から）
