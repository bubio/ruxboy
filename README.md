# RuxBoy

**English** | [日本語](README.ja.md)

<p align="center">
  <img src="docs/CoverArt.png" alt="Cover" width="*" height="*">
</p>


A Game Boy Color emulator, written in the [Rux language](https://rux-lang.dev/) with SDL3 for its multimedia layer. It's a command-line application.

The core is a port of BubiBoy Lite (Odin + SDL2, MIT License) to Rux.

Performance still has some rough edges. You'll probably need something in the Apple M4 class to run it comfortably.

<p align="center">
  <a href="https://github.com/bubio/ruxboy/releases/latest">
    <img src="https://img.shields.io/github/v/release/bubio/ruxboy" alt="Latest Release">
  </a>
  <a href="https://github.com/bubio/ruxboy/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/bubio/ruxboy" alt="License">
  </a>
  <a href="https://github.com/bubio/ruxboy/actions/workflows/ci.yml">
    <img src="https://github.com/bubio/ruxboy/actions/workflows/ci.yml/badge.svg">
  </a>
  <a href="https://github.com/bubio/ruxboy/releases/latest">
    <img src="https://img.shields.io/github/downloads/bubio/ruxboy/total.svg" alt="Downloads">
  </a>
</p>


## Supported platforms

- macOS 13.5+ (Intel / Apple Silicon)
- Ubuntu 26.04+ (amd64 / arm64)
- Windows 11+ (x64)

## Installation

Download the zip for your platform from [Releases](../../releases) and extract it.

- **macOS / Linux**: the SDL3 runtime must be installed separately.
  On macOS, `brew install sdl3`; on Ubuntu 26.04+, `sudo apt-get install libsdl3-0`
  (the `-dev` package is not needed).
- **Windows**: the zip already bundles `SDL3.dll`, so no extra setup is
  required. Just keep it next to `RuxBoy.exe`.
- **macOS**: since the binary is unsigned, Gatekeeper may warn on first launch
  that the developer can't be verified. If that happens, run `xattr -d
  com.apple.quarantine ./RuxBoy`, or right-click the binary in Finder and
  choose **Open**.

## Building from source

The compiler and standard library are fetched from a submodule (`external/Rux`).

```sh
git clone --recurse-submodules <this repository's URL>
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

### Windows

Requires Visual Studio (Desktop development with C++) and LLVM 22. Run the
build from inside the same shell session where you've loaded the Visual
Studio developer environment (`vcvarsall.bat`).

```powershell
# Run inside Developer PowerShell for VS
cd external\Rux
.\Run.ps1 build -Compiler <path to LLVM 22's clang++.exe>
cd ..\..
sh scripts/fetch_sdl3_windows.sh
sh scripts/build_windows.sh --release
```

The build output is placed at `Packages/App/Bin/Release/<OS>/<Arch>/RuxBoy[.exe]`.

## Usage

```
使用法: RuxBoy [options] game.gbc

  -h, --help        コマンドラインの使い方を表示
  -v, --version     バージョンを表示
  --scale N         表示倍率 (1-8、9以上は8に丸める、デフォルト 4)
  --fullscreen      フルスクリーン表示 (--scale は無視される)
  --shader KIND     シェーダー: nearest, smooth (デフォルト nearest)
  --recent          最近使ったROMの一覧を表示して終了
```

(The CLI's own `--help` output is currently Japanese-only; an English
translation isn't provided yet.)

### Keyboard shortcuts (while a ROM is running)

| Key | Function |
|---|---|
| Arrow keys | D-pad |
| Z / X | B / A |
| Enter | Start |
| Right Shift | Select |
| F1 | Save a savestate to the current slot |
| F3 | Load a savestate from the current slot |
| Esc | Quit |

## License

[MIT License](LICENSE)
