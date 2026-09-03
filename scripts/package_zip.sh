#!/bin/sh
# 配布用 zip を作成する。CI もこのスクリプトを呼ぶ(ローカル/CI 共通)。
#
# 使い方: package_zip.sh <binary-dir> <platform> <arch>
#   binary-dir: RuxBoy(.exe) の入っているディレクトリ。Windows は同じ
#               ディレクトリに SDL3.dll も必要(scripts/build_windows.sh の出力)。
#   platform:   macos, linux, windows
#   arch:       macos -> arm64, x86_64 / linux -> amd64, arm64 / windows -> x64
#
# 出力: RuxBoy-<version>-<platform>-<arch>.zip (プロジェクトルート直下)
# 同梱物は RuxBoy(.exe) / (Windowsのみ)SDL3.dll / LICENSE / README.md のみで、
# zip 内に余計なディレクトリ階層を作らない(展開したらファイルが直接出る)。
set -eu

dir=$(cd "$(dirname "$0")/.." && pwd)
cd "$dir"

if [ $# -ne 3 ]; then
    echo "使い方: $0 <binary-dir> <platform> <arch>" >&2
    exit 1
fi

binary_dir=$1
platform=$2
arch=$3

case "$platform" in
    macos|linux) bin_name=RuxBoy ;;
    windows)     bin_name=RuxBoy.exe ;;
    *)
        echo "Error: 不正な platform '$platform'(macos, linux, windows のいずれか)" >&2
        exit 1
        ;;
esac

case "$platform-$arch" in
    macos-arm64|macos-x86_64) ;;
    linux-amd64|linux-arm64) ;;
    windows-x64) ;;
    *)
        echo "Error: 不正な platform/arch の組み合わせ '$platform-$arch'" >&2
        exit 1
        ;;
esac

binary_path="$binary_dir/$bin_name"
if [ ! -f "$binary_path" ]; then
    echo "Error: バイナリが見つかりません: $binary_path" >&2
    exit 1
fi

version=$(sh "$dir/scripts/get_version.sh")

stage_dir=$(mktemp -d)
trap 'rm -rf "$stage_dir"' EXIT

cp "$binary_path" "$stage_dir/$bin_name"
chmod +x "$stage_dir/$bin_name"
cp "$dir/LICENSE" "$stage_dir/LICENSE"
cp "$dir/README.md" "$stage_dir/README.md"

if [ "$platform" = windows ]; then
    sdl_dll="$binary_dir/SDL3.dll"
    if [ ! -f "$sdl_dll" ]; then
        echo "Error: SDL3.dll が見つかりません: $sdl_dll" >&2
        exit 1
    fi
    cp "$sdl_dll" "$stage_dir/SDL3.dll"
fi

zip_name="RuxBoy-${version}-${platform}-${arch}.zip"
zip_path="$dir/$zip_name"
rm -f "$zip_path"

if [ "$platform" = windows ]; then
    (cd "$stage_dir" && zip "$zip_path" "$bin_name" SDL3.dll LICENSE README.md)
else
    (cd "$stage_dir" && zip "$zip_path" "$bin_name" LICENSE README.md)
fi

echo "$zip_path"
