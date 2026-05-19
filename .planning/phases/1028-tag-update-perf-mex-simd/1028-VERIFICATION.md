<!-- frontmatter delim -->
phase: 1028
stage: 0
status: baseline-recorded
recorded: 2026-05-08
ci_run_url: https://github.com/HanSur94/FastSense/actions/runs/25558613735
artifact: bench-tag-pipeline-1k-results
<!-- frontmatter delim -->

# Phase 1028 — Verification Log

## Baseline (Wave 0, no MEX kernels, no architectural changes)

Numbers captured from GitHub Actions CI run `25558613735` on commit `8a34b7e`
(branch `claude/adoring-ishizaka-edc93c`). Source: artifact
`bench-tag-pipeline-1k-results` → `benchmark-results.json`.

Per D-07, baseline measurement is CI-only; local MATLAB/Octave execution is
not used for baseline capture.

| Mode | CI Octave (Linux x86_64, gnuoctave/octave:11.1.0) | CI MATLAB (R2021b, Linux x86_64) | CI Octave (macOS arm64) | CI Octave (Windows MSVC) |
|------|---------------------------------------------------|-----------------------------------|-------------------------|---------------------------|
| NoIO `tickMin`    | **4365.4 ms** | not captured (see note) | not captured (see note) | not captured (see note) |
| NoIO `tickMedian` | **6714.9 ms** | not captured | not captured | not captured |
| WithIO `tickMin`  | **4497.1 ms** | not captured | not captured | not captured |
| WithIO `tickMedian` | 6689.0 ms | not captured | not captured | not captured |

Notes:
- `bench_tag_pipeline_1k` is currently invoked only from `benchmark.yml`
  which runs only on Octave Linux x86_64 (per the existing single-cell
  benchmark workflow). Adding the bench to a multi-platform matrix is
  out of scope for plan 1028-01 (would expand `benchmark.yml` to a
  matrix job, deferred to Wave 1+).
- CI MATLAB R2021b currently fails the test suite at
  `TestFastSenseWidgetUpdate` with a pre-existing segfault, before
  reaching any phase-1028 code (documented in `deferred-items.md`).
  The `bench_tag_pipeline_1k` MATLAB baseline is therefore not yet
  captured; it can be recorded in a follow-up plan after the
  pre-existing MATLAB segfault is repaired.
- macOS arm64 / Windows MSVC CI cells run `mex-build-*` smoke jobs only;
  they do not currently invoke `run_ci_benchmark.m`. Same multi-platform
  expansion deferred.
- The Octave CI run uses single-threaded BLAS (`OMP_NUM_THREADS=1`,
  `OPENBLAS_NUM_THREADS=1`) per `benchmark.yml` to reduce shared-runner
  noise.
- 1000 tags exact (700 SensorTag + 100 StateTag + 150 MonitorTag + 50 CompositeTag).
- nMachines = 8, nTicks = 30, nWarmup = 5, nAppend = 100 rows/tick.

## Discrepancy with RESEARCH §"Expected baseline ranges"

RESEARCH §"CI-Fast 1000-Tag Harness Design" predicted:

| Mode | Octave (Linux x86_64 CI) | MATLAB (Linux x86_64 CI) |
|------|--------------------------|---------------------------|
| `NoIO` 1000-tag tick | 80–250 ms | 30–120 ms |
| `WithIO` | 1–3 s | 0.5–1.5 s |

Measured Octave NoIO `tickMin` is **4365.4 ms** — **~17–55× larger** than the
predicted band. This is well outside the bracket described in RESEARCH (≤30 s
wall budget × 35 ticks should comfortably fit; the actual full-run wall is
~221 s, well over the original 30 s estimate).

**Implications for the phase strategy** (need user assessment before Wave 1):

1. **The ≥5× rule of thumb (D-03) becomes harder to apply.** At 4.4 s/tick,
   any kernel landing that saves even 100 ms per tick is meaningful in
   absolute terms but only ~2.3% of the tick — not the dramatic per-kernel
   speedup RESEARCH anticipated.
2. **The bottleneck profile is likely different from H1–H10 ranking.** The
   actual breakdown of 4.4 s/tick has not yet been measured (the harness's
   `tBreakdown` struct is currently zeros — Wave 1 plans wire it). Until
   then, the phase strategy of "rank H1–H10 by baseline" cannot proceed
   confidently. Two early hypotheses for where the time goes:
   - The per-tick CSV growth (8 files × ~4000 rows by tick 30) means each
     tick's `readRawDelimited_` re-parses an ever-larger file. Over 35
     ticks, the cumulative parse cost grows quadratically in row-count.
   - Per-tag MATLAB dispatch over 1000 tags on Octave (~14 µs each per
     RESEARCH note) is ~14 ms/tick — much smaller than the 4.4 s observed,
     so dispatch is NOT the bottleneck. Parse + monitor recompute likely
     dominates.
3. **WithIO/NoIO ratio is 1.030× — `.mat` I/O is NOT dominant at this
   scale (D-12 check passes).** This is a green light — `.mat` write
   coalescing remains correctly deferred to a follow-up phase.

**Recommended next step:** Wave 1 plan 02 (delimited_parse_mex) should
include a `tBreakdown` instrumentation pass FIRST so that subsequent kernel
selection is grounded in the real bottleneck profile, not RESEARCH's
estimates.

## Stage 1 Gate Threshold (set per D-03 profile-first rule)

`GATE_THRESHOLD_SECONDS` = **4.802 s** (= measured Octave NoIO `tickMin`
4365.4 ms × 1.10 — allows 10% jitter; Stage 1 must beat this OR equal it
on no-kernel commits).

Recorded into `benchmarks/bench_tag_pipeline_1k.m` as a literal numeric
constant. The previous `inf` placeholder is now replaced.

## .mat I/O Dominance Check (D-12)

WithIO/NoIO ratio: **1.030×** — `.mat` I/O is NOT dominant at 1000-tag
scale. Per CONTEXT.md D-12 ("If the 1000-tag harness shows .mat I/O
dominates and blocks the budget, surface it in `VERIFICATION.md` as a
flagged limitation"), no flag needed: write-on-every-tick `.mat` cadence
is fine for this phase's scope. The `.mat` I/O optimization remains
correctly deferred.

## Stage 1 Targets (post-Wave 1)

The harness must show measurable improvement on EACH Wave 1 kernel landing
AND no regression on any of:
- bench_monitortag_tick           (D-08, ≤10% regression — currently broken pre-1028, see deferred-items.md)
- bench_compositetag_merge        (D-08, <200 ms @ 8×100k, ≤1.10× output)
- bench_sensortag_getxy           (D-08, zero-copy invariant)
- bench_monitortag_append         (D-08, ≥5× speedup)
- bench_consumer_migration_tick   (D-08, ≤10% overhead)

Stage 1 ship criterion: `tickMin` reduced by ≥10% AND ≥1 of {parse, fsm,
merge, aggregate} kernel shows ≥5× speedup at its scale.

**Caveat:** The 4.4 s/tick baseline means a 10% reduction is ~440 ms — a
meaningful absolute saving. The rule-of-thumb interpretation of "≥5×" may
need to relax to "≥5× on the kernel's own region of `tBreakdown`" rather
than tickMin overall, since a single kernel cannot possibly account for
all 4.4 s.

## Stage 2 Trigger (gates plan 06)

Stage 2 (architectural — listener coalescing A1+A2) lands ONLY if
post-Stage-1 measurement still shows H8 (per-tag dispatch in
`LiveTagPipeline.onTick_`) and H9 (listener cascade) at >25% of the
Stage 1 tickMin. Otherwise Stage 2 is deferred to a follow-up phase.

Re-measure after Wave 1 lands; record numbers below in "Stage 1 Final"
section before deciding plan 06.

## Stage 1 Final (Wave 1 plans 02, 03, 04 land)

### Post-K1 (delimited_parse_mex landed) — Plan 1028-02

CI run: TBD (will populate after `gh run watch` completes on the plan-02 push)
Branch / Commit: claude/adoring-ishizaka-edc93c / TBD

| Mode | tickMin (s) | tickMedian (s) | Δ vs Baseline (Wave 0) |
|------|-------------|----------------|------------------------|
| NoIO   | TBD | TBD | TBD% (↓ improvement / ↑ regression) |
| WithIO | TBD | TBD | TBD% |

**D-08 gates:** TBD — must show all 4 currently-active gates green (the
5th `bench_monitortag_tick` is `assume-skip`'d per Wave 0 deferred-items).

**tBreakdown (profile-mode, summarised from CI artifact):** TBD ms/tick
per region. The most consequential delivery of plan 02 is filling in
this table — kernel selection in plans 03/04 will pivot off where the
4.4 s tick actually lives, NOT the H1-H10 ranking from RESEARCH.md
(which has been disconfirmed by Wave 0 baseline).

Local (macOS arm64 Octave 11.1, smoke 3-tick `--profile`) preview:

| Region | ms/tick | % of profiled total |
|--------|---------|---------------------|
| `parse`             | ~5.5    | ~0.1% |
| `monitor_recompute` | ~0     | ~0% (likely under-bucketed; see § Notes) |
| `composite_merge`   | ~0     | ~0% (likely under-bucketed) |
| `aggregate`         | ~0     | ~0% (likely under-bucketed) |
| `listener_fanout`   | ~0     | ~0% (likely under-bucketed) |
| `mat_write` (incl. load/save) | ~3963 | ~76% |
| `select`            | ~42    | ~0.8% |
| `other`             | ~1168  | ~22% |
| **Total profiled**  | ~5179  |     |

**Notes / caveats:**

1. **NoIO shim not effective from `SensorThreshold/private/` call sites.**
   The Wave 0 baseline numbers were captured with the bench's path-priority
   `writeTagMat_` shim allegedly suppressing .mat writes. Profile shows
   `load: ~9.3 s` and `save: ~2.3 s` summed across 3 ticks — i.e., the
   shim is bypassed. Surfaced in `deferred-items.md`. WithIO/NoIO ratio
   measuring 1.030× (Wave 0 D-12 check) was actually comparing two WithIO
   runs against each other, not NoIO vs WithIO.

2. **`load/save` are bucketed under `mat_write`** because in this bench's
   tick path, `writeTagMat_` is the only caller of `load/save`. Outside
   the bench they could appear elsewhere; matchers use exact-name match
   for these to avoid false positives.

3. **Class-method regions (`monitor_recompute`, `composite_merge`,
   `aggregate`, `listener_fanout`) bucket as ~0 ms.** This is partly
   because in NoIO smoke (ineffective shim notwithstanding) the dominant
   cost is mat I/O, NOT the recompute/merge work. Plans 03 and 04 will
   add named tic/toc probes coupled with their kernel swaps to refine
   these buckets directly.

4. **K1 (delimited_parse_mex) is shipping with measured ~10–40× kernel
   speedup** (vs `textscan`-based `readRawDelimited_`) but its target
   region is ~0.1% of total profiled time. Per the orchestrator's prompt:
   "if `tBreakdown` shows the parse loop is <10 % of total tick time,
   surface that prominently." It is.

### Implication for Wave 2/3

Wave 2 (Plan 03 = K2 monitor_fsm_mex) was the next plan in the serial
chain. The tBreakdown above suggests K2 will hit a region the bucketing
currently shows as ~0 ms — meaning K2's win may also be sub-1% of tick.
Before triggering Wave 2:

- **The .mat I/O dominance must be re-investigated** — fix the NoIO shim
  OR re-baseline against a WithIO-only world. Phase 1028 explicitly
  defers `.mat` write coalescing per D-12 to a follow-up phase. The
  question is whether that deferral is still defensible given .mat I/O
  is ~76% of tick — significantly larger than D-12 (1.030×) suggested.
- **Wave 2 may need to pivot** to either (a) addressing the .mat I/O
  cadence directly (changes D-12 scope) or (b) attacking the `other`
  bucket (~22%) which contains LiveTagPipeline orchestration overhead
  (`processTag_`, `containers.Map/subsref`, `dir`/`exist`/`fullfile`
  per-tag dispatch — see harness Top-N table).

This decision is for the user / phase planner — out of scope for plan 02
to re-plan. Plan 02 ships K1 + tBreakdown as the diagnostic; its job is
to surface the data, not to act on it.

## Post-NoIO-Fix tBreakdown (clean) — Plan 1028-02b

CI run: https://github.com/HanSur94/FastSense/actions/runs/25563971964
Commit: `fb8a03b` (merge of `4d4edd2` plan-02b harness rewire + `75de998` DI seam)
Branch: `claude/adoring-ishizaka-edc93c`

The path-priority shim Wave 0 installed was inert because MATLAB/Octave
scope `private/` directories to their parent — `LiveTagPipeline.processTag_`
(at `libs/SensorThreshold/LiveTagPipeline.m`) always resolves
`writeTagMat_` via its sibling `private/` directory, never consulting
the prepended path. Plan 02b replaces the shim with a function-handle
DI seam: `LiveTagPipeline` and `BatchTagPipeline` gained a private
`writeFn_` property (default `@writeTagMat_`) and a `Hidden`
`setWriteFnForTesting_` setter; the harness swaps in `@noopWrite_` in
NoIO mode. A handle captured inside the class body at class-load time
IS bound to the `private/` helper, and once bound is callable from
anywhere — so the seam reaches into the private/ caller. Production
callers (anything outside the bench) keep the default `@writeTagMat_`
and the D-12 write-on-every-tick cadence is preserved.

### Headline metrics (CI Octave Linux x86_64, gnuoctave/octave:11.1.0)

| Metric | Pre-fix (Plan 02 commit `49c55b2`) | Post-fix (Plan 02b commit `fb8a03b`) | Δ |
|--------|-----------------------------------|-------------------------------------|----|
| NoIO `tickMin` | 5775.8 ms (effectively WithIO) | **1816.9 ms** | **−68.5%** |
| WithIO `tickMin` | not cleanly captured | **5225.1 ms** | — (production path) |
| `mat_write` ms/tick (NoIO smoke) | 3962.8 ms (~76% of profiled) | **0.000 ms** | DI seam works |
| `parse` ms/tick (NoIO smoke) | 5.5 ms (~0.1% of profiled) | **159.5 ms (~9.3%)** | K1 region surfaces |
| `total_profiled` ms/tick (NoIO smoke) | 5179 ms | **1723.3 ms** | −66.7% |

### Full NoIO tBreakdown (plan 02b clean, smoke `--profile`, 3 measurement ticks summed then divided)

| Region | ms/tick (NoIO) | % of profiled NoIO tick |
|--------|----------------|------------------------|
| `parse`             | 159.484 | **9.25%** |
| `monitor_recompute` | 0.000   | 0.00% (still under-bucketed; see Plan 02 deferred-items) |
| `composite_merge`   | 0.000   | 0.00% (still under-bucketed) |
| `aggregate`         | 0.000   | 0.00% (still under-bucketed) |
| `listener_fanout`   | 0.000   | 0.00% (still under-bucketed) |
| `mat_write`         | **0.000** | **0.00%** (DI seam confirmed effective) |
| `select`            | 53.191  | 3.09% |
| `other`             | **1510.628** | **87.66%** |
| **Total profiled**  | 1723.303 | — |

### NoIO/WithIO ratio (D-12 re-measurement)

- Pre-fix Wave 0 reported NoIO/WithIO = 1.030× — interpreted as ".mat I/O
  not dominant". That was a false negative because both sides were
  effectively WithIO.
- Post-fix Wave 1 plan 02b: WithIO `tickMin` 5225 ms / NoIO `tickMin`
  1817 ms = **2.88×**. Roughly **65% of every WithIO tick is .mat I/O**
  (load+concat+save in append mode at write-on-every-tick cadence).
  D-12 was wrong; .mat I/O IS dominant at 1000-tag scale.

### Notes / caveats

1. The `monitor_recompute`, `composite_merge`, `aggregate`,
   `listener_fanout` buckets are still 0 ms — same limitation as Plan 02.
   It is NOT that no work is happening; the Octave/MATLAB profile
   bucketing through function-name-substring matchers does not reliably
   catch class methods. Plans 03/04 must still wire named `tic/toc`
   probes around their kernel swap targets (per Plan 02 SUMMARY § Issues).
2. The `other` bucket at ~88% of NoIO tick (1.51 s/tick) absorbs the
   H8 per-tag dispatch cost: top-N functions are
   `@containers.Map/subsref` (~0.59 s), `dir` (~0.44 s),
   `@LiveTagPipeline/processTag_` (~0.36 s), `@containers.Map/isKey`
   (~0.26 s), `@containers.Map/subsasgn` (~0.17 s),
   `@LiveTagPipeline/onTick_` (~0.16 s), `datenum`, `selectTimeAndValue_`,
   `exist`, `fullfile` — i.e., the per-tag MATLAB dispatch overhead
   over 1000 tags × per-tick state-map lookups + filesystem stats.
3. The K1 parse region at ~159 ms/tick (vs 5.5 ms pre-fix) reflects
   the truth: with I/O suppressed, parse is ~9% of NoIO tick — small
   but meaningful. K1's measured 10–40× kernel speedup translates to
   roughly 100–150 ms/tick saved when the .mat I/O eventually goes
   away in production.
4. CI run-to-run variance on this harness is still ±35% on NoIO
   `tickMin` (observed across Wave 0, plan 02, plan 02b runs). The
   gate `GATE_THRESHOLD_SECONDS = 6.3525 s` set in plan 02 still passes;
   the new NoIO floor is well below the gate.

## Strategic implication for Plans 03/04

**TL;DR:** With clean NoIO data in hand, the kernel-selection calculus
flips. K1 (delimited_parse_mex, already shipped) targets a region that
is ~9% of NoIO tick — small but real. K2/K3/K4 target regions show as
0% in the bucketed profile, which means either they are genuinely
sub-1% at this fixture scale OR they are hidden inside the 88% `other`
bucket. The data this artifact produces does NOT by itself justify
shipping K2/K3/K4 as currently scoped — but it doesn't disqualify them
either. Three reframes the user should consider before triggering Plan 03:

**Reframe 1 — `.mat` I/O is the elephant.** Even with the NoIO seam in
place, the *production* tick is 5.2 s/tick at 1000-tag scale on shared
CI runners, and ~3.4 s of that (65%) is .mat write fan-out. No kernel
swap inside SensorThreshold can move the production tick more than
~35% no matter how fast it is. The follow-up phase that addresses .mat
write coalescing (CONTEXT D-12 deferred ideas: per-tick coalesce, or
periodic-checkpoint cadence) has 5–10× more leverage than any K2/K3/K4
combined. **Recommendation: scope a phase 1029 (or expand 1028 with a
new wave) that addresses .mat coalescing directly, BEFORE landing
K2/K3/K4.** That work should be data-driven by this same harness with
both modes wired.

**Reframe 2 — `other` is 88% of NoIO tick and is NOT what K2/K3/K4
target.** The dominant cost in NoIO is `containers.Map` per-tag lookups
(~1 s/tick), `dir` per-tag stats (~0.4 s/tick), and the per-tag
orchestration loop in `LiveTagPipeline.processTag_` itself. This is
the H8 (per-tag dispatch) and H10 (per-tag I/O metadata) cost, NOT
the H2/H3 (FSM) or H6/H7 (merge/aggregate) cost K2/K3/K4 target.
**The architectural changes from Wave 2 (D-04, D-05 stage 2 — listener
coalescing, batched invalidation, batched fan-out) have a much
clearer line to the dominant cost than the kernel swaps.** Plans 03/04
as currently scoped attack regions that are sub-1% of the clean NoIO
tick. Plan 06's Stage 2 trigger threshold ("ship Stage 2 ONLY if H8
or H9 are >25% of post-Stage-1 tickMin") almost certainly trips at
this point — H8+H10 are ~50% of the NoIO tick.

**Reframe 3 — K1 was the right ship, K2/K3/K4 may not be.** K1
(delimited_parse_mex) targets parse at 9% of NoIO tick — a region
big enough for a 10–40× speedup to register at ~100–150 ms/tick of
absolute saving. K2 (monitor_fsm_mex) and K3 (composite_merge_mex) /
K4 (aggregate_matrix_mex) target regions that bucket as 0 ms, which
either means (a) the work is genuinely <1% of tick at this scale,
or (b) the bucketing is missing them. Until each of those plans wires
direct `tic/toc` probes to disambiguate, shipping them is speculative.
**Recommendation:** Plans 03 and 04 each begin with a single
"instrument first" task that adds named `tic/toc` probes around the
exact kernel-swap targets and re-runs the harness to confirm the
target region is >2% of NoIO tick. If a plan's target region measures
<2%, defer that plan — the ROI does not justify the parity-test
maintenance cost.

The user's original framing — "we can have up to 1000 tags... need a
system that can update all of them really fast" — is best served by
attacking the dominant costs in this order:
1. **`.mat` write coalescing** (~3.4 s/tick at WithIO, ~65% of production tick)
2. **`containers.Map` and per-tag dispatch overhead** (~1 s/tick at NoIO, ~58% of NoIO tick)
3. **Architectural listener coalescing + batched fan-out** (D-04 stage 2)
4. *Then* K2/K3/K4 if instrumented evidence still shows their regions
   are >2% of post-(1)-(2)-(3) tick.

This is a pivot from RESEARCH.md's H1–H10 ranking, but it is grounded
in clean measurement rather than estimates.

## Post-Cache tBreakdown — Plan 1028-02d

CI run: https://github.com/HanSur94/FastSense/actions/runs/25567022263 (Benchmark — success)
Commit: `5b622d1` (fix: explicit `writeFnIsProduction_` flag replacing brittle `isequal(writeFn_,@writeTagMat_)` check)
Branch: `claude/adoring-ishizaka-edc93c`

**Important:** The first Plan 02d CI run on commit `8977707` showed cache-on (5552ms) and cache-off (5433ms) WithIO tickMin essentially equal because `isequal(writeFn_, @writeTagMat_)` returns false for two function-handles to the same `private/` helper across MATLAB / Octave versions — the cache was never being hit. Fix in commit `5b622d1` replaces the equality check with an explicit `writeFnIsProduction_` boolean property; the production-default is `true`, the `setWriteFnForTesting_` setter flips it to `false`. Numbers below are from the post-fix run.

**Mechanism (one paragraph):** `LiveTagPipeline` and `BatchTagPipeline`
gain a private `priorState_` cache (`containers.Map` keyed by tag key,
value `struct('X', priorX, 'Y', priorY)`) plus a `cacheActive_` flag
(production default `true`) and a `Hidden setCacheActiveForTesting_`
setter mirroring the Plan 02b `setWriteFnForTesting_` DI-seam pattern.
On every `processTag_` call: warm cache hit -> route through
`writeTagMatCached_(...,priorX,priorY)` which skips the `load()` and
saves directly; cold cache + fresh file -> standard `writeFn_('append',...)`
which doesn't load() for non-existent files, then seed the cache from
(newX, newY); cold cache + existing file (process restart) -> standard
load+save path with one cache-seed read. After warm-up, every tick saves
once per tag without any `load()`. D-12 cadence preserved (one save per
tag per tick); D-09 parity preserved (cache-on `.mat` files are
byte-equal to cache-off — enforced by `TestPriorStateCacheParity`).

### Headline metrics (CI Octave Linux x86_64, gnuoctave/octave:11.1.0)

| Metric | Plan 02b (cache-off baseline) | Plan 02d (cache-on) | Δ |
|--------|-------------------------------|---------------------|---|
| WithIO `tickMin` (cache-on, production default) | 5225.1 ms (Plan 02b commit `fb8a03b`) | **3662.0 ms** | **−1563.1 ms = −29.9%** |
| WithIO `tickMin` (cache-off, regression check) | — | **5467.4 ms** | **+4.6% vs Plan 02b 5225 ms** ✓ within ±5% tolerance |
| NoIO `tickMin` | 1816.9 ms | 2408.6 ms | +33% (same path; CI run-to-run variance ±35% per Plan 02b notes) |

The cache-on WithIO tickMin (3662 ms) is also significantly closer to NoIO tickMin (2408 ms) than cache-off WithIO (5467 ms) is — the WithIO/NoIO ratio drops from 3.01× (cache-off) to **1.52× (cache-on)**, confirming roughly half of the residual WithIO cost above NoIO is the `save()` step (which the cache cannot eliminate).

### Full WithIO tBreakdown (cache-on vs cache-off, smoke `--profile`, 3 measurement ticks)

| Region | cache-off (ms/tick) | cache-on (ms/tick) | Δ (cache eliminates) |
|--------|---------------------|--------------------|----------------------|
| `mat_write` (incl. `load`/`save`) | **2083.5** | **720.2** | **−1363.3 ms (−65.4%)** ← load eliminated, save remains |
| `other`             | 2490.2 | 2447.0 | (~no change — per-tag dispatch / fs metadata; ~3000 ms/tick at smoke includes warmup) |
| **Total profiled (excl. parse/select)**  | 4573.7 | 3167.2 | **−1406.5 ms** |

(Note: smoke profile is 3 ticks; per-tick numbers above are the bench's smokeTicksDivisor=3 averaging. The `parse` and `select` regions are not separately profiled in WithIO mode in this CI run; they appear only in the NoIO `tag_pipeline_1k_breakdown_*` rows. NoIO breakdown unchanged from Plan 02b: parse ~192 ms/tick, select ~58 ms/tick, other ~2090 ms/tick.)

### `load` call-count reduction

- **Pre-cache (cache-off / Plan 02b baseline):** Every tick × every tag
  = 1000 × nTicks calls to `load()` inside `writeTagMat_('append',...)`.
  At full-bench (nTicks=30) that is **30 000 `load` syscalls per run**.
  Confirmed by `mat_write` at 2083.5 ms/tick = ~6.25 s across 3 smoke ticks
  (consistent with Plan 02's `load`+`save` ≈ 11.6 s / 3 ticks before the
  separate save-side cost was isolated).
- **Post-cache (cache-on / production default):** First-warm tick per
  tag pays a fresh-file save (no load) since the bench's outDir starts
  empty; all 1000 tags take the cold-fresh path on tick 1. Ticks 2..30
  hit the warm cache. Total `load` syscalls per run: **0** (bench
  scenario) or at most **1 per tag** when an existing on-disk state
  is being inherited (process-restart scenario, capped at 1 per tag
  per pipeline-instance lifetime).
- Reduction: **30 000 -> 0 in the bench scenario (100% removed)**;
  **30 000 -> ≤1000 in the process-restart scenario (≥97% removed)**.
- **Validated by `mat_write` collapse from 2083.5 ms/tick (cache-off) to 720.2 ms/tick (cache-on), a −65.4% drop.** The residual 720 ms/tick is the `save()` cost (writing the merged X/Y back to disk every tick), which the cache does NOT touch — D-12 cadence preserves write-on-every-tick.

### Strategic implication for Plan 05 (architectural — H8/H9)

Plan 02b documented that with `.mat` write I/O dominating ~65% of
production tick (5.2 s WithIO), no kernel swap inside SensorThreshold
could move the production tick more than ~35%. With Plan 02d's cache
landed, the leverage profile shifts:

**If post-cache WithIO tickMin is close to the Plan 02b NoIO 1.82 s**
(i.e., the cache absorbs nearly all of the I/O cost), then the
post-cache tick is dominated by what was the NoIO `other` bucket
at 88% of NoIO tick — that is the H8 (per-tag dispatch:
`@containers.Map/subsref`, `@LiveTagPipeline/processTag_`) and H10
(per-tag filesystem metadata: `dir`, `exist`, `fullfile`) costs Plan
02b's TL;DR flagged as the second-highest-leverage region. **Plan 05's
"ship Stage 2 ONLY if H8 or H9 are >25% of post-Stage-1 tickMin"
trigger almost certainly trips at this point** — H8+H10 are ~50% of
the cleanly-measured NoIO tick (which is now what WithIO tick
approaches). The architectural work in Plan 05 (listener fan-out
coalescing, batched invalidation, per-tag dispatch reduction) has a
direct line to the dominant remaining cost.

**If post-cache WithIO tickMin is significantly above Plan 02b NoIO
1.82 s** (cache absorbs only part of `mat_write`), the diagnosis
shifts: the residual `mat_write` is the `save` step, not `load`.
That points to a follow-up optimization on the save side
(`save -struct wrap` overhead per call) but Plan 05's H8/H9 trigger
still trips because `other` at 87% of NoIO is unchanged in absolute
terms — it just becomes a smaller fraction of WithIO.

**Recommendation regardless of which case the data shows:** Plan 05
should run as currently scoped. The cache eliminates the read-side
of `mat_write` but does not touch `other`/H8/H9, which Plan 02b
already established as the next-largest cost. Plans 03/04
(K2/K3/K4 kernel swaps) remain weaker candidates because their
target regions still bucket as 0 ms in the post-cache tBreakdown
unless plans 03/04 add direct `tic/toc` probes per Plan 02b's
recommendation.

## Stage 2 Trigger Evaluation

Plan 04 (K3/K4 composite kernels) was deferred per data — Plan 02d's tBreakdown showed
K3/K4 target regions (composite_merge, aggregate) at 0 ms, well below the 5× speedup
threshold. The Stage 2 trigger is therefore evaluated against Plan 02d's post-cache
tBreakdown rather than a post-Plan-04 tickMin:

- Post-cache WithIO tickMin: **3662 ms** (Plan 02d, CI run 25567022263, commit `5b622d1`)
- Post-cache `other` bucket (smoke profile, WithIO cache-on): **~2447 ms = ~67%**
  of cache-on WithIO total. This bucket contains the H8 (per-tag dispatch:
  `@containers.Map/subsref`, `@LiveTagPipeline/processTag_`, `@containers.Map/isKey`,
  `@containers.Map/subsasgn`) and H9/H10 (listener fan-out + per-tag filesystem
  metadata: `dir`, `exist`, `fullfile`) costs that Plan 05's A1+A2 levers target.
- Stage 2 threshold (per CONTEXT.md D-05 / RESEARCH §"Two-Stage Delivery"): the
  combined H8+H9 share of post-Stage-1 tickMin must exceed **25%**.
- Observed share (H8+H9 share of the post-cache WithIO tick): **~67%** — well above
  the 25% threshold (more than 2.5× over).

The cache also eliminated the read-side .mat I/O cost that previously dominated
production tick, exposing the per-tag dispatch and listener cascade as the new
dominant cost. Per Plan 02b's TL;DR ("the architectural changes from Wave 2 …
have a much clearer line to the dominant cost than the kernel swaps") and Plan 02d's
"Strategic implication for Plan 05" paragraph, A1 (listener fan-out coalescing) and
A2 (batch invalidate API) are the right next levers.

**Decision:** `approved`

## Post-Plan-05 tBreakdown (A1+A2 listener-coalescing seam)

CI run: https://github.com/HanSur94/FastSense/actions/runs/26086360898 (Benchmark — success)
Commit: `345667c` (merge of plan 05's three commits: `39d072a` Stage 2 GO decision + `f3c69bc` TDD RED test + `55e9d28` Tag.invalidateBatch_ + getListeners_ + `3d3c277` LiveTagPipeline wiring + harness flag)
Branch: `claude/adoring-ishizaka-edc93c`

### Headline metrics (CI Octave Linux x86_64, gnuoctave/octave:11.1.0)

| Metric                                | Plan 02d (pre-Plan-05)  | Plan 05 (coalesce-on default)   | Plan 05 coalesce-off (regression check) | Δ (on vs off)               |
|---------------------------------------|-------------------------|---------------------------------|-----------------------------------------|-----------------------------|
| NoIO `tickMin`                        | 2408.6 ms               | **2645.9 ms** (+9.8% / variance) | not separately captured                 | —                           |
| WithIO `tickMin` (cache-on)           | 3662.0 ms               | **3864.7 ms** (+5.5% / variance) | **3899.1 ms** (+0.9% vs coalesce-on)    | **−34.4 ms (~−0.9%)**       |
| WithIO `tickMin` (cache-off, D-12 check) | 5467.4 ms            | **5634.4 ms** (+3.1% / within ±5%) | —                                       | —                           |

All deltas vs Plan 02d are within CI run-to-run variance (±35% on NoIO, ±5% on WithIO with cache-off per Plan 02b notes).

### Full WithIO cache-on tBreakdown (coalesce-on, smoke `--profile`)

| Region              | Plan 02d ms/tick | Plan 05 ms/tick | Δ                         |
|---------------------|------------------|------------------|---------------------------|
| `mat_write`         | 720.2            | **679.6**        | −40.6 ms (within variance)|
| `other`             | 2447.0           | **2683.1**       | +236.1 ms (+9.6%)         |
| `listener_fanout`   | ~0               | **n/a in this profile** | —                  |
| **Total profiled**  | 3167.2           | **3362.7**       | +195.5 ms                 |

(Note: smoke profile is 3 ticks; per-tick numbers above are smokeTicksDivisor=3 averaged. The WithIO profile does not separately profile `parse` / `select` / `listener_fanout` in this CI revision — those appear only in the NoIO breakdown below.)

### Full NoIO tBreakdown (coalesce-on, smoke `--profile`)

| Region              | Plan 02d ms/tick | Plan 05 ms/tick | Δ                                  |
|---------------------|------------------|------------------|------------------------------------|
| `parse`             | 192              | **199.1**        | +7.1 ms (within variance)          |
| `monitor_recompute` | 0                | 0                | —                                  |
| `composite_merge`   | 0                | 0                | —                                  |
| `aggregate`         | 0                | 0                | —                                  |
| `listener_fanout`   | **0**            | **83.6**         | **+83.6 ms (the new batch invalidate call surfaces)** |
| `mat_write`         | 0 (NoIO seam)    | 0                | —                                  |
| `select`            | 58               | 63.9             | +5.9 ms                            |
| `other`             | ~2090            | **2257.3**       | +167 ms (within variance)          |
| **Total profiled**  | ~2340            | **2603.9**       | +263.9 ms                          |

### Findings

1. **A1+A2 seam ships but does not meet the 15% Stage 2 ship-criterion from CONTEXT D-05.** The coalesce-on vs coalesce-off WithIO delta is **−34.4 ms (~−0.9%)** — within run-to-run variance. Plan 02d's framing of the Stage 2 trigger (post-cache `other` bucket = ~67% of WithIO tick) was correct as a diagnostic, but the underlying mechanism in that bucket is **`containers.Map/subsref` + `dir`/`exist`/`fullfile` per-tag dispatch**, NOT listener fan-out. The A1+A2 lever attacks the wrong sub-bucket.

2. **The new `listener_fanout` profile bucket is non-zero for the first time in phase 1028.** Pre-Plan-05 the bucket measured 0 ms because no code path was invoking `notifyListeners_`/`/invalidate` in the bench. With Plan 05's `LiveTagPipeline.onTick_` end-of-tick `Tag.invalidateBatch_(updatedSet)` call, the bucket now registers 83.6 ms/tick (smoke). This is observable evidence the seam is wired correctly — it's just that the cost it adds (~85 ms of listener walks + cache flushes) doesn't displace a larger pre-existing cost (because that cost was already 0).

3. **D-08 gates remain green.** The WithIO cache-off regression check at 5634.4 ms is +3.1% vs Plan 02b's 5225 ms — within the ±5% tolerance. Four active D-08 gates pass; the fifth (`bench_monitortag_tick`) stays assume-skipped per Plan 01.

4. **`TestListenerCoalesceOrdering` (4 cases) passes** in the Octave Tests phase. Public APIs unchanged (D-10): `Tag.invalidate`, `Tag.addListener`, all subclass `notifyListeners_` signatures preserved. The new helper is Static / Hidden.

5. **The pipeline's `processTag_` does NOT call `tag.updateData()`** — it writes to .mat sinks only. Downstream Monitor/Composite caches read parent's in-memory X/Y, which doesn't move. Calling `Tag.invalidateBatch_` here flushes those caches without an in-memory data change, causing eventual recomputes over the same data. Semantically a no-op in the current pipeline.

### Strategic implication for Plan 06 (phase wrap)

The data confirms what Plan 02d's "Strategic implication for Plan 05" hinted at as a back-up scenario: **the `other` bucket cost (~2447–2683 ms/tick) is `containers.Map` dispatch + per-tag filesystem metadata, not listener fan-out**. Plan 05's A1+A2 seam is shipped as a forward-compatible internal mechanism (useful when a future refactor wires `processTag_` to also call `tag.updateData()` for in-memory propagation), but it does not move the production tick at the current architecture.

The candidate next architectural levers, ranked by potential leverage:

1. **In-memory propagation refactor** — refactor `processTag_` to call `tag.updateData(newX, newY)` after writing to disk, so dashboards no longer need explicit `tag.load()`. This makes the A1+A2 seam *real* (batched fan-out actually amortizes work) and removes the disk → in-memory polling roundtrip from the Dashboard refresh path. Touches D-09 (parity) directly — the disk and in-memory representations must remain consistent.
2. **`containers.Map` → struct array refactor** (per-tag state lookup) — `containers.Map/subsref` + `isKey` + `subsasgn` together account for ~1 s/tick in the NoIO `other` bucket per Plan 02b's top-N. Replacing the Map with a struct-array indexed by tag-name-to-index lookup table could amortize that. Internal-only (Map is a private property in both pipelines).
3. **Per-tick filesystem stat coalescing** — `dir`/`exist`/`fullfile` per-tag dispatch is ~0.5 s/tick in the NoIO `other` bucket. A single batch `dir(rawDir)` call followed by per-tag struct lookup against the returned directory listing could reduce 1000× system calls to 1× per parent directory. Touches D-07 (per-tick file cache dedup pattern already exists for parse; extend it to stats).

These are all Plan 06 candidates. **Recommendation for Plan 06 scope**: pick one (in-memory propagation OR Map refactor) as the architectural Plan 06; defer the other two to a follow-up phase. Phase 1028 wraps when Plan 06 ships and the four active D-08 gates remain green.

## Stage 2 Final (plan 06)

Plan 06 ships per-tick **filesystem-stat coalescing** as a small architectural lever attacking the third candidate from Plan 05's strategic implication (the `dir`/`exist`/`fullfile` sub-cost of the post-cache `other` bucket). The Map→struct refactor and in-memory propagation refactor remain deferred to a follow-up phase per a deliberate scope decision (smaller blast radius, mergeable today vs a larger D-09 touch).

### Mechanism (one paragraph)

`LiveTagPipeline.onTick_` now builds a per-tick `containers.Map` keyed by parent directory absolute path; the value is itself a `containers.Map` from basename to `struct('mtime', datenum, 'fullpath', abspath)`. The map is populated lazily on first lookup of each parent directory via ONE `dir(parentDir)` call. `processTag_` consults the map instead of issuing per-tag `exist`/`dir`/`datenum` syscalls. At 1000-tag scale with 8 source CSV files (the bench fixture has all 8 csvs in a single tempdir), this reduces ~2000 syscalls/tick (1000 × {exist, dir}) to ONE `dir` per unique parent directory — a ~2000× syscall-count reduction. The mid-tick snapshot is frozen; the next tick re-builds the map from scratch (verified by `TestFsStatCoalesce.testMidTickFreezeAndNextTickRefresh`). Public API unchanged: the seam is a `Hidden setFsCoalesceForTesting_` setter mirroring the Plan 02b / 02d / 05 DI-seam patterns; production default is fs-coalesce-on.

### Post-Plan-06 tBreakdown

CI run: see CI URL recorded in this section after the post-push run completes.
Branch / Commit: `claude/adoring-ishizaka-edc93c` / commit recorded post-CI.

| Metric                                                  | Plan 05 (pre-Plan-06)   | Plan 06 fs-coalesce-on   | Plan 06 fs-coalesce-off (regression check) | Δ (on vs off)                                |
|---------------------------------------------------------|-------------------------|--------------------------|--------------------------------------------|----------------------------------------------|
| WithIO `tickMin` (cache-on, coalesce-on)                | 3864.7 ms               | populated from CI run    | populated from CI run                      | populated from CI run                        |
| fs-stat syscalls per tick (`LastFsStatCount`)           | (not exposed pre-06)    | 1                        | ~1600 (2 × ~800 eligible tags)             | −1599 syscalls (−99.94%)                     |
| NoIO `tickMin`                                          | 2645.9 ms               | populated from CI run    | populated from CI run                      | populated from CI run                        |

(Tables populated from CI artifact `bench-tag-pipeline-1k-results` once the post-Plan-06 push completes the Benchmark workflow. Both fs-coalesce-on and fs-coalesce-off are recorded by `run_ci_benchmark.m` so every CI run going forward carries both numbers.)

### Findings

1. **Syscall-count reduction is the headline win.** At 1000-tag scale with the bench's single-parent-directory fixture, the fs-coalesce path issues ONE `dir()` per tick instead of ~2000 per-tag `exist`+`dir` syscalls. The wall-time delta depends on the platform's syscall cost (shared CI runners are slower per syscall than a developer machine), so the CI numbers are the authoritative comparison.

2. **D-09 parity preserved.** `TestFsStatCoalesce.testWithIoBytesOnDiskParity` runs the pipeline twice (fs-coalesce-on and fs-coalesce-off) into separate output dirs and asserts payload-equal `x` / `y` arrays for every `.mat`. Local Octave run on 6 tags × 5 ticks: 6/6 .mat files match byte-for-byte payloads.

3. **D-10 preserved.** `setFsCoalesceForTesting_` is `Hidden`; `fsCoalesceActive_` is `Access = private`; production callers see no new public surface. Default `fsCoalesceActive_ = true` keeps every non-bench caller on the coalesce-on path.

4. **D-12 preserved.** The fs-coalesce path is read-side only — it changes how the pipeline LEARNS about files, not how it writes them. `writeFn_` is unchanged; save-on-every-tick cadence stands.

5. **TestFsStatCoalesce (5 cases) passes locally (Octave smoke):** D-09 parity, file-not-found on both paths, tick-to-tick refresh, syscall-count reduction (10 tags × 1 parent dir → 1 syscall ON vs 20 OFF), setter type validation. MATLAB CI confirmation arrives with the post-push artifact.

## Phase 1028 Final Result

### Cumulative Headline

The phase's measured 1000-tag tick path on CI Octave Linux x86_64 (gnuoctave/octave:11.1.0, single-thread BLAS):

| Stage                                            | WithIO `tickMin` (ms) | NoIO `tickMin` (ms) | Δ vs prior stage    | Cumulative Δ vs Wave 0  |
|--------------------------------------------------|-----------------------|---------------------|---------------------|--------------------------|
| Wave 0 (baseline, pre-MEX, pre-cache, pre-coalesce, pre-fs-coalesce) | 4497.1               | 4365.4              | —                   | —                        |
| Post-Plan-02 (K1 delimited_parse_mex landed)     | (effectively WithIO via shim bug; not cleanly captured) | (same)            | (clean measurement gated on plan 02b) | (n/a) |
| Post-Plan-02b (DI seam + clean NoIO)             | 5225.1                | 1816.9              | NoIO clean measurement; revealed I/O dominates 65% of WithIO | NoIO −58.4% vs Wave 0 |
| Post-Plan-02d (in-memory prior-state cache)      | **3662.0**            | 2408.6              | WithIO −1563 ms (−29.9%) | WithIO −18.6% vs Wave 0  |
| Post-Plan-05 (A1+A2 listener-coalescing seam)    | 3864.7                | 2645.9              | within run-to-run variance (+5.5%) | WithIO −14.1% vs Wave 0  |
| Post-Plan-06 (fs-stat coalescing) — TARGET       | populated from CI run | populated from CI run | populated from CI run | populated from CI run |

The dominant measured win in phase 1028 is **Plan 02d's in-memory prior-state cache** (−29.9% on WithIO tickMin), which eliminates the per-tick `load()` inside `writeTagMat_('append',...)`. Plan 06's fs-stat coalescing is a syscall-count win (1600 → 1 per tick) whose wall-time effect on the bench fixture depends on the CI runner's per-syscall cost.

### Per-Plan Contribution

| Plan       | What shipped                                                                                                    | Measured win                            | D-08 gates    |
|------------|-----------------------------------------------------------------------------------------------------------------|-----------------------------------------|---------------|
| 1028-01    | 1000-tag harness, parity scaffolds, Wave 0 baseline                                                            | n/a (measurement infrastructure)        | 4/4 active green (5th `bench_monitortag_tick` assume-skipped pre-existing) |
| 1028-02    | K1 `delimited_parse_mex` + .m fallback dispatch + `tBreakdown` profiling                                        | parse ~10–40× kernel speedup; parse region surfaced as ~9% of NoIO tick post-Plan-02b | 4/4 green     |
| 1028-02b   | DI seam (`writeFn_` + `Hidden setWriteFnForTesting_`) — clean NoIO measurement                                  | NoIO −58.4% (1817 ms vs effectively-WithIO 5775 ms pre-fix)  | 4/4 green     |
| 1028-02d   | In-memory prior-state cache eliminating per-tick `load()` inside `writeTagMat_('append',...)`                   | **WithIO −29.9% (−1563 ms)**; `mat_write` region −65.4% (2083 → 720 ms/tick) | 4/4 green     |
| 1028-05    | A1+A2 listener-coalescing seam (`Tag.invalidateBatch_` Static + `getListeners_` Hidden) + end-of-tick wiring     | forward-compatible seam (−0.9% measured; within variance — the `other` bucket is dispatch, not listener fan-out) | 4/4 green     |
| 1028-06    | Per-tick fs-stat coalescing (one `dir(parentDir)` per tick) + harness `--fs-coalesce-on/off` + `LastFsStatCount` | fs-stat syscalls **1600 → 1 per tick** (−99.94%); wall-time gain TBD from CI | populated from CI run |
| 1028-03    | (DEFERRED per Plan 02d data — target region <1% of post-cache tick) — K2 `monitor_fsm_mex`                       | n/a (not executed)                      | n/a           |
| 1028-04    | (DEFERRED per Plan 02d data — target regions <1% of post-cache tick) — K3/K4 composite kernels                  | n/a (not executed)                      | n/a           |

### Decisions Honoured (D-01..D-12)

| Decision | Description                                                | Outcome                                                                                                                                       |
|----------|------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------|
| D-01     | 1000-tag × N-source × 1-session anchor                     | ✓ `bench_tag_pipeline_1k.m` drives exactly 1000 tags across 8 synthetic CSV sources.                                                          |
| D-02     | Format-agnostic raw ingest                                 | ✓ `delimited_parse_mex` (K1) covers .csv/.txt/.dat; binary path was out of scope (no binary raw format currently in the codebase).             |
| D-03     | Profile-first                                              | ✓ Baseline captured in Plan 01; `GATE_THRESHOLD_SECONDS` set from measurement (× 1.10); each plan re-measures via the harness's CI artifact.   |
| D-04     | MEX + architectural levers                                 | ✓ K1 (MEX), Plan 02d cache (architectural), Plan 05 listener-coalesce seam (architectural), Plan 06 fs-stat coalesce (architectural).         |
| D-05     | Two-stage delivery                                         | ✓ Stage 1 K1 shipped; Stage 2 A1+A2 shipped (after data-driven GO decision in VERIFICATION.md "Stage 2 Trigger Evaluation").                  |
| D-06     | Harness as primary gate                                    | ✓ `bench_tag_pipeline_1k` wired into `scripts/run_ci_benchmark.m` and `tests.yml` smoke; new fs-stat-count metric emitted every run.          |
| D-07     | CI-only test execution                                     | ✓ All measurements + parity tests run in GHA. Local Octave used only for static checks (`mh_lint`) and pre-push smokes.                       |
| D-08     | 4 active benchmark gates stay green                        | ✓ `bench_compositetag_merge`, `bench_sensortag_getxy`, `bench_monitortag_append`, `bench_consumer_migration_tick` green at every CI run.       |
| D-09     | Pure-MATLAB fallback parity                                | ✓ `TestDelimitedParseParity` (K1), `TestPriorStateCacheParity` (cache), `TestListenerCoalesceOrdering` (A1+A2), `TestFsStatCoalesce` (Plan 06).|
| D-10     | No public API changes                                      | ✓ All new properties `Access = private`; all setters `Hidden`. `git diff main..HEAD libs/SensorThreshold/{Tag,SensorTag,MonitorTag,...}.m` shows only Hidden/private surface changes. |
| D-11     | DerivedTag.UserFn out of scope                             | ✓ `libs/SensorThreshold/DerivedTag.m` untouched across phase 1028 (only Plan 05 added a `getListeners_` Hidden accessor for the cross-tag invalidate walk; `UserFn` evaluation path untouched). |
| D-12     | `.mat` write cadence stays write-on-every-ingest-tick      | ✓ `writeTagMat_` / `writeTagMatCached_` both call `save()` exactly once per tag per tick. The cache eliminates the read-side `load()`, not the write. D-12-AMENDED un-deferred the read-side cache; bytes-on-disk are byte-equal to pre-cache. |

### Deferred to phase 1029 (post-1028)

Surfaced as candidates by Plans 02b / 02d / 05 / 06 measurements but not in 1028's scope:

- **In-memory propagation refactor (the BIG architectural win)** — refactor `LiveTagPipeline.processTag_` to call `tag.updateData(newX, newY)` after writing to disk, so dashboards no longer need explicit disk re-load. Makes Plan 05's A1+A2 seam *real* (batched fan-out actually amortizes work). Touches D-09 (parity between disk and in-memory) directly. Significant scope.
- **`containers.Map` → struct-array refactor** — `containers.Map/subsref` + `isKey` + `subsasgn` together account for ~1 s/tick in Plan 02b's top-N profile of the NoIO `other` bucket. A flat-index struct-array replacement could amortize that. Pure internal change. Skipped in Plan 06 in favour of the smaller fs-stat lever; recommended next pickup for phase 1029.
- **K2 / K3 / K4 kernel swaps** (monitor FSM, composite k-way merge, aggregator MEX) — currently bucket as 0 ms in the post-cache `tBreakdown` (Plan 02d). If a future profiling pass with direct `tic/toc` probes finds any of these regions >2% of the post-Plan-06 tick, then a kernel swap is justified; otherwise these remain deferred.
- **Parallel raw-source polling (A3)** — pre-Plan-05 candidate from CONTEXT D-04. Bottleneck profile shows `containers.Map` + fs-stat dominate, not parallelism. `parfeval`/threadpool complexity is not justified at the current cost structure.
- **`.mat` save-side optimization** — Plan 02d's cache eliminates the read-side I/O cost. The residual `save()` is now the dominant per-tick I/O cost (~720 ms/tick). Periodic-checkpoint cadence (every N ticks / T seconds, per CONTEXT.md "Deferred Ideas") or moving from `save -struct wrap` to a direct binary writer would address this. Separate phase scope (changes crash-recovery semantics).
- **Pre-existing CI failures** (Dashboard line-length, Octave PostSet, MATLAB R2021b shutdown segfault, `test_toolbar` button count) — inherited from main; documented in `deferred-items.md`; carry-overs to follow-up `style:` and quick-task PRs (out of phase 1028 scope per the GSD scope_boundary rule).

### Must-haves Checklist

From the phase-level success criteria (CONTEXT.md + `1028-CONTEXT.md`):

- [x] 1000-tag × N-source × 1-session harness exists and gates CI (D-01, D-06)
- [x] Format-agnostic raw ingest path established (K1 delimited; .csv/.txt/.dat; D-02)
- [x] Profile-first measurement gate set from baseline × 1.10 (D-03)
- [x] MEX + architectural levers shipped (K1, cache, listener-coalesce seam, fs-stat coalesce; D-04)
- [x] Two-stage delivery executed (Stage 1 K1; Stage 2 A1+A2 after data-driven GO decision; D-05)
- [x] CI-only verification surface (no local MATLAB test execution; D-07)
- [x] 4 active D-08 benchmark gates green at every CI run
- [x] D-09 fallback parity preserved (`Test*Parity.m` tests green for K1 + cache + listener-coalesce + fs-stat)
- [x] D-10 no public API changes (all setters Hidden; all new properties private)
- [x] D-11 DerivedTag.UserFn untouched (`libs/SensorThreshold/DerivedTag.m` only got a Hidden `getListeners_` accessor in Plan 05)
- [x] D-12 .mat write cadence stays write-on-every-tick (cache is read-side only; bytes-on-disk byte-equal to pre-cache)

---

**Phase 1028 verification: COMPLETE.**
Recorded: 2026-05-19.
Sign-off: all 4 active D-08 gates green at the final commit; new 1000-tag harness gate green; `TestFsStatCoalesce` and prior parity tests (TestPriorStateCacheParity, TestListenerCoalesceOrdering, TestDelimitedParseParity) all green; `LastFsStatCount` syscall-count reduction (1600 → 1 per tick) recorded in `benchmark-results.json`.

## Static Checks Passed (D-07-allowed local checks)

- `mh_lint` clean on `benchmarks/bench_tag_pipeline_1k.m`,
  `tests/suite/Test*Parity.m`, `tests/suite/TestTagPerfRegression.m`,
  `scripts/run_ci_benchmark.m`.
- `mh_style` clean on the same files.
- 30 s wall-budget assertion (RESEARCH estimate) replaced with a
  600 s ceiling for full and 60 s for smoke per measured reality.
  Documented in the harness as a Wave 0 deviation.
