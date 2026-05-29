---
phase: 01-infrastructure-hardening
verified: 2026-04-01T21:00:00Z
status: passed
score: 7/7 must-haves verified
re_verification:
  previous_status: gaps_found
  previous_score: 6/7
  gaps_closed:
    - "testTimerContinuesAfterError now uses indirect ErrorFcn triggering — no private method call, correct MATLAB timer path exercised"
  gaps_remaining: []
  regressions: []
---

# Phase 1: Infrastructure Hardening Verification Report

**Phase Goal:** The dashboard engine is safe to extend — timer errors cannot silently kill refresh, GroupWidget children survive .m export, and jsondecode normalization is applied wherever nested arrays are decoded
**Verified:** 2026-04-01T21:00:00Z
**Status:** passed
**Re-verification:** Yes — after gap closure via Plan 01-04 (commit fdb5287)

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | When onLiveTick throws an uncaught error, the timer continues running and does not stop permanently | VERIFIED | ErrorFcn wired at DashboardEngine.m line 174; onLiveTimerError restarts if IsLive (line 778). testTimerContinuesAfterError now exercises this via indirect throwing-TimerFcn path (line 126) — no private-method call remains |
| 2 | The error message is logged via warning() with identifier DashboardEngine:timerError | VERIFIED | Line 776: `warning('DashboardEngine:timerError', ...)` present in onLiveTimerError |
| 3 | If stopLive() is called while IsLive=false the timer is NOT restarted by the error handler | VERIFIED | Line 778: guard `if obj.IsLive && ~isempty(obj.LiveTimer) && isvalid(obj.LiveTimer)` — restart only happens when IsLive is true |
| 4 | Existing startLive/stopLive API and behavior is unchanged for the normal (no-error) path | VERIFIED | No API changes; only addition of ErrorFcn to timer constructor |
| 5 | A shared normalizeToCell helper exists in libs/Dashboard/private/ so future phases can use it | VERIFIED | File exists at libs/Dashboard/private/normalizeToCell.m (confirmed present) |
| 6 | GroupWidget.fromStruct() calls normalizeToCell for children, tabs, and tab.widgets; no inline isstruct blocks remain | VERIFIED | 3 normalizeToCell calls at lines 492, 504, 508 confirmed; inline isstruct blocks removed |
| 7 | DashboardSerializer.loadJSON() calls normalizeToCell instead of inline isstruct check | VERIFIED | Line 182: `config.widgets = normalizeToCell(config.widgets)` confirmed |
| 8 | A GroupWidget with panel/collapsible children exported to .m and re-imported loads all children correctly | VERIFIED | emitChildWidget helper exists (line 412); case 'group' emits addChild() calls; testGroupWithChildrenRoundTrip and testMExportPreservesChildren tests exist and were reported passing |
| 9 | A GroupWidget with tabbed children exported to .m and re-imported loads children in correct tabs | VERIFIED | save() case 'group' handles tabbed mode separately with addChild(widget, tabName) form; testGroupTabbedRoundTrip test exists and reported passing |
| 10 | Old .m files that have no children still load without errors | VERIFIED | No structural change to non-group widget cases; DashboardSerializer.loadJSON unchanged except normalizeToCell call; testLoadFromMFile covers this path |
| 11 | All existing dashboard scripts run without modification | VERIFIED | No API changes across DashboardEngine, GroupWidget, or DashboardSerializer public interfaces |
| 12 | Previously saved JSON and .m dashboards load without errors or data loss | VERIFIED | normalizeToCell call in loadJSON() is backward-compatible (handles empty, struct, and cell); no breaking changes |
| 13 | DashboardBuilder API is unchanged | VERIFIED | DashboardSerializer.m changes are additive only (new emitChildWidget helper, groupCount counter, fixed group case) |

**Score:** 13/13 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `libs/Dashboard/DashboardEngine.m` | startLive() with ErrorFcn; onLiveTimerError private method | VERIFIED | ErrorFcn on line 174; onLiveTimerError method at line 766; warning identifier at line 776 |
| `tests/suite/TestDashboardEngine.m` | testTimerContinuesAfterError that uses indirect ErrorFcn triggering | VERIFIED | Method exists at line 110; uses `set(d.LiveTimer, 'TimerFcn', @(~,~) error(...))` at line 126; zero references to `onLiveTimerError` remain; `isrunning(d.LiveTimer)` assertion at line 132; `pause(0.5)` at line 129 |
| `libs/Dashboard/private/normalizeToCell.m` | Shared jsondecode struct-array-to-cell normalizer | VERIFIED | Exists, handles all 3 cases (empty, struct array, cell passthrough) |
| `libs/Dashboard/GroupWidget.m` | fromStruct() using normalizeToCell helper (3 calls) | VERIFIED | 3 normalizeToCell calls confirmed at lines 492, 504, 508; inline isstruct blocks removed |
| `libs/Dashboard/DashboardSerializer.m` | loadJSON() using normalizeToCell; emitChildWidget helper; fixed group case | VERIFIED | normalizeToCell in loadJSON (line 182); emitChildWidget defined (line 412) with 4 call sites; addChild emission confirmed |
| `tests/suite/TestDashboardSerializer.m` | testNormalizeToCellHelper test method | VERIFIED | Method exists; tests normalizeToCell indirectly via DashboardSerializer.loadJSON |
| `tests/suite/TestDashboardMSerializer.m` | testGroupWithChildrenRoundTrip and testGroupTabbedRoundTrip | VERIFIED | Both methods exist |
| `tests/suite/TestGroupWidget.m` | testMExportPreservesChildren test method | VERIFIED | Method exists at line 269 |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `DashboardEngine.m startLive()` | `onLiveTimerError private method` | `ErrorFcn` callback on timer constructor | VERIFIED | Line 174: `'ErrorFcn', @(t, e) obj.onLiveTimerError(t, e)` confirmed |
| `TestDashboardEngine.m testTimerContinuesAfterError` | `DashboardEngine.onLiveTimerError` | MATLAB timer infrastructure invoking ErrorFcn after TimerFcn throws | VERIFIED | Line 126 sets throwing TimerFcn; MATLAB timer calls the real ErrorFcn callback naturally; `isrunning` assertion at line 132 |
| `DashboardSerializer.m save() case 'group'` | `emitChildWidget private static method` | `DashboardSerializer.emitChildWidget(...)` call | VERIFIED | Multiple call sites in panel/tabbed loop and recursion confirmed |
| `generated .m file addChild calls` | `GroupWidget.addChild()` | `feval of generated .m function` | VERIFIED | sprintf emission sites for addChild confirmed |
| `GroupWidget.m fromStruct()` | `libs/Dashboard/private/normalizeToCell.m` | direct function call via private/ dir | VERIFIED | 3 normalizeToCell calls at lines 492, 504, 508 |
| `DashboardSerializer.m loadJSON()` | `libs/Dashboard/private/normalizeToCell.m` | direct function call via private/ dir | VERIFIED | Line 182: `config.widgets = normalizeToCell(config.widgets)` |

### Data-Flow Trace (Level 4)

Not applicable — this phase produces MATLAB utility/infrastructure code (timer callbacks, serializer helpers), not React/web components rendering dynamic data. No data-flow trace needed.

### Behavioral Spot-Checks

Step 7b: SKIPPED — requires live MATLAB runtime. Key behaviors are verified statically via artifact and key-link checks. Full suite was reported passing by the agent (see SUMMARY 01-03) with 5 documented pre-existing failures unrelated to Phase 1; Plan 01-04 reduces that count by 1 (testTimerContinuesAfterError should now pass).

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| INFRA-01 | 01-01 | DashboardEngine.LiveTimer has ErrorFcn that logs errors and keeps timer running | SATISFIED | Implementation verified (ErrorFcn wired, onLiveTimerError restarts); test testTimerContinuesAfterError rewritten via Plan 01-04 to use indirect ErrorFcn triggering — no private-method access, assertion reachable |
| INFRA-02 | 01-03 | DashboardSerializer .m export correctly serializes GroupWidget children | SATISFIED | emitChildWidget helper + fixed case 'group' + 3 passing round-trip tests |
| INFRA-03 | 01-02 | jsondecode struct-vs-cell normalization applied at all new nesting levels | SATISFIED | normalizeToCell.m exists; 3 call sites in GroupWidget.fromStruct; 1 in DashboardSerializer.loadJSON; additional calls in save() |
| COMPAT-01 | 01-01, 01-03 | Existing dashboard scripts run without modification | SATISFIED | No API changes; additive-only modifications |
| COMPAT-02 | 01-02, 01-03 | Previously serialized JSON dashboards load correctly | SATISFIED | normalizeToCell backward-compatible; TestDashboardSerializerRoundTrip reported passing |
| COMPAT-03 | 01-03 | Previously serialized .m dashboards load correctly | SATISFIED | Non-group widget cases unchanged; group case backward-compatible |
| COMPAT-04 | 01-03 | DashboardBuilder API remains unchanged | SATISFIED | No changes to DashboardBuilder; all modifications confined to DashboardSerializer internal methods |

All 7 requirement IDs from plan frontmatter accounted for. No orphaned requirements.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `tests/suite/TestGroupWidget.m` | testFullDashboardIntegration | Saves to `.json` extension but writes `.m` code | WARNING (pre-existing) | Pre-existing failure, not introduced by Phase 1. Tracked in deferred-items.md. |
| `tests/suite/TestDashboardBuilder.m` | testAddWidgetFromPalette, testDragSnapsToGrid, testResizeSnapsToGrid | Stale test expectations for deprecated 'kpi' type and numeric tolerance | WARNING (pre-existing) | 3 pre-existing failures, not introduced by Phase 1. Tracked in deferred-items.md. |

No blockers found. The previously blocking anti-pattern (direct private-method call in testTimerContinuesAfterError) has been removed by commit fdb5287.

### Human Verification Required

#### 1. Confirm testTimerContinuesAfterError passes in a live MATLAB session

**Test:** In a MATLAB session: `addpath('.'); install(); import matlab.unittest.*; r = TestSuite.fromFile('tests/suite/TestDashboardEngine.m', 'Name', 'TestDashboardEngine/testTimerContinuesAfterError'); run(r);`
**Expected:** Test PASSES — the timer fires a throwing TimerFcn, ErrorFcn restarts the timer, `isrunning` returns true
**Why human:** Cannot invoke MATLAB runtime in this environment to observe the actual result. All static checks pass (no private-method call, correct wiring, 0.5s pause present, assertion present) — runtime confirmation is the only remaining step.

#### 2. Confirm full-suite pre-existing failure count has not grown beyond 4

**Test:** `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('.'); install(); run_all_tests();"`
**Expected:** Exactly 4 pre-existing failures (testFullDashboardIntegration, testAddWidgetFromPalette, testDragSnapsToGrid, testResizeSnapsToGrid). testTimerContinuesAfterError should now PASS, reducing the count from the previous 5.
**Why human:** Cannot invoke MATLAB runtime in this environment.

### Gaps Summary

No gaps remain. All must-haves from Plan 01-04 are verified:

1. `testTimerContinuesAfterError` exists (line 110)
2. No call to `onLiveTimerError` anywhere in the test file (grep returns zero lines)
3. Indirect triggering is present: `set(d.LiveTimer, 'TimerFcn', @(~,~) error(...))` at line 126
4. `pause(0.5)` at line 129 gives MATLAB's timer thread time to complete the ErrorFcn cycle
5. `isrunning(d.LiveTimer)` assertion at line 132
6. Warning suppression with `warnState` pattern at lines 121-122

The one remaining item (runtime confirmation) is routed to human verification, not a structural gap.

---

_Verified: 2026-04-01T21:00:00Z_
_Verifier: Claude (gsd-verifier)_
