# Phase 1028: Tag update perf — MEX + SIMD - Context

**Gathered:** 2026-05-08
**Status:** Ready for planning

<domain>
## Phase Boundary

Profile and accelerate the **tag update path** end-to-end at the user's real workload point: **1000 tags fed by N async raw-file sources in a single MATLAB session**. Replace MATLAB hot loops with C MEX kernels (SIMD where it pays off, AVX2 + NEON via existing `simd_utils.h` pattern), and apply architectural changes (listener fan-out coalescing, batch invalidation, parallel source polling) where profiling shows they dominate.

**In scope:** SensorTag, StateTag, MonitorTag, CompositeTag (structural aggregation modes), and the surrounding plumbing — `LiveTagPipeline.onTick_/processTag_`, `private/readRawDelimited_`, `private/selectTimeAndValue_`, listener fan-out, MonitorTag.recompute_/applyHysteresis_/applyDebounce_/findRuns_/fireEventsInTail_, CompositeTag.mergeStream_/aggregator helper.

**Out of scope:** DerivedTag user-supplied function handle evaluation (`UserFn`); built-in DerivedTag operations unless profiling shows them hot at the user's workload; .mat write cadence/coalescing (deferred — see Deferred Ideas); changes to public Tag/Pipeline APIs.

</domain>

<decisions>
## Implementation Decisions

### Workload Anchor

- **D-01:** The design point is **1000 tags** wired through **one MATLAB session** ingesting raw files from **multiple machines in parallel** (async, no fixed cadence). All performance gates and harnesses must be expressed at this scale.
- **D-02:** Raw-file ingest must be format-agnostic: phase covers **all raw file formats currently supported by the codebase** (delimited text via `readRawDelimited_` is the present implementation). If new formats are introduced as part of this phase's optimization, both delimited and binary kernels are expected. Format choice driven by what profiling shows hot.

### Performance Approach

- **D-03:** **Profile-first.** Build the harness, measure baseline, set the budget after measurement (rule of thumb: ≥5× over MATLAB baseline for any new kernel; smaller wins acceptable only if absolute saving is meaningful at 1000-tag scale).
- **D-04:** **MEX + architectural.** Free hand to combine C/SIMD swap-in with structural changes — coalesced listener invalidation, batch fan-out, parallel raw-source polling — where profiling justifies. Not strictly drop-in.
- **D-05:** Two-stage delivery: (1) MEX swap-in wins first (drop-in behind existing function signatures), (2) architectural changes after the data confirms they dominate. Each stage is independently shippable.

### Profiling & CI Gating

- **D-06:** **New 1000-tag synthetic harness** is the primary CI gate for this phase. Wires N synthetic raw-file sources to 1000 tags spanning all four in-scope tag types, drives full `LiveTagPipeline` ticks. Lives at `benchmarks/bench_tag_pipeline_1k.m` (or similar).
- **D-07:** **Tests run in GitHub CI only.** No local MATLAB test execution during development of this phase. CI is the sole verification surface. Quick local static checks (mh_lint, `mcp__matlab__check_matlab_code`) are fine.

### Compatibility Constraints

- **D-08:** **All existing benchmark gates stay green as hard constraints.** No regression in `bench_monitortag_tick` (≤10%), `bench_compositetag_merge` (<200 ms @ 8×100k, ≤1.10× output), `bench_sensortag_getxy` (zero-copy invariant), `bench_monitortag_append`, `bench_consumer_migration_tick`. Tightening any of these is allowed but not required.
- **D-09:** **Pure-MATLAB `.m` fallback parity preserved** for every new MEX kernel — exact semantic equivalence, transparent fallback when binary is absent. Existing convention from `libs/FastSense/`.
- **D-10:** **No public API changes.** Tag classes, `LiveTagPipeline`, `BatchTagPipeline`, and the listener model retain their current public surface. Architectural changes (D-04) are internal to the pipeline.

### Tag-Type Scope

- **D-11:** **DerivedTag.UserFn out of scope.** User-supplied function handles are not MEX'd. The phase accelerates SensorTag, StateTag, MonitorTag, and CompositeTag (structural aggregation modes: `and`, `or`, `worst`, `count`, `majority`, `severity`). DerivedTag's surrounding plumbing (resolve, listener wiring, append) may still be optimized; only the expression evaluator is exempt.

### Write Cadence

- **D-12:** **`.mat` write cadence stays at write-on-every-ingest-tick** for this phase (current behavior). Per-tick I/O is acknowledged as a likely bottleneck at 1000 tags but is **deferred to a follow-up phase** to keep this one's blast radius bounded. If the 1000-tag harness shows .mat I/O dominates and blocks the budget, surface it in `VERIFICATION.md` as a flagged limitation.

- **D-12-AMENDED (2026-05-08, post-Plan-02b, refined post-Plan-02d):** Plan 02b's NoIO measurement-gap fix produced clean tBreakdown data showing `.mat` `load`/`save` consumed 65% of every production tick (WithIO/NoIO ratio 2.88×, not the 1.030× false-negative reported in Wave 0). Plan 02's `profileTopN` further isolated the dominant cost as the **`load` step inside `writeTagMat_('append', ...)`** (`load` ≈ 9.31 s vs `save` ≈ 2.28 s across 3 ticks) — i.e., the read-side `load → concat → save` sequence re-reads each tag's `.mat` from disk every tick. The original D-12 deferral was based on the broken measurement. Per the user's explicit "do whats best" directive, D-12 is **un-deferred** for this phase: an **in-memory prior-state cache** in `LiveTagPipeline` and `BatchTagPipeline` is in-scope. The pipeline owns a per-tag cache (`priorState_`, `containers.Map` keyed by tag key, value `struct('X', priorX, 'Y', priorY)`) populated lazily on first write per tag and refreshed after every write; warm-cache appends concatenate from the cached prior state and `save` without `load`. **Constraints preserved (unchanged from prior amendment):** the bytes-on-disk and tick cadence are identical — `save` still happens once per tag per tick (D-12 cadence), so crash-recovery semantics at the tick boundary are preserved; production callers see no public API change (D-10 holds — the cache flag is exposed only via `Hidden setCacheActiveForTesting_` mirroring the Plan 02b `writeFn_` DI-seam pattern); WithIO mode of the harness validates production-path performance both with cache-on (default) and cache-off (regression check). Only the **read-side `load` is eliminated on warm ticks**; the within-tick write-coalescing framing in the previous version of this amendment was incorrect (the pipeline already calls `writeFn_` exactly once per tag per tick — there is no within-tick redundancy to coalesce). The original "periodic checkpoint" option (every N ticks / T seconds) remains deferred.

### Claude's Discretion

- Choice of which specific MATLAB hot loops get C-kernel'd vs left in `.m`, driven by profiling output.
- SIMD width selection (AVX2 vs NEON vs scalar fallback) per kernel — follow existing `simd_utils.h` dispatch pattern.
- Exact harness shape (number of synthetic raw-file sources, sample rates, tag-graph topology) so long as it credibly represents 1000-tag multi-machine.
- Whether to add MATLAB `parfeval`/threadpool concurrency for parallel raw-source polling, or use MATLAB-side cooperative scheduling. Driven by what profiling shows.
- Naming and exact location of new MEX kernel files within `libs/SensorThreshold/private/mex_src/` (create this directory mirroring FastSense pattern).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Tag domain model

- `libs/SensorThreshold/Tag.m` — abstract base interface
- `libs/SensorThreshold/SensorTag.m` — raw signal carrier, zero-copy `getXY` invariant
- `libs/SensorThreshold/StateTag.m` — discrete state channel
- `libs/SensorThreshold/MonitorTag.m` §`recompute_`, §`appendData`, §`applyHysteresis_`, §`applyDebounce_`, §`findRuns_`, §`fireEventsInTail_` — primary MATLAB hot-loop targets
- `libs/SensorThreshold/CompositeTag.m` §`mergeStream_`, §aggregator helper — k-way merge + 7-mode aggregation (6 in scope, `user_fn` out)
- `libs/SensorThreshold/DerivedTag.m` — out-of-scope reference (UserFn evaluator stays MATLAB)
- `libs/SensorThreshold/TagRegistry.m` — singleton catalog (read-only context)

### Ingest pipeline

- `libs/SensorThreshold/LiveTagPipeline.m` §`onTick_`, §`processTag_`, §`dispatchParse_`, §`gcStaleTagState_` — primary architectural-change surface
- `libs/SensorThreshold/BatchTagPipeline.m` — secondary path (read-only context)
- `libs/SensorThreshold/private/readRawDelimited_.m` — delimited-text parse (216 lines, prime MEX target if profiling shows hot)
- `libs/SensorThreshold/private/selectTimeAndValue_.m` — column extraction
- `libs/SensorThreshold/private/writeTagMat_.m` — .mat writer (per-tick I/O — flagged for follow-up phase, do not modify cadence here)
- `libs/EventDetection/MatFileDataSource.m` — existing async file-source pattern (reference)

### MEX SIMD conventions

- `libs/FastSense/private/mex_src/simd_utils.h` — AVX2/NEON/scalar dispatch helpers; required pattern for any new kernel
- `libs/FastSense/build_mex.m` — build entry point; new kernels register here
- `libs/FastSense/private/mex_src/to_step_function_mex.c` — closest-shape existing kernel for reference (already used by MonitorTag.recompute_)
- `libs/FastSense/private/mex_src/compute_violations_mex.c` — batch violation detection reference

### Existing benchmark gates (hard constraints — must not regress)

- `benchmarks/bench_monitortag_tick.m` — ≤10% regression vs SensorTag baseline (12 sensors × 10k pts × 50 iter)
- `benchmarks/bench_compositetag_merge.m` — <200 ms @ 8×100k, ≤1.10× output size
- `benchmarks/bench_sensortag_getxy.m` — zero-copy invariant (constant overhead with N)
- `benchmarks/bench_monitortag_append.m` — append throughput
- `benchmarks/bench_consumer_migration_tick.m` — consumer-side tick

### Project context

- `CLAUDE.md` §"Conventions" §"Architecture" — naming, MEX patterns, error namespacing
- `.planning/ROADMAP.md` §"Phase 1028" — original phase goal text
- `install.m` — path setup + MEX build entry

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`simd_utils.h` AVX2/NEON dispatch macros** — already proven in 5 FastSense kernels; new tag kernels reuse the exact same pattern (`#if defined(__AVX2__) ... #elif defined(__ARM_NEON) ... #else /* scalar */`).
- **`build_mex` registration flow** — adding a new kernel = drop `.c` in `libs/SensorThreshold/private/mex_src/` (or FastSense equivalent), register in `build_mex.m`, ship `.m` fallback alongside.
- **Existing tag-path MEX** — `to_step_function_mex`, `compute_violations_mex`, `violation_cull_mex`, `resolve_disk_mex` already cover several tag hot loops. Re-profiling may show they leave gaps elsewhere.
- **`LiveTagPipeline.tickOnce`** — testable single-step entry point; the 1000-tag harness drives this directly without timer overhead.
- **`TestRunner.withTextOutput` + class-based tests** — existing pattern for the new harness's assertion shell.

### Established Patterns

- **Pure-MATLAB fallback parity** — every MEX kernel has a `.m` twin returning identical output. Tests assert MEX vs fallback parity at multiple sizes. Non-negotiable.
- **Listener fan-out via MATLAB `events`/`notify` + `Listeners_` cell** — MonitorTag/CompositeTag/DerivedTag all use this. Coalescing requires preserving the public listener contract while batching `notify` calls inside a tick boundary.
- **`Verbose` flag with `[ClassName]` prefix** for diagnostic output during profiling.
- **Namespaced errors** `'SensorTag:*'`, `'MonitorTag:*'`, `'CompositeTag:*'` — any new MEX-related errors follow same convention.
- **`bench_*` files self-bootstrap via `install()`** and exit non-zero on regression — pattern for the new 1000-tag harness.

### Integration Points

- **`LiveTagPipeline.onTick_`** — the natural seam for batch-coalesced invalidation. Right now it calls `processTag_` per tag in a loop; a coalesced variant collects all newly-appended SensorTags then drives a single fan-out pass.
- **`Tag.invalidate()`** — currently per-tag; an internal `invalidateBatch_(tags)` helper preserves the public API while letting the pipeline queue many tags for a single downstream pass.
- **`MonitorTag.recompute_`** — already calls `to_step_function_mex` and `compute_violations_mex`; remaining MATLAB time is in `applyHysteresis_` and `applyDebounce_` FSMs (hot at high event rates).
- **`CompositeTag.mergeStream_`** — vectorized k-way merge already lives here; aggregator switch is per-mode and a candidate for a single dispatch MEX over the 6 structural modes.

### 1000-tag-scale considerations (anticipated hot spots)

- **Per-tag MATLAB dispatch** at 1000 tags × any per-tag function call ≈ 1 ms (MATLAB) / 14 ms (Octave) just in dispatch overhead per `bench_sensortag_getxy.m` measurement notes. Implies batched APIs win over per-tag loops.
- **`readRawDelimited_` text parsing** — 216 lines of `textscan`/`strsplit`-style logic; classic MEX target.
- **Listener cascade** — 1000 SensorTags each with 2-3 Monitor/Composite listeners means ~3000 invalidation calls per tick; coalescing pays here.
- **`.mat` per-tick write fan** — flagged but deferred (D-12).

</code_context>

<specifics>
## Specific Ideas

- **User's framing in own words:** "we can have up to 1000 tags... for multiple machines.... all tags source data from the raw files and generate the .mat data for the tags... data in raw files will be written asynchronously... no fixed intervals so we must have a system that can update all of them really fast"
- This is a **real-time multi-source ingest** problem at industrial-plant scale, not a one-shot batch problem. Latency under continuous load is the dimension that matters; throughput-per-batch is secondary.
- **Test loop discipline:** all profiling and verification done in **GitHub Actions CI**, not local MATLAB. Iteration speed is gated by CI turnaround — design the harness to be fast (single bench, ≤30 s wall in CI).
- **Acceptance bar (anchored to the harness, not generic 5×):** the 1000-tag harness must show measurable improvement at every stage shipped; the final number is set after the baseline run lands in CI.

</specifics>

<deferred>
## Deferred Ideas

### `.mat` write cadence optimization (post-1028)

- Coalesce per-tag `.mat` writes within a tick (write each tag's .mat once at end of tick instead of on every append).
- Or move to periodic checkpoint (every N ticks / T seconds) with in-memory authoritative state.
- Likely substantial I/O win at 1000-tag scale but changes crash-recovery semantics; deserves its own scoping pass.

### DerivedTag built-in operations library

- If DerivedTag had a library of vectorizable common ops (diff, integrate, smooth, etc.) those could be MEX'd. Currently DerivedTag is `UserFn`-only; out of scope for 1028.
- Future: design a `DerivedOp` enum or a small library of named operations that can be MEX'd, leaving `UserFn` as the escape hatch.

### Cross-session multi-plant scheduler

- D-06 anchors on 1 session, N machines. The "1 session per plant, multiple plants" multi-session scenario from the original gray-area question is a separate ops/deployment concern — not addressed here.

### Reviewed Todos (not folded)

None — todo backlog had zero matches for phase 1028.

</deferred>

---

*Phase: 1028-tag-update-perf-mex-simd*
*Context gathered: 2026-05-08*
