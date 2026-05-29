---
phase: 1008-compositetag
verified: 2026-04-16T22:25:00Z
status: passed
score: 5/5 success criteria verified + 10/10 grep gates + 3/3 behavioral spot-checks
---

# Phase 1008: CompositeTag Verification Report

**Phase Goal:** Aggregate one or more MonitorTags / CompositeTags into a single derived signal via merge-sort streaming, supporting AND / OR / MAJORITY / COUNT / WORST / SEVERITY / USER_FN — replacing the legacy `CompositeThreshold` for time-series aggregation.

**Verified:** 2026-04-16T22:25:00Z
**Status:** PASSED
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | User can construct CompositeTag with 7 AggregateModes and observe correct aggregated output for documented truth table | VERIFIED | `test_compositetag` prints "All 30 CompositeTag tests passed." — includes 29-row truth table in testTruthTableAllModes covering AND/OR/MAJORITY/COUNT/WORST/SEVERITY/USER_FN with NaN handling per ALIGN-04 |
| 2 | User can call addChild(monitorTagOrKey, 'Weight', 0.7) accepting Tag handle or string key resolved via TagRegistry | VERIFIED | addChild at CompositeTag.m:154-192; tests B9 (handle), B10 (string-key via TagRegistry.get), B11 (weight). Grep: `TagRegistry\.get\(` matches inside addChild — the resolution path exists |
| 3 | Self-reference and deeper cycles (A→B→A) rejected at addChild time with CompositeTag:cycleDetected | VERIFIED | wouldCreateCycle_ DFS at CompositeTag.m:494-525 uses strcmp(.Key) (4 matches; RESEARCH §7 Octave SIGILL avoidance). Tests C16 (self), C17 (2-deep), C18 (3-deep), C19 (diamond-not-cycle) all GREEN |
| 4 | addChild(sensorTag) rejected — only MonitorTag/CompositeTag are valid children | VERIFIED | Type-guard at CompositeTag.m:172-176 raises CompositeTag:invalidChildType. Tests B12 (SensorTag reject), B13 (StateTag reject), B14 (CompositeTag accept) all GREEN |
| 5 | valueAt(t) returns aggregated current value WITHOUT materializing full series (fast path) | VERIFIED | valueAt at CompositeTag.m:262-283 iterates children and calls child.valueAt(t), NEVER getXY. Test E10 asserts `composite.recomputeCount_ == 0` after valueAt (no mergeStream_ dispatch). E11 asserts valueAt matches getXY sample under tolerance |

**Score:** 5/5 success criteria VERIFIED

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `libs/SensorThreshold/CompositeTag.m` | Class core + merge-sort + serialization | VERIFIED | 784 lines (exceeds 260-320 target — extensive doc); classdef CompositeTag < Tag present; all 13 required methods shipped (constructor, addChild, invalidate, addListener, getKind, getXY, valueAt, getTimeRange, toStruct, fromStruct, resolveRefs, getChildAt, mergeStream_, wouldCreateCycle_, aggregateMatrix_, aggregate_, splitArgs_, fieldOr_, aggregateForTesting, validateMode_) |
| `libs/SensorThreshold/TagRegistry.m` | +3 lines 'composite' case | VERIFIED | `case 'composite'` at line 354; error message mentions Phase 1008 + composite kind |
| `libs/FastSense/FastSense.m` | +3 line 'composite' case in addTag | VERIFIED | `case 'composite'` at line 978; body routes to addLine via getXY (same shape as monitor); Pitfall 1 preserved (no isa-by-subclass) |
| `tests/suite/TestCompositeTag.m` | MATLAB unittest with 28+ methods | VERIFIED | 542 lines; 30+ test methods; testRoundTrip3Deep count = 4 (forward, reverse, production-TagRegistry + extras) |
| `tests/suite/TestCompositeTagAlign.m` | 13 align tests | VERIFIED | 305 lines; 13 Test methods across A-G sections (merge-sort, pre-history drop, ZOH, NaN, valueAt, invalidation cascade, diamond) |
| `tests/test_compositetag.m` | Octave flat-assert mirror | VERIFIED | 481 lines; prints "All 30 CompositeTag tests passed." |
| `tests/test_compositetag_align.m` | Octave flat-assert mirror of align | VERIFIED | 260 lines; prints "All 13 CompositeTag align tests passed." |
| `benchmarks/bench_compositetag_merge.m` | Pitfall 3 gate bench | VERIFIED | 124 lines; asserts ratio ≤ 1.1x AND time < 0.2s; prints "Pitfall 3 PASS" |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| CompositeTag.addChild | TagRegistry.get | string-key resolution | WIRED | Line 168: `tag = TagRegistry.get(char(tagOrKey));` inside addChild body |
| CompositeTag.addChild | wouldCreateCycle_ | cycle gate BEFORE storing | WIRED | Line 177: `if obj.wouldCreateCycle_(tag)` guards before `children_{end+1}` push at line 187 |
| CompositeTag.wouldCreateCycle_ | Key equality (strcmp) | Octave SIGILL avoidance | WIRED | Line 502, 515: `strcmp(newChild.Key, obj.Key)` + `strcmp(gc.Key, obj.Key)` — NO isequal/== on handles |
| CompositeTag.addChild | child.addListener(obj) | invalidation cascade hookup | WIRED | Line 188-190: `if ismethod(tag, 'addListener'), tag.addListener(obj); end` |
| CompositeTag.aggregate_ | Class-header truth tables | Pitfall 6 doc gate | WIRED | 2 matches of `Truth [Tt]able` in class header covering AND/OR/WORST/COUNT/MAJORITY/SEVERITY/USER_FN |
| CompositeTag.getXY | mergeStream_ | Lazy-memoize branch | WIRED | Line 255-256: `if obj.dirty_ \|\| ~isfield(obj.cache_, 'x'), obj.mergeStream_(); end` |
| CompositeTag.mergeStream_ | sort() + single walk | RESEARCH §5 vectorized | WIRED | Line 440: `[sortedX, order] = sort(cat_X);` followed by vectorized emitMask + cummax per-child forward-fill (no union, no interp1) |
| CompositeTag.valueAt | child.valueAt(t) per child | COMPOSITE-06 fast-path | WIRED | Line 278: `vals(i) = c.tag.valueAt(t);` inside the per-child loop; NO getXY call |
| CompositeTag.toStruct | childkeys + childweights fields | Serialization Pass 1 stash | WIRED | Line 328-329: `s.childkeys = {childKeys};` + `s.childweights = childWeights;` |
| CompositeTag.resolveRefs | CompositeTag.addChild | Pass-2 wiring via validated path | WIRED | Line 355: `obj.addChild(childHandle, 'Weight', weight);` inside resolveRefs |
| TagRegistry.loadFromStructs Pass-2 | CompositeTag.resolveRefs | Two-phase deserialization | WIRED | TagRegistry.loadFromStructs iterates map and calls `tag.resolveRefs(map)` — production path exercised by `testRoundTrip3DeepViaProductionTagRegistry` |
| CompositeTag.mergeStream_ | ALIGN-03 pre-history drop | first_x = max(child.X(1)) | WIRED | Line 446: `first_x = max(cellfun(@(xx) xx(1), allX));` + emitMask includes `sortedX >= first_x` |
| TagRegistry.instantiateByKind | CompositeTag.fromStruct | 'composite' case dispatch | WIRED | TagRegistry.m:354-355 `case 'composite': tag = CompositeTag.fromStruct(s);` |
| FastSense.addTag | addLine via CompositeTag.getXY | 'composite' case in switch | WIRED | FastSense.m:978-980 `case 'composite': [x,y] = tag.getXY(); obj.addLine(...)` |
| bench_compositetag_merge | CompositeTag.getXY | 8 children × 100k jittered X | WIRED | bench calls `[X, ~] = comp.getXY()` inside tic/toc block |
| bench_compositetag_merge | Pitfall 3 output-size proxy | ratio ≤ 1.1 assert | WIRED | `assert(outSamples <= totalChildSamples * 1.1, ...)` |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| CompositeTag.getXY | obj.cache_.x / .y | mergeStream_ populates via real child.getXY() data | Yes — vectorized sort+cummax produces actual merged time series | FLOWING |
| CompositeTag.valueAt | vals array | child.valueAt(t) for each child (real scalar per-child) | Yes — aggregates real per-child instantaneous values | FLOWING |
| CompositeTag.toStruct | s.childkeys / s.childweights | Iterates real children_ storage and extracts Key/weight | Yes — real child keys (strings) + weights (doubles) | FLOWING |
| CompositeTag.fromStruct | obj.ChildKeys_ / obj.ChildWeights_ | Parses struct s.childkeys/s.childweights (real deserialized data) | Yes — double-wrap unwrap handles MATLAB cellstr collapse | FLOWING |
| CompositeTag.resolveRefs | obj.children_ | Real registry handles wired via addChild (full validation) | Yes — type-guard + cycle DFS + listener hookup all fire | FLOWING |
| bench_compositetag_merge | X output | comp.getXY() on real 8×100k MonitorTag fixture | Yes — 100k real output samples at 53ms | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Full CompositeTag test suite | `octave --no-gui --eval "install(); cd tests; test_compositetag();"` | "All 30 CompositeTag tests passed." | PASS |
| CompositeTag align test suite | `octave --no-gui --eval "install(); cd tests; test_compositetag_align();"` | "All 13 CompositeTag align tests passed." | PASS |
| Pitfall 3 bench | `octave --no-gui --eval "install(); bench_compositetag_merge();"` | ratio 0.125x, time 0.054s, "Pitfall 3 PASS" | PASS |
| MonitorTag regression | `octave --no-gui --eval "install(); cd tests; test_monitortag();"` | "All test_monitortag tests passed." | PASS |
| MonitorTag events regression | `test_monitortag_events()` | "All test_monitortag_events tests passed." | PASS |
| MonitorTag streaming regression | `test_monitortag_streaming()` | "All 7 streaming tests passed." | PASS |
| TagRegistry regression | `test_tag_registry()` | "All 14 test_tag_registry tests passed." | PASS |
| Golden integration test | `test_golden_integration()` | "All 9 golden_integration tests passed." | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| COMPOSITE-01 | 01, 03 | CompositeTag extends Tag; recursively composable | SATISFIED | `classdef CompositeTag < Tag` at line 1; `testRoundTrip3DeepComposite` (3-deep composite-of-composite) + production-path round-trip green |
| COMPOSITE-02 | 01 | 7 aggregation modes | SATISFIED | `testTruthTableAllModes` exercises all 7 modes with 29-row truth table + NaN handling; `aggregate_` + `aggregateMatrix_` both dispatch all 7 modes |
| COMPOSITE-03 | 01 | addChild accepts handle or key + Weight | SATISFIED | B9 (handle), B10 (string key via TagRegistry), B11 (Weight NV pair); Line 167-170 + 181-185 of CompositeTag.m |
| COMPOSITE-04 | 01 | Cycle detection via DFS on addChild | SATISFIED | wouldCreateCycle_ DFS; tests self/2-deep/3-deep/diamond; strcmp(Key) (4 matches) for Octave SIGILL avoidance |
| COMPOSITE-05 | 02, 03 | Merge-sort streaming; no N×M materialization | SATISFIED | mergeStream_ uses vectorized sort + cummax; zero `union(` and zero `interp1`; bench 0.125x ratio at 8×100k proves no materialization |
| COMPOSITE-06 | 02 | valueAt(t) fast path | SATISFIED | valueAt iterates children directly (no getXY); `testValueAtDoesNotMaterialize` asserts recomputeCount_==0 after valueAt |
| COMPOSITE-07 | 01 | Children restricted to MonitorTag/CompositeTag | SATISFIED | Type-guard via `~isa(tag, 'MonitorTag') && ~isa(tag, 'CompositeTag')`; tests B12 (SensorTag reject) + B13 (StateTag reject) |

All 7 requirements from the ROADMAP entry for Phase 1008 are SATISFIED.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| — | — | — | — | No anti-patterns detected |

- `grep -c "CompositeTag:notImplemented" libs/SensorThreshold/CompositeTag.m` → 0 (all Plan-01 stubs replaced in Plan 02)
- `grep -c "TODO\|FIXME\|XXX\|HACK\|PLACEHOLDER" libs/SensorThreshold/CompositeTag.m` → checked, no production-code matches found
- No empty handlers; no `return null`/`return []` hardcoded stubs in rendering paths
- Constructor-default `cache_ = struct()` + `dirty_ = true` + `ChildKeys_ = {}` + `ChildWeights_ = []` are CORRECT initial state patterns (overwritten by mergeStream_/fromStruct/addChild on first use) — NOT stubs

### Grep Gate Verdicts (Pitfall & Alignment Invariants)

| Gate | Command | Result | Expected | Verdict |
| --- | --- | --- | --- | --- |
| Pitfall 3 structural (no union) | `grep -c "union(" libs/SensorThreshold/CompositeTag.m` | 0 | 0 | PASS |
| ALIGN-01 (no interp1) | `grep -c "interp1" libs/SensorThreshold/CompositeTag.m` | 0 | 0 | PASS |
| Pitfall 6 (truth-table header) | `grep -cE "Truth [Tt]able" libs/SensorThreshold/CompositeTag.m` | 2 | ≥1 | PASS |
| RESEARCH §7 Key-eq DFS | `grep -c "strcmp.*\.Key" libs/SensorThreshold/CompositeTag.m` | 4 | ≥3 | PASS |
| RESEARCH §7 no handle-eq | `grep -cE "isequal\(.*[a-z]Tag\|[a-z]Tag\s*==\s*obj" libs/SensorThreshold/CompositeTag.m` | 0 | 0 | PASS |
| Pitfall 8 (3-deep in TestCompositeTag) | `grep -c "testRoundTrip3Deep" tests/suite/TestCompositeTag.m` | 4 | ≥2 | PASS |
| Pitfall 8 (NOT in TestTagRegistry) | `grep -c "CompositeTag" tests/suite/TestTagRegistry.m` | 0 | 0 | PASS |
| Pitfall 1 (no subclass isa in FastSense.addTag) | `grep -cE "isa\s*\(\s*tag\s*,\s*'(SensorTag\|StateTag\|MonitorTag\|CompositeTag)'" libs/FastSense/FastSense.m` | 0 | 0 | PASS |
| case 'composite' in TagRegistry | `grep -c "case 'composite'" libs/SensorThreshold/TagRegistry.m` | 1 | 1 | PASS |
| case 'composite' in FastSense | `grep -c "case 'composite'" libs/FastSense/FastSense.m` | 1 | 1 | PASS |

All 10 grep gates PASS.

### Legacy Zero-Churn (MIGRATE-02 Pitfall 5)

```bash
git diff a19a80b..HEAD -- libs/SensorThreshold/{Sensor,Threshold,ThresholdRule,CompositeThreshold,StateChannel,SensorRegistry,ThresholdRegistry,ExternalSensorRegistry}.m | wc -l
```

Result: **0 lines** — PASS (8 pre-existing SensorThreshold legacy classes byte-for-byte unchanged across all 3 Plans)

### File-Touch Budget

8 files in libs/tests/benchmarks touched across the phase (exactly matches 8/8 budget cap):

1. `benchmarks/bench_compositetag_merge.m` (NEW — Plan 03)
2. `libs/FastSense/FastSense.m` (EDIT +4 — Plan 03)
3. `libs/SensorThreshold/CompositeTag.m` (NEW — Plan 01, extended Plan 02+03)
4. `libs/SensorThreshold/TagRegistry.m` (EDIT +4 — Plan 03)
5. `tests/suite/TestCompositeTag.m` (NEW — Plan 01, extended Plan 02+03)
6. `tests/suite/TestCompositeTagAlign.m` (NEW — Plan 02)
7. `tests/test_compositetag.m` (NEW — Plan 01, extended Plan 02+03)
8. `tests/test_compositetag_align.m` (NEW — Plan 02)

### Pitfall 3 Bench (Primary Memory Gate)

| Metric | Measured | Gate | Margin | Verdict |
| --- | --- | --- | --- | --- |
| Output-size ratio | 0.125x (100000 / 800000) | ≤ 1.10x | 8.8x under | PASS |
| Compute time (cold) | 54 ms | < 200 ms | 3.7x under | PASS |
| RSS (diagnostic) | 335.4 MB | informational | — | — |

Observed on Octave 11.1.0 (macOS ARM64). Bench run during this verification session reproduces SUMMARY claims.

### Human Verification Required

None — all goal criteria verified programmatically via test suites, bench execution, and grep gates. No visual/UX/real-time/external-service dimensions in scope for this phase (pure domain-model + dispatch integration).

### Deferred / Out-of-Scope Items

- Pre-existing failure `tests/test_to_step_function.m :: testAllNaN` confirmed out-of-scope in `.planning/phases/1008-compositetag/deferred-items.md`; pre-dates Phase 1008 baseline `a19a80b`. NOT introduced by Phase 1008.
- Phase 1009 (consumer migration — FastSenseWidget/StatusWidget/GaugeWidget wiring) — explicitly deferred per ROADMAP.
- Phase 1010 (event-Tag binding) — explicitly deferred.
- Phase 1011 (legacy CompositeThreshold + Sensor/Threshold/*Registry deletion) — explicitly deferred; legacy zero-churn discipline preserved through Phase 1008 exit.

### Gaps Summary

No gaps. Every success criterion is backed by a GREEN test, every artifact exists with substantive implementation, every key link is wired, every Pitfall gate passes. The phase goal — "Aggregate MonitorTags/CompositeTags via merge-sort streaming with 7 aggregation modes; replace legacy CompositeThreshold for time-series aggregation" — is achieved:

- 7 modes present and truth-table-correct (29 rows GREEN)
- Merge-sort vectorized via sort+cummax (no union, no interp1; 0.125x output ratio proves no N×M materialization)
- CompositeTag is a Tag, recursively composable, plottable via FastSense.addTag, and round-trip serializable via production TagRegistry.loadFromStructs
- Legacy classes byte-for-byte unchanged (strangler-fig discipline preserved; deletion is Phase 1011)
- File-touch at exactly 8/8 budget cap

---

_Verified: 2026-04-16T22:25:00Z_
_Verifier: Claude (gsd-verifier)_
