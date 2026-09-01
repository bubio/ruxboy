#!/bin/sh
# 検証用ビルド & 実行スクリプト。  使い方: ./run.sh [--debug|--release]
#
# コンパイラは submodule external/Rux をビルドしたもの（external/Rux/Bin/rux）を
# 使う。標準ライブラリも同じ submodule から取るので、コンパイラとライブラリの
# 版が必ず一致する。RUX 環境変数で別のコンパイラを指せる。
#
# SDL3 の場所は pkg-config で調べ、--define SDL_PREFIX で渡す。Rux 側はその値を
# 見て #Link に絶対パスを埋め込むので（Src/Sdl3.rux 参照）、実行時に環境変数は
# 要らない。
set -eu

dir=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$dir/../.." && pwd)
rux=${RUX:-$root/external/Rux/Bin/rux}

if [ ! -x "$rux" ]; then
    echo "コンパイラが見つからない: $rux" >&2
    echo "external/Rux で次を実行してビルドする:" >&2
    echo '  sh Run.sh build --compiler "$(brew --prefix llvm@22)/bin/clang++"' >&2
    exit 1
fi

profile=Debug
case "${1:-}" in
    --release) profile=Release ;;
    --debug|"") ;;
    *) echo "usage: $0 [--debug|--release]" >&2; exit 2 ;;
esac

case "$(uname -s)" in
    Darwin) osdir=macOS ;;
    *) echo "この検証は macOS 専用" >&2; exit 2 ;;
esac
case "$(uname -m)" in
    arm64) archdir=AArch64 ;;
    x86_64) archdir=X86_64 ;;
    *) echo "未知のアーキテクチャ" >&2; exit 2 ;;
esac

cd "$dir"
"$rux" build ${1:+"$1"} --define "SDL_PREFIX=$(pkg-config --variable=prefix sdl3)"
exec "./Bin/$profile/$osdir/$archdir/Sdl3Probe"
