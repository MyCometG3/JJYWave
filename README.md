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

コマンドラインツール（swift build / xcodebuild）は利用想定外です。Xcode からビルドしてください。

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
├── Tests/                   # テスト関連ドキュメント
├── JJYWaveTests/            # 単体/統合テスト
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

## 貢献
- 実験プロジェクトとして Issue / Pull Request を歓迎します。大きな変更は事前に議論してください。

## ライセンス
- MIT License。詳細は [LICENSE.txt](LICENSE.txt) を参照してください。
- Copyright (c) 2025 MyCometG3