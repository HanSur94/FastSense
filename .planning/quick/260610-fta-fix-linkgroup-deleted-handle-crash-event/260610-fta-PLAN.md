---
quick_id: 260610-fta
description: Fix LinkGroup deleted-handle crash + EventViewer NaN-duration display
date: 2026-06-10
mode: quick-inline
---

# Quick Task 260610-fta: LinkGroup deleted-handle crash + EventViewer NaN duration

Two verified bugs from the 2026-06-09 review sweep, both reproduced live on R2025b.

## Task 1 — FastSense LinkGroup deleted-handle crash

**Repro (verified):** link two FastSense instances via LinkGroup, `delete()` one, zoom the survivor →
PostSet listener error "Invalid or deleted object" at FastSense.m:4586; propagation to remaining
members aborts. Registry 'cleanup' action (line 4649) has the same flaw: `cellfun(@(o) ishandle(o.hAxes), ...)`
throws on deleted handle objects, so dead entries can never be purged.

**Fix:**
- `propagateXLim` (FastSense.m ~4584): guard each member with `isvalid(other)` before property access.
- `getLinkRegistry` 'cleanup' (~4649): `cellfun(@(o) isvalid(o) && ishandle(o.hAxes), ...)`.
- Octave note: `isvalid` works on classdef handle objects in Octave 7+ (these are handle subclasses,
  not graphics); keep try/catch out — the direct guard is portable.

**Test:** new case in tests/test_dashboard_perf_fixes.m? No — wrong file. Add flat test
`tests/test_fastsense_link_group.m` if absent, else extend existing link tests: two linked instances,
delete one, set survivor XLim, assert no listener error (capture via warning state) and survivor
propagation still works after re-adding a third member.

## Task 2 — EventViewer NaN-duration display

**Repro (verified):** open events (IsOpen=true, EndTime=NaN, Duration=NaN) render duration as
"NaNh NaNm" in the table (line 328), tooltip (line 399), and details pane (line 678). Not a crash
(else-branch assigns str) — reviewer severity overstated; cosmetic but user-facing.

**Fix:** `formatDuration` (EventViewer.m ~746): guard `if ~isfinite(secs); str = '(open)'; return; end`.

**Test:** extend an existing EventViewer flat test (or add minimal case) asserting
formatDuration(NaN) == '(open)' via an open event in populateTable, no 'NaN' substring in table data.

## Verification (orchestrator, MATLAB MCP)
- Repro scripts before/after.
- Relevant suites: link-group tests, EventViewer tests.
