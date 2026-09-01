#!/bin/sh
set -e

# tests/roms/ にテスト ROM (Blargg) を配置するスクリプト。
# ライセンス上、テスト ROM をリポジトリにコミットしないため CI・ローカルの両方で
# このスクリプトを通して都度取得する（tests/roms/ は .gitignore 対象）。
# 再実行しても安全（取得済みファイルはスキップ）。

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
ROMS_DIR="$PROJECT_ROOT/tests/roms"
BLARGG_DIR="$ROMS_DIR/blargg"

# retrio/gb-test-roms をコミット固定で取得する
BLARGG_COMMIT="c240dd7d700e5c0b00a7bbba52b53e4ee67b5f15"
BLARGG_BASE_URL="https://raw.githubusercontent.com/retrio/gb-test-roms/$BLARGG_COMMIT"

mkdir -p "$BLARGG_DIR/cpu_instrs/individual" "$BLARGG_DIR/instr_timing"

fetch() {
	remote_path="$1"
	local_path="$2"

	if [ -f "$local_path" ]; then
		echo "fetch_test_roms.sh: 取得済み、スキップ: $local_path"
		return 0
	fi

	echo "fetch_test_roms.sh: 取得中: $remote_path"
	tmp_path="$local_path.tmp"
	encoded_path=$(printf '%s' "$remote_path" | sed 's/ /%20/g')
	if ! curl -fsSL --retry 3 --retry-delay 2 -o "$tmp_path" "$BLARGG_BASE_URL/$encoded_path"; then
		rm -f "$tmp_path"
		echo "fetch_test_roms.sh: 取得失敗: $remote_path" >&2
		return 1
	fi
	mv "$tmp_path" "$local_path"
}

# cpu_instrs 個別 ROM（ROM-only、フェーズ1でパスさせる対象）
fetch "cpu_instrs/individual/01-special.gb" "$BLARGG_DIR/cpu_instrs/individual/01-special.gb"
fetch "cpu_instrs/individual/02-interrupts.gb" "$BLARGG_DIR/cpu_instrs/individual/02-interrupts.gb"
fetch "cpu_instrs/individual/03-op sp,hl.gb" "$BLARGG_DIR/cpu_instrs/individual/03-op sp,hl.gb"
fetch "cpu_instrs/individual/04-op r,imm.gb" "$BLARGG_DIR/cpu_instrs/individual/04-op r,imm.gb"
fetch "cpu_instrs/individual/05-op rp.gb" "$BLARGG_DIR/cpu_instrs/individual/05-op rp.gb"
fetch "cpu_instrs/individual/06-ld r,r.gb" "$BLARGG_DIR/cpu_instrs/individual/06-ld r,r.gb"
fetch "cpu_instrs/individual/07-jr,jp,call,ret,rst.gb" "$BLARGG_DIR/cpu_instrs/individual/07-jr,jp,call,ret,rst.gb"
fetch "cpu_instrs/individual/08-misc instrs.gb" "$BLARGG_DIR/cpu_instrs/individual/08-misc instrs.gb"
fetch "cpu_instrs/individual/09-op r,r.gb" "$BLARGG_DIR/cpu_instrs/individual/09-op r,r.gb"
fetch "cpu_instrs/individual/10-bit ops.gb" "$BLARGG_DIR/cpu_instrs/individual/10-bit ops.gb"
fetch "cpu_instrs/individual/11-op a,(hl).gb" "$BLARGG_DIR/cpu_instrs/individual/11-op a,(hl).gb"

# cpu_instrs 統合版（MBC1 が必要。フェーズ4まで許可リストに残す）
fetch "cpu_instrs/cpu_instrs.gb" "$BLARGG_DIR/cpu_instrs/cpu_instrs.gb"

# instr_timing（フェーズ1でパスさせる対象）
fetch "instr_timing/instr_timing.gb" "$BLARGG_DIR/instr_timing/instr_timing.gb"

echo "fetch_test_roms.sh: 完了。配置先: $ROMS_DIR"
