---
phase: 1012-live-event-markers-and-click-to-details-on-fastsense-and-fastsensewidget
verified: 2026-04-24T10:00:00Z
status: passed
score: 8/8 must-haves verified; 4/4 manual items passed in interactive UAT
human_uat: [1012-HUMAN-UAT.md] (resolved)
re_verification: true
re_verification_date: 2026-04-24T10:05:00Z
re_verification_note: "Gap on Truth 8 closed inline in commit 374efce — updated tests/test_monitortag_streaming.m Scenario 2 to match Phase 1012 open-event semantics (IsOpen=true, EndTime=NaN on recompute_; closeEvent updates in place — 1 event total, not 2). Octave run: 'All 7 streaming tests passed.' All 8 filesystem + runtime must_haves now verified. Status advanced from gaps_found to human_needed per the 4 manual items below."
gaps: []
resolved_gaps:
  - truth: "Full MATLAB + Octave test suite green after phase"
    resolution_commit: "374efce"
    resolution_note: "Octave mirror test_monitortag_streaming.m Scenario 2 aligned with Phase 1012 semantics; all 7 streaming tests green"
human_verification:
  - test: "Click-details uipanel anchors near clicked marker without off-screen clipping"
    expected: "uipanel appears adjacent to the marker and fully within the figure boundary on both 1440x900 and 2560x1440 figures"
    why_human: "Rendering geometry is figure-size-dependent; no screenshot-diff infrastructure available"
  - test: "Click-outside-dismiss works correctly while axes zoom mode is active"
    expected: "Click outside the details panel closes the panel even when MATLAB zoom toolbar is engaged"
    why_human: "Requires live interaction with toolbar state that cannot be simulated headlessly"
  - test: "Open-to-closed visual transition on live demo (hollow-to-filled marker)"
    expected: "Running example_event_markers.m produces a visible hollow marker that becomes filled after the falling edge"
    why_human: "Requires a display and live timer ticks; headless Octave cannot render figure updates"
  - test: "Multi-widget Octave scenario with two FastSenseWidgets sharing one EventStore"
    expected: "Both widgets refresh independently without cross-contamination of LastEventIds_ cache"
    why_human: "Requires interactive Octave session with two concurrent DashboardEngine widgets"
---

# Phase 1012: Live Event Markers and Click-to-Details Verification Report

**Phase Goal:** Extend Phase-1010 Event-Tag overlay with three orthogonal capabilities: (1) open-event visibility with EventStore as Single Source of Truth; (2) click-to-details floating uipanel on each event marker; (3) FastSenseWidget-level ShowEventMarkers + EventStore wiring with live-refresh diff.

**Verified:** 2026-04-24T10:00:00Z
**Status:** GAPS FOUND
**Re-verification:** No — initial verification
**MATLAB availability:** Unavailable (runtime checks deferred to Octave)
**Octave availability:** /opt/homebrew/bin/octave — USED for all runtime verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Event.IsOpen logical property, default false, backward-compatible on .mat reload | VERIFIED | `libs/EventDetection/Event.m:28`: `IsOpen = false`; NaN guard at line 41; close() method at line ~75; Event:closedOpenEvent error ID present |
| 2 | EventStore.closeEvent(id, endTime, finalStats) in-place update; two distinct error IDs | VERIFIED | `libs/EventDetection/EventStore.m:43-73`: closeEvent delegates to ev.close(); EventStore:unknownEventId at 2 sites (lines 56, 72); EventStore:alreadyClosed at line 64 |
| 3 | MonitorTag.appendData emits IsOpen=true on rising edge; falling edge calls closeEvent with running stats from newY (not raw_new) | VERIFIED | `MonitorTag.m:397,408`: updateOpenStats_(newX(openMask), newY(openMask)); `MonitorTag.m:702`: obj.EventStore.closeEvent(obj.cache_.openEventId_, endT, fs); ev.IsOpen=true at lines 735, 888 in tail + recompute paths |
| 4 | FastSense.renderEventLayer_ per-event line() with ButtonDownFcn + UserData.eventId; open=hollow, closed=filled; Y via tag.valueAt(startT) | VERIFIED | `FastSense.m:2241-2281`: one line() per event in nested for loop; ButtonDownFcn at line 2265; UserData.eventId at line 2266; faceColor='none' for IsOpen at line 2253; tag.valueAt(ev.StartTime) at line 2249 |
| 5 | Click handler opens floating uipanel; ESC + click-outside + X-button dismiss; formatEventFields_ in methods(Access=protected) | VERIFIED | openEventDetails_ at line 2293; closeEventDetails_ at line 2348; WindowKeyPressFcn saved/wired at lines 2305/2345; WindowButtonDownFcn saved/wired at lines 2304/2344; formatEventFields_ in protected block at line 3743; X-button Callback at line 2331 |
| 6 | FastSenseWidget.ShowEventMarkers (default false) + EventStore (default []); forwarding guard appears exactly 2 times | VERIFIED | `FastSenseWidget.m:22-23`: ShowEventMarkers=false, EventStore=[]; guard `if obj.ShowEventMarkers \|\| ~isempty(obj.EventStore)` at lines 89 AND 389 (exactly 2 occurrences); LastEventIds_ at line 33; LastEventOpen_ at line 34; refreshEventMarkers_ at line 295; toStruct omits when false at line 279; fromStruct reads at line 485 |
| 7 | DashboardEngine.onLiveTick piggyback via refreshEventMarkers_; no dedicated timer added | VERIFIED | `FastSenseWidget.m:155,162,178`: refreshEventMarkers_() called from refresh() paths; no new timer created; relies on existing DashboardEngine tick dispatch |
| 8 | Full MATLAB + Octave test suites green after phase | FAILED | Octave suite: 78/79 passed; `test_monitortag_streaming` Scenario 2 FAILS at line 35: asserts EndTime==10 but Phase 1012 recompute_ now emits NaN (open event). MATLAB suite unavailable to confirm directly, but MATLAB TestMonitorTagStreaming WAS updated per 1012-02-SUMMARY. |

**Score:** 7/8 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `libs/EventDetection/Event.m` | IsOpen property + close() method; NaN endTime accepted | VERIFIED | IsOpen=false at line 28; close() method present; ~isnan(endTime) guard at line 41 |
| `libs/EventDetection/EventStore.m` | closeEvent method | VERIFIED | function closeEvent at line 43 |
| `libs/SensorThreshold/MonitorTag.m` | openStats_ + openEventId_ in 3 init paths; updateOpenStats_; flushOpenStats_ | VERIFIED | emptyOpenStats_() used at 4 sites; updateOpenStats_ defined; flushOpenStats_ defined; openEventId_ wired in tail + recompute paths |
| `libs/FastSense/FastSense.m` | Per-event line(); ButtonDownFcn; openEventDetails_/closeEventDetails_; formatEventFields_ protected | VERIFIED | All present at confirmed line numbers |
| `libs/Dashboard/FastSenseWidget.m` | ShowEventMarkers=false; EventStore=[]; LastEventIds_; LastEventOpen_; refreshEventMarkers_; guard x2 | VERIFIED | All present at confirmed line numbers |
| `libs/Dashboard/DashboardTheme.m` | EventMarkerSize = 8 | VERIFIED | Line 142: d.EventMarkerSize = 8 |
| `tests/suite/TestEventIsOpen.m` | 12-test MATLAB suite | VERIFIED | File exists; no assumeFail stubs (real tests) |
| `tests/suite/TestMonitorTagOpenEvent.m` | 7-test MATLAB suite; no assumeFail | VERIFIED | 7 test methods; no assumeFail matches |
| `tests/suite/TestFastSenseEventClick.m` | Real tests; only JVM-gated assumeFail | VERIFIED | 3 JVM-only assumeFail calls; Wave 0 stubs replaced |
| `tests/suite/TestFastSenseWidgetEventMarkers.m` | Real tests; only JVM-gated assumeFail | VERIFIED | 6 JVM-only assumeFail calls; Wave 0 stubs replaced |
| `tests/test_event_is_open.m` | Octave mirror | VERIFIED | File exists |
| `tests/test_monitortag_open_event.m` | Octave mirror | VERIFIED | File exists; no SKIP lines |
| `tests/test_fastsense_event_click.m` | Octave mirror | VERIFIED | File exists |
| `tests/test_fastsense_widget_event_markers.m` | Octave mirror | VERIFIED | File exists |
| `examples/example_event_markers.m` | Demo script | VERIFIED | File exists; references ShowEventMarkers, MonitorTag, EventStore |
| `benchmarks/bench_event_marker_regression.m` | Pitfall-10 bench; 3 configs; +/-5% gate | VERIFIED | File exists; otherTags config present; gate logic present |
| `tests/test_monitortag_streaming.m` | Octave streaming regression mirror | FAILED | Line 35 asserts EndTime==10 but Phase 1012 changed this to NaN |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| EventStore.closeEvent | Event.close | ev.close(endTime, finalStats) | VERIFIED | Line 68 in EventStore.m: ev.close(endTime, finalStats) |
| MonitorTag.appendData | EventStore.closeEvent | obj.EventStore.closeEvent(obj.cache_.openEventId_, endT, fs) | VERIFIED | MonitorTag.m line 702 |
| MonitorTag rising-edge | Event.IsOpen=true | ev.IsOpen=true before EventStore.append | VERIFIED | Lines 735, 888 in MonitorTag.m |
| FastSense.renderEventLayer_ | onEventMarkerClick_ | ButtonDownFcn per line() | VERIFIED | Line 2265 in FastSense.m |
| FastSense.openEventDetails_ | figure-level dismiss | PrevWBDFcn_ + PrevKPFcn_ save/restore | VERIFIED | Lines 2304-2305, 2344-2345, 2356-2357 in FastSense.m |
| FastSenseWidget.refresh() | FastSense.refreshEventLayer() | refreshEventMarkers_() diff then call | VERIFIED | FastSenseWidget.m lines 155, 162, 178 call refreshEventMarkers_(); lines 319-323 call obj.FastSenseObj.refreshEventLayer() |
| DashboardEngine.onLiveTick | FastSenseWidget marker diff | existing refresh dispatch -> refreshEventMarkers_ | VERIFIED | No new timer added; hooks into existing tick |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|--------------------|--------|
| FastSense.renderEventLayer_ | events (from es.getEventsForTag) | EventStore.getEventsForTag reads obj.events_ handle array | Yes — live EventStore handle | FLOWING |
| FastSenseWidget.refreshEventMarkers_ | events (from obj.EventStore.getEventsForTag) | Same EventStore SSOT | Yes — same live handle | FLOWING |
| FastSense.openEventDetails_ | ev (Event handle) | EventByIdMap_ keyed from renderEventLayer_ | Yes — live Event handle from store | FLOWING |

---

### Behavioral Spot-Checks (Octave)

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Event.IsOpen schema + EventStore.closeEvent | `octave --eval "... test_event_is_open"` | 12 passed, 0 failed | PASS |
| MonitorTag rising/falling edge + running stats | `octave --eval "... test_monitortag_open_event"` | 7 passed, 0 failed | PASS |
| FastSense per-marker ButtonDownFcn wiring | `octave --eval "... test_fastsense_event_click"` | 4 passed, 0 failed (3 GUI skipped) | PASS |
| FastSenseWidget ShowEventMarkers + diff | `octave --eval "... test_fastsense_widget_event_markers"` | 6 passed, 0 failed (3 GUI skipped) | PASS |
| Phase 1010 regression (ShowEventMarkers=true default) | `octave --eval "... test_fastsense_event_overlay"` | 6/6 tests passed | PASS |
| Full Octave suite | `octave --eval "... run_all_tests"` | 78/79 passed, **1 FAILED** | FAIL |
| Pitfall-10 bench (zero-event render) | `octave --eval "... bench_event_marker_regression"` | A=265ms B=253ms(-4.53%) C=262ms(-1.32%); PASS | PASS |

---

### Pitfall-10 Bench Numbers (Octave run)

```
Config A (no store)     median:   265.08 ms
Config B (empty store)  median:   253.08 ms   B vs A:  -4.53%  (gate: +/-5%) PASS
Config C (other tags)   median:   261.57 ms   C vs A:  -1.32%  (gate: +/-5%) PASS
PASS: all configs within 5% of baseline A.
```

---

### Requirements Coverage

No REQ-IDs assigned to Phase 1012 (stated in objective). Requirements traceability check skipped per phase specification.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| tests/test_monitortag_streaming.m | 35 | `assert(e1(1).EndTime == 10)` — hardcoded expectation of pre-Phase-1012 closed-event EndTime; Phase 1012 correctly changed this to NaN | Blocker | Octave regression suite fails 1/79; Phase 1010 boundary contract semantics test is stale |

No TODO/FIXME/placeholder comments found in phase-delivered source files. No empty implementations found in libs/ files.

---

### Human Verification Required

#### 1. Click-details uipanel visual anchor

**Test:** Open `examples/example_event_markers.m` in MATLAB or Octave with display, run until an event closes, click the marker.
**Expected:** The uipanel appears adjacent to the marker and fully within the figure boundary at both 1440x900 and 2560x1440 figure sizes.
**Why human:** Rendering geometry depends on figure size and pixel layout; no screenshot-diff infrastructure in this project.

#### 2. Click-outside dismiss while zoom is active

**Test:** Open example, enable axes zoom toolbar, click a marker to open details panel, then click outside the panel.
**Expected:** The details panel dismisses correctly even with zoom toolbar engaged; zoom interaction resumes normally after panel close.
**Why human:** Requires live toolbar state simulation that cannot be automated headlessly.

#### 3. Open-to-closed hollow-to-filled visual transition

**Test:** Run `example_event_markers.m` with display, observe marker after rising edge (hollow) and after falling edge (filled).
**Expected:** Marker appearance transitions from hollow circle to filled circle when the event closes.
**Why human:** Requires rendering and visual inspection; cannot be verified via grep on graphics handles.

#### 4. Multi-widget Octave scenario

**Test:** Build a DashboardEngine with two FastSenseWidgets sharing one EventStore; tick both; verify each widget's LastEventIds_ refreshes independently.
**Expected:** No cross-contamination; both widgets render correct markers for their respective Tag bindings.
**Why human:** Requires interactive Octave session with DashboardEngine timer + two concurrent widgets.

---

## Gaps Summary

One gap blocks the `status: passed` verdict:

**`tests/test_monitortag_streaming.m` was not updated for Phase 1012 semantics.**

The 1012-02 execution updated `tests/suite/TestMonitorTagStreaming.m` (MATLAB suite) to reflect that the recompute path now emits an open event with `EndTime=NaN`, and that `appendData` closes it via `EventStore.closeEvent` (resulting in 1 event total, not 2). However, the Octave flat-style mirror `tests/test_monitortag_streaming.m` was not updated to match. Specifically:

- Line 35: `assert(e1(1).EndTime == 10, ...)` — should be `assert(isnan(e1(1).EndTime), 'Scenario 2: open event EndTime must be NaN')`
- The comment on line 8 references the old two-event contract but was not synchronized with the SUMMARY's documented fix.
- Lines 38-42 expect 2 events after appendData; Phase 1012 semantics produce 1 event (open then closed via closeEvent).

The MATLAB suite `TestMonitorTagStreaming.m` correctly reflects Phase 1012 semantics (1 event, IsOpen=false, EndTime=12 at the falling edge). The Octave mirror needs to be synchronized.

**Root cause:** The SUMMARY for Plan 02 documents this as deviation item #4 ("TestMonitorTagStreaming Scenario 2 tested pre-Phase-1012 double-event behavior") but only lists `tests/suite/TestMonitorTagStreaming.m` in `files_modified` — the Octave flat-style mirror `tests/test_monitortag_streaming.m` was not included.

**Suggested fix:** Update `tests/test_monitortag_streaming.m` Scenario 2 block to match `TestMonitorTagStreaming.testAppendOngoingRunExtendsIntoTail`:
1. Replace line 35 with `assert(isnan(e1(1).EndTime), 'Scenario 2: open event EndTime must be NaN before close');`
2. Add `assert(e1(1).IsOpen == true, 'Scenario 2: recompute_ emits open event');`
3. Replace lines 38-42 with assertions matching the Phase 1012 single-close-event semantics: `assert(numel(e2) == 1, ...)`, `assert(e2(1).IsOpen == false, ...)`, `assert(e2(1).EndTime == 12, ...)`.

---

**FINAL STATUS: gaps_found**
The 8 filesystem must-haves all pass, the Phase 1010 regression guard passes, and the Pitfall-10 bench passes within the 5% gate. One gap remains: the Octave regression mirror `tests/test_monitortag_streaming.m` has a stale Scenario 2 assertion that was not synchronized with the Phase 1012 behavioral change to `TestMonitorTagStreaming.m`. Fixing this is a one-file, three-line correction.

---

_Verified: 2026-04-24T10:00:00Z_
_Verifier: Claude (gsd-verifier)_
