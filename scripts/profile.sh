#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -lt 1 || $# -gt 3 ]]; then
    echo "Usage: $0 <ndjson-file> [workers] [batch-size]"
    exit 2
fi

INPUT="$(realpath "$1")"
WORKERS="${2:-10}"
BATCH="${3:-500}"
OUT_DIR="profiles/$(date +%Y%m%d-%H%M%S)"

if [[ ! -f "$INPUT" ]]; then
    echo "Error: input file not found: $INPUT" >&2
    exit 2
fi

if ! [[ "$WORKERS" =~ ^[1-9][0-9]*$ && "$BATCH" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: workers and batch size must be positive integers" >&2
    exit 2
fi

mkdir -p "$OUT_DIR"
OUT_DIR="$(realpath "$OUT_DIR")"
CLI="$OUT_DIR/tx-cli"

go build -o "$CLI" ./cmd/tx-processor/cli

echo "Writing profiles to $OUT_DIR"

"$CLI" \
    "-file=$INPUT" \
    "-workers=$WORKERS" \
    "-batch=$BATCH" \
    "-cpuprofile=$OUT_DIR/cpu.pprof" \
    "-memprofile=$OUT_DIR/memory.pprof" \
    2>&1 | tee "$OUT_DIR/run.log"

echo
echo "CPU profile:    $OUT_DIR/cpu.pprof"
echo "Memory profile: $OUT_DIR/memory.pprof"
echo
echo "Inspect CPU:"
echo "  go tool pprof -top '$OUT_DIR/cpu.pprof'"
echo
echo "Inspect allocated memory:"
echo "  go tool pprof -sample_index=alloc_space -top '$OUT_DIR/memory.pprof'"
echo
echo "Inspect live heap:"
echo "  go tool pprof -sample_index=inuse_space -top '$OUT_DIR/memory.pprof'"
