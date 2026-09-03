#!/bin/sh
# RuxBoy テスト実行スクリプト
# 使い方: scripts/test.sh [--release]

set -eu

dir=$(cd "$(dirname "$0")/.." && pwd)
rux=${RUX:-$dir/external/Rux/Bin/rux}
# Windows: 拡張子無しの"rux"は実在せず"rux.exe"のみ存在する。RUX未指定でも
# 動くよう自動検出する(macOS/Linuxと同じ手順で使えるようにするため)。
if [ ! -x "$rux" ] && [ -x "$rux.exe" ]; then
    rux="$rux.exe"
fi

if [ ! -x "$rux" ]; then
    echo "コンパイラが見つからない: $rux" >&2
    exit 1
fi

echo "=== Running CpuTest ==="
(cd "$dir/Tests/Packages/Core/Cpu" && "$rux" run ${1:+"$1"})
echo "CpuTest: OK"

echo "=== Running BusTest ==="
(cd "$dir/Tests/Packages/Core/Bus" && "$rux" run ${1:+"$1"})
echo "BusTest: OK"

echo "=== Running JoypadTest ==="
(cd "$dir/Tests/Packages/Core/Joypad" && "$rux" run ${1:+"$1"})
echo "JoypadTest: OK"

echo "=== Running CpuInstrsTest ==="
(cd "$dir/Tests/Packages/Core/CpuInstrs" && "$rux" run ${1:+"$1"})
echo "CpuInstrsTest: OK"

echo "=== Running BlarggTest ==="
(cd "$dir/Tests/Packages/Core/Blargg" && "$rux" run ${1:+"$1"})

echo "=== Running ApuTest ==="
(cd "$dir/Tests/Packages/Core/Apu" && "$rux" run ${1:+"$1"})
echo "ApuTest: OK"

echo "=== Running DmgSoundTest ==="
(cd "$dir/Tests/Packages/Core/DmgSound" && "$rux" run ${1:+"$1"})

echo "=== Running MbcTest ==="
(cd "$dir/Tests/Packages/Core/Mbc" && "$rux" run ${1:+"$1"})

echo "=== Running MooneyeTest ==="
(cd "$dir/Tests/Packages/Core/Mooneye" && "$rux" run ${1:+"$1"})

echo "=== Running CgbTest ==="
(cd "$dir/Tests/Packages/Core/Cgb" && "$rux" run ${1:+"$1"})
echo "CgbTest: OK"

echo "=== Running Acid2Test ==="
(cd "$dir/Tests/Packages/Core/Acid2" && "$rux" run ${1:+"$1"})

echo "=== Running SaveStateTest ==="
(cd "$dir/Tests/Packages/Core/SaveState" && "$rux" run ${1:+"$1"})
echo "SaveStateTest: OK"

echo "=== All Tests Passed! ==="
