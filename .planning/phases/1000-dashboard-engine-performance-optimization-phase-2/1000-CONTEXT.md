# Phase 1000: Dashboard Engine Performance Optimization Phase 2 - Context

**Gathered:** 2026-04-05
**Status:** Ready for planning
**Mode:** Auto-generated (infrastructure phase — discuss skipped)

<domain>
## Phase Boundary

Fix 6 identified performance bottlenecks in DashboardEngine:

1. **FastSenseWidget.refresh() full teardown** (`FastSenseWidget.m:103-162`) — Every live tick destroys and recreates the entire axes+FastSense for sensor-bound widgets. Switch to incremental update reusing existing axes/FastSense via `updateData()`. Only rebuild on structural changes (sensor swap).

2. **broadcastTimeRange synchronous** (`DashboardEngine.m:743-755`) — Time slider calls `setTimeRange()` on every active widget synchronously per drag event. Debounce slider: coalesce rapid slider events into one broadcast.

3. **All-page panel creation at startup** (`DashboardEngine.m:272-286`) — Non-active pages get fully rendered during initial `render()`. Lazy page realization: only create panels for non-active pages on first `switchPage()`.

4. **getTimeRange full-array scan** (`FastSenseWidget.m:214-225`) — `min(Sensor.X)` and `max(Sensor.X)` scan entire X array per widget per tick via `updateLiveTimeRangeFrom()`. Cache min/max X, update incrementally on `updateData()`.

5. **switchPage synchronous realize** (`DashboardEngine.m:145-150`) — Unrealized widgets on page switch are realized one-by-one without batching. Reuse `realizeBatch()` with drawnow interleaving.

6. **Resize marks all dirty** (`DashboardEngine.m:904-910`) — Every resize marks every widget dirty, triggering full refresh on next tick. Debounce resize: only reposition on final event, don't mark dirty (position change doesn't need data refresh).

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — pure infrastructure/performance phase. Key guidance from prior analysis:

- FastSenseWidget.update() already exists and uses updateData() — extend this to be the primary live tick path, not just a fallback
- The debounce pattern should use MATLAB timer with short delay (e.g., 0.1s) since MATLAB doesn't have requestAnimationFrame
- Lazy page realization should still pre-allocate placeholder panels (cheap) but defer widget.render() (expensive)
- Cached time ranges should be invalidated on sensor reassignment, not just updated on tick
- All changes must maintain backward compatibility with existing dashboard scripts

</decisions>

<code_context>
## Existing Code Insights

### Key Files
- `libs/Dashboard/DashboardEngine.m` — Main orchestrator: onLiveTick, render, switchPage, repositionPanels, broadcastTimeRange
- `libs/Dashboard/FastSenseWidget.m` — refresh() teardown, update() incremental, getTimeRange()
- `libs/Dashboard/DashboardLayout.m` — allocatePanels, realizeWidget, realizeBatch pattern
- `libs/Dashboard/DashboardWidget.m` — Base class: markDirty(), Dirty flag, Realized flag

### Established Patterns
- `realizeBatch()` already exists with drawnow interleaving — reuse for switchPage
- `update()` vs `refresh()` split already exists in FastSenseWidget — extend update() coverage
- Theme caching via `getCachedTheme()` — pattern for lazy computation
- Dirty flag system already in place — refine when dirty is set vs when actual data refresh needed

### Integration Points
- onLiveTick calls w.update() for FastSenseWidget, w.refresh() for others
- All time range operations go through updateLiveTimeRangeFrom() → broadcastTimeRange()
- Resize goes through onResize → repositionPanels → markDirty per widget

</code_context>

<specifics>
## Specific Ideas

No specific requirements — infrastructure phase. Refer to ROADMAP phase description and the detailed analysis from the research session.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>
