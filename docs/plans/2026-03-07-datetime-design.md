# FastSense Datetime Support — Design

## Goal

Add datetime-aware X axis display to FastSense. Users pass `datenum` values (or MATLAB `datetime` objects, auto-converted) and get human-readable date/time tick labels that adapt to zoom level.

## Architecture

### Input

- `fp.addLine(x, y, 'XType', 'datenum')` — explicit opt-in, X is datenum doubles
- `fp.addLine(x, y)` where `x` is MATLAB `datetime` — auto-detected, converted to `datenum` via `datenum(x)`, `XType` set automatically

### Internal Pipeline

**No changes.** `datenum` values are regular doubles. Binary search, MinMax/LTTB downsampling, MEX accelerators, zoom/pan callbacks, pyramid levels — all work unchanged.

### Storage

- New field in `Lines` struct: `XType` — `'numeric'` (default) or `'datenum'`
- New property on `FastSense`: `XType` — set from first line that declares `'datenum'`, enforced consistent across all lines on same axes

### Tick Formatting

Custom tick formatter installed on axes when `XType == 'datenum'`. Format auto-selected based on visible X range:

| Visible range | Format | Example |
|---|---|---|
| > 1 day | `'mmm dd HH:MM'` | `Jan 15 10:00` |
| 1 hour – 1 day | `'HH:MM'` | `10:00` |
| 1 min – 1 hour | `'HH:MM'` | `10:30` |
| < 1 min | `'HH:MM:SS'` | `10:30:15` |

Tick formatter re-runs on every zoom/pan (inside `onXLimChanged`).

### Toolbar Display

- **Crosshair text:** `datestr(xp, 'mmm dd HH:MM:SS')` instead of `sprintf('x=%.4g', xp)`
- **Data cursor label:** `datestr(sx, 'mmm dd HH:MM:SS')` instead of `sprintf('(%.4g, %.4g)', sx, sy)`
- Toolbar checks `fp.XType` (or first `FastSenses{i}.XType`) to decide formatting

### FastSenseFigure

Each tile can independently have `XType == 'datenum'` or `'numeric'`. No figure-level setting needed — it inherits from the FastSense instances.

## What Changes

| File | Change |
|---|---|
| `FastSense.m` | Add `XType` property; detect datetime input in `addLine`; install tick formatter in `render`; update ticks in `onXLimChanged` |
| `FastSenseToolbar.m` | Format crosshair/cursor display based on `XType` |
| `tests/test_toolbar.m` | Add datetime formatting tests |
| `tests/test_datetime.m` | New: datenum axes, tick formatting, datetime auto-conversion |
| `examples/example_toolbar.m` | Add datetime demo section |
| `README.md` | Document datetime usage |

## What Does NOT Change

- `binary_search.m` / MEX
- `minmax_downsample.m` / MEX
- `lttb_downsample.m` / MEX
- `compute_violations.m`
- Zoom/pan pipeline (internally)
- `FastSenseFigure.m`
- `FastSenseTheme.m`

## Compatibility

- Works in both GNU Octave and MATLAB
- Uses `datenum`/`datestr` (available in both)
- MATLAB `datetime` input auto-converted via `datenum()`
- `isdatetime()` check guarded with `exist('isdatetime')` for Octave compatibility
