---
phase: 1043-dashboardserializer-resolver-seam-backward-compat
plan: 01
type: execute
wave: 0
depends_on: []
files_modified:
  - tests/suite/TestFleetDashboardResolver.m
  - tests/test_dashboard_resolver.m
autonomous: true
requirements: [DASH-01, DASH-02]
nyquist_compliant: true

must_haves:
  truths:
    - "A RED MATLAB class suite exists asserting all 4 success criteria (resolver-used, legacy-load, warning-fires, .m-export-machine-scoped) and fails before implementation"
    - "A RED Octave flat test exists asserting the resolver path, legacy-registry-hit path, and no-resolver-miss warning path, using the warning-as-error idiom"
    - "Both test files build Tag objects via fromStruct/configToWidgets without calling render() so they run headless on Octave CI"
  artifacts:
    - path: "tests/suite/TestFleetDashboardResolver.m"
      provides: "RED class suite for SC1/SC2/SC3/SC4 (D-06)"
      contains: "FastSenseWidget:tagResolverMissing"
      min_lines: 120
    - path: "tests/test_dashboard_resolver.m"
      provides: "RED Octave flat companion for resolver/warning logic (D-07)"
      contains: "warning('error'"
      min_lines: 40
  key_links:
    - from: "tests/suite/TestFleetDashboardResolver.m"
      to: "FastSenseWidget.fromStruct / DashboardEngine.load / DashboardSerializer.exportScript"
      via: "test method assertions on resolver binding, warning id, and exported .m string content"
      pattern: "fromStruct|TagResolver|exportScript"
    - from: "tests/test_dashboard_resolver.m"
      to: "FastSenseWidget.fromStruct"
      via: "direct 2-arg and 1-arg fromStruct calls with synthetic widget structs"
      pattern: "FastSenseWidget\\.fromStruct"
---

<objective>
Create the Wave 0 RED test scaffold for Phase 1043 — a MATLAB class suite (`TestFleetDashboardResolver`) and an Octave flat companion (`test_dashboard_resolver`) that pin all four success criteria of the resolver seam BEFORE any production code changes. These tests MUST fail (RED) when run against current HEAD, because the resolver is not yet threaded, the multi-page path drops it, the warning id is still `FastSenseWidget:tagNotFound`, and `linesForWidget` has no `'tag'` case.

This is the Nyquist Wave 0 dependency (VALIDATION.md §"Wave 0 Requirements"): no implementation task may claim completion until these scaffolds exist and the subsequent implementation turns them GREEN.

Covers the test obligations of D-06 (class suite, four behaviors a/b/c/d) and D-07 (Octave flat companion). The behaviors asserted close DASH-01 (multi-page resolver) and DASH-02 (backward-compat).

Purpose: Lock the observable contract (resolver-used vs registry-fallback vs warning) into executable RED assertions so the implementation plans (02, 03) have a deterministic GREEN target.
Output: Two new test files, RED against current code, GREEN after Plans 02 + 03.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/1043-dashboardserializer-resolver-seam-backward-compat/1043-CONTEXT.md
@.planning/phases/1043-dashboardserializer-resolver-seam-backward-compat/1043-RESEARCH.md
@.planning/phases/1043-dashboardserializer-resolver-seam-backward-compat/1043-VALIDATION.md

# Test patterns to mirror
@tests/test_machine.m
@tests/suite/TestDashboardSerializerRoundTrip.m
</context>

<artifacts_this_phase_produces>
This plan (01) produces the RED scaffolds. The full phase produces:
- `FastSenseWidget.fromStruct(s, tagResolver)` — optional 2nd arg (Plan 02)
- `DashboardSerializer.createWidgetFromStruct(ws, tagResolver)` — optional 2nd arg forwarding to fromStruct (Plan 02)
- `DashboardSerializer.configToWidgets(config, resolver)` — resolver threaded into createWidgetFromStruct (Plan 02)
- `DashboardEngine.load(..., 'TagResolver', r)` accepting BOTH `'TagResolver'` and `'SensorResolver'`; multi-page loop passes the resolver (Plan 02)
- `warning('FastSenseWidget:tagResolverMissing', ...)` warning id (Plan 02)
- `DashboardSerializer.linesForWidget(ws, pos, indent, machineVar)` `'tag'` case emitting both forms; `exportScript`/`exportScriptPages`/`save` inline `'tag'` case threaded with machineVar (Plan 03)
- These two new test files (Plan 01)
</artifacts_this_phase_produces>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: RED MATLAB class suite TestFleetDashboardResolver covering SC1-SC4</name>
  <files>tests/suite/TestFleetDashboardResolver.m</files>
  <read_first>
    - tests/suite/TestDashboardSerializerRoundTrip.m (class-suite structure: classdef ... < matlab.unittest.TestCase, TestClassSetup method `addPaths` calling addpath + install(), test methods, synthetic config struct fixtures at :40-130)
    - .planning/phases/1043-dashboardserializer-resolver-seam-backward-compat/1043-RESEARCH.md §"Fixture Strategy for Tests" (lines 418-513 — synthetic 2-page fleet config struct fixture and the per-SC observable signals at lines 569-594)
    - libs/Dashboard/FastSenseWidget.m:1500-1540 (fromStruct current 1-arg signature; tag path at :1513-1521)
    - libs/Fleet/Machine.m:82-168 (Machine('Id',...,'DataRoot',...) constructor; addTag; get(localKey) instance method)
    - libs/SensorThreshold/TagRegistry.m:67-230 (register, clear, find, list static methods)
  </read_first>
  <action>
    Create class `TestFleetDashboardResolver < matlab.unittest.TestCase`. Add a `methods (TestClassSetup)` block with method `addPaths` that calls `addpath` for the repo root then `install()` (mirror TestDashboardSerializerRoundTrip exactly). Add a `methods (TestMethodSetup)` (or per-test) that calls `TagRegistry.clear()` so registry state never leaks between tests. Implement these test methods, each building synthetic widget/config structs inline (no external example files), per D-06 (a/b/c/d) and the SC observable signals in RESEARCH:

    (1) `testLegacyLoadNoResolverUsesRegistry` (SC2 / DASH-02): register a SensorTag under key 'legacy_temp' via `TagRegistry.register`; build a single-page config with one fastsense widget whose `source = struct('type','tag','key','legacy_temp')`; save to a temp JSON via `DashboardSerializer.saveJSON` (or the project's JSON save entry — confirm the exact save method name in DashboardSerializer while reading); load via `DashboardEngine.load(path)` with NO resolver; verify the widget's `Tag` is non-empty and is the registered tag. Wrap the load in `testCase.verifyWarningFree(@() DashboardEngine.load(path))` to assert NO `FastSenseWidget:tagResolverMissing` warning fires on the legacy hit path.

    (2) `testMultiPageFleetResolverBindsPage2` (SC1 / DASH-01): call `TagRegistry.clear()`; create a `Machine('Id','M01','DataRoot',tempdir())` and `addTag(SensorTag('temperature'))` and `addTag(SensorTag('pressure'))`; build a 2-page config (page 1 widget source key 'temperature', page 2 widget source key 'pressure', both `source.type='tag'`) using the multi-page fixture form from RESEARCH lines 429-453; save to temp JSON; load via `DashboardEngine.load(path, 'TagResolver', @(k) m.get(k))`; assert the page-2 widget's `Tag` is non-empty, `isa(tag,'SensorTag')`, and its key equals 'pressure'; assert NEGATIVE leak: `TagRegistry.find(@(t) true)` is empty (machine tag never entered the global registry). Read the page-2 widget via the loaded engine's `Pages{2}` widget list (confirm the accessor while reading DashboardEngine).

    (3) `testNoResolverFleetTagMissWarns` (SC3 / DASH-02): `TagRegistry.clear()`; build a config whose widget source key 'pressure' is NOT in TagRegistry and pass NO resolver; assert the load does NOT error (no crash) AND emits warning `FastSenseWidget:tagResolverMissing` (use `testCase.verifyWarning(@() DashboardEngine.load(path), 'FastSenseWidget:tagResolverMissing')`); after load, assert the affected widget's `Tag` is empty (`isempty`).

    (4) `testExportScriptMachineVarEmitsMachineScopedTag` (SC4 / DASH-01): build a config with a fastsense widget `source.type='tag', key='pressure'`; call `DashboardSerializer.exportScript(config, filepath, 'machine')`; `fileread(filepath)` MUST contain `machine.get('pressure')` and MUST NOT contain `TagRegistry.get('pressure')`. Add a negative companion `testExportScriptNoMachineVarEmitsRegistry`: call `DashboardSerializer.exportScript(config, filepath)` (no machineVar); `fileread` MUST contain `TagRegistry.get('pressure')`.

    Every assertion message must name the SC and requirement (e.g. 'SC1/DASH-01: page-2 widget must bind via injected resolver'). Use `tempname()` for temp files and clean them in a try/onCleanup. Do NOT call `render()` anywhere. Do NOT use `contains(` (Octave parity is a project invariant) — use `~isempty(strfind(...))` for substring checks even though this is a MATLAB-only suite, to keep one idiom across both test files. Keep every line <= 160 chars (MISS_HIT). These tests are RED until Plans 02 + 03 ship.
  </action>
  <verify>
    <automated>mcp__matlab__check_matlab_code on tests/suite/TestFleetDashboardResolver.m returns no errors (parses clean); then mcp__matlab__run_matlab_test_file on tests/suite/TestFleetDashboardResolver.m — expect RED (failures/errors) against current HEAD, confirming the tests assert not-yet-implemented behavior. A clean PARSE with RED RESULTS is the success condition for this task.</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "classdef TestFleetDashboardResolver" tests/suite/TestFleetDashboardResolver.m` returns 1
    - File defines at least 5 test methods: `grep -cE "function test[A-Z]" tests/suite/TestFleetDashboardResolver.m` >= 5
    - Warning-id assertion present: `grep -c "FastSenseWidget:tagResolverMissing" tests/suite/TestFleetDashboardResolver.m` >= 2 (one verifyWarning, one verifyWarningFree-adjacent or comment)
    - `'TagResolver'` NV usage present: `grep -c "'TagResolver'" tests/suite/TestFleetDashboardResolver.m` >= 1
    - `.m` export assertions present: `grep -c "machine.get('pressure')" tests/suite/TestFleetDashboardResolver.m` >= 1 AND `grep -c "TagRegistry.get('pressure')" tests/suite/TestFleetDashboardResolver.m` >= 1
    - No render call: `grep -v '^[[:space:]]*%' tests/suite/TestFleetDashboardResolver.m | grep -c '\.render(' ` returns 0
    - No `contains(`: `grep -c "contains(" tests/suite/TestFleetDashboardResolver.m` returns 0
    - check_matlab_code reports no parse errors
    - run_matlab_test_file reports RED (at least one failing/erroring test) against current HEAD
  </acceptance_criteria>
  <done>The class suite parses clean, defines >=5 test methods covering SC1-SC4 (a/b/c/d from D-06), asserts the new warning id and the .m-export machine-scoped form, calls no render(), and runs RED against current HEAD.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: RED Octave flat companion test_dashboard_resolver for resolver + warning logic</name>
  <files>tests/test_dashboard_resolver.m</files>
  <read_first>
    - tests/test_machine.m:1-60 (Octave flat-test structure: function with no output, local add_*_path_() helper, install(), TagRegistry.clear(), try/catch + me.identifier substring check for error assertion at :26-32, trailing `fprintf('    All N tests passed.\n')`)
    - .planning/phases/1043-dashboardserializer-resolver-seam-backward-compat/1043-RESEARCH.md §"Octave flat test (D-07) — fromStruct + warning" (lines 466-513 — the warning-as-error idiom `warning('error', ID)` + try/catch, restore via `warning(warnState.state, ID)`)
    - libs/Dashboard/FastSenseWidget.m:1500-1540 (fromStruct tag path)
    - libs/Fleet/Machine.m:82-168 (Machine ctor + get)
  </read_first>
  <action>
    Create function `test_dashboard_resolver()` (no output args) mirroring `tests/test_machine.m` structure. Open with a local path helper (e.g. `add_dashboard_path_()` calling `install()`) then `TagRegistry.clear()`. Implement three assertions that exercise `FastSenseWidget.fromStruct` directly (NO DashboardEngine, NO render — Octave-safe):

    (1) Resolver path (SC1): create `m = Machine('Id','M01','DataRoot', tempdir())`; `m.addTag(SensorTag('pressure'))`; build `ws` struct with `ws.type='fastsense'`, `ws.title='Test'`, `ws.position=struct('col',1,'row',1,'width',6,'height',2)`, `ws.source=struct('type','tag','key','pressure')`; call `w = FastSenseWidget.fromStruct(ws, @(k) m.get(k))`; `assert(~isempty(w.Tag), 'resolver path: Tag must be bound (SC1)')`.

    (2) No-resolver fleet-tag miss → warning (SC3): with TagRegistry cleared (so 'pressure' is NOT registered), capture the warning state via `warnState = warning('query', 'FastSenseWidget:tagResolverMissing')`, then `warning('error', 'FastSenseWidget:tagResolverMissing')` to promote it to a catchable error; in a try/catch call `FastSenseWidget.fromStruct(ws)` (1-arg, no resolver); in the catch set `errored = ~isempty(strfind(me.identifier, 'FastSenseWidget:tagResolverMissing'))`; restore via `warning(warnState.state, 'FastSenseWidget:tagResolverMissing')`; `assert(errored, 'SC3: tagResolverMissing must fire on no-resolver miss')`.

    (3) Legacy registry hit → no warning, Tag bound (SC2): `TagRegistry.register('legacy_temp', SensorTag('legacy_temp'))`; build `ws2` with `source=struct('type','tag','key','legacy_temp')`; call `w2 = FastSenseWidget.fromStruct(ws2)` (1-arg, no resolver); `assert(~isempty(w2.Tag), 'SC2: legacy registry hit must bind Tag')`.

    End with `TagRegistry.clear()` then `fprintf('    All 3 tests passed.\n')`. Use only Octave-safe primitives: NO `contains(`, NO `verifyWarning` (that is class-suite only), use the `warning('error',ID)` + `strfind` idiom from test_machine.m. Keep lines <= 160 chars. RED until Plan 02 renames the warning id and adds the resolver path.
  </action>
  <verify>
    <automated>mcp__matlab__check_matlab_code on tests/test_dashboard_resolver.m returns no parse errors; then mcp__matlab__evaluate_matlab_code running `install(); test_dashboard_resolver()` — expect RED (assertion failure or unexpected error) against current HEAD because the resolver arg and new warning id do not yet exist. Clean PARSE + RED RUN is the success condition.</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "function test_dashboard_resolver" tests/test_dashboard_resolver.m` returns 1
    - Warning-as-error idiom present: `grep -c "warning('error', 'FastSenseWidget:tagResolverMissing')" tests/test_dashboard_resolver.m` >= 1
    - Warning state restored: `grep -c "warning(warnState.state" tests/test_dashboard_resolver.m` >= 1
    - 2-arg resolver call present: `grep -cE "FastSenseWidget\.fromStruct\(ws, @\(k\)" tests/test_dashboard_resolver.m` >= 1
    - 1-arg legacy call present: `grep -cE "FastSenseWidget\.fromStruct\(ws2\)" tests/test_dashboard_resolver.m` >= 1
    - No `contains(`: `grep -c "contains(" tests/test_dashboard_resolver.m` returns 0
    - No render call: `grep -c "\.render(" tests/test_dashboard_resolver.m` returns 0
    - check_matlab_code reports no parse errors
    - `install(); test_dashboard_resolver()` runs RED against current HEAD
  </acceptance_criteria>
  <done>The Octave flat test parses clean, exercises fromStruct's resolver/legacy/warning paths directly without render or DashboardEngine, uses the warning-as-error idiom, contains no `contains(`, and runs RED against current HEAD.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| test fixture → file system (tempname/tempdir) | Tests write synthetic JSON / `.m` files to temp paths; no untrusted input crosses here (fixtures are inline literals) |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-1043-01-01 | Tampering | temp files left behind by tests | accept | Tests use `tempname()`/`tempdir()` and clean up via onCleanup; stale temp files are low-value, OS-cleaned, no security impact |
| T-1043-01-02 | Information Disclosure | synthetic test fixtures | accept | Fixtures contain no PII or secrets — literal keys like 'temperature'/'pressure' only |
| T-1043-01-SC | Tampering | npm/pip/cargo installs | accept | No package installs in this plan — pure MATLAB/Octave test files, no dependency additions |
</threat_model>

<verification>
- Both new test files parse clean (`check_matlab_code` no errors).
- `TestFleetDashboardResolver` runs RED against current HEAD (asserts not-yet-built behavior).
- `test_dashboard_resolver()` runs RED against current HEAD.
- Neither file calls `render()`; neither uses `contains(` (Octave parity invariant).
- Grep gates in acceptance_criteria all pass (filtered to exclude comment lines where counting tokens).
</verification>

<success_criteria>
- `tests/suite/TestFleetDashboardResolver.m` exists, parses clean, >=5 test methods spanning SC1-SC4 (D-06 a/b/c/d), RED against HEAD.
- `tests/test_dashboard_resolver.m` exists, parses clean, 3 assertions (resolver / legacy / warning), warning-as-error idiom (D-07), RED against HEAD.
- Both Octave-safe (no render, no `contains(`).
</success_criteria>

<output>
Create `.planning/phases/1043-dashboardserializer-resolver-seam-backward-compat/1043-01-SUMMARY.md` when done.
</output>
