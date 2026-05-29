---
phase: 1013-dead-code-deletion-eventdetector-incrementaleventdetector-eventconfig
verified: 2026-04-28T00:00:00Z
status: passed
score: 5/5 must-haves verified
re_verification: null
gaps: []
human_verification:
  - test: "Run tests/suite/TestLegacyClassesRemoved.m on MATLAB R2020b CI"
    expected: "11/11 parameterized cases PASS (classIsAbsent for each of EventDetector, IncrementalEventDetector, EventConfig, Threshold, CompositeThreshold, StateChannel, ThresholdRule, Sensor, SensorRegistry, ThresholdRegistry, ExternalSensorRegistry)"
    why_human: "MATLAB binary not available on this dev machine; Octave-substitute already executed the equivalent exist(name,'class')==0 predicate against all 11 classes — PASS — but the matlab.unittest TestParameter parametrization itself ships only on MATLAB. Defer to next CI push."
  - test: "Run tests/suite/TestLiveEventPipelineTag.m on MATLAB R2020b CI (positive DEAD-05 oracle, end-to-end LiveEventPipeline + MonitorTag.appendData live-tick path)"
    expected: "Remains green — testMonitorTagPathEmitsEventsOnAppendData passes, parent-before-child ordering preserved, no regressions from the ≈6-line LEP edit"
    why_human: "MATLAB-only suite test; the ≈6-line LEP edit is byte-equivalent for observable behavior (the deleted detector_ field was write-only) but the affirmative evidence is the green CI run."
  - test: "Run tests/suite/TestLiveTagPipeline.m on MATLAB R2020b CI (D-14 invariant that LiveTagPipeline does NOT subclass LiveEventPipeline)"
    expected: "Remains green — testNoSubclassOfLiveEventPipeline passes; LEP class hierarchy unchanged"
    why_human: "MATLAB-only suite test; the LEP edit removed only a private field, not the class declaration — but the structural assertion is the green CI run."
---

# Phase 1013: Dead-code deletion (EventDetector / IncrementalEventDetector / EventConfig) Verification Report

**Phase Goal:** User running anything against `EventDetector`, `IncrementalEventDetector`, or `EventConfig` no longer reaches deleted-class references — the three classes are removed entirely from `libs/EventDetection/` and a focused contract test guards against accidental re-introduction.

**Verified:** 2026-04-28
**Status:** PASSED
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | (DEAD-05) Existing live pipelines (`LiveEventPipeline + MonitorTag + EventStore`) behavior unchanged | VERIFIED | `LiveEventPipeline.m` private properties block has only `timer_` + `cycleCount_` (no `detector_`). The pipeline path uses `monitor.appendData(newX, newY)` at line 233 (processMonitorTag_). Octave spot-check: `LiveEventPipeline(mons, dsmap)` constructs cleanly, returns `Status='stopped'`. Suite oracles `tests/suite/TestLiveEventPipelineTag.m` + `tests/suite/TestLiveTagPipeline.m` both present (note: plan/summary refer to `TestLivePipelineTag.m` but the actual filename is `TestLiveTagPipeline.m` — same file, harmless filename typo in docs). |
| 2 | (DEAD-01..03) Three files absent from libs/EventDetection/ | VERIFIED | `test ! -f` confirms ABSENT for all three: `EventDetector.m`, `IncrementalEventDetector.m`, `EventConfig.m`. `git log --diff-filter=D` shows commits `6293a1f`, `8bc04a4`, `8bdb167` deleted them. |
| 3 | (DEAD-06) `install.m` runs clean; no path entries reference deleted files | VERIFIED | `grep 'EventDetector\|IncrementalEventDetector\|EventConfig' install.m` returns 0 hits. Line 198 `core_classes = {'FastSense', 'SensorTag', 'MonitorTag', 'DashboardEngine', 'WebBridge'}` — `'EventDetector'` replaced with `'MonitorTag'`. Octave-substitute `install()` ran successfully without warnings. |
| 4 | (DEAD-04) Repo-wide grep against libs/ benchmarks/ install.m returns 0 hits | VERIFIED | `grep -rnE '\b(EventDetector\|IncrementalEventDetector\|EventConfig)\b' libs/ benchmarks/ install.m` returns 0 lines. examples/ carve-out per CONTEXT.md ratified relaxation §3 — Phase 1016 owns. |
| 5 | (DIFF-03) `tests/suite/TestLegacyClassesRemoved.m` runs green and asserts 11 deleted classes absent | VERIFIED | File present, 34 LOC, classdef inherits `matlab.unittest.TestCase`, `properties (TestParameter)` lists exactly 11 class names in locked order (3 v2.1 first, then 8 Phase-1011), `methods (TestClassSetup) addPaths` calls `install()`, `methods (Test) classIsAbsent(testCase, ClassName)` calls `verifyEqual(exist(ClassName, 'class'), 0, ...)`. Octave-substitute confirmed `ALL_11_ABSENT: PASS` against the same predicate. |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `libs/EventDetection/EventDetector.m` | MUST NOT EXIST | ABSENT (correct) | Deleted in commit `6293a1f` (-135 LOC) |
| `libs/EventDetection/IncrementalEventDetector.m` | MUST NOT EXIST | ABSENT (correct) | Deleted in commit `8bc04a4` (-103 LOC) |
| `libs/EventDetection/EventConfig.m` | MUST NOT EXIST | ABSENT (correct) | Deleted in commit `8bdb167` (-117 LOC) |
| `tests/suite/TestLegacyClassesRemoved.m` | Contract test, TestParameter, ≥18 LOC | VERIFIED (Levels 1-3) | Exists, 34 LOC, classdef + TestParameter + 11 class names + addPaths + classIsAbsent. Auto-discovered via `TestSuite.fromFolder(suite_dir)` at `tests/run_all_tests.m:43`. |
| `libs/EventDetection/LiveEventPipeline.m` | Forbids `IncrementalEventDetector` | VERIFIED | `grep -nE '\bdetector_\b\|\bIncrementalEventDetector\b'` returns 0 hits. Private properties block at lines 28-31 contains only `timer_` and `cycleCount_`. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `tests/suite/TestLegacyClassesRemoved.m` | MATLAB unittest auto-discovery | `TestSuite.fromFolder(suite_dir)` in run_matlab_suite | WIRED | `tests/run_all_tests.m:43` calls `suite = TestSuite.fromFolder(suite_dir);`. Pattern `classdef TestLegacyClassesRemoved < matlab.unittest.TestCase` confirmed at line 1. No edit needed — auto-discovered. |
| `libs/EventDetection/LiveEventPipeline.m` | `MonitorTag.appendData` | `processMonitorTag_` private method | WIRED | Line 233: `monitor.appendData(newX, newY);` inside `processMonitorTag_`. No `IncrementalEventDetector` dependency anywhere in the file. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| `tests/suite/TestLegacyClassesRemoved.m` | `ClassName` parameter | TestParameter property (literal 11-element cell array) | Yes (verified by Octave spot-check below) | FLOWING |
| `libs/EventDetection/LiveEventPipeline.m` | `monitor` (MonitorTag) | constructor `monitors` arg → `processMonitorTag_` private dispatch | Yes (Phase 1009 wiring intact; appendData call at line 233) | FLOWING |

N/A for the 3 deleted files (they have no data flow — they are absent).

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| All 11 legacy classes return `exist(name, 'class') == 0` after install() | `octave --eval "install(); for c={11 classes}; assert exist(c,'class')==0; end"` | `ALL_11_ABSENT: PASS` | PASS |
| `LiveEventPipeline` constructs cleanly without `IncrementalEventDetector` | `octave --eval "lep = LiveEventPipeline(mons, dsmap); disp(lep.Status)"` | `LEP_INSTANTIATED: status=stopped class=LiveEventPipeline` | PASS |
| DEAD-04 grep gate over libs/ benchmarks/ install.m | `grep -rnE '\b(EventDetector\|IncrementalEventDetector\|EventConfig)\b' libs/ benchmarks/ install.m` | (empty — 0 hits) | PASS |
| Contract test file structure intact | `grep -c "ClassName" tests/suite/TestLegacyClassesRemoved.m` | `4` (TestParameter, method arg, verifyEqual arg, sprintf arg) | PASS |
| Contract test has no TODO/FIXME/placeholder anti-patterns | `grep -c "TODO\|FIXME\|XXX\|HACK\|PLACEHOLDER" tests/suite/TestLegacyClassesRemoved.m` | `0` | PASS |
| `MonitorTag.appendData` is the live-tick path in LEP | `grep -n 'appendData' libs/EventDetection/LiveEventPipeline.m` | line 233: `monitor.appendData(newX, newY);` (plus 12 docstring refs) | PASS |
| MATLAB CI run of TestLegacyClassesRemoved (11/11 cases) | `matlab -batch ...` | DEFERRED — `matlab` binary not available locally; Octave-substitute exercises the same `exist(name,'class')==0` predicate and reports PASS for all 11. | DEFERRED |
| MATLAB CI run of TestLiveEventPipelineTag.m + TestLiveTagPipeline.m (positive DEAD-05 oracle) | `matlab -batch ...` | DEFERRED — see human_verification frontmatter. | DEFERRED |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| DEAD-01 | 1013-01-PLAN | `EventDetector` removed entirely from libs/EventDetection/ | SATISFIED | File absent (commit `6293a1f`); REQUIREMENTS.md line 14 marks `[x]` complete |
| DEAD-02 | 1013-01-PLAN | `IncrementalEventDetector.m` removed entirely | SATISFIED | File absent (commit `8bc04a4`); REQUIREMENTS.md line 15 marks `[x]` complete |
| DEAD-03 | 1013-01-PLAN | `EventConfig.m` removed entirely | SATISFIED | File absent (commit `8bdb167`); REQUIREMENTS.md line 16 marks `[x]` complete |
| DEAD-04 | 1013-01-PLAN | grep returns 0 hits in production code (libs/ benchmarks/ install.m per CONTEXT.md ratified relaxation §3) | SATISFIED | `grep -rnE` over scoped paths returns 0 lines. examples/ carved out — Phase 1016 owns. |
| DEAD-05 | 1013-01-PLAN | LiveEventPipeline + MonitorTag + EventStore behavior unchanged | SATISFIED | LEP private field cleanup is byte-equivalent for observable behavior (deleted field was write-only). Octave spot-check: LEP constructs successfully. Final affirmative evidence requires CI run of TestLiveEventPipelineTag — deferred to human verification (item 2). |
| DEAD-06 | 1013-01-PLAN | install.m no longer references deleted file paths | SATISFIED | `grep 'EventDetector...' install.m` returns 0; line 198 has `'MonitorTag'`; Octave `install()` ran without warnings. |
| DIFF-03 | 1013-01-PLAN | New `TestLegacyClassesRemoved.m` asserts 11 classes absent | SATISFIED | File at correct path, 34 LOC, parameterized over the locked 11-class list, auto-discovered by `TestSuite.fromFolder`. Octave spot-check confirmed predicate returns PASS for all 11. |

**Orphaned requirements:** None. All 7 requirement IDs in PLAN frontmatter are accounted for in REQUIREMENTS.md and verified above.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | — | — | — | No TODO/FIXME/XXX/HACK/PLACEHOLDER in the new contract test or the modified files. The `eventLogger.m` line 4 docstring example was repaired (now references `MonitorTag` instead of `EventDetector`). MonitorTag.m lines 560-561 docstring sanitized to `legacy detector`. |

### Human Verification Required

Three items deferred to MATLAB R2020b CI (matlab binary not available on dev machine):

#### 1. TestLegacyClassesRemoved.m on MATLAB CI

**Test:** `matlab -batch "cd('tests'); results = run_all_tests(); exit(any([results.Failed]))"`
**Expected:** `tests/suite/TestLegacyClassesRemoved/classIsAbsent` produces 11 sub-test entries, all PASS (one per parameterized class).
**Why human:** MATLAB binary not available locally; Octave-substitute already exercises the same `exist(name,'class')==0` predicate against all 11 classes and reports `ALL_11_ABSENT: PASS`. The matlab.unittest TestParameter parametrization runs only on MATLAB itself. Confidence is high (PASS expected).

#### 2. TestLiveEventPipelineTag.m on MATLAB CI (positive DEAD-05 oracle)

**Test:** Same `matlab -batch` invocation.
**Expected:** `tests/suite/TestLiveEventPipelineTag/testMonitorTagPathEmitsEventsOnAppendData` (and any sibling cases) remain green. The ≈6-line LEP edit (deleted unread `detector_` field + IncrementalEventDetector instantiation) MUST be byte-equivalent for observable behavior.
**Why human:** MATLAB-only suite test (Phase 1009 Plan 03 end-to-end). Octave spot-check proves LEP constructs cleanly without IncrementalEventDetector, but the live-tick path with parent-before-child ordering invariant (`updateData → appendData`) needs the actual MATLAB run for affirmative evidence.

#### 3. TestLiveTagPipeline.m on MATLAB CI (D-14 invariant)

**Test:** Same `matlab -batch` invocation.
**Expected:** `tests/suite/TestLiveTagPipeline/testNoSubclassOfLiveEventPipeline` remains green; the LEP class hierarchy is unchanged (only a private field was removed).
**Why human:** MATLAB-only suite test. Filename note: PLAN.md and SUMMARY.md refer to `TestLivePipelineTag.m`, but the actual file is `TestLiveTagPipeline.m`. Same file (no missing oracle), just a documentation-side word-order typo. The structural invariant is straightforward — confidence is high.

**Expected zombie test failures (Phase 1015 cleanup scope, NOT regressions):**
- `tests/suite/TestEventDetector.m` (constructor will fail — `EventDetector` undefined)
- `tests/suite/TestIncrementalDetector.m` (constructor will fail — `IncrementalEventDetector` undefined)
- `tests/suite/TestEventConfig.m` (constructor will fail — `EventConfig` undefined)
- `tests/suite/TestEventDetectorTag.m` (constructor will fail — `EventDetector` undefined)
- 5 Octave-flat siblings under `tests/test_*.m` (will fail under Octave runner)

These are **expected** test-count baseline drops, owned by Phase 1015 TEST-01..05.

### Gaps Summary

**No gaps blocking goal achievement.**

All 5 must-haves verified. Three observations worth surfacing (none are gaps):

1. **Filename typo in plan/summary docs:** PLAN.md and SUMMARY.md cite `tests/suite/TestLivePipelineTag.m` as one of the positive DEAD-05 oracles. The actual filename is `tests/suite/TestLiveTagPipeline.m` (word order swap). Both `TestLiveTagPipeline.m` and `TestLiveEventPipelineTag.m` are present and serve as the affirmative behavior-preservation evidence for the ≈6-line LEP edit. This is a documentation issue only — does not affect goal achievement and does not require a re-plan. Optional follow-up: a 1-line docstring fix in the SUMMARY.md.

2. **MATLAB CI deferral:** Gate E (full MATLAB R2020b suite run) is deferred to the next CI push. Octave-substitute exercises the equivalent absence predicate for all 11 classes (PASS) and confirms LiveEventPipeline constructs cleanly (PASS). Confidence in the deferred CI outcomes is high. Three items are listed under `human_verification` for the user to confirm on the next push.

3. **Zombie test failures expected on next CI:** 4 suite tests + 5 Octave-flat tests now reference deleted classes. Phase 1015 TEST-01..05 owns their cleanup. This was explicitly documented in CONTEXT.md anti-features and the SUMMARY.md handoff table. The test-count baseline drop is attributable, not a regression mystery.

---

*Verified: 2026-04-28*
*Verifier: Claude (gsd-verifier)*
