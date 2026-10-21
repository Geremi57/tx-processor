#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <ndjson-file>"
    echo "Optional environment variables:"
    echo "  WORKERS=1,2,4,8,10"
    echo "  BATCHES=100,500,1000"
    echo "  ITERATIONS=3"
    echo "  OUT_DIR=benchmark-results/<directory>"
    exit 2
fi

INPUT="$(realpath "$1")"

if [[ ! -f "$INPUT" ]]; then
    echo "Error: input file not found: $INPUT" >&2
    exit 2
fi

WORKERS="${WORKERS:-1,2,4,8,10}"
BATCHES="${BATCHES:-100,500,1000}"
ITERATIONS="${ITERATIONS:-3}"
OUT_DIR="${OUT_DIR:-benchmark-results/$(date +%Y%m%d-%H%M%S)}"

if ! [[ "$ITERATIONS" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: ITERATIONS must be a positive integer" >&2
    exit 2
fi

IFS=',' read -r -a WORKER_LIST <<< "$WORKERS"
IFS=',' read -r -a BATCH_LIST <<< "$BATCHES"

for value in "${WORKER_LIST[@]}" "${BATCH_LIST[@]}"; do
    if ! [[ "$value" =~ ^[1-9][0-9]*$ ]]; then
        echo "Error: worker counts and batch sizes must be positive integers" >&2
        exit 2
    fi
done

mkdir -p "$OUT_DIR"
OUT_DIR="$(realpath "$OUT_DIR")"
CLI="$OUT_DIR/tx-cli"
CSV="$OUT_DIR/results.csv"

echo "Building CLI..."
go build -o "$CLI" ./cmd/tx-processor/cli

TRANSACTIONS="$(awk 'END { print NR+0 }' "$INPUT")"

if (( TRANSACTIONS == 0 )); then
    echo "Error: input file contains no lines: $INPUT" >&2
    exit 2
fi

printf 'workers,batch,iteration,transactions,elapsed_seconds,transactions_per_second,exit_code\n' > "$CSV"

echo "Input:        $INPUT"
echo "Transactions: $TRANSACTIONS"
echo "Workers:      $WORKERS"
echo "Batch sizes:  $BATCHES"
echo "Iterations:   $ITERATIONS"
echo "Results:      $OUT_DIR"
echo

failures=0

for worker_count in "${WORKER_LIST[@]}"; do
    for batch_size in "${BATCH_LIST[@]}"; do
        for ((iteration=1; iteration<=ITERATIONS; iteration++)); do
            log="$OUT_DIR/w${worker_count}-b${batch_size}-run${iteration}.log"

            printf 'workers=%s batch=%s run=%s ... ' \
                "$worker_count" "$batch_size" "$iteration"

            start_ns="$(date +%s%N)"

            if "$CLI" \
                "-file=$INPUT" \
                "-workers=$worker_count" \
                "-batch=$batch_size" \
                >"$log" 2>&1; then
                status=0
            else
                status=$?
                failures=$((failures + 1))
            fi

            end_ns="$(date +%s%N)"
            elapsed_ns=$((end_ns - start_ns))

            elapsed_seconds="$(awk -v ns="$elapsed_ns" \
                'BEGIN { printf "%.6f", ns / 1000000000 }')"

            throughput="$(awk \
                -v count="$TRANSACTIONS" \
                -v ns="$elapsed_ns" \
                'BEGIN {
                    if (ns > 0) printf "%.2f", count * 1000000000 / ns
                    else print "0"
                }')"

            printf '%s,%s,%s,%s,%s,%s,%s\n' \
                "$worker_count" "$batch_size" "$iteration" \
                "$TRANSACTIONS" "$elapsed_seconds" "$throughput" "$status" \
                >> "$CSV"

            if (( status == 0 )); then
                printf '%s transactions/sec (%s seconds)\n' \
                    "$throughput" "$elapsed_seconds"
            else
                printf 'FAILED (exit %s); see %s\n' "$status" "$log"
            fi
        done
    done
done

echo
echo "Benchmark results: $CSV"
echo "Individual logs:   $OUT_DIR"

if (( failures > 0 )); then
    echo "Warning: $failures run(s) failed. Inspect their log files." >&2
    exit 1
fi

echo "All benchmark runs completed successfully."
