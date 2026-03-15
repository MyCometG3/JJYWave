# JJYWave

実験用の macOS アプリです。JJY 長波時刻信号（40/60 kHz）に類する簡易的な振幅変調と、テストトーン（13.333 / 15.000 / 20.000 kHz）の生成を行います。教育・検証目的のプロジェクトです。

注意: 本リポジトリは実験用です。ハードウェア・ソフトウェア環境や地域の規制によっては、使用に法的・技術的な制約が生じる場合があります。音量・聴覚保護や電波に関する法令を遵守してください。

## 特徴
- JJY 40/60 kHz の簡易キャリア生成と AM 変調（簡易時刻コード）
- テストトーン（13.333 / 15.000 / 20.000 kHz）の切替
- 現在時刻の表示
- ローカライズ（英語・日本語）：Strings Catalog（Localizable.xcstrings）で管理
- Xcode プロジェクト（SPM/Makefile 等は未使用）

## 動作環境
- macOS（Apple Silicon / Intel）
- Xcode（最新版推奨）

## ビルド手順
1. リポジトリをクローン
2. `JJYWave.xcodeproj` を Xcode で開く
3. 必要に応じて Signing を設定
4. ターゲット「My Mac」を選択
5. Build（⌘B）→ Run（⌘R）

通常の開発は Xcode を推奨します。`swift build` は利用想定外です。

CI/自動検証では `xcodebuild` を利用できます。

- 通常テスト: `xcodebuild test -project JJYWave.xcodeproj -scheme JJYWaveTests -destination 'platform=macOS'`
- Analyze: `xcodebuild analyze -project JJYWave.xcodeproj -scheme JJYWave -destination 'platform=macOS'`
- warnings-as-errors 検証: `xcodebuild test -project JJYWave.xcodeproj -scheme JJYWaveTests -destination 'platform=macOS' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES`

## 使い方（概要）
- Start/Stop ボタンで生成の開始／停止
- セグメントコントロールで周波数を選択（13.333 / 15.000 / 20.000 / 40.000 / 60.000 kHz）
- 生成中は 40/60 kHz の切替がブロックされます（停止してから切替）

## テスト
- Xcode から ⌘U で `JJYWaveTests` を実行できます（`JJYWaveTests.xctestplan` 同梱）
- カバレッジやシナリオの詳細は `Tests/README.md` を参照
  - フレーム構築（BCD/マーカー/うるう秒/サービスビット）
  - スケジューリング（分境界、ドリフト検出）
  - オーディオ（サンプルレート、バッファ生成、周波数・振幅・デューティ精度）

## 変更履歴
### v1.2
- Swift 6 移行後の検証フローを整理し、CI を `Swift 6 Validation`（Analyze + Tests）に一本化
- CI の Xcode 選択を自動・決定的にし、Node20 非互換アクション依存を解消（`actions/checkout@v6`）
- テストソース運用を `Tests/` に統一し、未使用のテンプレート参照を削除
- Copilot 再レビュー運用（push 後の自動実行を基本）を文書化
- ローカル生成物 `build/` を Git 管理対象外に設定

### v1.1
- 周波数選択（13.333 / 15.000 / 20.000 / 40.000 / 60.000 kHz）の永続化を追加（`UserDefaults`）
- スケジューラとオーディオ生成の安定性を改善（分境界処理・再開整合・再入防止の見直し）
- 関連テストを拡充し、スケジューリング／オーディオ挙動の検証を強化
- 説明テキストビューを編集不可化
- Space キーによる Start/Stop トグル操作に対応
- Xcode 26.3 の Recommended Settings を適用し、マーケティングバージョンを 1.1 に更新

## プロジェクト構成（ルート）
```
JJYWave/
├── .github/                 # 設定・ドキュメント（Copilot 用ガイド）
├── App/                     # アプリ UI 層
├── JJYKit/                  # コアロジック（オーディオ生成・フレーム構築 など）
├── Assets.xcassets/         # アイコン・画像
├── Base.lproj/              # Interface (Main.storyboard など)
├── mul.lproj/               # Strings Catalog 用ロケール（Xcode 管理）
├── JJYWave.xcodeproj/       # Xcode プロジェクト
├── JJYWave.entitlements     # サンドボックス権限
├── Localizable.xcstrings    # Strings Catalog
├── Tests/                   # 単体/統合テストとテスト関連ドキュメント
├── JJYWaveTests.xctestplan  # テストプラン
├── LICENSE.txt
├── README.md
├── .gitignore
└── validate_project.py      # プロジェクト検証用スクリプト
```

## ローカライズ
- 英語（en）/ 日本語（ja）対応
- Xcode の Strings Catalog（`Localizable.xcstrings`、`mul.lproj/`）で管理

## 免責・注意
- 本アプリは正確な時刻配信・同期を目的としていません。
- 聴覚・音量・周辺機器に配慮してください。
- 電波送信・再放射に関する法令・規約を必ず遵守してください。

## 開発体制について
- コーディングは主に Copilot により生成し、人手で最小限の加筆修正・検証を行っています。

## Concurrency Guidelines
- UI 更新（`NSView`/`NSControl` 操作）はメインコンテキストで実行する。
- 非同期コールバックから UI を更新する場合は `Task { @MainActor in ... }` を優先する。
- 共有可変状態は専用の直列キュー（例: `concurrencyQueue` / `syncQueue`）で保護する。
- 同一キュー再入時は追加 `async` を避け、即時実行で順序性を保つ。
- オーディオのタイミングクリティカル経路では、挙動検証前に安易な並列化を行わない。

### Swift 6 Validation (CI)
- Swift 6 移行は完了しており、CI では `xcodebuild analyze` と `xcodebuild test` を継続実行しています。
- ワークフロー: `.github/workflows/swift6-validation.yml`
- 旧 strict-concurrency 専用ゲート（`scripts/strict_concurrency_check.sh` / `.github/workflows/strict-concurrency-check.yml`）は廃止済みです。

## 貢献
- 実験プロジェクトとして Issue / Pull Request を歓迎します。大きな変更は事前に議論してください。

## ライセンス
- MIT License。詳細は [LICENSE.txt](LICENSE.txt) を参照してください。
- Copyright (c) 2025-2026 MyCometG3
