#!/bin/sh
# RuxBoy Windows ビルドスクリプト
# 使い方: scripts/build_windows.sh [--debug|--release]
#
# コンパイラは submodule external/Rux/Bin/rux.exe を使う。RUX 環境変数で
# 別のコンパイラを指定できる。
#
# macOS/Linuxと違い、Windowsは`--define SDL_PREFIX`が不要
# (`Packages/Sdl3/Src/Sdl3.rux`はWindowsでは絶対パスを埋め込まず、PEのインポートに
# 素の"SDL3.dll"を渡す方式のため。docs/dev/PLAN.md参照)。ビルド自体はSDL3.dllが
# 無くても成功するが(リンク時に検証されない)、実行には.exeと同じディレクトリに
# SDL3.dllが必要。`scripts/fetch_sdl3_windows.sh`で取得したものをコピーする。
set -eu

dir=$(cd "$(dirname "$0")/.." && pwd)
rux=${RUX:-$dir/external/Rux/Bin/rux.exe}

if [ ! -x "$rux" ]; then
    echo "コンパイラが見つからない: $rux" >&2
    echo "external/Rux で次を実行してビルドする(Visual Studio開発者環境が必要):" >&2
    echo '  ./Run.ps1 build -Compiler <LLVM 22のclang++.exeへのパス>' >&2
    exit 1
fi

profile=Debug
case "${1:-}" in
    --release) profile=Release ;;
    --debug|"") ;;
    *) echo "usage: $0 [--debug|--release]" >&2; exit 2 ;;
esac

case "$(uname -m)" in
    aarch64|arm64) archdir=AArch64 ;;
    x86_64)        archdir=x86-64 ;;
    *)             echo "未知のアーキテクチャ: $(uname -m)" >&2; exit 2 ;;
esac

cd "$dir/Packages/App"
"$rux" build ${1:+"$1"}

bin="$dir/Packages/App/Bin/$profile/Windows/$archdir/RuxBoy.exe"

sdl_cache="$dir/external/Sdl3Windows/$archdir/SDL3.dll"
if [ -f "$sdl_cache" ]; then
    cp "$sdl_cache" "$(dirname "$bin")/SDL3.dll"
    echo "SDL3.dll を配置: $(dirname "$bin")/SDL3.dll"
else
    echo "警告: SDL3.dll が見つからない ($sdl_cache)。" >&2
    echo "  'sh scripts/fetch_sdl3_windows.sh' で取得するか、手動で $(dirname "$bin")/ へ配置すること。" >&2
    echo "  ビルド自体は完了しているが、SDL3.dllが無いと実行できない。" >&2
fi

echo "ビルド完了: $bin"
