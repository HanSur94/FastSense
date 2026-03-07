# Metadata Support Design

## Overview

Add optional per-line metadata support to FastPlot. Metadata uses forward-fill (zero-order hold) semantics keyed by timestamps, displayed in the data cursor tooltip when a toolbar toggle is active. Live mode supports a separate metadata file.

## Data Model

Metadata is an optional struct passed at `addLine` time:

```matlab
meta.datenum  = [100, 500, 1200];
meta.operator = {'Alice', 'Bob', 'Alice'};
meta.mode     = {'auto', 'manual', 'auto'};

fp.addLine(x, y, 'Metadata', meta);
```

- `meta` must contain a `datenum` (or `datetime`) field as the time key
- All other fields are value vectors/cell arrays of the same length as `datenum`
- Forward-fill semantics: each entry is active from its timestamp until the next metadata timestamp
- Points before the first metadata timestamp show no metadata

Stored as `Lines(i).Metadata` (struct or empty `[]`).

## Tooltip Integration

When metadata toolbar button is active and data cursor snaps to a point:

```
X: 1050.5
Y: 3.72
---------
operator: Bob
mode: manual
```

Lookup algorithm:
1. Get snapped X value from data cursor
2. Binary search `meta.datenum` for largest value <= snapped X
3. If found, display all non-datenum fields from that entry
4. If snapped X is before first metadata timestamp, show no metadata

## Toolbar Button

- New toggle button "Metadata" added to `FastPlotToolbar`
- When off: data cursor behaves as before (X, Y only)
- When on: data cursor tooltip includes active metadata fields below the X/Y values
- No visual markers on the plot at any time
- Metadata button is independent of data cursor / crosshair mutual exclusion

## Live Mode

```matlab
fp.startLive('data.mat', @dataUpdateFcn, ...
    'MetadataFile', 'meta.mat', 'MetadataVars', {'operator', 'mode'}, ...
    'Interval', 1.5);
```

- `MetadataFile`: explicit path to a separate .mat file containing metadata
- `MetadataVars`: cell array of variable names to extract (plus `datenum` always extracted automatically)
- Polled on the same timer as the data file, with its own last-modified check
- On file change: load specified variables + datenum, build metadata struct, update `Lines(i).Metadata`

### updateData extension

```matlab
fp.updateData(lineIdx, newX, newY, 'Metadata', meta);
```

Optional name-value pair. If provided, replaces the line's metadata struct.

## Key Implementation Details

- Metadata stored as optional field `Lines(i).Metadata` (struct or `[]`)
- Binary search on `meta.datenum` for O(log n) lookup at tooltip time (reuse existing `binary_search.m`)
- No downsampling or clustering needed (no visual markers on plot)
- Metadata lookup is separate from the rendering/downsample pipeline -- no impact on performance
- `datetime` values in metadata fields are converted to `datestr()` for display
- Metadata works with both `FastPlot` and `FastPlotFigure` (dashboard) via existing target resolution

## Non-Goals

- No visual markers or colored bands on the plot
- No display-level field filtering (user controls what fields are passed in)
- No metadata editing from the UI
