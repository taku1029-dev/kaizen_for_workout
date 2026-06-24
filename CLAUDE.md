# KaizenForWorkout

iPhone ネイティブ筋トレ記録・分析アプリ。Flutter + Dart + Isar で構築。

## 目的

Google Spreadsheet での手動記録を置き換え、部位別ボリューム計算・週次成長率など高度な分析をネイティブ体験で提供する。

## 技術スタック

| レイヤー | 技術 |
|---------|------|
| UI | Flutter (Material 3) |
| 言語 | Dart |
| 状態管理 | flutter_riverpod |
| ローカルDB | Isar (embedded objects) |
| チャート | fl_chart |
| 最小 iOS | 13.0 |
| 開発環境 | Linux (AMD Ryzen 7) |
| iOS ビルド | GitHub Actions (macOS runner) |

## ディレクトリ構造

```
kaizen_for_workout/
├── lib/
│   ├── main.dart                          # エントリポイント + ProviderScope + NavigationBar
│   ├── models/
│   │   ├── muscle_group.dart              # enum MuscleGroup (forearms/arms/etc.)
│   │   ├── exercise.dart                  # @collection: 種目名 + 部位
│   │   ├── embedded_set.dart              # @embedded: 重量・レップ数（セッション内埋め込み）
│   │   ├── workout_session.dart           # @collection: 日付 + List<EmbeddedSet>
│   │   └── seed_data.dart                 # 初回起動時のデフォルト種目
│   ├── services/
│   │   ├── database_service.dart          # Isar 初期化・CRUD・シード
│   │   └── analytics_service.dart         # ボリューム計算・週次成長率・PR（pure Dart）
│   ├── providers/
│   │   └── app_providers.dart             # Riverpod providers (sessions/exercises/analytics)
│   └── screens/
│       ├── today/
│       │   ├── today_screen.dart          # 今日のセット記録
│       │   └── add_set_sheet.dart         # セット追加ボトムシート
│       ├── history/
│       │   ├── history_screen.dart        # 過去ワークアウト一覧
│       │   └── session_detail_screen.dart # 1日の詳細表示
│       ├── analytics/
│       │   ├── analytics_screen.dart      # 分析タブ (筋肉グループ選択)
│       │   ├── volume_chart.dart          # 部位別週次ボリューム棒グラフ
│       │   └── weekly_progress_chart.dart # 最大重量折れ線グラフ + PR表示
│       └── settings/
│           ├── settings_screen.dart
│           └── exercise_manager_screen.dart  # 種目の追加・編集・アーカイブ
└── test/
    └── analytics_service_test.dart        # AnalyticsService ユニットテスト
```

## データモデル概要

Isar の embedded objects を使い、セット情報はセッション内に埋め込む（JOIN 不要）。

```
WorkoutSession (@collection)
  date: DateTime
  sets: List<EmbeddedSet>
    exerciseId: int       ← Exercise の Isar ID
    exerciseName: string  ← 非正規化（履歴保持のため）
    muscleGroup: enum
    setNumber: int
    reps: int
    weightKg: double

Exercise (@collection)
  name: string
  muscleGroup: enum
  isArchived: bool
```

### ボリュームの定義

```
1セットのボリューム = weightKg × reps
1日の部位別ボリューム = Σ(各セットのボリューム) [同一 MuscleGroup]
週次成長率 = (今週合計 − 先週合計) / 先週合計 × 100 [%]
```

## ビルド手順

```bash
# 依存パッケージのインストール
flutter pub get

# Isar の .g.dart ファイルを生成（モデル変更時に再実行）
dart run build_runner build --delete-conflicting-outputs

# Linux デスクトップで起動（開発中の UI 確認）
flutter run -d linux

# テスト
flutter test

# iOS ビルド（macOS 環境または GitHub Actions で実行）
flutter build ios --release
```

### 初回セットアップ

```bash
# Flutter SDK が未インストールの場合
# https://docs.flutter.dev/get-started/install/linux
flutter doctor

# プロジェクト作成（既存ディレクトリに適用する場合）
flutter create . --project-name kaizen_for_workout
# 生成後、lib/ test/ pubspec.yaml を本リポジトリのファイルで上書きする
```

## コーディング規約

- `@riverpod` アノテーション不使用、`Provider` / `StreamProvider` / `StateProvider` を明示的に使う
- ビジネスロジックは Screen に書かず `AnalyticsService` / `DatabaseService` に集約する
- `AnalyticsService` は Isar に依存しない pure Dart クラスにする（テスト容易性のため）
- コメントは「なぜ」が非自明な場合のみ記載する（1行まで）
- `const` コンストラクタを積極的に使用する

## ADR インデックス

| # | タイトル | ステータス |
|---|---------|-----------|
| [ADR-001](ADR/ADR-001-technology-stack.md) | Technology Stack — SwiftUI + Swift 6 | Superseded by ADR-004 |
| [ADR-002](ADR/ADR-002-data-persistence.md) | Data Persistence — SwiftData + CloudKit | Superseded by ADR-005 |
| [ADR-003](ADR/ADR-003-data-migration-strategy.md) | Data Migration Strategy — New Start | Accepted |
| [ADR-004](ADR/ADR-004-technology-stack-flutter.md) | Technology Stack — Flutter + Dart | Accepted |
| [ADR-005](ADR/ADR-005-data-persistence-isar.md) | Data Persistence — Isar ローカル | Accepted |

### ADR テンプレート

新しい ADR を追加するときは以下のテンプレートを使い、上の表にも追記すること。

```markdown
# ADR-NNN: タイトル

- **ステータス**: Proposed / Accepted / Deprecated / Superseded by ADR-XXX
- **日付**: YYYY-MM-DD
- **決定者**: (名前)

## コンテキスト

なぜこの決定が必要になったか。

## 決定

何を選んだか。

## 理由

なぜそれを選んだか。定量的・定性的な根拠を記載する。

## 却下した代替案

| 案 | 却下理由 |
|----|---------|
| ... | ... |

## 結果

この決定がもたらす影響（ポジティブ / ネガティブ）。
```
