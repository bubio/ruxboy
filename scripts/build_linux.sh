#!/bin/sh
# RuxBoy Linux ビルドスクリプト
# 使い方: scripts/build_linux.sh [--debug|--release]
#
# コンパイラは submodule external/Rux/Bin/rux を使う。
# SDL3 の場所は pkg-config で調べ --define SDL_PREFIX で渡す。
# RUX 環境変数で別のコンパイラを指定できる。
set -eu

dir=$(cd "$(dirname "$0")/.." && pwd)
rux=${RUX:-$dir/external/Rux/Bin/rux}

if [ ! -x "$rux" ]; then
    echo "コンパイラが見つからない: $rux" >&2
    echo "external/Rux で次を実行してビルドする:" >&2
    echo '  sh Run.sh build --compiler /usr/bin/clang++-22' >&2
    exit 1
fi

profile=Debug
case "${1:-}" in
    --release) profile=Release ;;
    --debug|"") ;;
    *) echo "usage: $0 [--debug|--release]" >&2; exit 2 ;;
esac

if ! sdl_prefix=$(pkg-config --variable=prefix sdl3 2>/dev/null); then
    echo "SDL3 が見つからない。'sudo apt-get install libsdl3-dev' などで導入してください。" >&2
    exit 1
fi

case "$(uname -m)" in
    aarch64) archdir=AArch64 ;;
    x86_64)  archdir=x86-64 ;;
    *)       echo "未知のアーキテクチャ: $(uname -m)" >&2; exit 2 ;;
esac

cd "$dir/Packages/App"
"$rux" build ${1:+"$1"} --define "SDL_PREFIX=$sdl_prefix"

bin="$dir/Packages/App/Bin/$profile/Linux/$archdir/RuxBoy"
echo "ビルド完了: $bin"
