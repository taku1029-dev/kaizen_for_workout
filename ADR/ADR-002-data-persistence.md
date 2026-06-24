# ADR-002: Data Persistence — SwiftData + CloudKit

- **ステータス**: Superseded by ADR-005
- **日付**: 2026-06-23
- **決定者**: taku1029

## コンテキスト

ワークアウトデータをデバイスに永続化し、複数デバイス間（iPhone + iPad）で同期する方法を選定する。ローカルのみ・iCloud 同期・カスタムバックエンドの 3 案を検討した。

## 決定

**SwiftData（ローカル永続化）+ CloudKit（iCloud 同期）** を採用する。

## 理由

- SwiftData は Swift Macro (`@Model`) ベースで CoreData よりも宣言的かつボイラープレートが少ない
- `ModelContainer` に `.cloudKitContainerIdentifier` を指定するだけで iCloud 自動同期が有効になり、追加インフラ不要
- Apple ID で認証されるため、ユーザー側の認証管理コストがゼロ
- オフライン時はローカルに書き込み、オンライン復帰後に自動マージされる

## 却下した代替案

| 案 | 却下理由 |
|----|---------|
| ローカルのみ (SwiftData 単体) | デバイス紛失時にデータ消失。複数デバイス利用不可 |
| Firebase Firestore | Google アカウント依存、Apple エコシステム外、月額コスト発生、プライバシー考慮が必要 |
| カスタム REST バックエンド | サーバー構築・運用・認証・セキュリティ対応が必要で初期コストが過大 |
| Realm | サードパーティ依存。CloudKit 同期に別途実装が必要 |

## 結果

- **ポジティブ**: サーバー不要でインフラコストゼロ。Apple のインフラで高信頼性のバックアップ・同期が実現
- **ネガティブ**: iCloud ストレージ容量の上限（無料 5GB）が存在するが、筋トレデータは軽量なので現実的な制約にならない
- **制約**: CloudKit は Apple エコシステム限定。将来 Android 版が必要になった場合は ADR を更新して代替手段を検討すること
- **将来の拡張**: CloudKit のサーバーサイドダッシュボードから生データを確認可能。Web UI が必要になった場合は CloudKit JS SDK が利用できる
