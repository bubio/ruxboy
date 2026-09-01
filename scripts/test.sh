#!/bin/sh
# RuxBoy テスト実行スクリプト
# 使い方: scripts/test.sh [--release]

set -eu

dir=$(cd "$(dirname "$0")/.." && pwd)
rux=${RUX:-$dir/external/Rux/Bin/rux}

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

echo "=== Running CpuInstrsTest ==="
(cd "$dir/Tests/Packages/Core/CpuInstrs" && "$rux" run ${1:+"$1"})
echo "CpuInstrsTest: OK"

echo "=== Running BlarggTest ==="
(cd "$dir/Tests/Packages/Core/Blargg" && "$rux" run ${1:+"$1"})

echo "=== All Tests Passed! ==="
