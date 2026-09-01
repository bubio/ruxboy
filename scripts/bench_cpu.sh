#!/bin/sh
# CPU スループット計測（Phase 1.5）
# 使い方: scripts/bench_cpu.sh [--debug|--release]

set -eu

dir=$(cd "$(dirname "$0")/.." && pwd)
rux=${RUX:-$dir/external/Rux/Bin/rux}

if [ ! -x "$rux" ]; then
    echo "コンパイラが見つからない: $rux" >&2
    exit 1
fi

case "${1:-}" in
    --release|--debug|"") ;;
    *) echo "usage: $0 [--debug|--release]" >&2; exit 2 ;;
esac

(cd "$dir/Tests/Packages/Core/CpuPerf" && "$rux" run ${1:+"$1"})
