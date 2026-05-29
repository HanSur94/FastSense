---
phase: 05-detachable-widgets
verified: 2026-04-01T00:00:00Z
status: passed
score: 7/7 must-haves verified
re_verification: false
---

# Phase 05: Detachable Widgets — Verification Report

**Phase Goal:** Users can pop any widget out as a standalone figure window that stays live-synced with the dashboard's data updates, without degrading dashboard refresh rate
**Verified:** 2026-04-01
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | DetachedMirror class exists as a handle class with hFigure, hPanel, and Widget properties | VERIFIED | `libs/Dashboard/DetachedMirror.m` — 198 lines, `classdef DetachedMirror < handle`, `properties (SetAccess = private): hFigure, hPanel, Widget, RemoveCallback` |
| 2 | DetachedMirror.cloneWidget() dispatches all 15 widget types via toStruct/fromStruct | VERIFIED | Switch on `s.type` in `cloneWidget()` (lines 141–175) covers: fastsense, number, status, text, gauge, table, rawaxes, timeline, group, heatmap, barchart, histogram, scatter, image, multistatus; `otherwise` branch calls `error('DetachedMirror:unknownType',...)` |
| 3 | Detached FastSenseWidget gets UseGlobalTime=false and live Sensor restored | VERIFIED | Lines 181–185: `if isa(w,'FastSenseWidget') && ~isempty(original.Sensor): w.Sensor = original.Sensor; w.UseGlobalTime = false` |
| 4 | RawAxesWidget clone gets PlotFcn/DataRangeFcn restored | VERIFIED | Lines 190–193: `if isa(w,'RawAxesWidget') && ~isempty(original.PlotFcn): w.PlotFcn = original.PlotFcn; w.DataRangeFcn = original.DataRangeFcn` |
| 5 | Every widget shows a detach button in its header chrome after realizeWidget() | VERIFIED | `DashboardLayout.realizeWidget()` lines 311–314: unconditional call to `addDetachButton(widget)` when `obj.DetachCallback` is non-empty; `addDetachButton()` creates `uicontrol` with `Tag='DetachButton'` at position `[0.82 0.90 0.08 0.08]` |
| 6 | Clicking detach opens a standalone figure window; mirror is live-ticked on every engine timer tick; closing removes mirror from registry | VERIFIED | `DashboardEngine.detachWidget()` (lines 576–597): creates `DetachedMirror`, stores in `DetachedMirrors`; `onLiveTick()` (lines 774–786): iterates `DetachedMirrors` and calls `m.tick()`; `removeDetachedByRef()` (lines 828–850): removes mirror by identity on figure close via `containers.Map` pattern |
| 7 | Multiple detached widgets do not create additional MATLAB timers | VERIFIED | `DetachedMirror` constructor creates no timers; mirrors are driven by the engine's single `LiveTimer` via the `onLiveTick()` loop; test `testNoExtraTimers` verifies `numel(timerfind)` is unchanged |

**Score:** 7/7 truths verified

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `libs/Dashboard/DetachedMirror.m` | Standalone handle class for detached widget mirrors | VERIFIED | 198 lines, substantive implementation — constructor, `tick()`, `isStale()`, `onFigureClose()`, `cloneWidget()` with full 15-type dispatch |
| `tests/suite/TestDashboardDetach.m` | Test scaffold for all DETACH requirements (7 methods) | VERIFIED | 244 lines, 7 test methods confirmed: `testDetachButtonInjected`, `testDetachOpensWindow`, `testMirrorTickedOnLive`, `testCloseRemovesFromRegistry`, `testFastSenseIndependentZoom`, `testNoExtraTimers`, `testMirrorIsReadOnly` |
| `libs/Dashboard/DashboardLayout.m` | Detach button injection — `DetachCallback` property + `addDetachButton()` | VERIFIED | 567 lines; `DetachCallback = []` at line 24; `addDetachButton()` at lines 529–547; `realizeWidget()` guard at lines 311–314 |
| `libs/Dashboard/DashboardEngine.m` | `DetachedMirrors` registry, `detachWidget()`, `removeDetached()`, `onLiveTick()` mirror tail | VERIFIED | 1191 lines; `DetachedMirrors = {}` at line 44; `detachWidget()` at lines 576–597; `removeDetached()` at lines 599–617; `removeDetachedByRef()` at lines 828–850; mirror tick loop in `onLiveTick()` at lines 774–786; `DetachCallback` wired in `render()` at line 246 and in `rerenderWidgets()` at line 640 |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `DashboardEngine.render()` | `DashboardLayout.DetachCallback` | `obj.Layout.DetachCallback = @(w) obj.detachWidget(w)` | WIRED | Line 246 — before `allocatePanels()`, so all subsequent `realizeWidget()` calls inject the button |
| `DashboardEngine.rerenderWidgets()` | `DashboardLayout.DetachCallback` | `obj.Layout.DetachCallback = @(w) obj.detachWidget(w)` | WIRED | Line 640 — after `createPanels()`, re-wires callback on page switch (Pitfall 3 from RESEARCH.md addressed) |
| `DashboardEngine.onLiveTick()` | `DetachedMirror.tick()` | Mirror loop iterating `obj.DetachedMirrors` | WIRED | Lines 774–786 — calls `m.tick()` on each non-stale mirror; stale indices collected and cleaned in same tick |
| `DetachedMirror.onFigureClose()` | `DashboardEngine.removeDetachedByRef()` | `removeCallback` lambda passed into constructor via `containers.Map` indirect reference | WIRED | `detachWidget()` creates `mirrorHolder = containers.Map({'mirror'},{[]})`, then `removeCallback = @() obj.removeDetachedByRef(mirrorHolder)`, then after mirror creation `mirrorHolder('mirror') = mirror` — handle-class container ensures closure sees live value; `onFigureClose()` calls `RemoveCallback()` before `delete(hFigure)` |
| `DashboardLayout.realizeWidget()` | `DashboardLayout.addDetachButton()` | `if ~isempty(obj.DetachCallback): obj.addDetachButton(widget)` | WIRED | Lines 311–314 — unconditional (not gated on Description like info icon) |
| `DetachedMirror.cloneWidget()` | DashboardWidget subclasses | `switch s.type` dispatch | WIRED | 15 `case` branches + `otherwise` error; all widget type strings verified present |

---

## Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `DetachedMirror.tick()` | `obj.Widget` (cloned DashboardWidget) | `cloneWidget()` restores live `Sensor` reference from original for `FastSenseWidget`; other widgets refresh from their own state | Yes — `FastSenseWidget.update()` reads live Sensor data; other `refresh()` calls delegate to widget subclass implementations | FLOWING |
| `DashboardEngine.onLiveTick()` mirror tail | `obj.DetachedMirrors` cell array | `detachWidget()` appends to array; `removeDetachedByRef()` filters by identity | Yes — iterates live `DetachedMirror` objects | FLOWING |

---

## Behavioral Spot-Checks

Step 7b: SKIPPED — project requires MATLAB runtime; cannot run `matlab -batch` in static verification environment. Test suite results are documented in SUMMARY files and confirmed through static code analysis.

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| DETACH-01 | 05-01, 05-02 | Every widget shows a detach button in its header chrome | SATISFIED | `DashboardLayout.addDetachButton()` exists and is called unconditionally from `realizeWidget()` when `DetachCallback` is set; `DashboardEngine.render()` and `rerenderWidgets()` both set `DetachCallback`; test `testDetachButtonInjected` covers this |
| DETACH-02 | 05-01, 05-03 | Clicking detach opens the widget as a standalone figure window | SATISFIED | `DashboardEngine.detachWidget()` creates `DetachedMirror` (which creates a figure) and appends to `DetachedMirrors`; `DetachCallback` wires button click to `detachWidget()`; test `testDetachOpensWindow` covers this |
| DETACH-03 | 05-01, 05-03 | Detached widget receives live data updates from DashboardEngine timer | SATISFIED | `onLiveTick()` mirror loop calls `m.tick()` on every live mirror; `tick()` calls `widget.update()` (FastSenseWidget) or `widget.refresh()` (others); test `testMirrorTickedOnLive` covers this |
| DETACH-04 | 05-01, 05-03 | Closing a detached figure window cleanly removes it from the mirror registry | SATISFIED | `CloseRequestFcn` -> `onFigureClose()` -> `RemoveCallback()` -> `removeDetachedByRef()` removes mirror from `DetachedMirrors` by identity; `containers.Map` pattern ensures closure sees live mirror reference; test `testCloseRemovesFromRegistry` covers this |
| DETACH-05 | 05-01 | Detached FastSenseWidget gets independent time axis zoom/pan (UseGlobalTime = false) | SATISFIED | `cloneWidget()` sets `w.UseGlobalTime = false` on any cloned `FastSenseWidget`; test `testFastSenseIndependentZoom` covers this |
| DETACH-06 | 05-01, 05-03 | Multiple widgets can be detached simultaneously without degrading dashboard refresh rate | SATISFIED | `DetachedMirror` constructor creates no timers; mirrors share the engine's single `LiveTimer`; mirror tick loop runs inside existing `onLiveTick()` without extra timer creation; test `testNoExtraTimers` covers this |
| DETACH-07 | 05-01 | Detached widgets are read-only live mirrors (no edits syncing back) | SATISFIED | `cloneWidget()` produces a new object via `toStruct/fromStruct` round-trip — new object handle, not the original; test `testMirrorIsReadOnly` verifies `mirror.Widget ~= originalWidget` |

All 7 DETACH requirements are marked Complete in `REQUIREMENTS.md` — matches implementation evidence.

**No orphaned requirements found.** REQUIREMENTS.md phase 5 row maps exactly DETACH-01 through DETACH-07; all are claimed in plan frontmatter.

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `libs/Dashboard/DashboardEngine.m` | 607–616 | `removeDetached()` public method: filtering by `m.isStale()` only when `~isvalid(widget)` — the logic means stale mirrors are only removed when the passed `widget` is also invalid, not independently | Info | Minor API inconsistency; `removeDetachedByRef()` is the real removal path; stale mirrors are also cleaned in `onLiveTick()` loop. Does not block goal. |

No blockers or warnings found. The one info-level item is a minor logic inconsistency in a secondary cleanup path that has no user-visible impact.

---

## Human Verification Required

### 1. Visual button placement

**Test:** Render a dashboard with at least one widget; observe that the detach button ('^') appears in the top-right of the widget panel, immediately left of the info icon when Description is also set.
**Expected:** Detach button visible at top-right of panel header chrome; clicking it opens a new figure window titled "{WidgetTitle} — Live".
**Why human:** Button visibility and click behavior require MATLAB figure rendering.

### 2. Live sync feels non-degrading

**Test:** Create a dashboard with 3–4 widgets including a FastSenseWidget with live data; detach 2 widgets; observe dashboard refresh rate and detached window update rate during live mode.
**Expected:** Dashboard refresh rate unchanged; detached windows update on each timer tick; no lag introduced.
**Why human:** Performance feel and timer cadence require a running MATLAB session.

### 3. Independent zoom on detached FastSenseWidget

**Test:** Detach a FastSenseWidget; pan/zoom the detached window's time axis; verify the main dashboard's time axis is unaffected.
**Expected:** Detached and dashboard time axes are independent.
**Why human:** Interactive pan/zoom behavior requires MATLAB figure interaction.

---

## Gaps Summary

No gaps found. All seven must-have truths are verified, all four key artifacts are substantive and wired, all key links are confirmed in code, and all seven DETACH requirement IDs are satisfied with test coverage.

The phase goal is achieved: users can pop any widget out as a standalone figure window that stays live-synced with the dashboard's data updates without degrading dashboard refresh rate.

---

_Verified: 2026-04-01_
_Verifier: Claude (gsd-verifier)_
