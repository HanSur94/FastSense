# FastPlot Configuration Management Overhaul

**Date:** 2026-03-08
**Status:** Approved

## Problem

FastPlot has duplicated varargin parsing across all `add*()` methods, no persistent user defaults, hard-coded performance constants, silent failure on typos in option names, and no way to reset color cycling or re-apply themes after creation.

## Design

### 1. `FastPlotDefaults.m` — Persistent user defaults

A plain function returning a struct. Users edit this file to set global preferences. Cached via `persistent` variable in a private loader for zero repeated overhead.

```matlab
function cfg = FastPlotDefaults()
    cfg.Theme = 'default';
    cfg.Verbose = false;
    cfg.MinPointsForDownsample = 5000;
    cfg.DownsampleFactor = 2;
    cfg.PyramidReduction = 100;
    cfg.DefaultDownsampleMethod = 'minmax';
    cfg.DashboardPadding = 0.06;
    cfg.DashboardGapH = 0.05;
    cfg.DashboardGapV = 0.07;
    cfg.TabBarHeight = 0.03;
end
```

**Loading**: Private helper `getDefaults()` uses `persistent` to cache the struct. One function call per MATLAB session, zero cost after that. A `FastPlot.clearDefaultsCache()` static method allows forcing a reload.

### 2. `private/parseOpts.m` — Shared varargin parser

Replaces all duplicated for-loops across `addLine`, `addThreshold`, `addBand`, `addMarker`, `addShaded`, constructors, `startLive`, and `updateLine`.

```matlab
function [opts, unmatched] = parseOpts(defaults, args, verbose)
```

- Case-insensitive key matching (same behavior as today)
- Returns parsed opts struct with defaults filled in
- Returns unmatched key-value pairs separately (needed by `addLine` which passes extras through to line handle properties)
- When `verbose` is true, warns on unknown keys: `Warning: FastPlot:unknownOption — Unknown option 'Colr'. Valid options: Color, DisplayName, ...`
- No `inputParser`, no reflection — just a for-loop with `isfield` check
- Performance: equivalent to current inline loops (one function call overhead, negligible)

### 3. Performance constants become instance properties

Move `MIN_POINTS_FOR_DOWNSAMPLE`, `DOWNSAMPLE_FACTOR`, `PYRAMID_REDUCTION` from `Constant` properties to regular private properties. Defaults loaded from `FastPlotDefaults` in constructor. Configurable per-instance via constructor varargin.

These values are only read during `render()` and `redraw()`, not in tight inner loops, so the switch from compile-time constant to instance property has no measurable impact.

Also applies to `FastPlotFigure` (`PADDING`, `GAP_H`, `GAP_V`) and `FastPlotDock` (`TAB_BAR_HEIGHT`).

### 4. `resetColorIndex()` method

Public method on FastPlot:
```matlab
function resetColorIndex(obj)
    obj.ColorIndex = 0;
end
```

Gives users explicit control over color cycling without exposing the internal property.

### 5. `reapplyTheme()` method

Public method that re-applies the current `Theme` to existing axes and line handles. Explicit call (no automatic listener) to avoid overhead.

Updates: figure background, axes colors, font, grid, and iterates existing line handles to update widths.

### 6. Backward compatibility

- All existing public API signatures unchanged
- Default behavior identical (same default values)
- `FastPlotTheme.m` presets unchanged
- No new dependencies
- Users who never touch `FastPlotDefaults.m` see zero difference

## Files to create
- `FastPlotDefaults.m` — user-editable defaults function
- `private/getDefaults.m` — cached loader with persistent variable

## Files to modify
- `private/parseOpts.m` — new shared parser (replaces `binary_search.m` pattern)
- `FastPlot.m` — use parseOpts, load defaults, add resetColorIndex/reapplyTheme, promote constants
- `FastPlotFigure.m` — use parseOpts, load defaults for layout constants
- `FastPlotDock.m` — use parseOpts, load defaults for tab bar height
- `FastPlotToolbar.m` — no config changes needed (toolbar reads from target objects)

## Performance considerations
- `getDefaults()` uses `persistent` — one file read per session
- `parseOpts()` is a single function call wrapping the same for-loop pattern already used inline
- Constants promoted to properties — read only during render/redraw, not hot paths
- Warning generation only when `Verbose` is true (off by default)
- No `inputParser`, no `validateattributes`, no reflection
