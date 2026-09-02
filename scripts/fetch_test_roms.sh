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
MOONEYE_COMMIT="6745fe8ccc5e8035e104934dcea8c6500171b65e"
MOONEYE_BASE_URL="https://raw.githubusercontent.com/asoderman/Mooneye-Test-Suite-ROMS/$MOONEYE_COMMIT"

mkdir -p "$BLARGG_DIR/cpu_instrs/individual" "$BLARGG_DIR/instr_timing" \
	"$BLARGG_DIR/dmg_sound/rom_singles" \
	"$ROMS_DIR/mooneye/acceptance/timer" "$ROMS_DIR/mooneye/acceptance/interrupts" \
	"$ROMS_DIR/mooneye/acceptance/ppu" "$ROMS_DIR/acid2"

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

# dmg_sound 個別ROM（フェーズ5でパスさせる対象。MBC1+RAM+BATTERY、cpu_instrsと
# 同じピン留めコミットから取得するため新規ピン留めは不要）
fetch "dmg_sound/rom_singles/01-registers.gb" "$BLARGG_DIR/dmg_sound/rom_singles/01-registers.gb"
fetch "dmg_sound/rom_singles/02-len ctr.gb" "$BLARGG_DIR/dmg_sound/rom_singles/02-len ctr.gb"
fetch "dmg_sound/rom_singles/03-trigger.gb" "$BLARGG_DIR/dmg_sound/rom_singles/03-trigger.gb"
fetch "dmg_sound/rom_singles/04-sweep.gb" "$BLARGG_DIR/dmg_sound/rom_singles/04-sweep.gb"
fetch "dmg_sound/rom_singles/05-sweep details.gb" "$BLARGG_DIR/dmg_sound/rom_singles/05-sweep details.gb"
fetch "dmg_sound/rom_singles/06-overflow on trigger.gb" "$BLARGG_DIR/dmg_sound/rom_singles/06-overflow on trigger.gb"
fetch "dmg_sound/rom_singles/07-len sweep period sync.gb" "$BLARGG_DIR/dmg_sound/rom_singles/07-len sweep period sync.gb"
fetch "dmg_sound/rom_singles/08-len ctr during power.gb" "$BLARGG_DIR/dmg_sound/rom_singles/08-len ctr during power.gb"
fetch "dmg_sound/rom_singles/09-wave read while on.gb" "$BLARGG_DIR/dmg_sound/rom_singles/09-wave read while on.gb"
fetch "dmg_sound/rom_singles/10-wave trigger while on.gb" "$BLARGG_DIR/dmg_sound/rom_singles/10-wave trigger while on.gb"
fetch "dmg_sound/rom_singles/11-regs after power.gb" "$BLARGG_DIR/dmg_sound/rom_singles/11-regs after power.gb"
fetch "dmg_sound/rom_singles/12-wave write while on.gb" "$BLARGG_DIR/dmg_sound/rom_singles/12-wave write while on.gb"

fetch_mooneye() {
	remote_path="$1"
	local_path="$2"

	if [ -f "$local_path" ]; then
		echo "fetch_test_roms.sh: 取得済み、スキップ: $local_path"
		return 0
	fi

	echo "fetch_test_roms.sh: 取得中: $remote_path"
	tmp_path="$local_path.tmp"
	if ! curl -fsSL --retry 3 --retry-delay 2 -o "$tmp_path" "$MOONEYE_BASE_URL/$remote_path"; then
		rm -f "$tmp_path"
		echo "fetch_test_roms.sh: 取得失敗: $remote_path" >&2
		return 1
	fi
	mv "$tmp_path" "$local_path"
}

for name in div_write rapid_toggle tim00 tim00_div_trigger tim01 tim01_div_trigger \
	tim10 tim10_div_trigger tim11 tim11_div_trigger tima_reload \
	tima_write_reloading tma_write_reloading
do
	fetch_mooneye "acceptance/timer/$name.gb" "$ROMS_DIR/mooneye/acceptance/timer/$name.gb"
done

# acceptance/interrupts: 割り込み系 acceptance ROM（フェーズ2）
for name in ei_sequence ei_timing halt_ime0_ei halt_ime0_nointr_timing \
	halt_ime1_timing if_ie_registers intr_timing rapid_di_ei \
	reti_intr_timing reti_timing
do
	fetch_mooneye "acceptance/$name.gb" "$ROMS_DIR/mooneye/acceptance/$name.gb"
done
fetch_mooneye "acceptance/interrupts/ie_push.gb" "$ROMS_DIR/mooneye/acceptance/interrupts/ie_push.gb"

# acceptance/ppu: STAT blocking / LYC on-off の acceptance ROM(フェーズ3)
for name in stat_irq_blocking stat_lyc_onoff
do
	fetch_mooneye "acceptance/ppu/$name.gb" "$ROMS_DIR/mooneye/acceptance/ppu/$name.gb"
done

# emulator-only/mbc1,mbc2,mbc5: MBC系 ROM(フェーズ4)。MBC3(+RTC)はmooneyeスイート
# に該当ROMが無いため、MbcTest内のユニットテストで検証する(docs/dev/phases/
# phase-04-cartridge-mbc.md参照)。MBC1Mマルチカート(multicart_rom_8Mb)は
# BubiBoy Lite同様スコープ外。
mkdir -p "$ROMS_DIR/mooneye/emulator-only/mbc1" "$ROMS_DIR/mooneye/emulator-only/mbc2" \
	"$ROMS_DIR/mooneye/emulator-only/mbc5"

for name in bits_ramg bits_bank1 bits_bank2 bits_mode rom_512kb rom_1Mb rom_2Mb \
	rom_4Mb rom_8Mb rom_16Mb ram_64kb ram_256kb
do
	fetch_mooneye "emulator-only/mbc1/$name.gb" "$ROMS_DIR/mooneye/emulator-only/mbc1/$name.gb"
done

for name in bits_ramg bits_romb bits_unused ram rom_512kb rom_1Mb rom_2Mb
do
	fetch_mooneye "emulator-only/mbc2/$name.gb" "$ROMS_DIR/mooneye/emulator-only/mbc2/$name.gb"
done

for name in rom_512kb rom_1Mb rom_2Mb rom_4Mb rom_8Mb rom_16Mb rom_32Mb rom_64Mb
do
	fetch_mooneye "emulator-only/mbc5/$name.gb" "$ROMS_DIR/mooneye/emulator-only/mbc5/$name.gb"
done

# dmg-acid2 (フェーズ3): mattcurrie/dmg-acid2 のリリース資産から直接取得する
# (retrio/gb-test-roms や asoderman/Mooneye-Test-Suite-ROMS とはリポジトリが異なる)。
ACID2_ROM_URL="https://github.com/mattcurrie/dmg-acid2/releases/download/v1.0/dmg-acid2.gb"
ACID2_ROM_PATH="$ROMS_DIR/acid2/dmg-acid2.gb"
if [ -f "$ACID2_ROM_PATH" ]; then
	echo "fetch_test_roms.sh: 取得済み、スキップ: $ACID2_ROM_PATH"
else
	echo "fetch_test_roms.sh: 取得中: $ACID2_ROM_URL"
	tmp_path="$ACID2_ROM_PATH.tmp"
	if curl -fsSL --retry 3 --retry-delay 2 -o "$tmp_path" "$ACID2_ROM_URL"; then
		mv "$tmp_path" "$ACID2_ROM_PATH"
	else
		rm -f "$tmp_path"
		echo "fetch_test_roms.sh: 取得失敗: $ACID2_ROM_URL" >&2
	fi
fi

# cgb-acid2 (フェーズ6): mattcurrie/cgb-acid2 のリリース資産から直接取得する。
CGB_ACID2_ROM_URL="https://github.com/mattcurrie/cgb-acid2/releases/download/v1.1/cgb-acid2.gbc"
CGB_ACID2_ROM_PATH="$ROMS_DIR/acid2/cgb-acid2.gb"
if [ -f "$CGB_ACID2_ROM_PATH" ]; then
	echo "fetch_test_roms.sh: 取得済み、スキップ: $CGB_ACID2_ROM_PATH"
else
	echo "fetch_test_roms.sh: 取得中: $CGB_ACID2_ROM_URL"
	tmp_path="$CGB_ACID2_ROM_PATH.tmp"
	if curl -fsSL --retry 3 --retry-delay 2 -o "$tmp_path" "$CGB_ACID2_ROM_URL"; then
		mv "$tmp_path" "$CGB_ACID2_ROM_PATH"
	else
		rm -f "$tmp_path"
		echo "fetch_test_roms.sh: 取得失敗: $CGB_ACID2_ROM_URL" >&2
	fi
fi

echo "fetch_test_roms.sh: 完了。配置先: $ROMS_DIR"
