---
phase: 1008-compositetag
plan: 01
subsystem: domain-model
tags: [compositetag, aggregation, cycle-detection, truth-tables, strangler-fig, tdd, octave-safety]

# Dependency graph
requires:
  - phase: 1004-tag-foundation
    provides: Tag base class (throw-from-base abstract pattern); TagRegistry singleton
  - phase: 1006-monitortag-lazy-in-memory
    provides: observer pattern (addListener/invalidate cascade); splitArgs_ NV-parsing template
  - phase: 1007-monitortag-streaming-persistence
    provides: MonitorTag append semantics (unaffected by this plan)
provides:
  - CompositeTag class skeleton (constructor + addChild + cycle DFS + aggregator helper)
  - 7-mode truth-table aggregator (and/or/majority/count/worst/severity/user_fn) with locked NaN semantics
  - Key-equality cycle-detection DFS (Octave SIGILL avoidance per RESEARCH §7)
  - Class-header Pitfall 6 truth-table documentation gate
  - CompositeTag:notImplemented stubs for getXY/valueAt/getTimeRange/toStruct (Plan 02 fills)
affects: [1008-02 (merge-sort getXY + serialization), 1008-03 (FastSense/TagRegistry integration), 1009 (consumer migration), 1010 (event binding rewrite)]

# Tech tracking
tech-stack:
  added: []  # Pure-MATLAB; no new deps
  patterns:
    - "Key-equality DFS for handle-graph cycle detection (Octave-safe alternative to isequal/==)"
    - "Test-probe static wrapper (aggregateForTesting) over private aggregate_ helper"
    - "Public read-only inspection API (getChildCount/getChildKeys/getChildWeights/isDirty) in lieu of exposing private children_"
    - "Plan-02 placeholder stubs via CompositeTag:notImplemented error IDs"

key-files:
  created:
    - libs/SensorThreshold/CompositeTag.m
    - tests/suite/TestCompositeTag.m
    - tests/test_compositetag.m
  modified: []

key-decisions:
  - "Test-probe API chosen: public read-only getters (getChildCount/getChildKeys/getChildWeights/isDirty) + static aggregateForTesting wrapper. Alternative (expose children_ as SetAccess=private) was rejected — would leak internal struct shape into tests."
  - "AggregateMode validation happens in splitArgs_-adjacent validateMode_ — before UserFn gate — so 'xor' raises invalidAggregateMode before userFnRequired can even be evaluated."
  - "Cycle DFS uses Key equality (strcmp) exclusively — never isequal/== on handles. RESEARCH §7 documents Octave SIGILL on handle-compare with listener cycles; CompositeTag.addChild creates such cycles by design."
  - "Default Weight for non-severity modes is 1.0 — stored but only consumed by SEVERITY.aggregate_. Documented in class header."
  - "Plan-02 methods (getXY/valueAt/getTimeRange/toStruct) throw CompositeTag:notImplemented rather than returning empty — keeps the contract explicit and surfaces accidental Plan-01 callers immediately."

patterns-established:
  - "Handle-graph cycle detection via visited-Keys DFS: strcmp(gc.Key, obj.Key) + cellfun(@(k) strcmp(k, gc.Key), visitedKeys)"
  - "Child type-guard BEFORE cycle check: rejects SensorTag/StateTag handles at addChild time rather than failing later in aggregate_"
  - "Constructor path: splitArgs_ → obj@Tag(key, tagArgs{:}) FIRST → validateMode_ → NV-dispatch → UserFn gate"

requirements-completed: [COMPOSITE-01, COMPOSITE-02, COMPOSITE-03, COMPOSITE-04, COMPOSITE-07]

# Metrics
duration: 5min
completed: 2026-04-16
---

# Phase 1008 Plan 01: CompositeTag Class Core Summary

**CompositeTag < Tag ships with 7-mode truth-table aggregator, Key-equality cycle DFS (Octave SIGILL-safe), and class-header Pitfall 6 doc gate — public API shape locked for Plan 02 mergeStream_ to fill.**

## Performance

- **Duration:** ~5 minutes (two TDD commits)
- **Started:** 2026-04-16T19:46:51Z
- **Completed:** 2026-04-16T19:51:22Z
- **Tasks:** 2 (RED + GREEN)
- **Files created:** 3 (CompositeTag.m + TestCompositeTag.m + test_compositetag.m)
- **Files modified:** 0 (Pitfall 5 strangler-fig invariant holds)

## Accomplishments

- Constructor accepts 7 AggregateModes (case-insensitive via `lower(char(...))`), Tag NV universals (Name/Labels/Criticality/etc.), and CompositeTag-specific NV pairs (UserFn, Threshold) — all routed through `splitArgs_`.
- `addChild(tagOrKey, 'Weight', w)` resolves string keys via `TagRegistry.get`, rejects SensorTag/StateTag via `isa` gate, runs Key-equality cycle DFS BEFORE storing the child, and registers composite as listener on child so child invalidation cascades.
- 7-mode aggregator (`aggregate_`) passes every RESEARCH §4 truth-table row (29 binary-input × NaN combinations) including the AND-with-NaN → NaN, OR-with-NaN → other-operand, WORST ignoring NaN, COUNT/SEVERITY threshold binarization, and MAJORITY strict-binary semantics.
- Class-header Truth Table documentation present verbatim (Pitfall 6 doc gate) for all 7 modes.
- Plan-02 methods (`getXY` / `valueAt` / `getTimeRange` / `toStruct`) stubbed with explicit `CompositeTag:notImplemented` error so accidental Plan-01 callers fail loudly.
- Phase 1006/1007 regression tests (test_monitortag, test_monitortag_events, test_monitortag_streaming, test_sensortag, test_statetag, test_tag_registry) all remain green.

## Task Commits

1. **Task 1 (RED): TestCompositeTag + Octave mirror** — `3519baa` (test)
2. **Task 2 (GREEN): CompositeTag class core** — `bd6070a` (feat)

Both committed with `--no-verify` per plan directive.

## Files Created/Modified

- `libs/SensorThreshold/CompositeTag.m` (NEW, 422 lines) — classdef CompositeTag < Tag; constructor; addChild with cycle-DFS + type-guard + listener hookup; 7-mode aggregate_ helper; aggregateForTesting public test-probe; Plan-02 throw-from-base stubs; class-header Pitfall 6 truth tables.
- `tests/suite/TestCompositeTag.m` (NEW) — classdef TestCompositeTag < matlab.unittest.TestCase; 22 test methods grouped A/B/C/D/E/F; truth-table literal from RESEARCH §4 verbatim (29 rows).
- `tests/test_compositetag.m` (NEW) — Octave flat-assert mirror of the MATLAB suite; prints "All 22 CompositeTag tests passed." on success.

## Decisions Made

- **Test-probe API surface:** Added four public read-only getters (`getChildCount`, `getChildKeys`, `getChildWeights`, `isDirty`) and one public static wrapper (`aggregateForTesting`) rather than exposing `children_`/`dirty_` via `SetAccess=private`. Reason: keeps internal struct shape (`struct('tag', h, 'weight', w)`) decoupled from the test contract; Plan 02 can refactor `children_` storage without churning tests.
- **`aggregateForTesting` deliberately lives in a separate `methods (Static)` block** (not private) — class header documents it as test-only. Private `aggregate_` remains the canonical code path invoked by the forthcoming `mergeStream_` in Plan 02.
- **Validation order in constructor:** `validateMode_` runs AFTER `obj@Tag(key, tagArgs{:})` (Octave ctor rule — no obj access before super ctor) and BEFORE the UserFn gate, so passing mode='xor' raises `invalidAggregateMode` immediately even if UserFn is also absent.
- **Default Weight = 1.0** for all modes (not just SEVERITY). Non-SEVERITY modes ignore the weight field; stored-but-unused is cheaper than a conditional-store.

## Verbatim vs RESEARCH §2 skeleton

- **Verbatim:** constructor skeleton (splitArgs_ + obj@Tag first + validateMode_), wouldCreateCycle_ DFS with strcmp(Key) and visitedKeys set, aggregate_ dispatch switch with NaN rules, splitArgs_ tagKeys/cmpKeys partition.
- **Deferred to Plan 02 (expected, not a deviation):** `mergeStream_`, `resolveRefs`, `fromStruct`, `toStruct` implementation. Plan 01 ships `CompositeTag:notImplemented` stubs for getXY/valueAt/getTimeRange/toStruct per the plan's own output spec.
- **Added (minor):** public read-only getters (getChildCount/getChildKeys/getChildWeights/isDirty/getKind) as the chosen test-probe API; static `aggregateForTesting` wrapper. Both are documented in the class header and called out in key-decisions.

## Grep Gate Verdicts

| Gate | Rule | Result |
|------|------|--------|
| `classdef CompositeTag < Tag` | classdef literal | 1 match (expect 1) ✓ |
| `Truth [Tt]able` | Pitfall 6 doc gate | 2 matches (expect ≥1) ✓ |
| `interp1` | ALIGN-01 precursor | 0 matches (expect 0) ✓ |
| `\bunion\b` | Pitfall 3 precursor | 0 matches (expect 0) ✓ |
| `CompositeTag:cycleDetected` | locked error ID present | 3 matches (expect ≥1) ✓ |
| `strcmp.*\.Key` | Key-equality DFS (RESEARCH §7) | 4 matches (expect ≥3) ✓ |
| `isequal\(.*[a-z]Tag\|[a-z]Tag\s*==\s*obj` | Octave SIGILL avoidance | 0 matches (expect 0) ✓ |
| CompositeTag.m SLOC | ≥180 | 422 lines ✓ |

## Pitfall 5 (Strangler-Fig) Legacy-Unchanged Audit

`git diff HEAD~2 -- libs/SensorThreshold/{Sensor,Threshold,ThresholdRule,CompositeThreshold,StateChannel,SensorRegistry,ThresholdRegistry,ExternalSensorRegistry,Tag,SensorTag,StateTag,TagRegistry,MonitorTag}.m libs/FastSense/FastSense.m`
→ **empty diff** (no bytes changed in any pre-existing file). Invariant holds.

The `grep "CompositeTag" Tag.m` and `grep "CompositeTag" MonitorTag.m` each return pre-existing header comments mentioning CompositeTag as a Tag subclass — these pre-date Phase 1008 Plan 01 and were NOT introduced by this plan (verified via `git diff HEAD~2`).

## File-Touch Audit

- **This plan:** 3 files created (CompositeTag.m, TestCompositeTag.m, test_compositetag.m).
- **Phase 1008 running total:** 3 / 8 target files (Plan 02 adds ~3, Plan 03 adds ~2).

## Deviations from Plan

None — plan executed exactly as written. All 22 tests GREEN on first GREEN run; no auto-fix rules triggered.

## Issues Encountered

None.

## Known Stubs

Four Plan-02 methods deliberately throw `CompositeTag:notImplemented`. This is by design per the plan's output spec (Plan 02 will replace these with working implementations):

- `libs/SensorThreshold/CompositeTag.m:205 getXY()` — merge-sort streaming (Plan 02)
- `libs/SensorThreshold/CompositeTag.m:211 valueAt(t)` — fast-path aggregation (Plan 02)
- `libs/SensorThreshold/CompositeTag.m:217 getTimeRange()` — min/max across children (Plan 02)
- `libs/SensorThreshold/CompositeTag.m:223 toStruct()` — serialization (Plan 02)

Not user-facing stubs — the class is not yet wired into FastSense (that's Plan 03). No callers exist outside tests.

## User Setup Required

None — no external service or env var configuration required.

## Next Phase Readiness

- Plan 02 (merge-sort getXY + toStruct/fromStruct + resolveRefs + 3-deep round-trip) can start immediately. All the API shape it needs (constructor, children_, cache_, dirty_, listeners_, ChildKeys_, ChildWeights_, recomputeCount_) is in place.
- Plan 03 (FastSense/TagRegistry integration) depends on Plan 02 getXY being non-stub.
- No blockers. No CLAUDE.md-driven adjustments needed this plan (no architectural change, no new DB table, no breaking API).

## Self-Check

- `libs/SensorThreshold/CompositeTag.m` — FOUND
- `tests/suite/TestCompositeTag.m` — FOUND
- `tests/test_compositetag.m` — FOUND
- Commit `3519baa` (Task 1 RED) — FOUND in `git log`
- Commit `bd6070a` (Task 2 GREEN) — FOUND in `git log`
- Octave: `test_compositetag()` prints "All 22 CompositeTag tests passed." — VERIFIED
- Regression: `test_monitortag/test_monitortag_events/test_monitortag_streaming/test_sensortag/test_statetag/test_tag_registry` all pass — VERIFIED

## Self-Check: PASSED

---
*Phase: 1008-compositetag*
*Completed: 2026-04-16*
