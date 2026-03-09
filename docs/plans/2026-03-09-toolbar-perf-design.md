# Toolbar Rendering Performance Optimization

## Goal

Minimize toolbar rendering time by caching icons and reusing toolbar HG objects across tab switches in FastPlotDock.

## Approach

Two complementary optimizations:

### 1. Static Icon Cache

Pre-compute all 10 icons once per MATLAB session using a `persistent` map in `makeIcon`. Add a static `initIcons()` method that pre-warms all icons in one call.

- `makeIcon` checks cache before generating
- `createToolbar` calls `initIcons()` at the top
- Icon names: cursor, crosshair, grid, legend, autoscale, export, refresh, live, metadata, theme

### 2. Toolbar Handle Reuse in FastPlotDock

Instead of creating/destroying `FastPlotToolbar` on every tab switch, keep one toolbar per dock and rebind it to the active tab's target.

**New method: `rebind(target)` on FastPlotToolbar**
- Cleans up active mode (crosshair lines, cursor dots, restores callbacks)
- Updates `Target`, `hFigure`, `FastPlots`
- Reinstalls datacursor callback on new figure
- Syncs toggle states: live button to `target.LiveIsActive`, metadata button to `MetadataEnabled`

**FastPlotDock changes:**
- Single `Toolbar` property instead of per-tab `Tabs(n).Toolbar`
- `selectTab` calls `obj.Toolbar.rebind(newTarget)` instead of `FastPlotToolbar(...)`
- First toolbar still created eagerly (unavoidable)
- Undock still creates a fresh toolbar (different figure)

**Why this works:** In the dock, all tabs share the same underlying figure. The `uitoolbar` HG handle stays parented to that figure. Only the logical target (which `FastPlotFigure`/`FastPlot` the buttons operate on) changes.

### 3. Test Compatibility

- Constructor and public API unchanged
- `makeIcon` caching is transparent to tests
- Add missing icon names (`metadata`, `theme`) to `testAllIconNames`
- No new test file needed; dock integration tests exercise rebind implicitly
