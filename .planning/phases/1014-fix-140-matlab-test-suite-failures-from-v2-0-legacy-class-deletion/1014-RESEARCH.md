# Phase 1014: Fix ~140 MATLAB test-suite failures from v2.0 legacy-class deletion — Research

**Researched:** 2026-04-22
**Domain:** MATLAB classdef test migration (tests/suite) after v2.0 Tag reboot
**Confidence:** HIGH

## Summary

Phase 1011 deleted eight legacy classes (`Sensor`, `Threshold`, `ThresholdRule`, `CompositeThreshold`, `StateChannel`, `SensorRegistry`, `ThresholdRegistry`, `ExternalSensorRegistry`) and the standalone `detectEventsFromSensor` function. The `libs/run_all_tests.m` Octave suite, the golden integration test, and every `*Tag` test were migrated; **the classdef suite in `tests/suite/` was not.** ~140 tests now fail because they instantiate deleted classes directly.

A second finding dwarfs the first in implication: the **widget production code itself** (`StatusWidget.m`, `GaugeWidget.m`, `IconCardWidget.m`, `MultiStatusWidget.m`, `ChipBarWidget.m`) still reads threshold objects through the old API — `t.IsUpper`, `t.allValues()`, `isa(t, 'CompositeThreshold')` — **but the classes those calls target no longer exist.** Those widget branches are dead-code-until-executed; they throw as soon as a test passes a real threshold through them. Any test that exercises the widgets' `Threshold`-path code is therefore testing deleted behaviour — CONTEXT.md D-02-A instructs us to **delete** those test methods, not migrate them.

Third finding: the same pattern holds for `EventConfig.addSensor`, `EventConfig.runDetection` (now returns empty), `EventConfig.addTag` (does not exist), `IncrementalEventDetector.process` (throws `legacyRemoved`), and `EventDetector.detect` (only the 2-arg `(tag, threshold)` overload remains). Tests calling the legacy pipelines are testing stubs. The scope cut is to **delete** those test methods rather than try to rewrite them against a non-existent API.

**Primary recommendation:** Split into 7 wave-2 parallel plans organized along the six Category-A..F failure axes plus an infra/fixtures-first Wave 1. Do NOT rewrite widget-threshold tests into a new API — delete them; the widget code paths they tested are themselves dead. Do not touch the `TagRegistry`-based `*Tag.m` replacement tests — those run the live path and their passing is the real acceptance signal.

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01.** Scope = `tests/suite/*.m` only. Fix all failing tests in the classdef suite. Do not re-work library code to match old tests. Do not touch `tests/test_*.m`.
- **D-02.** Failure categorisation (locked): A (~80 legacy-class instantiations), B (~8 `EventDetector.detect` 6-arg drift), C (~10 `testCase.TestData`), D (4 headless image export), E (2 real bugs in `TestDashboardBugFixes`), F (~15 residual verify-failures).
- **D-02-A heuristic.** If a reasonable Tag-API equivalent exists → migrate. If the test specifically exercised deleted behaviour → **delete** the individual `function testX` method (not the whole file unless every method falls in this bucket).
- **D-02-C pattern.** Every `testCase.TestData.X` → `properties (Access = private)` block; proven by Phase 1006 MATLABFIX-B.
- **D-02-E.** Two fixes allowed in `libs/`:
  1. `testSensorListenersMultiPage` line 263-265: test fix (replace `s_y_ = rand(...)` local-var assignment with `s.updateData(x, newY)`).
  2. `testExitEditModeAfterFigureClose`: library fix in `libs/Dashboard/DashboardBuilder.m:124` — add `ishandle(hFig)` guard before first `set` call.
- **D-03.** Verification strategy: local MATLAB run (`scripts/run_tests_with_coverage.m`) + CI green on the `Tests → MATLAB Tests` job. Octave suite must stay green. MISS_HIT clean.
- **D-04.** Commit discipline: one test-class per commit when feasible. Commit messages: `fix(1014-test): migrate TestXxx to Tag API` or `fix(1014-lib): <exact fix>`. No bundled cleanup. No MISS_HIT suppressions.
- **D-05.** Budget: 2-day soft, 4-day hard. Any single test class taking > 45 min → **delete the failing methods**. Library cascades beyond the two D-02-E files → STOP and re-discuss.
- **D-06.** Defer: no new test coverage, no Octave classdef migration, no re-introduced legacy shims, no test class renames.

### Claude's Discretion

- Exact wave structure for the plan.
- Whether to split `TestSensorDetailPlot` (21 failures) across multiple plans or keep as one.
- Per-test choice between "migrate to Tag API" vs "delete" (governed by D-02-A heuristic).

### Deferred Ideas (OUT OF SCOPE)

- Test coverage gap audit (v2.1 concern).
- Consolidation of `TestSensorDetailPlot` vs `TestSensorDetailPlotTag`, `TestFastSenseWidget` vs `TestFastSenseWidgetTag` (separate refactor).
- MATLAB R2020b → R2023b upgrade (would eliminate Category C).
- Octave classdef suite coverage.

## Phase Requirements

No exclusive REQ-IDs. Coverage criterion is an infrastructure gate:

| ID | Description | Research Support |
|----|-------------|------------------|
| PHASE-1014-GATE | `Tests → MATLAB Tests` CI job green on push to topic branch | `.github/workflows/tests.yml:234-305` (MATLAB job) + `scripts/run_tests_with_coverage.m` entry point |
| PHASE-1014-GATE | Octave Tests job remains green | `tests/run_all_tests.m` unchanged (function-style tests already migrated) |
| PHASE-1014-GATE | MISS_HIT lint clean (no new suppressions) | `miss_hit.cfg` at repo root; D-04 forbids suppression additions |

## Standard Stack

### Core — test migration targets (already in codebase)
| Library | Purpose | Why Standard |
|---------|---------|--------------|
| `SensorTag` (`libs/SensorThreshold/SensorTag.m:1`) | Replaces legacy `Sensor`; inlined X/Y, `updateData`, PostSet-via-listener | Canonical v2.0 replacement |
| `StateTag` (`libs/SensorThreshold/StateTag.m:1`) | Replaces `StateChannel`; ZOH `valueAt` | Byte-for-byte `StateChannel.valueAt` parity |
| `MonitorTag` (`libs/SensorThreshold/MonitorTag.m:1`) | Replaces the "alarm signal" concept (NOT `Threshold` value-object) | MONITOR-05 carrier pattern ships; see pitfall 1 |
| `CompositeTag` (`libs/SensorThreshold/CompositeTag.m:1`) | Replaces `CompositeThreshold` for aggregation | 7 AggregateModes, AND/OR/MAJORITY/COUNT/WORST/SEVERITY/USER_FN |
| `TagRegistry` (`libs/SensorThreshold/TagRegistry.m:1`) | Replaces `SensorRegistry`/`ThresholdRegistry`/`ExternalSensorRegistry` | Hard-errors on duplicate key (Pitfall 7) |
| `EventDetector` 2-arg overload (`libs/EventDetection/EventDetector.m:39`) | `det.detect(tag, threshold)` — the only overload alive | Phase 1011 deleted 6-arg |

### Supporting — test-only helpers
| Helper | Path | When to Use |
|--------|------|-------------|
| `MakePhase1009Fixtures.makeSensorTag` | `tests/suite/MakePhase1009Fixtures.m:23` | Golden-fixture SensorTag with known Y pattern |
| `MakePhase1009Fixtures.makeMonitorTag` | `tests/suite/MakePhase1009Fixtures.m:49` | Default `y > 15` monitor |
| `MockTag` | `tests/suite/MockTag.m` | Abstract Tag probe |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Rewriting `testChipThreshold` against `MonitorTag` | Delete the method | Widget's `IsUpper`/`allValues()` path is dead product code; rewriting hides the fact that the widget itself is broken. Delete per D-02-A. |
| Keep `TestStatusWidget.testDeriveStatusFromSensorWithThresholds` | Delete | Exercises `Sensor.addThreshold` (deleted method) + widget's `isa(t,'CompositeThreshold')` branch (deleted class). No v2.0 path equivalent at the widget level; the `*Tag` widget tests already cover the live path. |
| Rewrite `TestEventStore.testAutoSave` against `EventStore.append + MonitorTag` | Delete the 7 failing methods | `EventConfig.runDetection` is a documented stub (`legacyRemoved`). Tests exist only to prove the legacy wiring; wiring is gone. Live EventStore persistence is already covered by `TestEventStoreRw`. |

**Installation:** no install step — fixtures exist in repo.

**Version verification:** MATLAB CI pinned to R2020b (`.github/workflows/tests.yml:248`). `matlab-actions/setup-matlab@v3` is the current action. Verified 2026-04-22.

## Architecture Patterns

### Recommended Plan Decomposition
See `## Wave/Plan Decomposition` section. 7 plans, Wave 0 → Wave 3.

### Pattern 1: Legacy-class test method → delete
**What:** Any `function testX(testCase)` whose body instantiates `Threshold(...)`, `CompositeThreshold(...)`, `Sensor(...)`, `StateChannel(...)`, `SensorRegistry.*`, `ThresholdRegistry.*`, or `ExternalSensorRegistry.*` AND whose assertions target behaviour that was deliberately deleted.
**When to use:** DEFAULT action for Category A. The product-code paths reached by these tests are themselves deleted (widgets' `t.IsUpper` / `t.allValues()` branches). Replacement coverage already exists in the parallel `*Tag.m` test files.
**Example:** Delete `TestStatusWidget.testDeriveStatusFromSensorWithThresholds` (exercises deleted `Sensor.addThreshold` + deleted widget branch). Retain `TestStatusWidgetTag` equivalents — they use `MonitorTag` + `Tag` property.

### Pattern 2: Legacy-class test → migrate to new Tag API
**What:** Test whose *name* still expresses a meaningful invariant in the v2.0 world (e.g., "event emitted on threshold violation") and whose body can be rewritten against the live API.
**When to use:** When the test verifies a behaviour that exists in v2.0 but through a different surface (e.g., event emission is now through `MonitorTag` + `EventStore`, not `EventDetector.detect`).
**Example:**
```matlab
% BEFORE (TestEventDetector/testDetectSingleEvent — 6-arg legacy):
det = EventDetector();
events = det.detect(t, values, 10, 'upper', 'warn', 'temp');

% AFTER (2-arg Tag overload — already the only live API):
st = SensorTag('temp', 'Name', 'temp', 'X', t, 'Y', values);
% BUT Threshold class is deleted — we cannot construct the second arg.
% → DELETE this test. Live coverage is in TestEventDetectorTag (skip this
%   — TestEventDetectorTag itself currently fails because it too calls
%   Threshold(...). It is *also* dead).
```
Which leads to **Pattern 2-bis: even the `*Tag.m` tests may call `Threshold(...)`** — confirmed for `TestEventDetectorTag.m:36`, `TestIconCardWidgetTag.m:76`, several others. For those, the correct fix is EITHER (a) delete the method (preferred under D-05/D-06 budget pressure), OR (b) construct the threshold as a plain-struct mock when the widget only needs `IsUpper`/`allValues()` field access.

### Pattern 3: `testCase.TestData` → `properties (Access = private)`
**What:** R2023a `TestData` → R2020b `properties` block on the test class.
**When to use:** MANDATORY for every file grepped — only 2 files found:
- `tests/suite/TestNavigatorOverlay.m` (10 methods touched)
- `tests/suite/TestSensorDetailPlot.m` (~21 methods, but `testCase.TestData.sensor` is the only field)

**Example:**
```matlab
classdef TestNavigatorOverlay < matlab.unittest.TestCase
    properties (Access = private)   % NEW
        hFig
        hAxes
    end
    methods (TestMethodSetup)
        function createFixture(testCase)
            testCase.hFig = figure('Visible', 'off');  % was testCase.TestData.hFig
            testCase.hAxes = axes('Parent', testCase.hFig);
            plot(testCase.hAxes, [0 100], [0 10]);
            xlim(testCase.hAxes, [0 100]);
            ylim(testCase.hAxes, [0 10]);
        end
    end
    methods (TestMethodTeardown)
        function destroyFixture(testCase)
            if ishandle(testCase.hFig)
                delete(testCase.hFig);
            end
        end
    end
    methods (Test)
        function testConstructorCreatesOverlay(testCase)
            ov = NavigatorOverlay(testCase.hAxes);  % was testCase.TestData.hAxes
            ...
        end
    end
end
```
Every `testCase.TestData.X` → `testCase.X`. Every `declared field X` → add to `properties (Access = private)`. Reference: `tests/suite/TestFastSenseTheme.m` uses no `TestData` — it just uses local variables + `testCase.addTeardown`; but for fixtures that span methods, `properties` is the R2020b-compatible pattern.

### Pattern 4: `DashboardBuilder.exitEditMode` library fix (Category E)
**What:** Current code at `libs/Dashboard/DashboardBuilder.m:117-151` calls `set(hFig, ...)` at lines 124-125 BEFORE checking `ishandle(hFig)` at line 140. When the figure was deleted externally, the first two `set` calls throw.
**Fix:** Add an `ishandle(hFig)` guard BEFORE the first `set` call. Proposed diff:

```matlab
function exitEditMode(obj)
    if ~obj.IsActive, return; end
    obj.IsActive = false;
    obj.SelectedIdx = 0;
    obj.DragMode = '';

    hFig = obj.Engine.hFigure;
    % FIX: guard first before any `set` calls. If the figure was
    % deleted externally, restore paths below still run (safeDelete is
    % handle-safe) but we skip set() on an invalid handle.
    if ~isempty(hFig) && ishandle(hFig)
        set(hFig, 'WindowButtonMotionFcn', obj.OldMotionFcn);
        set(hFig, 'WindowButtonUpFcn', obj.OldButtonUpFcn);
    end
    obj.OldMotionFcn = '';
    obj.OldButtonUpFcn = '';

    obj.clearOverlays();
    obj.clearGrid();
    obj.destroyGhost();

    safeDelete(obj.hPalette);  obj.hPalette = [];
    safeDelete(obj.hPropsPanel);  obj.hPropsPanel = [];

    % Re-read hFig (same value — method is idempotent).
    hFig = obj.Engine.hFigure;
    if isempty(hFig) || ~ishandle(hFig)
        return;
    end
    set(hFig, 'WindowButtonMotionFcn', '');
    set(hFig, 'WindowButtonUpFcn', '');

    theme = DashboardTheme(obj.Engine.Theme);
    obj.Engine.setContentArea(obj.Engine.Toolbar.getContentArea());
    obj.relayoutWidgets(theme);
end
```

No other `libs/Dashboard/DashboardBuilder.m` changes required — `enterEditMode` at line 85 already checks `ishandle(eng.hFigure)` via the `'DashboardBuilder:noFigure'` error path (covered by `testEnterEditModeWithoutRenderErrors`, already green). Adjacent methods (`onMouseMove`, `onMouseUp`, `applyProperties`) read handles through either `obj.Engine.hFigure` or widget overlay refs; they fire only from figure callbacks, which cannot run after the figure is deleted.

### Pattern 5: `testSensorListenersMultiPage` test fix
**What:** Lines 263-265 of `TestDashboardBugFixes.m` assign `s_y_ = rand(1, 10)` — this is a **local-variable assignment**, not a property set on `s`. No PostSet listener on `SensorTag.Y` fires because the object is untouched. Confirmed: `SensorTag.updateData(X, Y)` at `libs/SensorThreshold/SensorTag.m:265` is the idiomatic way to change Y and fire listeners (`notifyListeners_` at line 269).

**Fix (test only, no lib change):**
```matlab
% Before (broken — assigns to local var):
try
    s_y_ = rand(1, 10);
    testCase.verifyTrue(w.Dirty, ...);

% After:
try
    s.updateData(1:10, rand(1, 10));   % fires PostSet listener chain
    testCase.verifyTrue(w.Dirty, ...);
```

### Anti-Patterns to Avoid
- **Re-introducing a `Threshold.m` or `CompositeThreshold.m` shim under `libs/SensorThreshold/`.** CONTEXT.md D-06 explicitly forbids this; cleanup was deliberate.
- **Editing `libs/Dashboard/StatusWidget.m` (or GaugeWidget/IconCardWidget/MultiStatusWidget/ChipBarWidget) to fix the dead `t.IsUpper` / `t.allValues()` branches.** Those branches are unreachable in v2.0 (no `Threshold` object can be constructed). Deleting them is scope creep into a separate refactor. D-02-E allows exactly 1 library file change (`DashboardBuilder.m`); widget code is explicitly out of scope.
- **Rewriting `testCase.TestData` tests as R2023a+ `matlab.unittest.TestCase` dynamic properties.** R2020b doesn't support it; see MATLABFIX-B precedent.
- **Bundling multiple categories into a single commit.** D-04 mandates one test-class per commit for bisectability.
- **Adding any `MISS_HIT suppress_rule` entry.** D-04 forbids it; fix the test body instead.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Threshold value-object mock | `classdef MockThreshold` in tests/suite | Nothing — delete the test | D-06 forbids; widget code is dead regardless |
| PostSet-listener firing on SensorTag.Y | Custom event.listener(s, 'Y', 'PostSet', ...) | `s.updateData(X, Y)` | Canonical path already fires listeners (`SensorTag.m:265`) |
| Two-phase loader for Tag round-trip | Local `helperLoadStructsLocal_` copied around | `TagRegistry.loadFromStructs(structs)` | Production-grade path, see TestCompositeTag for pattern |
| Sensor→Event detection | `EventDetector.detect(6-arg)` migration shim | Delete tests; live path = MonitorTag + EventStore | 6-arg overload deleted in Phase 1011 |
| Incremental event detection | `IncrementalEventDetector.process(...)` | `MonitorTag.appendData(newX, newY)` | Phase 1007 MONITOR-08; incremental detector is a stub |
| Headless image export in CI | Writing a new test scaffold | Trust Phase 1006-04 fix (already in DashboardEngine.m:452-468, verified) | `exportgraphics()` present |

**Key insight:** v2.0 removed entire concepts (value-object thresholds, standalone detector pipeline, `Sensor.resolve()` side-effects). Where a test exists to exercise those concepts, the *conceptual* coverage is absent by design — the correct pattern is delete, not migrate-to-mock.

## Runtime State Inventory

This is a test-suite refactor phase. No stored data, live services, OS registrations, secrets, or build artifacts embed references to the deleted classes that would survive a code edit.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — TagRegistry is in-process; no SQLite tables keyed on deleted class names | None |
| Live service config | None — no external services consume the test suite | None |
| OS-registered state | None — CI workflow re-runs from scratch on each push; `.github/workflows/tests.yml` already references `matlab` + `scripts/run_tests_with_coverage.m` by name, those remain | None |
| Secrets / env vars | None — `FASTSENSE_SKIP_BUILD` and `FASTSENSE_RESULTS_FILE` unrelated to class names | None |
| Build artifacts / installed packages | `install()` adds `tests/suite` to path; path entry is a directory, not a class ref — survives unchanged | None |

**Confirmation:** After every test file in `tests/suite/` is updated, no runtime system still caches or registers a reference to `Sensor`/`Threshold`/etc. The MATLAB `path` cache rebuilds from `addpath` on session start; `install()` at the top of each test class re-registers the directory. No test-side state persists across CI runs.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| MATLAB R2020b | CI MATLAB job | ✓ (pinned via `matlab-actions/setup-matlab@v3`) | R2020b | — |
| GNU Octave 7+ / 11.1.0 | Octave sanity suite | ✓ (CI) | 11.1.0 | Local docker fallback: `docker run gnuoctave/octave:11.1.0` |
| MISS_HIT | Lint gate | ✓ (pip install) | per miss_hit.cfg | — |
| `exportgraphics()` | `DashboardEngine.exportImage` | ✓ (R2020a+, present in R2020b) | builtin | Octave retains `print()` branch |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** None.

Note: local MATLAB not available to this orchestrator. **Authoritative signal is the CI `MATLAB Tests` job.** An Octave sanity pass via docker is the pre-CI smoke proxy — must stay green, but does NOT prove MATLAB will pass (MATLAB tests use `matlab.unittest.TestCase`, function-style Octave tests do not).

## Common Pitfalls

### Pitfall 1: Mistaking `MonitorTag` for `Threshold`
**What goes wrong:** The word "threshold" in the legacy API has at least three meanings, all mushed together. v2.0 separated them.
- **Value + direction + label carrier:** Legacy `Threshold(key, 'Direction', 'upper'); t.addCondition(struct(), 50)`. No v2.0 equivalent — the **concept is gone** at the widget / detector layer. `MonitorTag` is a binary-signal tag, not a value-object.
- **Violation detector:** Legacy `EventDetector.detect(t, values, 10, 'upper', 'warn', 'temp')`. v2.0: `det.detect(tag, threshold)` but `threshold` is now a `MonitorTag`-like tag object with a `ConditionFn`, not a value-and-direction record.
- **Alarm boundary:** Legacy `Sensor.Thresholds{k}.IsUpper`. v2.0: the ConditionFn inside a `MonitorTag` — there is no `IsUpper` property on the monitor.

**Why it happens:** The name collision is real and irreducible. `MonitorTag.ConditionFn = @(x,y) y > 50` is *semantically* what `Threshold('upper', 50)` used to encode, but through a different surface (lambda vs field).
**How to avoid:** For Category A tests, the D-02-A heuristic is *delete unless a direct migration is trivial*. Almost no test has a trivial direct migration — confirmed by reading 5 widget test files. Errors I've flagged in `libs/Dashboard/StatusWidget.m:162-200, 286-360` are proof that even the widgets' threshold-reading code is dead; migrating tests to MonitorTag won't make those code paths come alive because they don't look for MonitorTag.
**Warning signs:** Writing a `classdef MockThreshold` to fake `IsUpper`/`allValues()` → you're trying to resuscitate dead product code.

### Pitfall 2: `EventDetector.detect` signature confusion
**What goes wrong:** Tests call the deleted 6-arg form `det.detect(t, values, 10, 'upper', 'warn', 'temp')`; code has only the 2-arg form `det.detect(tag, threshold)`. Looks like signature drift — but the 6-arg wasn't "removed", it never existed in v2.0 at all.
**Why it happens:** Phase 1011 SUMMARY notes `EventDetector 6-arg legacy path removed`. Tests didn't track.
**How to avoid:** All 8 methods of `TestEventDetector` call the 6-arg form and rely on value/direction/label strings. All require `Threshold(...)` on the 2-arg path. Both are impossible. **Delete `TestEventDetector.m` entirely** (or reduce to a single `testTagOverload` method that exists in `TestEventDetectorTag.m` already).
**Warning signs:** The 6-arg detect appears in both `TestEventDetector.m` and some Category F tests like `TestIncrementalDetector.makeTag`.

### Pitfall 3: "But the test had a good reason to exist..."
**What goes wrong:** Reviewer resistance to deleting tests ("won't that hide a regression?"). The concern is valid in general; here it's mis-applied.
**Why it happens:** Tests named `testAutoSave`, `testBackupCreated`, etc. sound like they guard important behaviour. But each body hits `cfg.addTag(s)` on a class (`EventConfig`) where `addTag` doesn't exist, OR `cfg.runDetection()` which returns empty by design.
**How to avoid:** For each deletion candidate, verify: (a) is the product behaviour also deleted? (b) is there a v2.0-equivalent test in the parallel `*Tag.m` file? If yes to both, safe to delete.
**Warning signs:** Feeling guilty about deletion → re-read Phase 1011 SUMMARY and CONTEXT.md D-02-A. Deletion is the documented plan.

### Pitfall 4: `testCase.TestData` migration breaks test isolation
**What goes wrong:** `TestData` is per-method; `properties` is per-instance. MATLAB `TestRunner` reuses the test instance across methods IF `TestClassSetup` populates state; a naive `properties` migration can leak state across methods via mutations in one test that the next one sees.
**Why it happens:** R2020b's `matlab.unittest.TestCase` constructs a new instance per method by default, but `TestMethodSetup` fires per-method. So `properties (Access = private)` + `TestMethodSetup` that re-initializes them is equivalent. Safe.
**How to avoid:** Always pair the `properties` block with `TestMethodSetup` that reassigns every field. Mirror `TestNavigatorOverlay.createFixture` exactly — it already has the right shape.
**Warning signs:** A test passes in isolation but fails inside the full suite → state leak between methods.

### Pitfall 5: Deleting a test method leaves an un-renameable stub
**What goes wrong:** MATLAB `classdef` files require at least one method inside each `methods` block. Deleting the last method from `methods (Test)` leaves an empty block → syntax error.
**Why it happens:** If every method of `TestEventDetector.m` gets deleted, the whole file should be deleted, not left as an empty skeleton.
**How to avoid:** When deleting all methods, delete the file too. CI auto-discovers files via `TestSuite.fromFolder` — no index to update. CONTEXT.md D-06 says "Do NOT rename test classes" but that refers to renaming; deletion of a fully-obsolete file is in-scope.
**Warning signs:** `if it compiles but every verify fails, the methods are still there but broken` vs `if it doesn't compile, the scaffolding leaked an empty block`.

### Pitfall 6: Octave regression while fixing MATLAB
**What goes wrong:** Octave runs the function-style tests only (`tests/test_*.m`), not the classdef suite. But some `libs/` edits (Category E: `DashboardBuilder.m`) touch code run by Octave tests too.
**Why it happens:** `DashboardBuilder.exitEditMode` is called from `test_dashboard_builder_interaction.m` etc. If the `ishandle` guard is buggy, Octave may regress.
**How to avoid:** Before committing the Category E library fix, run the docker Octave pass:
```bash
docker run --rm -v "$PWD:/work" -w /work gnuoctave/octave:11.1.0 \
    bash -c "xvfb-run octave --eval \"cd('tests'); r = run_all_tests(); exit(double(r.failed > 0));\""
```
**Warning signs:** `tests.yml → Octave Tests` job turns red after a push.

## Code Examples

### Category A — Migrate (when genuinely trivial; rare)
```matlab
% Source: TestCompositeTag.m:91 — the golden pattern
function testAddChildHandle(testCase)
    s = SensorTag('s', 'X', 1:10, 'Y', 1:10);      % replaces Sensor('s', ...)
    m = MonitorTag('m', s, @(x, y) y > 5);         % replaces Threshold(key, 'Direction', 'upper'); t.addCondition(struct(),5)
    c = CompositeTag('c', 'and');                   % replaces CompositeThreshold(...)
    c.addChild(m);
    testCase.verifyEqual(c.getChildCount(), 1);
end
```
Only applies when the test name checks a property that still exists in the new API AND the widget/detector code actually reads the new type.

### Category A — Delete (DEFAULT)
```matlab
% TestStatusWidget.testDeriveStatusFromSensorWithThresholds
% Before: 50 lines instantiating Threshold(...) + Sensor.addThreshold
% After: deleted (with git trail preserved).
% Reason: StatusWidget.m:185-200 reads obj.Sensor.Thresholds{k}.IsUpper.
%         obj.Sensor is a SensorTag; SensorTag.Thresholds getter returns {} always (SensorTag.m:92).
%         The loop runs zero times. The "violation" assertion cannot be hit.
%         The *Tag.m parallel tests (TestStatusWidgetTag — not in the failing list →
%         already green OR not yet written) cover the live Tag binding path.
```

### Category B — Delete TestEventDetector entirely; keep TestEventDetectorTag after fixing
```matlab
% TestEventDetector.m — all 8 methods call the deleted 6-arg form.
% Action: delete the file.
% TestEventDetectorTag.m still creates Threshold(...) — delete those 3 method bodies OR
%   inline a plain struct mock where the downstream only reads Direction/Name:
%     thr = struct('Direction','upper','Name','Warn','Key','warn', ...
%                  'allValues', @() 10, 'IsUpper', true);
%   But EventDetector.detect at libs/EventDetection/EventDetector.m:58 calls
%   threshold.allValues() (method call), which requires a class not a struct.
%   → Delete the TestEventDetectorTag methods too; keep the file shell + one
%     smoke test that constructs EventDetector() with no detect() call.
```

### Category C — testCase.TestData → properties (full diff)
```matlab
% BEFORE: TestNavigatorOverlay.m:9-26
methods (TestMethodSetup)
    function createFixture(testCase)
        testCase.TestData.hFig = figure('Visible', 'off');
        testCase.TestData.hAxes = axes('Parent', testCase.TestData.hFig);
        plot(testCase.TestData.hAxes, [0 100], [0 10]);
        xlim(testCase.TestData.hAxes, [0 100]);
        ylim(testCase.TestData.hAxes, [0 10]);
    end
end

% AFTER:
properties (Access = private)
    hFig
    hAxes
end
methods (TestMethodSetup)
    function createFixture(testCase)
        testCase.hFig = figure('Visible', 'off');
        testCase.hAxes = axes('Parent', testCase.hFig);
        plot(testCase.hAxes, [0 100], [0 10]);
        xlim(testCase.hAxes, [0 100]);
        ylim(testCase.hAxes, [0 10]);
    end
end
methods (TestMethodTeardown)
    function destroyFixture(testCase)
        if ishandle(testCase.hFig), delete(testCase.hFig); end
    end
end
```
Inside every test method, `testCase.TestData.hAxes` → `testCase.hAxes`. Same for `hFig`.

`TestSensorDetailPlot` fixture: only `testCase.TestData.sensor` — wrap in `properties (Access = private)\n    sensor\nend`.

### Category E-test fix — TestDashboardBugFixes.testSensorListenersMultiPage
```matlab
% Line 263-265 — current (broken):
try
    s_y_ = rand(1, 10);
    testCase.verifyTrue(w.Dirty, ...);
catch
    testCase.assumeTrue(false, 'Octave lacks PostSet');
end

% Target:
try
    s.updateData(1:10, rand(1, 10));
    testCase.verifyTrue(w.Dirty, ...);
catch
    testCase.assumeTrue(false, 'Octave lacks PostSet');
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Threshold` value-object | Gone — use `MonitorTag` for boolean signal, rely on widget `Threshold`-prop code-path being dead | Phase 1011 (2026-04-17) | Widget tests for threshold-binding paths lose coverage; parallel `*Tag` tests replace them |
| `EventDetector.detect(t, y, val, dir, label, name)` — 6-arg | `det.detect(tag, threshold)` — 2-arg | Phase 1009 + 1011 | TestEventDetector obsolete |
| `IncrementalEventDetector.process(key, sensor, t, y, ...)` | `MonitorTag.appendData(newX, newY)` | Phase 1007 MONITOR-08 | TestIncrementalDetector obsolete |
| `SensorRegistry.register / .get` | `TagRegistry.register / .get` (hard-errors on dup) | Phase 1004 | Registry tests already migrated |
| `EventConfig.addSensor(s)` + `.runDetection()` | Use `EventStore` + `MonitorTag` directly | Phase 1011 | TestEventStore obsolete |
| `testCase.TestData.X` (R2023a+) | `properties (Access = private)` block | R2020b pin (Phase 1006) | 2 files affected |
| `exportImage` via `print()` headless fail | `exportgraphics()` on R2020a-R2023b | Phase 1006-04 (2026-04-16) | Fix present at `libs/Dashboard/DashboardEngine.m:452-468`; verified |

**Deprecated/outdated:**
- `loadModuleData` / `loadModuleMetadata`: Octave-only fixtures moved or deleted with Phase 1011. Check-and-delete per-test-method.
- `detectEventsFromSensor` standalone function: gone; no equivalent.
- Sensor-centric event detection entirely: gone; see `libs/EventDetection/EventConfig.m:35-42` stub.

## Open Questions

1. **Do `TestStatusWidgetTag`, `TestGaugeWidgetTag`, `TestChipBarWidgetTag` exist and pass?**
   - What we know: `TestIconCardWidgetTag.m`, `TestMultiStatusWidgetTag.m`, `TestFastSenseWidgetTag.m` exist in `tests/suite/`. Both are listed as failing (4+ verify failures each) in the CI log.
   - What's unclear: Do they fail because they also call `Threshold(...)` (confirmed for TestIconCardWidgetTag line 76), or because of a deeper issue with the Tag path?
   - Recommendation: In Wave 0 of the plan, run a per-file local grep for `Threshold(` in the `*Tag.m` test files — any matches indicate further Category A cleanup. Likely: **all 6 widget+tag+event tests need the `Threshold(...)` calls extracted or deleted.**

2. **Does `TestLivePipeline` (8 failures) still have a live v2.0 analogue?**
   - What we know: `LiveEventPipeline` was rewired in Phase 1009 to take `MonitorTargets` directly; `TestLiveEventPipelineTag.m` is the v2.0 test (also has failures).
   - What's unclear: Whether `TestLivePipeline` tests a behaviour that still exists, or a deleted pipeline.
   - Recommendation: Treat as Category A — scan the test body; if it calls `Threshold(...)` or `addSensor`, delete methods; if it calls `pipeline.start()` + observes events, migrate.

3. **Does `TestDashboardToolbarImageExport` still fail in CI, or was it fixed by Phase 1006-04?**
   - What we know: `libs/Dashboard/DashboardEngine.m:452-468` has `exportgraphics` (verified line 468), the `useExportGraphics` branch is in place.
   - What's unclear: Why the CI log still lists 4 failures in this test. Possibilities: (a) MATLAB CI path regression, (b) test itself has migrated to something else, (c) stale CI log from before Phase 1006-04 merge.
   - Recommendation: Planner should confirm by reading the LATEST CI log (not the investigation log). If the failures are still there post-1006-04, it's a new regression — diagnose independently. Do not preemptively "fix" what's already fixed.

4. **Do the 3 `TestToolbar` verify-failures reference deleted APIs or are they real UI drift?**
   - What we know: `TestToolbar.m` does NOT grep-match `Threshold(`. It tests `FastSenseToolbar` (not a widget). 3 of 19 methods fail per the CI log.
   - What's unclear: Which 3, and why.
   - Recommendation: Per-method diagnosis during planning Wave 0. Likely candidates: `testToolbarHasAllButtons` (expects 11 children; may have changed), `testViolationsToggle` (exercises `addThreshold` on FastSense — which still works, so this is a real product-vs-test check).

## Wave/Plan Decomposition

**Recommended plan split: 7 plans across 4 waves.**

### Wave 0 — Pattern-establishing pilots (sequential; unblocks Wave 1-3)
**1014-01-PLAN: Category C pilot + Category E fixes (no-parallelism wave)**
- Files touched: `tests/suite/TestNavigatorOverlay.m` (10 methods → `properties` block), `tests/suite/TestSensorDetailPlot.m` (replace only the `testCase.TestData.sensor` references — leave Category A tests alone in this plan), `tests/suite/TestDashboardBugFixes.m` (test fix: `updateData` line 263-265), `libs/Dashboard/DashboardBuilder.m` (lib fix: `ishandle` guard at line 124).
- Why Wave 0: `TestNavigatorOverlay` is the Category C pattern source — Wave 1's many per-file migrations can copy from it. The library fix is a blocker for `testExitEditModeAfterFigureClose` and must land before Wave 1 claims D-02-E is resolved.
- Effort: 30-60 min.
- Commit plan: 4 commits (one per file touched).

### Wave 1 — Per-file Category A migrations (parallel)
**1014-02-PLAN: Widget threshold-test DELETE batch**
- Files: `TestStatusWidget.m` (12 failures — 9 threshold methods to delete), `TestGaugeWidget.m` (8), `TestIconCardWidget.m` (6), `TestChipBarWidget.m` (3), `TestMultiStatusWidget.m` (9 — incl. `CompositeThreshold` references which are double-dead).
- Strategy: Delete every method that instantiates `Threshold(...)`/`CompositeThreshold(...)`. Keep the core construction/render/getType/fromStruct tests (they pass, they don't exercise deleted code paths).
- Output per file: reduce method count, file stays green, no methods migrated.
- Effort: 20-30 min per file × 5 files = ~120 min.

**1014-03-PLAN: `*Tag.m` widget + event tests — fix `Threshold(...)` calls**
- Files: `TestIconCardWidgetTag.m` (3 methods), `TestMultiStatusWidgetTag.m` (2), `TestFastSenseWidgetTag.m` (unknown count), `TestEventDetectorTag.m` (at least 3 methods with `Threshold(...)`), `TestLiveEventPipelineTag.m` (unknown), `TestEventTimelineWidgetTag.m` (unknown), `TestSensorDetailPlotTag.m` (unknown — 3 failures per CI log).
- Strategy: Per method — does the body test a real v2.0 code path (Tag property precedence over Threshold) that survives deleting the `Threshold(...)` constructor call? If yes, simplify the method to drop the `Threshold` arm. If no, delete the method.
- Effort: 15-25 min per file × 7 files = ~120 min.

**1014-04-PLAN: `TestSensorDetailPlot.m` heavy-hitter (21 failures)**
- Files: only `tests/suite/TestSensorDetailPlot.m`.
- Strategy: Category A-dominant; many methods use `Event(...)` (still supported) + `createTagWithThreshold` static helper that calls `Threshold(...)`. Strip the helper; delete threshold-dependent methods; keep pure render/navigation tests.
- Effort: 45-60 min (D-05 budget edge).
- Split-or-not decision: 1 plan. File is coherent; splitting bisects context. If it blows 45-min budget, trigger D-05 kill-switch and delete the remaining failing methods.

**1014-05-PLAN: EventDetection test-suite collapse**
- Files: `TestEventDetector.m` (delete file — 8 methods all call deleted 6-arg), `TestIncrementalDetector.m` (delete file — 8 methods all call `process(6-arg)` which throws `legacyRemoved`), `TestEventStore.m` (delete 7 methods that call `cfg.addTag`+`runDetection`; keep `testFromFileNotFound` which is pure static — check EventViewer path), `TestEventConfig.m` (6 failures — strip methods that call `addSensor`/`addTag`), `TestLivePipeline.m` (8 failures — likely delete most).
- Strategy: Aggressive deletion under D-02-A. Most methods exercise the deleted Sensor-resolve pipeline.
- Effort: 45-75 min.

### Wave 2 — Dashboard edge-cases (parallel, shared Wave 1 pattern)
**1014-06-PLAN: Dashboard small-number failures batch**
- Files: `TestDashboardEngine.m` (1), `TestDashboardPerformance.m` (1), `TestDashboardBuilderInteraction.m` (5), `TestDashboardSerializerRoundTrip.m` (1 × 4 sub-verifications), `TestDataStoreWAL.m` (2), `TestDatastoreEdgeCases.m` (1), `TestNumberWidget.m` (1 + 2 verify = 3), `TestFastSenseAddTag.m` (1), `TestFastSenseWidget.m` (2 + 1 verify = 3), `TestFastSenseWidgetUpdate.m` (1), `TestWebBridge.m` (5), `TestDataSource.m` (1 verify).
- Strategy: Per-test root-cause. Mixed Category A + F. Each method gets ~5 min triage; fix trivial ones, delete rest.
- Effort: 60-90 min total.

### Wave 3 — Category F residuals (parallel, cleanup)
**1014-07-PLAN: Category F residual triage**
- Files: `TestTag.m` (1 verify — `testConstructorRequiresKey`), `TestToolbar.m` (3), `TestMonitorTagEvents.m` (1), `TestMonitorTagPersistence.m` (3 — grep gates, likely fragile against MonitorTag doc text changes), `TestDashboardToolbarImageExport.m` (confirm Phase 1006-04 fix: probably green already; if still red → diagnose).
- Strategy: Per-test diagnosis; see Category F Triage Table below.
- Effort: 45-60 min.

### Triage Table (Category F methods)
| Test | Suspected root cause | Fix: test or lib? | Est. effort |
|------|----------------------|-------------------|-------------|
| `TestTag/testConstructorRequiresKey` | Tag constructor signature; Tag.m:80 confirms it errors on empty/non-char → test calls `MockTag()` no-arg → likely an argument ordering issue | Test | 5 min |
| `TestToolbar/testToolbarHasAllButtons` | Hardcoded `verifyEqual(numel(children), 11)` — toolbar changed | Test | 10 min |
| `TestToolbar/testExportPNG` | `exportPNG` may call into `print()` — headless regression analog of Category D | Test or lib | 15 min |
| `TestToolbar/*third* (unnamed)` | — | Investigate | 15 min |
| `TestMonitorTagEvents/testCarrierPatternNoTagKeys` | MONITOR-05 carrier text drift; test greps MonitorTag.m for specific text | Test | 10 min |
| `TestMonitorTagPersistence/testMonitorTagHasPersistProperties` | Regex drift on MonitorTag.m property declarations | Test | 5 min |
| `TestMonitorTagPersistence/testFastSenseDataStoreHasMonitorAPI` | Regex drift on FastSenseDataStore.m | Test | 5 min |
| `TestMonitorTagPersistence/testPitfall2StructuralGate` | Structural regex gate; may have drifted after Phase 1010 (`EventBinding.attach` call above storeMonitor adds lines to 5-line window) | Test (widen window or rewrite gate) | 10 min |
| `TestDashboardSerializerRoundTrip/testRoundTripPreservesWidgetSpecificProperties` | 4 sub-verifications — widget schema drift | Test | 20 min |
| `TestDashboardBuilderInteraction/×5` | UI layer drift — Phase 1000 performance work changed render() ordering | Test | 25 min |
| `TestDashboardToolbarImageExport/×4` | Phase 1006-04 fix present; if still failing, either R2020b CI quirk or new regression | Diagnose first | 30 min |
| `TestDataSource/×1 verify` | — | Investigate | 10 min |
| `TestFastSenseWidget/×1 verify` | — | Investigate | 10 min |
| `TestGaugeWidget/×1 verify` | — | Investigate | 10 min |

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `matlab.unittest` (R2020b) + `matlab.unittest.TestRunner.withTextOutput` |
| Config file | None (auto-discovery via `TestSuite.fromFolder`) |
| Quick run command | `matlab -batch "addpath('scripts'); run_tests_with_coverage()"` (requires local MATLAB) |
| Full suite command | Same — `run_tests_with_coverage()` runs everything in `tests/suite/` |
| CI trigger | `.github/workflows/tests.yml` → `matlab-actions/run-command@v3` with `addpath('scripts'); run_tests_with_coverage();` |
| Octave proxy | `docker run --rm -v "$PWD:/work" -w /work gnuoctave/octave:11.1.0 bash -c "xvfb-run octave --eval \"cd('tests'); r = run_all_tests(); exit(double(r.failed > 0));\""` |
| Lint | `mh_style libs/ tests/ examples/` + `mh_lint libs/ tests/ examples/` + `mh_metric --ci libs/ tests/ examples/` |

### Phase Requirements → Test Map
Phase 1014 has no exclusive REQ-IDs; the "requirement" is CI green. The test-map is inverted (the tests ARE the subject). Per-plan sampling strategy below.

| Plan | Primary target | Automated sampling command | Expected after plan |
|------|----------------|----------------------------|---------------------|
| 1014-01 | C + E | `matlab -batch "run(matlab.unittest.TestSuite.fromClass(?TestNavigatorOverlay))"` + `run(?TestDashboardBugFixes)` | 10+2 tests green |
| 1014-02 | Widget threshold DELETE | `for T in TestStatusWidget TestGaugeWidget TestIconCardWidget TestChipBarWidget TestMultiStatusWidget; do matlab -batch "run(matlab.unittest.TestSuite.fromClass(?$T))"; done` | Lower method count, zero failures in the survivors |
| 1014-03 | `*Tag` Threshold strip | Same loop for `TestIconCardWidgetTag TestMultiStatusWidgetTag TestFastSenseWidgetTag TestEventDetectorTag TestLiveEventPipelineTag TestEventTimelineWidgetTag TestSensorDetailPlotTag` | Zero failures |
| 1014-04 | SensorDetailPlot | `matlab -batch "run(?TestSensorDetailPlot)"` | Zero failures |
| 1014-05 | EventDetection collapse | `for T in TestEventDetector TestIncrementalDetector TestEventStore TestEventConfig TestLivePipeline; do …` | Files deleted OR zero failures |
| 1014-06 | Dashboard small-numbers | Per-file loop over the 12 files | Zero failures |
| 1014-07 | Category F | Per-file loop over the 7 files | Zero failures |

### Sampling Rate
- **Per task commit:** run the single affected test class via `matlab -batch "run(matlab.unittest.TestSuite.fromClass(?TestXxx))"` (or `octave --eval "test_...()"` when the plan touches code an Octave function-test exercises). Must go from red → green on the touched file.
- **Per wave merge:** run the full suite `scripts/run_tests_with_coverage.m` (local if MATLAB present; else CI smoke by pushing WIP). Failure count monotonically decreasing vs. baseline.
- **Phase gate:** CI `Tests → MATLAB Tests` job green on push; `Tests → Octave Tests` job still green; MISS_HIT steps clean.

### Wave 0 Gaps
- `{none}` — existing test infrastructure covers all phase requirements. `tests/suite/` is the phase subject; no new test files need creation; no fixture factory additions (MakePhase1009Fixtures.m covers Category A migration patterns already).
- Framework install: none needed beyond the CI's `setup-matlab@v3` action.
- The PRE-flight diagnostic for 1014-01 (before any file edit): **run the full suite locally or via CI on the unchanged branch to capture baseline failure count** — so monotonic reduction is provable.

## Risk Register

| Risk | Mitigation |
|------|------------|
| Migrating `Threshold → MonitorTag` silently passes the test but covers different behaviour (test passes, tests the wrong thing) | Default action under D-02-A is **delete**, not migrate. Only migrate when the test name describes a behaviour that exists in v2.0 AND the target widget/detector actually reads the new type. Reviewer sign-off on any migration. |
| Deleting a test method hides a real regression | Every deletion is accompanied by a verification that (a) the product code path is itself deleted/unreachable, OR (b) parallel coverage exists in the `*Tag.m` file. Document in commit message: `DELETE <method> — tests widget's deleted Threshold.IsUpper branch; coverage in TestXxxTag`. |
| R2020b pin edge case diverges from local MATLAB | Rely on CI as authoritative (D-03). Don't trust local passes from newer MATLAB. |
| Flaky headless tests (Category D) | Category D already fixed per `libs/Dashboard/DashboardEngine.m:452-468`. If still failing post-Wave 1, diagnose independently (possible CI environment regression); no test-side fix. |
| Library change to `DashboardBuilder.m` cascades to more methods | Strict boundary: only `exitEditMode` at lines 117-151 is touched. Grep `DashboardBuilder.m` for other `set(hFig, ...)` paths that might have the same bug — they're inside `enterEditMode` guarded by `DashboardBuilder:noFigure` check, which fires earlier, so safe. |
| Octave test regression from Category E library fix | Pre-commit docker Octave pass (see Pitfall 6). |
| TestSensorDetailPlot (21 failures) blows the 45-min budget | D-05 kill-switch: delete remaining failing methods. Keep pure render/navigation/zoom tests (6-8 survivors). |
| A deletion-heavy plan gets reverted ("we need those tests back") | Each plan SUMMARY.md lists **exactly** which methods were deleted and why. If a reviewer wants them back, it's a v2.1 test-coverage phase, not a 1014 rollback. |
| `TestEventDetectorTag.m` et al. turn out to ALSO call `Threshold(...)` | Confirmed — see Code Examples Category B. Plan 1014-03 addresses this. The `*Tag` tests are NOT automatically safe. |

## Effort Estimate per Plan (bounded; D-05 45-min-per-class kill-switch)

| Plan | Files | Methods | Risk of blowing D-05 | Rank |
|------|-------|---------|-----------------------|------|
| 1014-04 `TestSensorDetailPlot` | 1 | 21 failures, 1 file | **HIGH** — single-file 21 failures; static `createTagWithThreshold` helper entangles many methods. D-05 kill-switch may fire. | **1** |
| 1014-05 EventDetection collapse | 5 | ~37 | **MEDIUM-HIGH** — 5 files but deletion is often whole-file (`TestEventDetector`, `TestIncrementalDetector`). Budget risk is in `TestLivePipeline` (8 failures, unclear root cause). | 2 |
| 1014-03 `*Tag` Threshold strip | 7 | ~15-20 | **MEDIUM** — 7 files, most with 2-4 methods; pattern is consistent across files (drop `Threshold(...)` arms). | 3 |
| 1014-02 Widget-threshold DELETE | 5 | ~38 | **MEDIUM** — many methods but the pattern is uniform: delete all threshold/composite/sensor-resolve methods. | 4 |
| 1014-06 Dashboard small-numbers batch | 12 | ~25 | **MEDIUM** — 12 files but each has 1-5 failures; risk is that one file surfaces an unexpected library issue. | 5 |
| 1014-07 Category F residuals | 7 | ~15 | **LOW** — per-test diagnosis; regex drift fixes are fast. | 6 |
| 1014-01 C+E pilots | 4 | ~12 | **LOW** — well-scoped, patterns proven. | 7 |

**Bottom line:** Plan 1014-04 (TestSensorDetailPlot) is the MOST likely to blow D-05 budget. Second-riskiest is 1014-05 (EventDetection collapse) due to `TestLivePipeline` unknowns. Plan these first to surface problems early.

## Sources

### Primary (HIGH confidence)
- `.planning/phases/1014-.../1014-CONTEXT.md` — user decisions, failure categories
- `.planning/STATE.md` — project decisions history, Phase 1011 completion notes
- `.planning/ROADMAP.md:399-407` — Phase 1014 scope statement
- `.planning/phases/1006-.../1006-CONTEXT.md` + `1006-04-PLAN.md` — precedent for MATLABFIX-B (Cat. C) and MATLABFIX-F (Cat. D)
- `libs/SensorThreshold/Tag.m`, `SensorTag.m`, `StateTag.m`, `MonitorTag.m`, `CompositeTag.m`, `TagRegistry.m` — current v2.0 API surface
- `libs/EventDetection/EventDetector.m`, `IncrementalEventDetector.m`, `EventConfig.m` — current signature state; stubs documented in source
- `libs/Dashboard/DashboardBuilder.m` (lines 90-180), `DashboardEngine.m` (lines 373-480), `StatusWidget.m` (lines 155-360) — library code realities
- `libs/Dashboard/ChipBarWidget.m:240-290` — proves widgets read `.IsUpper`/`.allValues()` from deleted classes
- `tests/suite/TestCompositeTag.m` — GREEN reference pattern (CONFIRMED: uses the Tag API correctly throughout)
- `tests/suite/TestFastSenseTheme.m` — GREEN reference for non-TestData fixture idiom
- `tests/suite/TestMonitorTag.m`, `TestSensorTag.m`, `TestStateTag.m`, `TestCompositeTag.m` — v2.0 reference tests (known green)
- `.github/workflows/tests.yml:234-305` — MATLAB Tests job definition; R2020b pin confirmed at line 248
- `scripts/run_tests_with_coverage.m` — CI entry point

### Secondary (MEDIUM confidence)
- CI failure list from CONTEXT.md `<specifics>` block — inventory of failing tests (run `24780979036`; assumed accurate; may have drifted since)
- `tests/suite/MakePhase1009Fixtures.m` — test fixture factory pattern

### Tertiary (LOW confidence)
- Exact number of F-category failures and their specific root causes — triaged by *expectation* rather than *execution*. Planner must verify each during Wave 3 planning.
- Whether `TestLivePipeline` has any salvageable methods — body not read; assumed all-delete.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — every library file read, signatures verified
- Architecture patterns: HIGH — prior-art tests (`TestCompositeTag`, `TestFastSenseTheme`) serve as canonical references
- Pitfalls: HIGH — each pitfall has source-file corroboration
- Category F individual diagnoses: MEDIUM — triage-by-expectation; planner verifies during Wave 3

**Research date:** 2026-04-22
**Valid until:** 2026-05-22 (30 days — test suite content is stable; CI workflow file unchanged since Phase 1006)

## RESEARCH COMPLETE

**Phase:** 1014 - Fix ~140 MATLAB test-suite failures from v2.0 legacy-class deletion
**Confidence:** HIGH

### Key Findings
- **Default action for Category A is DELETE, not migrate.** Widget code paths that tests target (`StatusWidget.m`, `GaugeWidget.m`, `IconCardWidget.m`, `MultiStatusWidget.m`, `ChipBarWidget.m`) still reference DELETED classes (`Threshold`, `CompositeThreshold`, `Sensor.addThreshold`) — those widget branches are dead code. Tests exercising them cannot succeed regardless of migration effort. Parallel `*Tag.m` tests already cover live v2.0 paths.
- **`EventDetector.detect` currently has only a 2-arg `(tag, threshold)` overload** — every 6-arg caller in `TestEventDetector.m` is calling a deleted signature. **Delete the entire file.** Same applies to `TestIncrementalDetector.m` (calls `process(6-arg)` which throws `legacyRemoved`).
- **The "Tag" test variants ALSO reference deleted classes.** `TestEventDetectorTag.m:36`, `TestIconCardWidgetTag.m:76`, several others still instantiate `Threshold(...)`. Plan 1014-03 scope confirmed — the `*Tag` tests are not automatically safe.
- **Category C affects only 2 files:** `TestNavigatorOverlay.m` (10 methods) and `TestSensorDetailPlot.m` (via `TestData.sensor` only — 1 field). Pattern is mechanical.
- **Category E library fix is strictly `DashboardBuilder.exitEditMode` line 124** — add `ishandle(hFig)` guard BEFORE the first `set` call. No other `libs/` changes needed.
- **Phase 1006-04 `exportgraphics()` fix is still present** at `libs/Dashboard/DashboardEngine.m:452-468` (verified). If Category D still fails in CI, that's a new regression, not a missed Phase 1006 fix.

### File Created
`.planning/phases/1014-fix-140-matlab-test-suite-failures-from-v2-0-legacy-class-deletion/1014-RESEARCH.md`

### Confidence Assessment
| Area | Level | Reason |
|------|-------|--------|
| Standard Stack | HIGH | Every current library file read; API signatures verified |
| Architecture (plan decomposition) | HIGH | Pattern sources (TestCompositeTag, TestFastSenseTheme) read in full; 7-plan split aligns with Category A-F failure axes |
| Pitfalls | HIGH | Each pitfall grounded in a source-file line reference |
| Category F individual diagnoses | MEDIUM | Triage-by-expectation; planner Wave 3 verifies |
| Effort estimates | MEDIUM | Method counts from CI log; D-05 kill-switch bounds upside |

### Open Questions (for planner to resolve in Wave 0)
1. Do `TestStatusWidgetTag`, `TestGaugeWidgetTag`, `TestChipBarWidgetTag` exist and (if yes) have their own `Threshold(...)` calls needing cleanup?
2. Has `TestDashboardToolbarImageExport` Category D been resolved by Phase 1006-04 already (expected YES), or does the CI log reflect a new regression (expected NO)? Planner should confirm with fresh CI run.
3. Does `TestLivePipeline` have ANY salvageable methods or is it 100% deletion? Body was not read in research.

### Ready for Planning
Research complete. Planner can now create 7 PLAN.md files per the Wave decomposition table. Wave 0 (1014-01) must land before Wave 1 to seed the Category C pattern and apply the library fix. Wave 1 plans 1014-02 through 1014-05 run in parallel. Wave 2 (1014-06) and Wave 3 (1014-07) follow.
