# Benchmarks

FastSense ships a suite of isolated microbenchmarks in the `benchmarks/` directory. These complement the integration examples in `examples/`: instead of measuring absolute throughput on a specific machine, they verify that each hot-path kernel scales correctly — catching algorithmic regressions (e.g. an O(N) kernel quietly becoming O(N²)) regardless of host CPU speed.

## Running the Benchmarks

Each benchmark is a standalone MATLAB function. Run any of them from the repo root after calling `install()`:

```matlab
install();

bench_downsample_kernels   % MinMax + LTTB downsampling kernels
bench_binary_search        % Binary range-window lookup
bench_violation_cull       % Threshold violation detection + culling
bench_datastore_range      % Disk-backed range queries (FastSenseDataStore)
bench_delimited_parse      % CSV ingestion pipeline (Tag layer)
```

Or headless from the shell:

```bash
octave --no-gui --eval "install(); bench_downsample_kernels();"
```

Each benchmark prints a results table and exits `PASS:` on success, or throws an `assert` failure (non-zero exit) when a scaling regression is detected.

## Machine-Independent Scaling Gates

All five benchmarks use **log-log exponent fitting** rather than absolute time limits:

1. Sweep over a range of input sizes (e.g. 10K → 10M points).
2. Fit `time ~ N^exponent` to the large-N portion of the sweep.
3. Assert the exponent stays below a threshold.

This makes the gate:

- **Stable across machines** — only algorithmic behaviour matters, not CPU speed.
- **Sensitive to real regressions** — a linear scan replacing an indexed read, or a quadratic realloc in a parser, drives the exponent clearly above the gate.
- **Robust to one-off spikes** — each size uses the median of multiple timed runs.

## Benchmark Reference

### `bench_downsample_kernels`

Times `minmax_downsample` and `lttb_downsample` as **pure computation** (no figure, no rendering). Both are driven to ~2 000-point output across a 10K–10M input sweep so their throughput is directly comparable.

| Kernel | MEX binary | Gate | Baseline result\* |
|--------|-----------|------|-------------------|
| `minmax_downsample` (`minmax_core_mex`) | ✅ active | exponent ≤ 1.3 | ~764 Mpts/s @ 10M, exponent 0.88 |
| `lttb_downsample` (`lttb_core_mex`) | ✅ active | exponent ≤ 1.3 | ~349 Mpts/s @ 10M, exponent 0.87 |

\* MATLAB R2025b, Apple M4.

**Why it matters:** Downsampling runs on every render and every zoom/pan over the full dataset — it is FastSense's core value. Previously only `minmax_downsample` had any coverage (a single call buried in the render-heavy `benchmark.m`); LTTB had zero benchmark coverage.

**Reaching private wrappers:** `minmax_downsample`/`lttb_downsample` live in `libs/FastSense/private/`. Because MATLAB rejects `addpath` on a `private/` directory, the benchmark `cd`s into the folder instead — the current working directory is always searched regardless of its name, in both MATLAB and Octave. `onCleanup` restores the original directory even if an assertion fails.

---

### `bench_binary_search`

Times 20 000 scalar `binary_search` lookups (both `'left'` and `'right'` directions) across a 10K–50M sorted-array sweep.

| Direction | Gate | Baseline result\* |
|-----------|------|-------------------|
| `'left'` | per-query exponent ≤ 0.6 | ~0.95 µs/query @ 10K → ~1.8 µs @ 50M, exponent 0.09 |
| `'right'` | per-query exponent ≤ 0.6 | similar |

\* MATLAB R2025b, Apple M4.

**Why it matters:** `binary_search` is called on every zoom/pan and render to locate the visible index window in a raw full-length sorted array (`FastSense.m`, `FastSenseToolbar.m`, `SensorTag.m`). If the MEX silently stops loading and the pure-MATLAB fallback takes over, or a change turns it into a linear scan, large-data interactivity collapses — nothing else in the suite would catch it.

**MEX detection caveat:** `binary_search_mex` lives in `libs/FastSense/private/` and is not visible from `benchmarks/`. A plain `exist('binary_search_mex','file')` call from here misreports as fallback. The benchmark instead checks for the compiled binary on disk (`binary_search_mex.<mexext>`) directly.

---

### `bench_violation_cull`

Times `violation_cull` — the fused detect-and-cull kernel behind threshold violation markers — for both the constant-threshold branch (sentinel `thX=0`) and a 5-knot step-function threshold, across a 1K–1M input sweep.

| Branch | Gate | Baseline result\* |
|--------|------|-------------------|
| Constant threshold | exponent ≤ 1.3 | ~288 Mpts/s @ 1M, exponent 0.93 |
| Step-function threshold | exponent ≤ 1.3 | ~261 Mpts/s @ 1M, exponent 0.92 |

\* MATLAB R2025b, Apple M4.

**Why it matters:** Called once per (threshold × line) pair on every render/zoom for thresholds with `ShowViolations` (`FastSense.m:1368/1371`, `4468/4471`). Production input is the downsampled display data (~few thousand points); the larger sizes exist purely to verify linear scaling.

---

### `bench_datastore_range`

Tests `FastSenseDataStore.getRange` — the out-of-core range-query path for disk-backed datasets. Builds a chunked SQLite store at each size (100K–5M points), then fires 30 fixed-window queries per measurement. Window width is scaled so each query returns ~10 000 points regardless of total dataset size.

| Gate | Baseline result\* |
|------|-------------------|
| query-time vs total-N exponent ≤ 0.5 | ~0.16 ms flat across 100K→5M (50× more data), exponent −0.11 |

\* MATLAB R2025b, mksqlite active.

**Why it matters:** Every zoom/pan on a disk-backed line issues a range query. The indexed store must seek to the window (O(log N) chunk lookup + read), not scan the whole dataset. A full-scan regression drives the exponent toward 1.0 and trips the gate.

**Cleanup guarantee:** Each store is `cleanup()`'d after its measurement (via `try/catch` + post-loop cleanup), so temporary SQLite files never leak even if the assertion fails mid-run.

---

### `bench_delimited_parse`

Times `dispatchDelimitedParse_` — the CSV-ingestion entry point for the `SensorThreshold` Tag pipeline — on 4-column deterministic CSVs across a 1K–500K row sweep. File generation is excluded from timing. Temp files are always deleted.

| Gate | Baseline result\* |
|------|-------------------|
| row-scaling exponent ≤ 1.3 | ~5.7 M rows/s (~205 MB/s) at 100K–500K rows, exponent 0.98 |

\* MATLAB R2025b, `delimited_parse_mex` active.

**Why it matters:** `dispatchDelimitedParse_` is the front door for raw sensor data into the Tag pipeline. The compiled MEX is ~10–40× faster than the `textscan` fallback. This benchmark confirms the MEX is active and that parsing stays near-linear as log sizes grow.

---

## Coverage Map

The file `benchmarks/.reports/coverage.md` tracks which performance-critical paths have isolated microbenchmark coverage. Summary as of 2026-06-24:

| Path | Status |
|------|---------|
| Downsampling kernels — MinMax + LTTB | ✅ `bench_downsample_kernels` |
| Binary search range lookup | ✅ `bench_binary_search` |
| Violation detect + cull (constant & step) | ✅ `bench_violation_cull` |
| Disk range query (`FastSenseDataStore.getRange`) | ✅ `bench_datastore_range` |
| CSV ingestion (`dispatchDelimitedParse_`) | ✅ `bench_delimited_parse` |
| Tag layer (`SensorTag`/`MonitorTag`/`CompositeTag` getXY, append) | ✅ `bench_sensortag_getxy`, `bench_monitortag_tick/append`, `bench_compositetag_merge`, `bench_tag_pipeline_1k` |
| Dashboard refresh / load | ✅ `bench_dashboard`, `bench_dashboard_live`, `bench_dashboard_load` |
| End-to-end render, zoom/pan, memory, features | ✅ `benchmark.m`, `benchmark_zoom.m`, `benchmark_memory.m`, `benchmark_features.m` |
| `to_step_function_mex` | ⏸️ Deferred — no confirmed production caller (under investigation) |
| `EventStore` persistence scaling | ◻️ Open |
| `LiveEventPipeline` per-tick processing | ◻️ Open |

## See Also

- [[MEX Acceleration]] — SIMD kernel details and platform compilation flags
- [[Performance]] — end-to-end throughput metrics, tuning options, and memory management
- `benchmarks/.reports/coverage.md` — ranked coverage map with per-benchmark change log
