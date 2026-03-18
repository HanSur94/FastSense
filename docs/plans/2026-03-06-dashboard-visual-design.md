# FastSense Enhancement: Visual Customization + Dashboard Layouts

**Date:** 2026-03-06
**Status:** Approved

---

## 1. Problem Statement

FastSense today is a single-axes class. Building multi-panel dashboards requires manual `subplot()` calls, manual `Parent`/`LinkGroup` wiring, and no theming support. Visual customization is limited to pass-through MATLAB line properties. There are no shaded regions, band fills, or custom markers.

**Goal:** Add a figure-level layout manager (`FastSenseFigure`) for tiled dashboards with spanning, a comprehensive theming system with inheritance, and new visual elements (shaded fills, bands, markers) — all while keeping full backward compatibility.

---

## 2. Requirements

### Functional
- Tiled grid layout with configurable rows/columns
- Tiles can span multiple rows and/or columns
- Every tile is a FastSense axes (no non-plot tiles for now)
- Theme system with presets and custom definitions
- Theme inheritance: element override > tile theme > figure theme > default preset
- Auto line color cycling from theme palette
- Shaded regions between two curves (downsampled on zoom)
- Horizontal band fills (constant y bounds)
- Area fills from line to baseline
- Custom event markers with configurable shape/size/color
- Link groups remain explicit (not auto-linked in dashboards)
- Standalone FastSense gains theme support without requiring FastSenseFigure

### Non-Functional
- Full backward compatibility — all existing scripts unchanged
- Pure MATLAB, no toolbox dependencies
- Compatible with MATLAB R2020b+ and GNU Octave 7+

---

## 3. Architecture

### 3.1 Class Structure

```
FastSenseFigure (handle class)        -- figure + layout + theme
  hFigure                            -- figure handle
  Theme                              -- FastSenseTheme struct
  Grid [rows, cols]                  -- layout grid dimensions
  Tiles{}                            -- cell array of FastSense instances
  TileSpans{}                        -- per-tile [rowSpan, colSpan]
  tile(n) -> FastSense                -- get/create FastSense for tile n
  setTileSpan(n, [r,c])             -- make tile span multiple rows/cols
  tileTitle(n, str)                  -- set title for tile n
  tileXLabel(n, str)                 -- set xlabel for tile n
  tileYLabel(n, str)                 -- set ylabel for tile n
  setTileTheme(n, themeOverrides)    -- per-tile theme override
  renderAll()                        -- render all unrendered tiles
  render()                           -- alias for renderAll()

FastSense (handle class)              -- per-axes (extended)
  existing API unchanged
  addShaded(x, y1, y2, ...)          -- fill between two curves
  addBand(yLow, yHigh, ...)         -- horizontal band fill
  addFill(x, y, ...)                -- area fill to baseline
  addMarker(x, y, ...)              -- custom event markers
  Theme (inherited or overridden)    -- per-tile theme
  auto line color cycling            -- from theme LineColorOrder

FastSenseTheme (function, not class)  -- returns theme struct
  Background, AxesColor, GridColor, GridAlpha
  GridStyle, FontName, FontSize, TitleFontSize
  ForegroundColor                    -- text, tick labels, axis lines
  LineColorOrder                     -- Nx3 matrix or palette name
  LineWidth                          -- default line width
  ThresholdColor, ThresholdStyle
  ViolationMarker, ViolationSize
  BandAlpha
```

### 3.2 New Files

| File | Purpose |
|------|---------|
| `FastSenseFigure.m` | Figure-level layout manager with tiled grid, spanning, theming |
| `FastSenseTheme.m` | Function returning theme preset structs and merge logic |

### 3.3 Extended: `FastSense.m`

| Addition | Description |
|----------|-------------|
| `addShaded(x, y1, y2, ...)` | Fill between two curves (downsampled on zoom) |
| `addBand(yLow, yHigh, ...)` | Horizontal band fill (constant bounds) |
| `addFill(x, y, ...)` | Area fill to baseline |
| `addMarker(x, y, ...)` | Custom event markers |
| `'Theme'` constructor param | Per-tile theming with inheritance |
| Auto line color cycling | From theme's `LineColorOrder` palette |

---

## 4. FastSenseFigure API

```matlab
%% Construction
fig = FastSenseFigure(rows, cols);
fig = FastSenseFigure(rows, cols, 'Theme', 'dark');
fig = FastSenseFigure(rows, cols, 'Theme', myCustomTheme);
fig = FastSenseFigure(rows, cols, 'Position', [100 100 1400 800], 'Name', 'Dashboard');

%% Tile spanning
fig.setTileSpan(1, [1 2]);   % tile 1 spans 1 row, 2 columns
fig.setTileSpan(3, [2 1]);   % tile 3 spans 2 rows, 1 column

%% Getting tiles (returns FastSense instance, creates axes on first call)
fp = fig.tile(1);
fp.addLine(x, y, 'DisplayName', 'Sensor1');
fp.render();

%% Convenience: labels per tile
fig.tileTitle(1, 'Temperature');
fig.tileXLabel(3, 'Time (s)');
fig.tileYLabel(2, 'Pressure (bar)');

%% Render all tiles at once
fig.renderAll();

%% Theme override per tile
fig.setTileTheme(2, struct('Background', [0.1 0.1 0.15]));
```

### Layout Algorithm

Tiles are numbered left-to-right, top-to-bottom (same as MATLAB's `subplot`). When a tile has a span, subsequent tile numbers skip the occupied cells. The figure uses normalized position units to compute each axes' position, accounting for padding/gaps.

### Key Behaviors

- `tile(n)` is lazy -- axes and FastSense are created on first access
- `renderAll()` calls `render()` on all tiles that haven't been rendered yet
- Figure is kept invisible until `renderAll()` or the first `tile.render()` call
- Standard figure properties (`Name`, `Position`, `Color`) forwarded to underlying figure handle

---

## 5. Visual Enhancements

```matlab
%% Shaded region between two curves
fp.addShaded(x, y_upper, y_lower, ...
    'FaceColor', [1 0 0], 'FaceAlpha', 0.15, 'EdgeColor', 'none', ...
    'DisplayName', 'Confidence Band');

%% Horizontal band fill (constant y bounds, spans full x range)
fp.addBand(yLow, yHigh, ...
    'FaceColor', [1 0.9 0.9], 'FaceAlpha', 0.3, ...
    'Label', 'Danger Zone');

%% Area fill from line to baseline (default baseline = 0)
fp.addFill(x, y, ...
    'FaceColor', [0 0.5 1], 'FaceAlpha', 0.2, ...
    'Baseline', 0, 'DisplayName', 'Energy');

%% Custom event markers at specific x,y positions
fp.addMarker(x_events, y_events, ...
    'Marker', 'v', 'MarkerSize', 8, ...
    'Color', [0.8 0 0], 'Label', 'Fault Detected');
```

### Implementation Notes

- `addShaded` uses `patch()` with NaN-separator batching
- Shaded regions are downsampled along with their boundary data on zoom
- `addBand` creates a rectangle patch -- no downsampling (constant bounds)
- `addFill` is sugar for `addShaded(x, y, baseline)`
- `addMarker` creates a line object with `'none'` LineStyle and configurable marker props
- All new elements get `UserData.FastSense` tagging (`'shaded'`, `'band'`, `'fill'`, `'marker'`)

### Rendering Order (back to front)

1. Bands
2. Shaded fills
3. Data lines
4. Thresholds
5. Violation markers
6. Custom markers

---

## 6. Theming System

### 6.1 Built-in Presets

| Preset | Description |
|--------|-------------|
| `'default'` | White background, standard MATLAB colors |
| `'dark'` | Dark gray background, bright lines |
| `'light'` | Soft white background, muted lines |
| `'industrial'` | Engineering-style, high contrast |
| `'scientific'` | Publication-ready: white bg, serif font (Times New Roman), thin axes box, no grid, colorblind-safe palette, LaTeX-friendly proportions |

### 6.2 Custom Themes

```matlab
myTheme = struct( ...
    'Background',       [0.05 0.05 0.08], ...
    'AxesColor',        [0.12 0.12 0.16], ...
    'ForegroundColor',  [0.9 0.9 0.9],   ...
    'GridColor',        [0.3 0.3 0.3],    ...
    'GridAlpha',        0.5,              ...
    'GridStyle',        ':',              ...
    'FontName',         'Consolas',       ...
    'FontSize',         10,               ...
    'TitleFontSize',    13,               ...
    'LineWidth',        1.0,              ...
    'LineColorOrder',   'vibrant',        ...
    'ThresholdColor',   [0.8 0 0],        ...
    'ThresholdStyle',   '--',             ...
    'ViolationMarker',  'o',              ...
    'ViolationSize',    4,                ...
    'BandAlpha',        0.15              ...
);
```

### 6.3 Line Color Palettes

| Palette | Description |
|---------|-------------|
| `'vibrant'` | High saturation, good for dark backgrounds |
| `'muted'` | Desaturated, good for print/light backgrounds |
| `'colorblind'` | Deuteranopia-safe 8-color palette |
| Custom | Nx3 matrix of RGB values |

Auto-cycling: when `addLine` is called without a `Color` argument, the next color from `LineColorOrder` is assigned automatically. Each FastSense instance tracks its position in the cycle.

### 6.4 Theme Inheritance

```
Element override > Tile theme > Figure theme > 'default' preset
```

- `FastSenseTheme('dark')` returns the full dark preset struct
- `FastSenseTheme('dark', 'LineColorOrder', 'colorblind')` returns dark with one field overridden
- Merging: simple `fieldnames` loop, override wins
- Unset fields in custom themes inherit from `'default'`

---

## 7. Standalone FastSense Enhancements

```matlab
%% Standalone with theme (no FastSenseFigure required)
fp = FastSense('Theme', 'dark');
fp.addLine(x, y);
fp.render();

%% Full constructor signature
fp = FastSense();
fp = FastSense('Parent', ax);
fp = FastSense('LinkGroup', 'sensors');
fp = FastSense('Theme', 'dark');
fp = FastSense('Parent', ax, 'LinkGroup', 'g1', 'Theme', myTheme);
```

No theme = `'default'` preset. All new methods are optional additions.

---

## 8. Constraints

- Tiles are plots only (no text/KPI panels)
- Link groups remain explicit (not auto-linked in dashboards)
- Full backward compatibility
- Pure MATLAB, no toolbox dependencies
- X must be monotonically increasing (unchanged)
- MATLAB R2020b+ and GNU Octave 7+
