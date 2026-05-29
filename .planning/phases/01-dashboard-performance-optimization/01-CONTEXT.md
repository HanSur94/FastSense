# Phase 1: Dashboard Performance Optimization - Context

**Gathered:** 2026-04-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Make dashboard creation, instantiation, and interactivity significantly faster. Target 2x improvement in creation+render time and <50ms per live tick refresh for a 20-widget mixed dashboard. Add a reusable benchmark script for tracking performance over time.

</domain>

<decisions>
## Implementation Decisions

### Profiling & Measurement Strategy
- Use `tic/toc` wall-clock benchmarks on dashboard creation, render, and refresh cycles
- Benchmark scenario: 20-widget mixed dashboard (FastSense, Number, Status, Group widgets)
- Add `benchmarks/bench_dashboard.m` as a reusable performance tracking script
- Target: 2x faster creation+render, <50ms per live tick refresh

### Creation & Instantiation Optimizations
- Replace 17-case switch in `addWidget` with `containers.Map` type→constructor lookup, built once at construction
- Cache `DashboardTheme()` struct on engine instance, invalidate only when `Theme` property changes — currently reconstructed on every `switchPage`, `rerenderWidgets`, `render`
- Keep eager `DashboardLayout` creation (current behavior) — layout object is lightweight
- Profile widget constructors first, optimize only if they show up as bottleneck

### Render & Interactivity Optimizations
- Optimize `rerenderWidgets` to reposition existing panels instead of destroy+recreate — only recreate when widget list actually changes
- Optimize `onLiveTick`: cache `activePageWidgets()` result, skip non-dirty widgets early, consolidate to single pass instead of multiple loops
- Verify `realizeBatch` visibility-first ordering works correctly, tune batch size from profiling
- `switchPage` should hide/show panels instead of full rerender — keep panels alive across page switches

### Claude's Discretion
- Widget constructor optimization approach (if profiling reveals bottleneck)
- Exact batch size tuning for `realizeBatch`
- Any additional micro-optimizations discovered during profiling

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `DashboardEngine.m` — main orchestrator with render(), onLiveTick(), rerenderWidgets(), switchPage()
- `DashboardLayout.m` — 24-column grid with allocatePanels(), createPanels(), computePosition()
- `DashboardWidget.m` — base class with Realized flag, Dirty flag, markDirty/markRealized lifecycle
- `DashboardTheme.m` — theme struct generator (called repeatedly, candidate for caching)
- Existing `benchmarks/` directory for benchmark scripts

### Established Patterns
- Handle classes with property-based state management
- `activePageWidgets()` as central widget list accessor (multi-page aware)
- `realizeBatch()` with visibility-first ordering and drawnow between batches
- `Dirty` flag on widgets for change tracking
- `Realized` flag with markRealized/markUnrealized lifecycle methods

### Integration Points
- `DashboardEngine.render()` — initial dashboard rendering
- `DashboardEngine.onLiveTick()` — live refresh cycle
- `DashboardEngine.rerenderWidgets()` — called from onResize() and switchPage()
- `DashboardEngine.addWidget()` — widget creation dispatch
- `DashboardLayout.createPanels()` — panel allocation and positioning

</code_context>

<specifics>
## Specific Ideas

- `DashboardTheme()` is called in at least 6 places — caching will eliminate redundant struct creation
- `rerenderWidgets()` destroys all panels and recreates from scratch on every resize — repositioning in-place is much cheaper
- `onLiveTick()` calls `activePageWidgets()` 4 times and iterates widgets in 3 separate loops — can be consolidated
- `switchPage()` calls `DashboardTheme()` and then `rerenderWidgets()` which calls it again — double construction
- `addWidget` switch has 17 cases evaluated sequentially — map lookup is O(1)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>
