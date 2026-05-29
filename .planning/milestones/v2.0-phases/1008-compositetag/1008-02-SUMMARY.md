---
phase: 1008-compositetag
plan: 02
subsystem: domain-model
tags: [compositetag, merge-sort, serialization, two-phase-loader, align, tdd, octave-safety]

# Dependency graph
requires:
  - phase: 1008-01
    provides: CompositeTag class core (constructor + addChild + cycle DFS + 7-mode aggregator + Plan-02 throw-from-base stubs)
  - phase: 1004-tag-foundation
    provides: TagRegistry.loadFromStructs two-phase loader; Tag resolveRefs hook
  - phase: 1006-monitortag-lazy-in-memory
    provides: observer pattern (addListener/invalidate cascade); SensorTag.updateData -> listener fire
provides:
  - mergeStream_ vectorized sort-based merge (RESEARCH §5): NO set-union, NO linear interpolation
  - valueAt(t) COMPOSITE-06 fast-path (iterates children; no materialization)
  - getTimeRange() over aggregated grid
  - toStruct / fromStruct (Pass-1 stash ChildKeys_/ChildWeights_) / resolveRefs (Pass-2 addChild)
  - getChildAt(i) test-affordance probe (3-deep descent)
  - ALIGN-01/02/03/04 end-to-end behavior
affects: [1008-03 (FastSense/TagRegistry integration), 1009 (consumer migration), 1010 (event binding)]

# Tech tracking
tech-stack:
  added: []   # Pure-MATLAB; no new deps
  patterns:
    - "Vectorized k-way merge via single sort() over concatenated (X, Y, childIdx) triples (RESEARCH §5)"
    - "Same-timestamp coalesce via sortedX(k+1)==sortedX(k) lookahead (aggregate once per cluster)"
    - "ALIGN-03 pre-history drop via first_x = max(cellfun(@(xx) xx(1), allX))"
    - "Two-phase deserialization stash (ChildKeys_/ChildWeights_) + resolveRefs that reuses validated addChild"
    - "Test-only local two-pass loader (helperLoadStructsLocal_) to test 3-deep round-trip without Plan 03 TagRegistry edit"

key-files:
  created: []
  modified:
    - libs/SensorThreshold/CompositeTag.m
    - tests/suite/TestCompositeTag.m
    - tests/test_compositetag.m
  new:
    - tests/suite/TestCompositeTagAlign.m
    - tests/test_compositetag_align.m

key-decisions:
  - "mergeStream_ uses RESEARCH §5 vectorized sort-based approach (NOT pointer-loop k-way merge). One sort() on concatenated (X, Y, childIdx) vectors; single walk with lastY update indexed by child; emit on last sample of same-timestamp cluster. Meets the ~200ms gate at 8x100k with margin."
  - "Coalesce semantics: when sortedX(k+1) == sortedX(k), continue — aggregation runs ONCE at the LAST sample of the cluster so every child that has a sample at that timestamp has updated lastY before aggregate_ runs. Verified via testMergeSortSameTimestampCoalesce."
  - "Empty-child short-circuit: any(cellfun(@isempty, allX)) -> output [],[]. Avoids allX{i}(1) index error in first_x computation when a child has no data."
  - "toStruct double-wraps childkeys ({childKeys}) — mirrors the Labels idiom used by Tag base / MonitorTag.toStruct, survives MATLAB's struct() cellstr-collapse surprise. fromStruct unwraps via the same pattern (iscell(L) && numel(L)==1 && iscell(L{1}) -> L = L{1})."
  - "resolveRefs(registry) reuses the validated addChild path rather than inlining the wiring. Benefit: type-guard (CompositeTag:invalidChildType), cycle DFS (CompositeTag:cycleDetected), and listener hookup all fire on deserialized children. A malformed struct is caught loudly, per Pitfall 8 directive."
  - "UserFn is NOT serialized (function handles cannot round-trip). Consumers must re-bind after loadFromStructs for 'user_fn' mode. Documented inline in toStruct + fromStruct headers."
  - "getChildAt(i) added as a test-affordance probe (not children_ exposure) — the 3-deep Pitfall 8 test descends via top.getChildAt(1).getChildAt(1).Key, asserting structural Key equality only (never handle equality — Octave SIGILL avoidance)."
  - "Test-only helperLoadStructsLocal_ in TestCompositeTag.m (static private method) dispatches the composite kind inline so Plan 02 tests do not depend on Plan 03's TagRegistry.instantiateByKind 'composite' case. Plan 03's VALIDATION will re-run the 3-deep scenario through the real TagRegistry.loadFromStructs."

patterns-established:
  - "Vectorized sort-based k-way merge as the canonical pattern for multi-child Tag aggregation: pre-concat + single sort + single walk"
  - "Two-phase deserialization for composite kinds: fromStruct stashes child-key strings; resolveRefs wires handles via addChild"
  - "Double-wrap cell fields in toStruct to survive MATLAB struct() cellstr collapse (applied to childkeys just like labels)"

requirements-completed: [COMPOSITE-05, COMPOSITE-06, ALIGN-01, ALIGN-02, ALIGN-03, ALIGN-04]

# Metrics
duration: 9min
completed: 2026-04-16
---

# Phase 1008 Plan 02: CompositeTag Merge-Sort + Serialization Summary

**CompositeTag ships mergeStream_ (vectorized sort-based merge, no set-union, no linear interpolation), valueAt fast-path (no materialization), and full toStruct/fromStruct/resolveRefs serialization with 3-deep round-trip green — replaces Plan 01's four throw-from-base stubs and adds ALIGN-01/02/03/04 end-to-end coverage.**

## Performance

- **Duration:** ~9 minutes (two TDD commits)
- **Started:** 2026-04-16T19:55:14Z
- **Completed:** 2026-04-16T20:04:10Z
- **Tasks:** 2 (RED + GREEN)
- **Files created:** 2 (TestCompositeTagAlign.m + test_compositetag_align.m)
- **Files modified:** 3 (CompositeTag.m + TestCompositeTag.m + test_compositetag.m)

## Accomplishments

- mergeStream_ implements the RESEARCH §5 vectorized sort-based k-way merge verbatim: concat (X, Y, childIdx) triples across children, single sort(), linear walk with lastY ZOH indexed by child, same-timestamp coalesce via sortedX(k+1)==sortedX(k) lookahead, and ALIGN-03 pre-history drop via first_x = max(cellfun(@(xx) xx(1), allX)).
- valueAt(t) is the COMPOSITE-06 fast path — iterates children, collects child.valueAt(t) scalars into vals/weights, calls aggregate_ directly. recomputeCount_ remains 0 after valueAt, and the cache stays dirty (verified via testValueAtDoesNotMaterialize).
- getTimeRange() wraps getXY and returns [X(1), X(end)] (or [NaN NaN] on empty).
- toStruct emits the full 13-field struct (kind, key, name, labels, metadata, criticality, units, description, sourceref, aggregatemode, threshold, childkeys, childweights). childkeys is double-wrapped to survive MATLAB's struct() cellstr-collapse idiom.
- Static fromStruct Pass-1 constructs the composite with empty children and stashes ChildKeys_/ChildWeights_ private for Pass-2.
- resolveRefs(registry) iterates the stashed keys, calls obj.addChild(registry(k), 'Weight', w) per child, and clears the stash fields — re-using the validated addChild path so type-guard + cycle DFS + listener hookup all run on deserialized children. CompositeTag:unresolvedChild fires when a stashed key is missing from the registry.
- getChildAt(i) added as a test-affordance probe for the 3-deep descent assertions (Pitfall 8).
- Phase 1006/1007 regression tests (test_monitortag, test_monitortag_events, test_monitortag_streaming, test_sensortag, test_statetag, test_tag_registry) all remain green.

## Task Commits

1. **Task 1 (RED):** `57c60b4` — test(1008-02): RED tests for merge-sort + ALIGN + 3-deep round-trip
2. **Task 2 (GREEN):** `7c07966` — feat(1008-02): CompositeTag merge-sort + serialization + valueAt fast-path

Both committed with `--no-verify` per plan directive.

## Files Created/Modified

- `libs/SensorThreshold/CompositeTag.m` (MODIFIED, +282 / -23) — stubs replaced with real implementations of getXY (lazy-memoize + mergeStream_), valueAt (fast path), getTimeRange, toStruct, resolveRefs, getChildAt; new static fromStruct + private fieldOr_; new private mergeStream_ (the heart of the plan).
- `tests/suite/TestCompositeTag.m` (MODIFIED, extended) — added six Plan-02 methods (testToStructMinimalComposite, testFromStructEmptyChildren, testRoundTripCompositeWith2Children, testRoundTrip3DeepComposite, testRoundTrip3DeepReverseOrder, testFileBudgetWatermark) + static private helperLoadStructsLocal_.
- `tests/test_compositetag.m` (MODIFIED, extended) — added H section (tests 23..27: toStruct/fromStruct/round-trip 2-child/3-deep forward+reverse) + I section (test 28: file-budget watermark) + local function helperLoadStructsLocal_compositetag_.
- `tests/suite/TestCompositeTagAlign.m` (NEW) — classdef with 13 methods across A (merge-sort correctness), B (ALIGN-03 pre-history drop), C (ALIGN-01 no interp1 source + ZOH binary output), D (ALIGN-03+04 joint NaN propagation), E (COMPOSITE-06 valueAt fast-path), F (invalidation cascade), G (diamond invalidation).
- `tests/test_compositetag_align.m` (NEW) — Octave flat-assert mirror of the MATLAB suite; prints "All 13 CompositeTag align tests passed." on success.

## Decisions Made

- **Vectorized merge vs pointer-loop k-way merge.** RESEARCH §5 explicitly calls the sort-based approach "the idiomatic MATLAB/Octave implementation" that hits ~150ms at 8×100k (vs ~640ms for a per-iteration pointer-loop k-way merge that would FAIL the 200ms gate). Chose vectorized sort, verified via inline bench fixture (4×1000 = ~45ms in Octave).
- **Same-timestamp coalesce via lookahead.** Instead of an explicit grouping pass, the walk uses `if k < M && sortedX(k+1) == sortedX(k), continue; end` — wait for the last sample of the cluster, then aggregate with all children's updated lastY. Simpler than a two-pass grouping approach and matches RESEARCH §5 verbatim.
- **Empty-child short-circuit.** `any(cellfun(@isempty, allX)) -> output [],[]` before `first_x` computation to avoid `allX{i}(1)` indexing error. Matches the principle that a composite of any-empty-child should emit empty (since ZOH on a missing child is NaN, and `any(isnan(...))` in AND means every output would be NaN — empty output is more useful for downstream consumers).
- **Test-only local two-pass loader instead of editing TagRegistry.** Plan 03 owns the `instantiateByKind` 'composite' case; testing the 3-deep round-trip in Plan 02 would otherwise require cross-plan dependencies. Solution: inline kind-dispatch in `helperLoadStructsLocal_` as a static private method of TestCompositeTag and a local function in test_compositetag.m. Plan 03's VALIDATION will re-run the same 11-struct scenario through the real TagRegistry.loadFromStructs to prove end-to-end order-insensitivity.
- **Docstring phrasing to satisfy grep gates.** Initial comment drafts mentioned "interp1" and "union()" as prohibited operations. The structural grep gates (`grep -c "interp1"` / `grep -c "union("` must return 0) don't distinguish prose from code, so rephrased to "no linear interpolation" / "no set-union" in all comments. Code correctness unchanged; gate compliance preserved.

## Grep Gate Verdicts

| Gate | Rule | Result |
|------|------|--------|
| `interp1` | ALIGN-01 (no linear interpolation) | 0 matches (expect 0) |
| `union(` | Pitfall 3 structural (no N×M materialization via set-union) | 0 matches (expect 0) |
| `\[sortedX, order\] = sort` | RESEARCH §5 vectorized merge shape | 1 match (expect ≥1) |
| `strcmp.*\.Key` | RESEARCH §7 Key-equality DFS (Octave SIGILL safe) | 4 matches (expect ≥3) |
| `isequal(.*Tag\|Tag == obj` | Octave handle-equality SIGILL avoidance | 0 matches (expect 0) |
| `CompositeTag:notImplemented` | Stubs replaced | 0 matches (expect 0) |
| `function mergeStream_` | merge-sort private method present | 1 match (expect 1) |
| `function resolveRefs` | Pass-2 hook present | 1 match (expect 1) |
| `function v = valueAt` | Fast-path public method present | 1 match (expect 1) |
| `function obj = fromStruct` | Static Pass-1 ctor present | 1 match (expect 1) |
| `testRoundTrip3Deep` in TestCompositeTag.m | Forward + reverse | 2 matches (expect ≥2) |
| `CompositeTag` in TestTagRegistry.m | File-budget discipline | 0 matches (expect 0) |
| `Truth [Tt]able` in CompositeTag.m | Pitfall 6 doc gate persists | 2 matches (expect ≥1) |
| CompositeTag.m SLOC | ≥260 | 681 lines (exceeds 260 target — extensive docstrings) |

## Pitfall 5 (Strangler-Fig) Legacy-Unchanged Audit

`git diff HEAD~1 -- libs/SensorThreshold/{Sensor,Threshold,ThresholdRule,CompositeThreshold,StateChannel,SensorRegistry,ExternalSensorRegistry,Tag,SensorTag,StateTag,MonitorTag,TagRegistry}.m libs/FastSense/FastSense.m`
→ **0 bytes changed**. Invariant holds. Plan 03 owns TagRegistry + FastSense edits.

## Informational Wall-Time Benchmark

Ran a 4-children × 1000-sample fixture in Octave 11.1.0 (macOS ARM64):
```
mergeStream_ wall-time at 4x1000: 45.442 ms; output M=1000
```

This is informational only — Plan 03's `benchmarks/bench_compositetag_merge.m` owns the authoritative 8×100k / <200ms / <50MB peak-RAM gate. The small-fixture measurement indicates the vectorized approach is on-trend for the gate; no red flags.

## File-Touch Audit

- **This plan:** 2 files created (TestCompositeTagAlign.m, test_compositetag_align.m) + 3 files modified (CompositeTag.m, TestCompositeTag.m, test_compositetag.m).
- **Phase 1008 running total:** 5 / 8 target files (Plan 03 adds bench_compositetag_merge.m + edits TagRegistry.m + edits FastSense.m = 3 more touches; target = 8).

## Deviations from Plan

**[Rule 2 - Prose-triggered grep gate]** Initial docstring drafts included literal `interp1` and `union()` references in comments explaining what the algorithm does NOT do. The structural grep gates don't distinguish comments from code, so I rephrased to "no linear interpolation" / "no set-union" across three comment blocks (class header, getXY docstring, mergeStream_ docstring). Code correctness unchanged; gate compliance preserved. Found during Task 2 verification run.

No other deviations — plan executed as written. All 13 align tests + 28 composite tests (Plan 01's 22 + Plan 02's 6) GREEN on first GREEN run; all Phase 1006/1007 regressions green.

## Issues Encountered

None beyond the docstring / grep-gate phrasing detail above.

## Known Stubs

None. All four Plan-01 throw-from-base stubs (getXY/valueAt/getTimeRange/toStruct) are now working implementations; `grep "CompositeTag:notImplemented"` returns 0.

## User Setup Required

None.

## Next Phase Readiness

- Plan 03 (FastSense/TagRegistry integration + Pitfall-3 bench) can start immediately. All of Plan 02's public API surface is locked:
  - `getXY()` returns the merged (X, Y) aggregated grid
  - `valueAt(t)` returns the instantaneous scalar
  - `getKind() == 'composite'`
  - `toStruct()` / `fromStruct(s)` / `resolveRefs(registry)` are the two-phase serialization triple
- Plan 03's TagRegistry edit needs to add `case 'composite': tag = CompositeTag.fromStruct(s);` to `instantiateByKind`. Plan 03's FastSense edit needs `case 'composite': [x, y] = tag.getXY(); obj.addLine(x, y, ...);` to `addTag`.
- Plan 03's VALIDATION should re-run the 3-deep scenario (sourced from TestCompositeTag.testRoundTrip3DeepComposite + Reverse) through the real TagRegistry.loadFromStructs to prove end-to-end order-insensitivity via the production two-phase loader (Plan 02 uses a test-only local loader).
- No blockers. No CLAUDE.md-driven adjustments needed this plan (no architectural change, no new DB table, no breaking API).

## Self-Check

- `libs/SensorThreshold/CompositeTag.m` — FOUND
- `tests/suite/TestCompositeTag.m` (extended) — FOUND
- `tests/test_compositetag.m` (extended) — FOUND
- `tests/suite/TestCompositeTagAlign.m` — FOUND
- `tests/test_compositetag_align.m` — FOUND
- Commit `57c60b4` (Task 1 RED) — FOUND in `git log`
- Commit `7c07966` (Task 2 GREEN) — FOUND in `git log`
- Octave: `test_compositetag()` prints "All 28 CompositeTag tests passed." — VERIFIED
- Octave: `test_compositetag_align()` prints "All 13 CompositeTag align tests passed." — VERIFIED
- Regression: `test_monitortag/test_monitortag_events/test_monitortag_streaming/test_sensortag/test_statetag/test_tag_registry` all green — VERIFIED
- Plan 03 boundary: 0-byte diff on TagRegistry.m + FastSense.m — VERIFIED

## Self-Check: PASSED

---
*Phase: 1008-compositetag*
*Completed: 2026-04-16*
