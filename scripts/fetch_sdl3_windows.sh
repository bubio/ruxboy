#!/bin/sh
# Windows用SDL3.dllを取得して external/Sdl3Windows/<arch>/SDL3.dll へ配置する。
# 使い方: scripts/fetch_sdl3_windows.sh
#
# macOS(brew)/Linux(apt)と違いWindowsには標準のSDL3配布パッケージマネージャが
# 無いため、libsdl-org/SDL の公式GitHub Releaseからランタイム同梱zip
# (SDL3-<version>-win32-<arch>.zip)を取得する(ヘッダ/importライブラリは不要。
# Rux側は`#Link("SDL3.dll")`でファイル名のみ参照し、リンク時にDLLの実在検証を
# 行わないため、ビルドには不要で実行時にのみ必要。docs/dev/PLAN.md参照)。
# 取得先はリポジトリにコミットしない(.gitignore対象)、再実行しても安全。
set -eu

dir=$(cd "$(dirname "$0")/.." && pwd)

# d01b8c9時点のexternal/Rux固定と同じ考え方でバージョンを固定する。
SDL3_VERSION="3.4.16"

case "$(uname -m)" in
    aarch64|arm64) archdir=AArch64; zip_arch="arm64" ;;
    x86_64)        archdir=x86-64;  zip_arch="x64" ;;
    *)             echo "未知のアーキテクチャ: $(uname -m)" >&2; exit 2 ;;
esac

dest_dir="$dir/external/Sdl3Windows/$archdir"
dest="$dest_dir/SDL3.dll"

if [ -f "$dest" ]; then
    echo "fetch_sdl3_windows.sh: 取得済み、スキップ: $dest"
    exit 0
fi

mkdir -p "$dest_dir"
tmp_zip="$dest_dir/SDL3.zip.tmp"
url="https://github.com/libsdl-org/SDL/releases/download/release-$SDL3_VERSION/SDL3-$SDL3_VERSION-win32-$zip_arch.zip"

echo "fetch_sdl3_windows.sh: 取得中: $url"
if ! curl -fsSL --retry 3 --retry-delay 2 -o "$tmp_zip" "$url"; then
    echo "fetch_sdl3_windows.sh: 取得失敗: $url" >&2
    rm -f "$tmp_zip"
    exit 1
fi

unzip -p "$tmp_zip" SDL3.dll > "$dest"
rm -f "$tmp_zip"

echo "fetch_sdl3_windows.sh: 完了。配置先: $dest"
