---
phase: 1041-canonicalmapper
plan: 01
type: execute
wave: 0
depends_on: []
files_modified:
  - tests/suite/TestCanonicalMapper.m
  - install.m
  - libs/Fleet/.gitkeep
autonomous: true
requirements: [CANON-01, CANON-02, CANON-03, CANON-04, CANON-05]
must_haves:
  truths:
    - "Running TestCanonicalMapper executes all 30 named test methods (they fail RED because CanonicalMapper.m does not exist yet)"
    - "libs/Fleet/ is on the MATLAB path after install()"
    - "The two grep-gate tests are present and will pass trivially (or be skipped) until CanonicalMapper.m exists, then enforce Octave-safety"
  artifacts:
    - path: "tests/suite/TestCanonicalMapper.m"
      provides: "Nyquist test suite — 30 test methods (RED scaffold), TestClassSetup addPaths"
      contains: "classdef TestCanonicalMapper < matlab.unittest.TestCase"
      min_lines: 200
    - path: "install.m"
      provides: "libs/Fleet on path"
      contains: "addpath(fullfile(root, 'libs', 'Fleet'))"
    - path: "libs/Fleet/.gitkeep"
      provides: "Fleet library directory exists in git"
  key_links:
    - from: "tests/suite/TestCanonicalMapper.m"
      to: "libs/Fleet (path)"
      via: "addPaths -> install() + addpath(fullfile(repo,'libs','Fleet'))"
      pattern: "addpath\\(fullfile\\(repo, 'libs', 'Fleet'\\)\\)"
    - from: "install.m"
      to: "libs/Fleet"
      via: "addpath after libs/Help line"
      pattern: "libs', 'Fleet"
---

<objective>
Create the Wave 0 foundation for Phase 1041: the `TestCanonicalMapper.m` Nyquist test suite (all 30 test methods named in VALIDATION.md, written RED against the not-yet-existing `CanonicalMapper`), register `libs/Fleet/` on the MATLAB path in `install.m`, and create the `libs/Fleet/` directory. This is the feedback harness every downstream plan runs (`runtests('tests/suite/TestCanonicalMapper')`, ~5 s latency).

Purpose: Nyquist validation requires the test file to exist before implementation so each subsequent task has an automated GREEN/RED signal. The implementation file and `libs/Fleet/` do not exist yet — this plan bootstraps both the path and the test contract.
Output: `tests/suite/TestCanonicalMapper.m` (30 RED test methods), `install.m` with Fleet path, `libs/Fleet/.gitkeep`.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/1041-canonicalmapper/1041-RESEARCH.md
@.planning/phases/1041-canonicalmapper/1041-VALIDATION.md

<interfaces>
<!-- Contracts the test scaffold asserts against. CanonicalMapper.m is built in Plans 02-03; -->
<!-- the test file references these signatures so they fail RED until implemented. -->

CanonicalMapper public API (target — built in Plans 02/03; tests reference these now):
```matlab
m = CanonicalMapper();                          % handle class, no required args
m.suggest(tagInfos)                             % tagInfos: cell of structs {machineId, localKey, name, units}
keys = m.unmapped(machineId)                     % cellstr of localKeys with no mapping
pending = m.reviewPending()                      % cell of entry structs needing review
ok = m.isResolvable(logicalId, machineId)        % logical
m.override(logicalId, machineId, localKey)       % manual mapping; status='OVERRIDDEN'
m.confirm(logicalId, machineId)                  % user-endorse; status='CONFIRMED'
s = m.toStruct()                                 % struct: version=1, entries={...}
m2 = CanonicalMapper.fromStruct(s)               % static factory
m.save(filepath)                                 % atomic JSON write
m3 = CanonicalMapper.load(filepath)              % static factory from JSON
```

Entry struct schema (each value in the per-logicalId cell):
```matlab
entry.logicalId    % char: canonical sensor name (normalized cluster form)
entry.machineId    % char
entry.localKey     % char
entry.localName    % char
entry.localUnits   % char (may be '')
entry.similarity   % double [0,1]
entry.confidence   % char enum: 'HIGH' | 'MEDIUM' | 'LOW'
entry.status       % char enum: 'AUTO' | 'CONFIRMED' | 'OVERRIDDEN' | 'PENDING'
entry.unitMismatch % logical
```

Confidence thresholds (constants in CanonicalMapper, asserted by boundary tests):
```matlab
HIGH_THRESHOLD_   = 0.90   % sim >= 0.90 -> HIGH
MEDIUM_THRESHOLD_ = 0.60   % sim >= 0.60 -> MEDIUM ; sim < 0.60 -> LOW
sim = 1 - editDistance_(normA, normB) / max(numel(normA), numel(normB))
```

Reference test patterns:
- tests/suite/TestMonitorTag.m:25-46 — TestClassSetup `addPaths` (addpath(repo); install(); addpath suite)
- tests/suite/TestMonitorTag.m:290-360 — grep-gate idiom: `fileread` + `regexp`/`strfind` (NOT shell system())
- tests/suite/TestTagRegistry.m:11-28 — addPaths + install() pattern
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Register libs/Fleet on path and create the directory</name>
  <read_first>
    - install.m (lines 51-77 — the addpath block; you will insert one line after the libs/Help addpath at line 62)
    - .planning/phases/1041-canonicalmapper/1041-RESEARCH.md (Open Question #3 — install.m modification decision is LOCKED to Phase 1041)
  </read_first>
  <action>
    LOCKED DECISION (RESEARCH.md Open Question #3 + Q7): add the `libs/Fleet` path in Phase 1041 (NOT deferred to 1042), because the directory is created here and the test harness needs it.

    1. In `install.m`, in the "Always: add all paths" block, add exactly this line immediately AFTER the existing `addpath(fullfile(root, 'libs', 'Help'));` line (currently line 62):
       ```matlab
       addpath(fullfile(root, 'libs', 'Fleet'));
       ```
       Place it as the last entry in the libs addpath group (after Help), before the "Demo workspaces" comment block. Do not reorder or remove any existing addpath line.

    2. Create the directory `libs/Fleet/` by writing a placeholder file `libs/Fleet/.gitkeep` containing a single line:
       ```
       # libs/Fleet — FastSense v5.0 Multi-Machine Fleet layer (Phase 1041+). CanonicalMapper.m and CanonicalMapEditor.m live here.
       ```
       (The directory must exist in git so the path registration is meaningful and downstream plans can write into it. Plan 02 creates CanonicalMapper.m here; once it exists you may leave .gitkeep in place — it is harmless.)
  </action>
  <verify>
    <automated>grep -n "addpath(fullfile(root, 'libs', 'Fleet'))" install.m</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "addpath(fullfile(root, 'libs', 'Fleet'))" install.m` returns exactly `1`
    - The new addpath line appears AFTER the `libs', 'Help'` addpath line: `grep -n "libs', 'Help'\|libs', 'Fleet'" install.m` shows Help before Fleet in file order
    - All 9 pre-existing libs addpath lines (FastSense, SensorThreshold, EventDetection, Dashboard, WebBridge, FastSenseCompanion, PlantLog, Concurrency, Help) are still present: `grep -c "addpath(fullfile(root, 'libs'," install.m` returns `10`
    - File `libs/Fleet/.gitkeep` exists: `ls libs/Fleet/.gitkeep` exits 0
    - `mcp__matlab__evaluate_matlab_code` running `install; disp(exist(fullfile(fileparts(which('install')),'libs','Fleet'),'dir'))` prints `7` (Fleet dir on disk and reachable)
  </acceptance_criteria>
  <done>install.m registers libs/Fleet on the path; libs/Fleet/ exists in the repo with a .gitkeep; existing library paths are unchanged.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Write TestCanonicalMapper.m with all 30 RED test methods (CANON-01..02 + grep gates)</name>
  <read_first>
    - tests/suite/TestMonitorTag.m (lines 1-50 for TestClassSetup addPaths + TestMethodSetup; lines 290-360 for the fileread+regexp grep-gate idiom — DO NOT use shell system(), use fileread)
    - tests/suite/TestTagRegistry.m (lines 11-28 — addPaths + install() reference)
    - .planning/phases/1041-canonicalmapper/1041-VALIDATION.md (the Per-Task Verification Map — the authoritative list of all 30 test method names)
    - .planning/phases/1041-canonicalmapper/1041-RESEARCH.md (§ Code Examples for expected behavior; § Validation Architecture "Highest-Risk Correctness Areas" for boundary values)
  </read_first>
  <behavior>
    All 30 methods must EXECUTE and FAIL (RED) because CanonicalMapper does not exist yet (constructor errors). They define the GREEN target for Plans 02-04. The 30 methods (exact names — these are asserted by the Nyquist auditor):
    CANON-01 (5): testNormalizeLowercase, testEditDistanceSymmetry, testEditDistanceKnownPairs, testSuggestTwoMatchingPairs, testSuggestNoMatches
    CANON-02 confidence (5): testConfidenceHighThreshold, testConfidenceMediumThreshold, testConfidenceLowThreshold, testConfidenceBoundaryHigh, testConfidenceBoundaryMedium
    CANON-02 units (4): testUnitMismatchDowngradesHigh, testUnitMismatchDowngradesMedium, testUnitMismatchEmptyUnitsIgnored, testUnitMatchCaseInsensitive
    CANON-03 (5): testOverrideCreatesEntry, testOverrideSurvivesResuggest, testRoundTripPreservesEntries, testRoundTripPreservesOverriddenStatus, testSaveLoadRoundTrip
    CANON-04 (7): testReviewPendingReturnsLow, testReviewPendingReturnsUnitMismatch, testReviewPendingExcludesGoodEntries, testUnmappedReturnsUnresolved, testUnmappedEmptyWhenAllMapped, testIsResolvableFalseForLow, testIsResolvableTrueForHigh
    CANON-05 (1): testEditorConstructs
    SUCCESS-5 grep gates (2): testOctaveSafeGrepGate, testNoToolboxCallGrepGate
  </behavior>
  <action>
    Create `tests/suite/TestCanonicalMapper.m` as `classdef TestCanonicalMapper < matlab.unittest.TestCase`. This task writes the FULL test bodies (RED), not stubs — the assertions define exact expected behavior for Plans 02-04.

    STRUCTURE:
    - Class header comment block (description + the CANON-01..05 + SUCCESS-5 coverage list + `See also CanonicalMapper, CanonicalMapEditor`).
    - `methods (TestClassSetup)` with a method named EXACTLY `addPaths` (project convention):
      ```matlab
      function addPaths(testCase) %#ok<MANU>
          here = fileparts(mfilename('fullpath'));
          repo = fileparts(fileparts(here));
          addpath(repo);
          install();
          addpath(fullfile(repo, 'libs', 'Fleet'));   % redundant-safe even after install.m registers it
      end
      ```
    - No persistent/singleton state — CanonicalMapper is NOT a singleton, so no TestMethodSetup reset is required (add an empty-bodied one only if you prefer symmetry).
    - A local helper inside the class file (a private function or a static method) `sampleTagInfos_()` returning the canonical 3-machine fixture used across suggest tests:
      ```matlab
      tagInfos = {
          struct('machineId','M01','localKey','temp_motor','name','Motor Temperature','units','degC'), ...
          struct('machineId','M02','localKey','temp_mtor', 'name','Temp Mtor',        'units','degC'), ...   % ~HIGH match to M01
          struct('machineId','M03','localKey','pressure',  'name','Pressure',         'units','bar') ...      % no match -> unmapped
      };
      ```

    TEST BODIES — write real assertions (verifyEqual / verifyTrue / verifyEmpty / verifyNotEmpty). Concrete expectations:

    CANON-01:
    - testNormalizeLowercase: a fixture-key like `'Temp_Motor-1'` must normalize to `'temp_motor_1'` (lowercase, non-alphanumeric -> '_', collapse repeated '_', trim leading/trailing '_'). Since normalize_ is private, assert via behavior: build two tagInfos whose keys differ ONLY by case/punctuation (`'Temp-Motor'` vs `'temp_motor'`) and verify `suggest` clusters them into ONE logicalId (numel(keys)==1). (If a public normalize wrapper is added in Plan 02, prefer asserting it directly; otherwise assert via suggest behavior — document which.)
    - testEditDistanceSymmetry: assert via suggest determinism — swapping the order of two tagInfos yields the same similarity for the matched pair (commutativity of the distance). Build the same pair in both orders, suggest both, verify the matched entry's `similarity` is equal to within 1e-12.
    - testEditDistanceKnownPairs: documents the Wagner-Fischer contract `editDist('abc','abc')=0`, `editDist('abc','axc')=1`, `editDist('abc','')=3`. Assert via the similarity formula: two keys `'abc'` and `'axc'` give `sim = 1 - 1/3` ≈ 0.6667; build tagInfos with those keys and units equal, suggest, verify the matched entry similarity == (1 - 1/3) within 1e-9.
    - testSuggestTwoMatchingPairs: build a 4-tagInfo fixture forming TWO matching clusters (e.g. M01 `temp_motor`/M02 `temp_mtor` AND M01 `pressure_in`/M02 `pressure_inlet`), suggest, verify `numel(m.toStruct().entries)` covers both clusters and the number of distinct logicalIds == 2.
    - testSuggestNoMatches: build tagInfos with mutually dissimilar keys (`'temp'`, `'pressure'`, `'flowrate'` each on a different machine), suggest, verify 0 logicalIds created (no cross-machine cluster) AND each machine's key appears in `m.unmapped(machineId)`.

    CANON-02 confidence:
    - testConfidenceHighThreshold: a near-identical pair (e.g. `'temp_motor'` vs `'temp_mtor'`, sim ≈ 0.90) -> matched entry `confidence == 'HIGH'`.
    - testConfidenceMediumThreshold: a pair with sim in [0.60, 0.90) -> `confidence == 'MEDIUM'`. Construct keys with a known mid-range similarity (e.g. `'temperature'` vs `'temp'`: editDist 7, max len 11, sim ≈ 0.3636 -> too low; instead use `'pressure_in'` vs `'pressure_out'`: pick keys you compute to land in [0.60,0.90)). Compute the expected sim in a comment and assert MEDIUM.
    - testConfidenceLowThreshold: a pair with sim < 0.60 -> `confidence == 'LOW'`.
    - testConfidenceBoundaryHigh: construct a key pair whose normalized similarity is EXACTLY 0.90 (e.g. normalized lengths 10, edit distance 1 -> sim = 1 - 1/10 = 0.90) and verify `confidence == 'HIGH'` (boundary is inclusive: `sim >= 0.90`). Over-sampled risk area.
    - testConfidenceBoundaryMedium: construct a pair with sim EXACTLY 0.60 (lengths 5, edit distance 2 -> 1 - 2/5 = 0.60) and verify `confidence == 'MEDIUM'` (inclusive `>= 0.60`). Over-sampled risk area.

    CANON-02 units:
    - testUnitMismatchDowngradesHigh: a HIGH-similarity pair where the two units differ (`'degC'` vs `'K'`) -> the lower-confidence entry has `unitMismatch == true` AND `confidence == 'MEDIUM'` (HIGH downgraded one level). The canonical unit is taken from the first HIGH-confidence match.
    - testUnitMismatchDowngradesMedium: a MEDIUM-similarity pair with mismatched units -> `unitMismatch == true` AND `confidence == 'LOW'`.
    - testUnitMismatchEmptyUnitsIgnored: a matched pair where one entry has `units == ''` -> `unitMismatch == false` (no info, not a mismatch) and confidence NOT downgraded.
    - testUnitMatchCaseInsensitive: units `'degC'` vs `'DegC'` -> `unitMismatch == false` (case-insensitive compare via lower()).

    CANON-03 (these will stay RED through Plan 02 and go GREEN in Plan 03 — that is expected and correct for Nyquist):
    - testOverrideCreatesEntry: after `m.suggest(...)`, call `m.override('temperature_motor','M03','t_case')`; verify an entry exists for ('temperature_motor','M03') with `status=='OVERRIDDEN'` and `localKey=='t_case'`.
    - testOverrideSurvivesResuggest: override a pair, then call `m.suggest(...)` again with the full fixture; verify the OVERRIDDEN entry is unchanged (status still 'OVERRIDDEN', localKey still the override value) — suggest must not replace non-AUTO entries.
    - testRoundTripPreservesEntries: suggest, then `s = m.toStruct(); m2 = CanonicalMapper.fromStruct(s);` verify `numel(m2 entries) == numel(m entries)` and a spot-checked entry's logicalId/machineId/confidence match.
    - testRoundTripPreservesOverriddenStatus: override an entry, toStruct -> fromStruct, verify the rebuilt entry still has `status=='OVERRIDDEN'`. (Use JSON-string round-trip via jsonencode/jsondecode on toStruct output to also exercise the encode path WITHOUT disk I/O.)
    - testSaveLoadRoundTrip: suggest, `m.save(tempname)`, `m2 = CanonicalMapper.load(thatPath)`, verify entry count and a spot entry match. Use a `tempname` path and delete it in the test (wrap in onCleanup or delete at end).

    CANON-04 (RED through Plan 02, GREEN in Plan 03):
    - testReviewPendingReturnsLow: construct a LOW-confidence AUTO entry, verify it appears in `m.reviewPending()`.
    - testReviewPendingReturnsUnitMismatch: construct a unit-mismatch entry (any confidence), verify it appears in `reviewPending()`.
    - testReviewPendingExcludesGoodEntries: a HIGH-confidence no-mismatch AUTO entry must NOT appear in `reviewPending()`; also assert a CONFIRMED and an OVERRIDDEN entry do not appear.
    - testUnmappedReturnsUnresolved: with the 3-machine fixture, `m.unmapped('M03')` returns a cellstr containing `'pressure'` (the unmatched key).
    - testUnmappedEmptyWhenAllMapped: a fixture where every key on machine 'M01' is part of a cluster -> `m.unmapped('M01')` returns `{}` (empty).
    - testIsResolvableFalseForLow: a LOW+AUTO entry -> `m.isResolvable(logicalId,'Mxx') == false`.
    - testIsResolvableTrueForHigh: a HIGH+AUTO entry -> `m.isResolvable(logicalId,'Mxx') == true`.

    CANON-05 (RED through Plans 02-03, GREEN in Plan 04; MATLAB-only):
    - testEditorConstructs: guard with `if exist('OCTAVE_VERSION','builtin'); testCase.assumeFail('uifigure is MATLAB-only'); end` (use `assumeFail`/`assumeTrue(false)` so Octave SKIPS, not FAILS). Then: build a mapper, `m.suggest(sampleTagInfos_())`, construct `ed = CanonicalMapEditor(m)`, verify `ed.IsOpen == true` (or `isvalid(ed)` true and a uifigure handle exists), then `delete(ed)` / `ed.close()` in cleanup. Smoke only — no visual assertion (that is the manual UAT item).

    SUCCESS-5 grep gates (use the fileread + regexp idiom from TestMonitorTag.m:290-360 — NOT shell system(); portable and headless-safe). These reference `libs/Fleet/CanonicalMapper.m`, which does NOT exist in Wave 0:
    - testOctaveSafeGrepGate: `if exist('OCTAVE_VERSION','builtin')==0 && ... ` no — keep it simple: locate the file; if it does not exist yet, `testCase.assumeFail('CanonicalMapper.m not yet implemented')` so it SKIPS in Wave 0 and ENFORCES from Plan 02 onward. When the file exists: `src = fileread(fullfile(repo,'libs','Fleet','CanonicalMapper.m')); testCase.verifyEmpty(regexp(src,'\<contains\s*\(','match'), 'CanonicalMapper.m must not call contains() — Octave-safe gate');`.
    - testNoToolboxCallGrepGate: same file-existence guard, then `testCase.verifyEmpty(regexp(src,'\<editDistance\s*\(','match'), 'CanonicalMapper.m must not call Statistics Toolbox editDistance()');`. (Note: the private helper is named `editDistance_` with a trailing underscore, so the regex `editDistance\s*\(` with a word boundary will NOT match `editDistance_(` — confirm your regex uses `\<editDistance\s*\(` or `[^_]editDistance\(` so the private helper is allowed. Document this in a comment.)

    NAMING: every test method camelCase starting with `test`. Use `verifyEqual` with abs tolerance for floating-point similarity (`'AbsTol', 1e-9`).

    After writing, run `runtests('tests/suite/TestCanonicalMapper')` — expect all non-skipped methods to FAIL/ERROR (RED) because CanonicalMapper does not exist. That RED result is the success condition for this task.
  </action>
  <verify>
    <automated>runtests('tests/suite/TestCanonicalMapper') executes all 30 methods (RED expected — CanonicalMapper does not exist). Run via mcp__matlab__run_matlab_test_file on tests/suite/TestCanonicalMapper.m</automated>
  </verify>
  <acceptance_criteria>
    - File exists: `ls tests/suite/TestCanonicalMapper.m` exits 0
    - `grep -c "classdef TestCanonicalMapper < matlab.unittest.TestCase" tests/suite/TestCanonicalMapper.m` returns `1`
    - TestClassSetup method is named addPaths: `grep -c "function addPaths(testCase)" tests/suite/TestCanonicalMapper.m` returns `1`
    - All 30 method names are present. Each of the following greps returns >= 1:
      `grep -c "function testNormalizeLowercase" ...`, `testEditDistanceSymmetry`, `testEditDistanceKnownPairs`, `testSuggestTwoMatchingPairs`, `testSuggestNoMatches`, `testConfidenceHighThreshold`, `testConfidenceMediumThreshold`, `testConfidenceLowThreshold`, `testConfidenceBoundaryHigh`, `testConfidenceBoundaryMedium`, `testUnitMismatchDowngradesHigh`, `testUnitMismatchDowngradesMedium`, `testUnitMismatchEmptyUnitsIgnored`, `testUnitMatchCaseInsensitive`, `testOverrideCreatesEntry`, `testOverrideSurvivesResuggest`, `testRoundTripPreservesEntries`, `testRoundTripPreservesOverriddenStatus`, `testSaveLoadRoundTrip`, `testReviewPendingReturnsLow`, `testReviewPendingReturnsUnitMismatch`, `testReviewPendingExcludesGoodEntries`, `testUnmappedReturnsUnresolved`, `testUnmappedEmptyWhenAllMapped`, `testIsResolvableFalseForLow`, `testIsResolvableTrueForHigh`, `testEditorConstructs`, `testOctaveSafeGrepGate`, `testNoToolboxCallGrepGate`
    - Total method count: `grep -c "function test" tests/suite/TestCanonicalMapper.m` returns `30`
    - Grep gates use fileread (not shell system): `grep -c "fileread(" tests/suite/TestCanonicalMapper.m` returns >= 1; `grep -c "system(" tests/suite/TestCanonicalMapper.m` returns `0`
    - The static analyzer reports no syntax errors: `mcp__matlab__check_matlab_code` on tests/suite/TestCanonicalMapper.m returns no error-level diagnostics
    - `runtests('tests/suite/TestCanonicalMapper')` RUNS (does not crash the harness) and reports the methods as failed/incomplete (RED) — confirming the suite is wired and the implementation is genuinely missing
  </acceptance_criteria>
  <done>TestCanonicalMapper.m contains all 30 named test methods with real assertion bodies (not stubs), uses the addPaths/install() setup convention, uses fileread-based grep gates guarded for the not-yet-existing CanonicalMapper.m, and runs RED end-to-end.</done>
</task>

</tasks>

<verification>
- `runtests('tests/suite/TestCanonicalMapper')` runs all 30 methods (RED — CanonicalMapper.m absent). This is the per-task feedback command for every downstream plan.
- `install` adds libs/Fleet to the path with no regression to the other 9 lib paths.
- No syntax errors in the test file (mcp__matlab__check_matlab_code).
- Octave-safety + no-toolbox grep gates are present (fileread idiom) and guarded so they SKIP cleanly until CanonicalMapper.m exists.
</verification>

<success_criteria>
- tests/suite/TestCanonicalMapper.m exists with exactly 30 `function test*` methods, all named per VALIDATION.md, with real bodies.
- install.m registers `libs/Fleet` (1 new addpath line, 10 total libs paths).
- libs/Fleet/ exists in git via .gitkeep.
- The suite executes RED and provides a stable ~5 s feedback signal for Plans 02-04.
</success_criteria>

<output>
After completion, create `.planning/phases/1041-canonicalmapper/1041-01-SUMMARY.md`
</output>
