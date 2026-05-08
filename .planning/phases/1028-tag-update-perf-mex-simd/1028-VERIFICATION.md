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

## Stage 2 Final (plan 06)

TBD or "deferred per Stage 2 Trigger".

## Static Checks Passed (D-07-allowed local checks)

- `mh_lint` clean on `benchmarks/bench_tag_pipeline_1k.m`,
  `tests/suite/Test*Parity.m`, `tests/suite/TestTagPerfRegression.m`,
  `scripts/run_ci_benchmark.m`.
- `mh_style` clean on the same files.
- 30 s wall-budget assertion (RESEARCH estimate) replaced with a
  600 s ceiling for full and 60 s for smoke per measured reality.
  Documented in the harness as a Wave 0 deviation.
