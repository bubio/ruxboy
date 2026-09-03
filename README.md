# RuxBoy

**English** | [日本語](README.ja.md)

<p align="center">
  <img src="docs/CoverArt.png" alt="Cover" width="*" height="*">
</p>


A Game Boy Color emulator, written in the [Rux language](https://rux-lang.dev/) with SDL3 for its multimedia layer. It's a command-line application.

The core is a port of BubiBoy Lite (Odin + SDL2, MIT License) to Rux.

Performance still has some rough edges. You'll probably need something in the Apple M4 class to run it comfortably.

## Status

RuxBoy is an experimental project exploring the Rux language by porting
BubiBoy Lite's core. Core emulation (CPU, PPU, APU, MBC1/2/3/5, GBC features,
savestates), the CLI frontend, and CI/CD covering macOS, Linux, and Windows
are all in place, and release zips are built and attached automatically. It
passes the Blargg, Mooneye acceptance, and dmg-acid2/cgb-acid2 test suites,
with 3 known Mooneye edge-case failures (`rapid_toggle`, `reti_timing`,
`stat_lyc_onoff`) that are tracked but not yet fixed. Windows arm64 is not
yet supported. Performance is still rough on typical hardware, as noted
above.

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
Usage: RuxBoy [options] game.gbc

  -h, --help        Show command-line usage
  -v, --version     Show version
  --scale N         Display scale (1-8, values above 8 are clamped to 8, default 4)
  --fullscreen      Fullscreen display (--scale is ignored)
  --shader KIND     Shader: nearest, smooth (default nearest)
  --recent          List recently used ROMs and exit
```

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
