# Lazy Tab Rendering Design

## Problem

`FastPlotDock.render()` renders ALL tabs upfront (line 116-121), including invisible ones. For a 5-tab dock, tabs 2-5 are fully rendered (downsampling + graphics creation + toolbar) but immediately hidden. This wastes ~80% of startup time.

## Solution

Only render the active tab (tab 1) on `render()`. Defer rendering of other tabs until first `selectTab(n)`.

## Changes

### 1. Add `IsRendered` field to Tabs struct

Add `'IsRendered', {}` to the struct definition on line 36.

### 2. Extract `renderTab(idx)` private method

```matlab
function renderTab(obj, idx)
    obj.Tabs(idx).Figure.renderAll();
    obj.reparentAxes(idx);
    obj.Tabs(idx).Toolbar = FastPlotToolbar(obj.Tabs(idx).Figure);
    obj.Tabs(idx).IsRendered = true;
end
```

### 3. Modify `render()` — only render tab 1

Replace the loop (line 116-121) with a single `renderTab(1)` call. Mark all other tabs as `IsRendered = false`.

### 4. Modify `selectTab(n)` — lazy render on first switch

Before the show/hide logic, check `obj.Tabs(n).IsRendered`. If false, call `renderTab(n)`.

### 5. Update `addTab()` — set IsRendered correctly

- When adding before `render()`: set `IsRendered = false`
- When adding after `render()` (line 97-104): already calls `renderAll()`, so set `IsRendered = true`

### 6. Update `undockTab()` — handle unrendered tabs

If undocking a tab that hasn't been rendered yet, render it first before reparenting.

### 7. Update `removeTab()` — skip render cleanup for unrendered tabs

If removing an unrendered tab, skip toolbar/axes cleanup (they don't exist yet).

## Edge Cases

- `addTab()` after `render()`: existing code already renders immediately — mark `IsRendered = true`
- `undockTab()` on unrendered tab: render before undocking
- `removeTab()` on unrendered tab: just delete the panel, no render cleanup needed

## Expected Speedup

- N-tab dock startup: O(N) renders → O(1) render
- 5-tab dock: ~5x faster startup
- Trade-off: one-time ~100-500ms delay on first tab switch
