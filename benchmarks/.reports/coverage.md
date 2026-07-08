# Benchmark coverage notes

Tracks what `/bench-evolve` has added and which performance-critical paths
still lack isolated benchmark coverage. Newest entries first.

## Performance-critical surface (ranked) and coverage status

| Path | Why it matters | Coverage |
|------|----------------|----------|
| **Downsampling kernels** (`minmax_downsample` / `lttb_downsample` → `minmax_core_mex` / `lttb_core_mex`) | Runs on every render + every zoom/pan, over the full dataset (≤50M pts). The library's core value. | ✅ `bench_downsample_kernels.m` (isolated, both methods) — *added 2026-06-24*. Also exercised indirectly in `benchmark.m` / `benchmark_zoom.m` / `benchmark_features.m` (render-mixed). |
| **`binary_search`** (`binary_search_mex`) | Range-window lookup on raw full-N sorted arrays; on the resolve path for every zoom/pan + every tag range query (`FastSense.m`, `FastSenseToolbar.m`, `SensorTag.m`). | ✅ `bench_binary_search.m` (isolated, log-scaling gate) — *added 2026-06-24*. |
| **Violation marker path** (`violation_cull` → `violation_cull_mex`; constant + step-function branches) | Fused detect+cull on every threshold render/zoom for thresholds with `ShowViolations` (incl. time-varying step thresholds). | ✅ `bench_violation_cull.m` (isolated, both branches, linear-scaling gate) — *added 2026-06-24*. |
| **Disk range-query** (`FastSenseDataStore.getRange`, `resolve_disk_mex`) | Out-of-core read on every zoom/pan of a disk-backed line. The large-data story's hot read path. | ✅ `bench_datastore_range.m` (fixed-window query, indexed-read gate) — *added 2026-06-24*. Store create/slice still only exploratory (`benchmark_datastore.m` / `profile_datastore.m`). |
| **CSV ingestion** (`dispatchDelimitedParse_` → `delimited_parse_mex`, fallback `readRawDelimited_`) | Front door for raw sensor data into the Tag pipeline; MEX is ~10–40× the textscan fallback. Slow parse = slow load for big logs. | ✅ `bench_delimited_parse.m` (isolated, row-scaling gate) — *added 2026-06-24*. |
| **Pyramid build** (`FastSense.buildPyramidLevel`) | Multi-level pre-downsample cache built at render for large lines (powers O(1) zoom). Full-N at render. | ◐ Partial — it is essentially `minmax_downsample` per level (already gated by `bench_downsample_kernels.m`) + chunked disk reads; only *memory*-benchmarked end-to-end (`benchmark_memory.m`). Low marginal value to isolate; private method. |
| **`to_step_function_mex`** | SIMD step-function conversion — a compiled, deployed, correctness-tested kernel (`TestToStepFunctionMex`). | ⏸️ **DEFERRED** — no confirmed production caller. `MonitorTag.recompute_` emits a binary vector (no step conversion); `StateTag.getXY` is pass-through; only the test suite calls it. The `dispatchDelimitedParse_` comment citing it is stale. **Investigate whether it's still wired into any render path (or is vestigial) before benchmarking.** |
| **Tag layer** (SensorTag/MonitorTag/CompositeTag getXY, resolve, append) | Live-tick recompute path. | ✅ `bench_sensortag_getxy`, `bench_monitortag_tick`, `bench_monitortag_append`, `bench_compositetag_merge`, `bench_consumer_migration_tick`, `bench_tag_pipeline_1k`. |
| **Dashboard refresh / load** | Live dashboard refresh rate. | ✅ `bench_dashboard`, `bench_dashboard_live`, `bench_dashboard_load`. |
| **Detached-mirror refresh** (`detachWidget` → `DetachedMirror.tick` inside `onLiveTick`) | The project's **headline constraint**: detached live mirrors must not degrade dashboard refresh rate. Mirrors tick inline on the same refresh path. | ✅ `bench_detached_mirror_refresh.m` (0/1/2/4 mirrors, amortized tick) — *added 2026-06-24*. MATLAB-only (Octave detach bug, filed). |
| **Multi-line render/refresh** (single axes, many lines) | `updateData` re-downsamples **all** lines every live tick; multi-sensor overlay is common. Lines-per-axes was untested (existing benches use one line or vary widget count). | ✅ `bench_fastsense_multiline.m` (line-count sweep 1→64, refresh Hz) — *added 2026-06-24*. |
| **DerivedTag resolve chain** (`DerivedTag.getXY` recompute + invalidate cascade) | Live invalidation cascades through derived-tag graphs; the leaf refresh recomputes the whole chain. | ✅ `bench_derived_resolve_chain.m` (depth sweep, cold recompute vs warm cache) — *added 2026-06-24*. Isolates the memoization + cascade **plumbing** (not the user `ComputeFn`) — addresses the recompute_ deferral noted below. |
| **Full render vs plot(), zoom/pan, memory, features** | End-to-end render comparison. | ✅ `benchmark.m`, `benchmark_zoom.m`, `benchmark_memory.m`, `benchmark_features.m`. |

## Change log

### 2026-06-24 — `bench_derived_resolve_chain.m`
- **Gap closed:** DerivedTag resolve-graph recompute cost vs dependency depth.
  Rather than timing a single `recompute_` (dominated by the user `ComputeFn` —
  the reason it was deferred, see pivot note below), it builds a
  sensor→T1→…→TD chain and isolates the FRAMEWORK plumbing: the invalidate
  cascade + per-node `getXY` memoization walk.
- **What it does:** sweeps depth 1→32 (1e6 pts/node); times COLD leaf `getXY`
  after invalidating the whole chain (full recompute = live cost) vs WARM
  `getXY` (memoized cache). Throughput bench (no gate); uses min-over-reps
  (GC-robust for the per-node array allocations).
- **First run (MATLAB R2025b):** cold 0.69→14.2 ms ~linear in depth; warm flat
  ~0.02 ms (memo saves the whole chain walk). Verified portable (full Octave run).

### 2026-06-24 — `bench_detached_mirror_refresh.m`
- **Gap closed:** the project's **headline constraint** — detached live mirrors
  must not degrade dashboard refresh rate — had no committed bench.
- **What it does:** holds 8 widgets constant, detaches 0/1/2/4 as mirrors
  (`detachWidget`), and times amortized active `onLiveTick` (mirrors tick inline
  on the same path). Reports refresh ms / Hz / overhead vs baseline.
- **First run (MATLAB R2025b):** baseline ~18 ms (≈55 Hz); mirrors add real,
  increasing overhead (+35% → ~+120–200% at 4 mirrors). Methodology: needs ~20
  warmup ticks to settle, and `onLiveTick` is BIMODAL under `drawnow('limitrate')`,
  so the stable metric is the amortized average, not a per-tick median.
- **Octave:** skips cleanly — the detach path hits an Octave-incompatible
  `feval([className '.fromStruct'], s)` in `DashboardWidgetRegistry.fromStruct:92`,
  which also breaks serialized dashboard load under Octave (filed as a task).

### 2026-06-24 — `bench_fastsense_multiline.m`
- **Gap closed:** multi-line scaling on a single FastSense axes (multi-sensor
  overlay) — existing benches use one line or vary widget count, not lines/axes.
- **What it does:** sweeps line count 1→64 at 100K pts/line; times `updateData`
  (re-downsamples all lines) with `SkipViewMode`, reporting refresh Hz + us/line.
  Headless invisible figure, progress bar silenced via `ShowProgress`.
- **First run (MATLAB R2025b):** 564 Hz (1 line) → 39 Hz (64 lines); us/line
  falls as fixed per-call overhead amortizes. Verified portable (Octave API smoke).

### 2026-06-24 — `bench_downsample_kernels.m`
- **Gap closed:** isolated downsampling-kernel microbenchmark. Previously the
  only coverage was a single `minmax_downsample(x,y,1000)` call buried inside
  the render-heavy `benchmark.m`; **LTTB had zero coverage anywhere**.
- **What it does:** times `minmax_downsample` and `lttb_downsample` as pure
  computation (no figure/render) across a 10K→10M size sweep, same ~2000-pt
  output budget for both, reporting per-call ms + throughput (Mpts/s).
- **Gate:** machine-independent — fits the empirical log-log scaling exponent
  over the large-N portion and asserts it stays ≤ 1.3 (catches super-linear
  creep regardless of host speed).
- **Reaches the private wrappers** by `cd`-ing into `libs/FastSense/private`
  (current folder is always searched, even when named `private`) — works in
  both MATLAB and Octave, unlike the `addpath(.../private)` trick that
  `benchmark.m` uses (Octave-only; MATLAB rejects private dirs on the path).
- **First run (MATLAB R2025b, MEX active):** MinMax ~764 Mpts/s @ 10M,
  LTTB ~349 Mpts/s @ 10M; scaling exponents 0.88 / 0.87 → PASS.

### 2026-06-24 — `bench_binary_search.m`
- **Gap closed:** isolated range-lookup microbenchmark. `binary_search` is the
  most broadly-used uncovered kernel — the resolve/zoom window lookup in
  `FastSense.m` (4060/4103/4178/4460), timestamp lookup (1683), toolbar
  click/range, and tag range resolve (`SensorTag.m:152`), on raw full-N sorted
  arrays, every zoom/pan. Re-prioritised **above** the violation marker path
  this run: `violation_cull` runs on already-downsampled display data
  (small-N, per-frame), whereas `binary_search` hits the raw full-N array.
- **What it does:** times 20k scalar `'left'`/`'right'` lookups across a
  10K→50M sweep, reporting per-query µs + Mqueries/s.
- **Gate:** machine-independent — fits the per-query log-log exponent over the
  large-N portion and asserts it stays ≤ 0.6, catching the catastrophic
  O(log N)→O(N) (linear-scan) regression regardless of host speed.
- **MEX detection caveat (baked into the bench):** `binary_search_mex` lives in
  `libs/FastSense/private` and is visible to `binary_search.m` (its parent) but
  NOT from `benchmarks/`. A plain `exist('binary_search_mex','file')` in the
  bench misreports as fallback; the bench instead checks the built binary for
  the current platform on disk (`['binary_search_mex.' mexext]`).
- **First run (MATLAB R2025b, MEX active):** ~0.95 µs/query @ 10K → ~1.8 µs @ 50M;
  exponent 0.09 (firmly logarithmic), growth 1.9× over the sweep → PASS.

### 2026-06-24 — `bench_violation_cull.m`
- **Gap closed:** isolated threshold-marker microbenchmark. `violation_cull` is
  the fused detect+cull kernel called per (threshold x line) on every
  render/zoom (`FastSense.m:1368/1371`, `4468/4471`); only
  `bench_event_marker_regression.m` touched a neighbouring path before.
- **What it does:** times both threshold branches as pure computation — a
  constant threshold (thX=0 sentinel) and a 5-knot step-function threshold —
  across a 1K→1M input sweep, reporting per-call ms + throughput. Annotated
  that production input is the displayed/downsampled data (~few thousand pts,
  the low end); upper sizes verify linear scaling.
- **Gate:** machine-independent — log-log scaling exponent over N >= 1e4 must
  stay <= 1.3 (catches super-linear creep in detect+cull).
- **Reaches the private wrapper** via the `cd`-into-`libs/FastSense/private`
  trick (see [[benchmarking-private-mex-kernels]]).
- **First run (MATLAB R2025b, MEX active):** constant ~288 Mpts/s @ 1M, step
  ~261 Mpts/s @ 1M; at the realistic ~1K size both are sub-10 µs. Scaling
  exponents 0.93 / 0.92 → PASS.

### 2026-06-24 — `bench_datastore_range.m`
- **Gap closed:** focused, deterministic gate for the disk-backed range-query
  path (`FastSenseDataStore.getRange`), which every zoom/pan on a disk-backed
  line hits. Previously only exploratory scripts existed (`benchmark_datastore.m`
  is a .mat-vs-SQLite sweep and Linux-only — shells out to `free`;
  `profile_datastore.m` is a profiler script). No figure needed.
- **What it does:** builds a chunked store at each size, fires fixed-size view
  windows (width scaled so each query returns ~10k pts regardless of N), times
  `getRange`, and reports create time + per-query ms + queries/s.
- **Gate:** machine-independent — the indexed store must read only the window,
  so per-query time must stay ~constant as the dataset grows; asserts the
  query-time-vs-total-N exponent <= 0.5 (a full-scan regression → ~1.0).
- **Robustness:** warms up a throwaway store first (absorbs one-time SQLite/MEX
  init), and always `cleanup()`s each store (try/catch + post-loop) so temp DBs
  never leak even if the gate trips.
- **First run (MATLAB R2025b, mksqlite active):** query time flat at ~0.16 ms
  across 100K→5M (50× more data), exponent −0.11, exactly 10002 pts/query → PASS.

### Pivot note this run
Intended target was `to_step_function_mex`, but a fresh survey found it has **no
confirmed production caller** (see table) — benchmarking it would violate the
"path that matters" rule. Deferred it (flagged for investigation) and pivoted to
the disk range-query gate instead.

### 2026-06-24 — `bench_delimited_parse.m`
- **Gap closed:** isolated CSV-ingestion microbenchmark. `delimited_parse_mex`
  (via `dispatchDelimitedParse_`) is the parse front door for the Tag pipeline,
  documented at ~10–40× the textscan fallback, with zero coverage
  (BatchTagPipeline / delimited ingestion was entirely unbenchmarked).
- **What it does:** generates deterministic 4-column CSVs of growing row count,
  times `dispatchDelimitedParse_` (file generation excluded), reports parse ms +
  rows/s + MB/s. Always deletes its temp files (per-iter + onCleanup backstop).
- **Gate:** machine-independent — log-log row-scaling exponent over rows ≥ 1e4
  must stay ≤ 1.3 (catches super-linear parse creep, e.g. O(rows²) realloc).
- **Reaches the private wrapper** via `cd`-into-`libs/SensorThreshold/private`
  (see [[benchmarking-private-mex-kernels]]).
- **First run (MATLAB R2025b, MEX active):** ~5.7 M rows/s (~205 MB/s) at 100K–500K
  rows; exponent 0.98 (essentially linear) → PASS.

### Pivot notes this run
Two earmarked targets were rejected on fresh survey:
- **Pyramid build** — `buildPyramidLevel` is just `minmax_downsample` per level
  (already gated) + chunked reads; private; low marginal value. Downgraded to
  ◐ Partial in the table, not benchmarked.
- **DerivedTag.recompute_** — thin dispatch around a user-supplied `ComputeFn`
  (`[X,Y] = ComputeFn(Parents)`), so a microbench would mostly measure the test
  closure, not a FastSense kernel. Deferred unless paired with a built-in
  compute/alignment path worth isolating.

### Next gap for the following iteration
Survey fresh, but leading candidates (higher-level paths now that the core MEX
kernels are covered):
- **EventStore persistence scaling** — `EventStore.save` (atomic temp-rename
  write) / `load` as event count grows; relevant for long-running live
  dashboards. Confirm it isn't already covered by `bench_event_marker_regression`
  / `bench_dashboard_*` (those attach stores but may not stress save/load at scale).
- **LiveEventPipeline per-tick processing** (`processMonitorTag_`) on the live
  refresh path — confirm it isn't already covered by `bench_monitortag_tick`.
- Still open: the `to_step_function_mex` wiring question (filed as a background task).
