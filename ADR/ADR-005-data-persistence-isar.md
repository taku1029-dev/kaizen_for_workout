# ADR-005: Data Persistence — Isar (ローカル) + 将来的な Firebase

- **ステータス**: Accepted
- **日付**: 2026-06-23
- **決定者**: taku1029
- **Supersedes**: ADR-002

## コンテキスト

ADR-002 では SwiftData + CloudKit を採用していたが、Flutter への移行（ADR-004）に伴い、CloudKit は利用不可となった。Flutter に公式の CloudKit ライブラリは存在せず、サードパーティ製パッケージも構造化データの双方向同期には対応していない。Flutter エコシステムで利用可能なローカル DB とクラウド同期の選択肢を再検討した。

## 決定

**Isar でローカル永続化し、クラウド同期は将来 Firebase Firestore で対応する（初期実装ではローカルのみ）**。

## 理由

### Isar を選んだ理由
- Flutter / Dart ファーストな設計で、`@collection` / `@embedded` アノテーションによる宣言的なスキーマ定義ができる
- Embedded objects (`@embedded`) によりセット情報をセッションに埋め込める — JOIN なしでクエリが完結し実装がシンプル
- `watch()` で Dart Stream として変更を監視でき、Riverpod と親和性が高い
- Linux / iOS / Android すべてをサポートし、開発環境での動作確認が可能

### クラウド同期を後回しにした理由
- 単一デバイス（iPhone 1台）での使用開始であり、初期に同期は不要
- 筋トレデータは軽量なためデバイス紛失リスクは低い（Apple Backup で保護される）
- Firebase の初期設定コストより、コア機能完成を優先する

## 却下した代替案

| 案 | 却下理由 |
|----|---------|
| CloudKit (ADR-002) | Flutter に公式サポートなし。構造化データの同期が実装困難 |
| Drift (SQLite) | リレーショナルモデルは今回の組み込みセット構造に対してオーバースペック |
| Hive | スキーマ進化（フィールド追加）のサポートが Isar より弱い |
| Firebase Firestore (初期から) | 設定コスト（Google アカウント、Firebase プロジェクト作成）が初期スコープに対して過大 |

## 結果

- **ポジティブ**: ネットワーク不要、オフライン完全動作、サードパーティ依存なし（Isar は Apache 2.0）
- **ネガティブ**: デバイス間同期なし（iPhone + iPad の併用時は手動エクスポートが必要）
- **将来の拡張**: `lib/services/sync_service.dart` を作成し Firebase Firestore と同期する設計を想定。Isar のコレクション構造は Firestore ドキュメントにほぼそのままマッピングできる
