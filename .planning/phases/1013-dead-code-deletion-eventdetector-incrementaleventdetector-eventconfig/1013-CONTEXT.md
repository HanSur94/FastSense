# Phase 1013: Dead-code deletion (EventDetector / IncrementalEventDetector / EventConfig) - Context

**Gathered:** 2026-04-22
**Status:** Ready for planning
**Mode:** Smart-discuss infrastructure shortcut — pure deletion phase, no grey areas

<domain>
## Phase Boundary

Remove `EventDetector.m`, `IncrementalEventDetector.m`, and `EventConfig.m` entirely from `libs/EventDetection/`. Ship `tests/suite/TestLegacyClassesRemoved.m` as the regression contract guarding against any future re-introduction of these 3 classes plus the 8 classes deleted in Phase 1011 (`Threshold`, `CompositeThreshold`, `StateChannel`, `ThresholdRule`, `Sensor`, `SensorRegistry`, `ThresholdRegistry`, `ExternalSensorRegistry`).

The deletion must leave the live-event pipeline (`LiveEventPipeline + MonitorTag + EventStore`) byte-for-byte unchanged in observable behavior. No production code calls these 3 classes today (verified by Architecture research §2 — zero callers).

</domain>

<decisions>
## Implementation Decisions

### Deletion Scope (locked during /gsd:new-milestone)

- **Full delete** chosen over hard-error stub. Per user decision in REQUIREMENTS.md authoring: no external callers exist; the cleanest end state is removing the files entirely. Cascade includes the existing stubbed methods (`IncrementalEventDetector.process`, `EventConfig.addSensor`/`runDetection`/`escalateEvents` which are already empty bodies / hard-error stubs from Phase 1011).
- The 3 files in scope: `libs/EventDetection/EventDetector.m`, `libs/EventDetection/IncrementalEventDetector.m`, `libs/EventDetection/EventConfig.m`.
- `Event.m`, `EventStore.m`, `EventBinding.m`, `EventViewer.m`, `LiveEventPipeline.m`, `NotificationRule.m`, `NotificationService.m`, `DataSource.m` (and subclasses), `detectEventsFromSensor.m`, `generateEventSnapshot.m` are **NOT** in scope — they remain as production v2.0 code.

### Contract Test (DIFF-03)

- New file: `tests/suite/TestLegacyClassesRemoved.m`
- Single test class with one method per asserted-absence: 11 total (3 v2.1 + 8 Phase-1011).
- Pattern: `testCase.verifyEqual(exist('ClassName', 'class'), 0)` for each.
- File-header comment explicitly notes its purpose (regression guard, not behavioral test).
- Lives in `tests/suite/` so MATLAB CI runs it; not mirrored to `tests/test_*.m` (Octave-flat) because suite tests are MATLAB-only by runner geometry, and the asserted classes are equally absent on both runtimes.

### install.m

- Remove any `addpath` or path-entry lines that reference the 3 deleted files (DEAD-06). No file currently `addpath`s individual `.m` files inside `libs/EventDetection/` (it's done at directory level), so the impact is likely zero — verify by reading `install.m`.

### Verification Gates (from PITFALLS.md — subset for this phase)

- **Gate A — scope:** `git diff --name-only` ⊆ declared `affected_files`; net-LOC budget ≈ -300 to -500.
- **Gate C — dead-code grep:** `grep -rE '\b(EventDetector|IncrementalEventDetector|EventConfig)\b' libs/ examples/ benchmarks/` → 0 hits in production code.
- **Gate D — Octave smoke:** `tests/test_examples_smoke.m` passes.
- **Gate E — MATLAB CI:** `tests/run_all_tests.m` green on R2020b; document any test-count baseline drop.
- Gates B (golden untouched) and F (skip-list parity) are implied / not yet in scope (Phase 1015 owns DIFF-04; golden test is implicitly untouched here).

### Anti-features (locked)

- Do **NOT** stub the deleted classes (full delete, not deprecation shim).
- Do **NOT** delete `Event.m` / `EventStore.m` / `EventBinding.m` / `EventViewer.m` / `LiveEventPipeline.m` — they're production v2.0 code, not in scope.
- Do **NOT** delete the test files for these classes in this phase — that's Phase 1015 (TEST-01..05). This phase only adds `TestLegacyClassesRemoved.m`; the zombie test deletions stay for the test-cleanup phase to keep commit blame clean and to avoid bisect collisions when one of those test files contains a still-relevant stray that needs migration rather than deletion.
- Do **NOT** modify `LiveEventPipeline.m` despite it sitting next to the deleted files. Pure isolation: in/out of `libs/EventDetection/` only the deletions. **(See ratified relaxations below.)**

### Anti-features (ratified relaxations 2026-04-28 — user adjudication after plan-checker iteration 1)

The plan-checker (iteration 1) surfaced a real conflict between the "pure isolation" anti-feature and the DEAD-04 grep gate. The user ratified these narrow, behavior-preserving relaxations:

1. **`libs/EventDetection/LiveEventPipeline.m` may be edited** — strictly to delete the unread `detector_` field declaration (~line 30) and its `IncrementalEventDetector(...)` instantiation (~lines 64-68). Total ≈6 lines. Verified dead state: `obj.detector_` is allocated but never read elsewhere in the file. Behavior-preserving. **All other LEP edits remain forbidden.**
2. **`libs/SensorThreshold/MonitorTag.m` lines 527-528 may be edited** — strictly to rewrite docstring TEXT containing `EventDetector` references (e.g., `EventDetector` → `legacy detector` or analogous). No code-path change. **All other MonitorTag edits remain forbidden.**
3. **`examples/05-events/*.m` references to deleted classes are explicitly Phase 1016 scope.** Phase 1013 DEAD-04 grep gate carves out `examples/`. Phase 1016 (DEMO-01..09) rewrites those stubs entirely. The carve-out is one phase only and must be documented in PLAN.md verify block + SUMMARY.

**Net DEAD-04 grep gate post-relaxation:** `grep -rE '\b(EventDetector|IncrementalEventDetector|EventConfig)\b' libs/ benchmarks/ install.m` returns 0 hits. `examples/` not asserted this phase (Phase 1016 owns it).

### Claude's Discretion

- Exact file-header text for `TestLegacyClassesRemoved.m` (one-liner banner is fine).
- Order of `addpath` cleanup if `install.m` does reference deleted files (cosmetic only).
- Whether to use `methods (Test)` block with one method per class (verbose but readable) or a single parameterized test (`TestParameter`) over the 11 class names. Recommend the parameterized form — clean error message per class on failure, smaller file.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets

- `tests/suite/TestGoldenIntegration.m` — pattern for a focused, narrative test file with `% DO NOT REWRITE` semantics (referenced by DIFF-02 in Phase 1015; sets the precedent for a regression-guard test class).
- `tests/suite/Test*.m` patterns — class-based MATLAB tests inheriting `matlab.unittest.TestCase`; `methods (TestClassSetup)` for `addPaths`; `methods (Test)` for assertions.
- `matlab.unittest.qualifications.Verifiable.verifyEqual` and `matlab.unittest.parameters.TestParameter` are the canonical idioms (already in use across the suite).

### Established Patterns

- Class deletion precedent from Phase 1011: 8 classes deleted in a single phase with a 100-file diff; subsequent grep gates verified zero production refs. v2.1 Phase 1013 mirrors this at much smaller scale (3 classes, expected ~5-10 file diff including the deletions themselves).
- Hard-error legacy-removed stubs (`error('Class:legacyRemoved', ...)`) exist for `IncrementalEventDetector.process` and `EventConfig.addSensor`. Those become moot once the host classes are deleted.
- `install.m` adds paths at directory level (`addpath(fullfile(root, 'libs', 'EventDetection'))`), not file level — the directory survives, only files leave.

### Integration Points

- After deletion, the only intra-library cross-file ref to inspect is whether any file inside `libs/EventDetection/` (other than the 3 deletion targets) imports / requires / cross-references the deleted classes. Architecture research found zero such hits, but the plan should re-verify post-deletion.
- `tests/suite/TestLegacyClassesRemoved.m` lands in `tests/suite/` — picked up by `run_matlab_suite` automatic discovery; no edit to `tests/run_all_tests.m` required.

</code_context>

<specifics>
## Specific Ideas

- **TestParameter form for the contract test** (over per-method form) — single readable file, clean per-class diagnostic on failure:
  ```matlab
  classdef TestLegacyClassesRemoved < matlab.unittest.TestCase
      properties (TestParameter)
          ClassName = {'EventDetector', 'IncrementalEventDetector', 'EventConfig', ...
                       'Threshold', 'CompositeThreshold', 'StateChannel', 'ThresholdRule', ...
                       'Sensor', 'SensorRegistry', 'ThresholdRegistry', 'ExternalSensorRegistry'};
      end
      methods (Test)
          function classIsAbsent(testCase, ClassName)
              testCase.verifyEqual(exist(ClassName, 'class'), 0, ...
                  sprintf('Legacy class %s should not be reachable', ClassName));
          end
      end
  end
  ```
- The `0` literal for `exist(..., 'class')` means "not found." `2` would be a function/file, `8` would be a class on path. Asserting `== 0` is the correct absence check.

</specifics>

<deferred>
## Deferred Ideas

- Test-file deletion for `TestEventDetector.m`, `TestIncrementalDetector.m`, `TestEventConfig.m`, `TestEventDetectorTag.m`, `TestCompositeThreshold.m` → Phase 1015 (TEST-01..05).
- Wiki / doc updates for legacy class references → out of v2.1 scope (doc-only, not code).
- CI grep gate for these class names → Phase 1016 (DIFF-01); the contract test ships first as the in-suite guard.

</deferred>
