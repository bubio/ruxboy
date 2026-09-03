# RuxBoy

Game Boy Color エミュレーター。[Rux 言語](https://rux-lang.dev/) で書かれ、マルチメディア層に SDL3 を使うコマンドラインアプリです。

コアは BubiBoy Lite (Odin + SDL2, MIT License) を Rux へ移植したものです。

## 対応プラットフォーム

- macOS 13.5+ (Intel / Apple Silicon)
- Ubuntu 26.04+ (amd64 / arm64)
- Windows (準備中)

## ビルド

コンパイラと標準ライブラリは submodule (`external/Rux`) から取得します。

```sh
git clone --recurse-submodules <このリポジトリのURL>
cd RuxBoy
```

### macOS

```sh
brew install llvm@22 cmake ninja sdl3
(cd external/Rux && sh Run.sh build --compiler "$(brew --prefix llvm@22)/bin/clang++")
sh scripts/build_macos.sh --release
```

### Linux (Ubuntu 26.04+)

```sh
sudo apt-get install clang-22 cmake ninja-build libsdl3-dev
(cd external/Rux && sh Run.sh build --compiler /usr/bin/clang++-22)
sh scripts/build_linux.sh --release
```

ビルド成果物は `Packages/App/Bin/Release/<OS>/<Arch>/RuxBoy` に生成されます。

## 使い方

```
使用法: RuxBoy [options] game.gbc

  -h, --help        コマンドラインの使い方を表示
  -v, --version     バージョンを表示
  --scale N         表示倍率 (1-8、9以上は8に丸める、デフォルト 4)
  --fullscreen      フルスクリーン表示 (--scale は無視される)
  --shader KIND     シェーダー: nearest, smooth (デフォルト nearest)
  --recent          最近使ったROMの一覧を表示して終了
```

### キーボードショートカット (ROM実行中)

| キー | 機能 |
|---|---|
| 矢印キー | 十字キー |
| Z / X | B / A |
| Enter | Start |
| 右Shift | Select |
| F1 | 現在のスロットへセーブステートを保存 |
| F3 | 現在のスロットからセーブステートを復元 |
| Esc | 終了 |

## ライセンス

[MIT License](LICENSE)
