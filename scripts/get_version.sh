#!/bin/sh
# Packages/App/Src/Version.rux の AppVersion 定数を単一の源として抽出する。
# リリース zip のファイル名はこの値から生成する。
set -eu

dir=$(cd "$(dirname "$0")/.." && pwd)
version_file="$dir/Packages/App/Src/Version.rux"
manifest_file="$dir/Packages/App/Rux.toml"

version=$(sed -n 's/^pub const AppVersion: Slice<char8> = "\([0-9][0-9.]*\)";$/\1/p' "$version_file" | head -n 1)

if [ -z "$version" ]; then
    echo "Error: $version_file から AppVersion を抽出できませんでした。書式 'pub const AppVersion: Slice<char8> = \"x.y.z\";' を確認してください。" >&2
    exit 1
fi

# Rux.toml の [Package] Version はビルド時の表示にのみ使われる別の値だが、
# 混乱を避けるため AppVersion と一致していることを検証する(手で二重管理)。
manifest_version=$(sed -n 's/^Version = "\([0-9][0-9.]*\)"$/\1/p' "$manifest_file" | head -n 1)
if [ "$manifest_version" != "$version" ]; then
    echo "Error: $manifest_file の Version ($manifest_version) が $version_file の AppVersion ($version) と一致しません。両方を更新してください。" >&2
    exit 1
fi

echo "$version"
