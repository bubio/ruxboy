# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

Game Boy Color エミュレーター **RuxBoy**。既存の Odin 製エミュレーター **BubiBoy Lite** のコアを **Rux 言語**へ移植し、マルチメディア層に **SDL3** を使う。

`docs/BluePrint.md` が要求仕様の唯一の源。実装方針で迷ったら必ず参照する。ただし**この文書は編集してはならない**（青写真＝入力文書のため）。開発が進んで事情が変わった場合、BluePrint に必ずしも従う必要はないが、逸脱はユーザーの承認を得て記録すること。

## 現状

エミュレーター本体のコードはまだ存在しない。リポジトリにあるのは
`docs/BluePrint.md` と技術検証パッケージ `spikes/Sdl3Probe/` のみ。git は未初期化。

**`spikes/Sdl3Probe/NOTES.md` に Rux + SDL3 の実現可能性検証の結果（23 項目、
Debug/Release 両方で通過）がまとまっている。** 実装を始める前に必ず読むこと。

### ツールチェイン（確認済み）

コンパイラも標準ライブラリも **submodule `external/Rux`**（`rux-lang/Rux` を
**d01b8c9 に固定**）から取る。両者の版が必ず一致する。PATH には入れない。

```sh
git submodule update --init                                        # 取得
cd external/Rux
sh Run.sh build --compiler "$(brew --prefix llvm@22)/bin/clang++"   # 出力は Bin/rux
```

必要なもの: LLVM 22 / CMake 3.30+ / Ninja 1.11+（`brew install llvm@22 cmake ninja`）。
詳細は `external/Rux/Docs/Platforms/macOS.md`。

- ソース拡張子 `.rux`、マニフェスト `Rux.toml`（PascalCase の TOML サブセット、
  未知のキーはエラー）、ソースは `Src/` 直下、テストは `Tests/`
- `rux new <Name> --executable [--path <dir>]` / `build` / `run` / `check` /
  `test` / `fmt` / `lint`
- `--debug`（既定）/ `--release` / `--target <triple>` / `--define <k=v>`
- 出力は `Bin/<Profile>/<OS>/<Arch>/<Name>`

**標準ライブラリはレジストリ未公開**（`rux add Rux/Io` が書くレジストリ依存は
404 で解決できない）。`external/Rux/Packages/` へ**相対パス**で依存する。
絶対パスと symlink は不可、推移的依存も自分のマニフェストに列挙する。
`rux fmt` は `Rux.toml` のコメントを消すので注意。詳細は NOTES.md の
「標準ライブラリの入手方法」。

### まだ未確定なこと

- ビルド / パッケージングスクリプトの構成、CI ワークフロー
- ディレクトリ構成、CLI オプション、設定ファイル形式

## 移植元 — BubiBoy Lite

参照先: `~/dev/_Emu/BubiBoyLite/`（Odin + SDL2、MIT License）

- `src/core/` — エミュレーション本体（cpu / ppu / apu / bus / mbc / cartridge / timer / interrupt / joypad / serial / savestate など）。**RuxBoy が移植する主対象。**
- `src/app/` — CLI・TUI・SDL 連携・設定 / セーブ / recent ファイル管理。
- `scripts/` — プラットフォーム別ビルド、バージョン取得、zip パッケージング、テスト ROM 取得。CI から同じスクリプトを呼ぶ構成になっており、RuxBoy でも同じ設計意図を踏襲する（BluePrint の「ローカルと CI で同等」に対応）。
- `docs/` — architecture.md / PLAN.md / phases/ による段階的開発計画。RuxBoy でも同様の計画文書を作るなら `docs/dev/` 配下に置く。

BubiBoy Lite 側の決定（Windows 非対応、SDL2、BIOS ROM 非対応など）は **RuxBoy にそのまま適用されない**。RuxBoy の判断は BluePrint を基準にすること。

### BubiBoy Lite との最大の構造差

**SDL3 のバインディングが存在しないため、必要最小限を自前で実装する必要がある。** BubiBoy Lite は Odin 標準の SDL2 バインディングをそのまま使えたが、RuxBoy にはその前提がない。SDL3 はシステムにインストール済みのものを使う（自前ビルドしない）。

`extern` 宣言を書くときは **必ず `/opt/homebrew/include/SDL3/*.h` を grep して
署名を採る**こと。SDL2 → SDL3 で改名と戻り値の変更が多く、BubiBoy Lite の
SDL2 コードをそのまま読み替えると間違える。

## 対応プラットフォーム

BluePrint の優先順どおり、**macOS を完成させてから**他へ広げる。

1. macOS 13.5+ / Intel・Apple Silicon
2. Ubuntu 24.04+ / amd64・arm64
3. Windows 11+ / x64・arm64

配布は GitHub Releases、全プラットフォーム zip、CLI アプリとして提供。バージョンはセマンティックバージョニング（ビルド番号がある場合は 1 からの連番）。ライセンスは BubiBoy Lite に準じる（MIT）。

## Git / コミット方針

BluePrint 内の 2 つの記述は次のように整合的に読む:

- **禁止事項が初回のゲート**: ユーザーから明示的な指示があるまでコミット・プッシュしてはならない。
- **許可が出た後**: 特別な指示がなければブランチを切らず `main` へ直接コミット・プッシュする。

submodule は 2 つ。`external/Rux` は Rux コンパイラ + 標準ライブラリ（d01b8c9 固定）。
`docs/dev/` は技術ドキュメント置き場で、`git@github.com:bubio/dev-docs.git` に本プロジェクト用ブランチを作り **git submodule** として管理する（開発ドキュメントを公開リポジトリから隠すため）。ローカルには `~/dev/_Emu/dev-docs` がある。

## 厳守事項

- **実際のユーザー名をコード・設定・ドキュメント・コミットに残さない。** パスは必ず `~` や `$HOME` で表現する。
- **README.md に開発関連の内容を書かない。** 開発向け情報は `docs/dev/` へ。
- 設定ファイル等の置き場所は各 OS の習慣に従う。
- 市販ゲーム ROM での動作確認が必要になったら、実行前にユーザーへ相談する。
