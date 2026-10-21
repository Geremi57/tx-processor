# Profiling and Benchmarking

This guide explains how to profile and benchmark the transaction processor.

## Prerequisites

- Go installed and available on your PATH.
- Repository dependencies downloaded.
- A valid NDJSON dataset, such as sample_transactions.json.
- Required services, including PostgreSQL and Redis, running if needed.

## CPU and Memory Profiling

Run the profiling script:

    scripts/profile.sh sample_transactions.json

Optionally specify the worker count and batch size:

    scripts/profile.sh sample_transactions.json 4 500

Arguments:
- Input NDJSON file.
- Worker count (default: 10).
- Batch size (default: 500).

The script creates a timestamped directory under profiles/ containing the
CPU profile, memory profile, and execution log.

### Inspect the CPU profile

Replace TIMESTAMP with the directory created by the script.

    go tool pprof -top profiles/TIMESTAMP/cpu.prof

To open the interactive profile viewer:

    go tool pprof -http=:8080 profiles/TIMESTAMP/cpu.prof

### Inspect the memory profile

    go tool pprof -top profiles/TIMESTAMP/mem.prof

To inspect memory allocated over the run:

    go tool pprof -alloc_space -top profiles/TIMESTAMP/mem.prof

## Benchmarking

Run the benchmark script:

    scripts/benchmark.sh sample_transactions.json

Configure worker counts, batch sizes, and iterations with environment variables:

    WORKERS=1,4,8 BATCHES=100,500 ITERATIONS=3 scripts/benchmark.sh sample_transactions.json

- WORKERS: comma-separated worker counts.
- BATCHES: comma-separated batch sizes.
- ITERATIONS: number of runs per combination.

The script writes CSV results and run logs to a timestamped directory under
benchmark-results/.

## Interpreting Results

- Compare repeated runs instead of relying on a single measurement.
- Keep the dataset and environment consistent across comparisons.
- Elapsed time may include logging, database writes, and other overhead.
- Profiling adds overhead, so use profiling runs to investigate CPU and memory
  behavior rather than as the sole source of benchmark numbers.
- Check exit codes before interpreting throughput results.

Generated profiling and benchmark artifacts should remain local and should not
be committed to the repository.
