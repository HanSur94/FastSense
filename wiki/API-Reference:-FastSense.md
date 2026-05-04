<!-- AUTO-GENERATED from source code by scripts/generate_api_docs.py — do not edit manually -->

# API Reference: FastSense

## `FastSense` --- Ultra-fast time series plotting with dynamic downsampling.

> Inherits from: `handle`

FastSense renders 1K to 100M data points with fluid zoom/pan by
  dynamically downsampling data to screen resolution using MinMax or
  LTTB algorithms. A multi-level pyramid cache provides instant
  re-downsample on zoom without touching raw data.

### Constructor

```matlab
obj = FastSense(varargin)
```

FASTSENSE Construct a FastSense instance.
  fp = FASTSENSE() creates a new FastSense with default settings.
  fp = FASTSENSE('Parent', ax, 'Theme', 'dark') creates a plot
  inside existing axes ax with the 'dark' theme.
  fp = FASTSENSE('LinkGroup', 'g1', 'Verbose', true) creates a
  plot that shares zoom/pan with other plots in group 'g1'.

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| ParentAxes | `[]` | axes handle, empty = create new |
| LinkGroup | `''` | string ID for linked zoom/pan |
| Theme | `[]` | theme struct (from FastSenseTheme) |
| Verbose | `false` | print diagnostics to console |
| LiveViewMode | `''` | 'preserve' \| 'follow' \| 'reset' (empty = no view mode applied) |
| LiveFile | `''` | path to .mat file for live mode |
| LiveUpdateFcn | `[]` | @(fp, data) callback for live updates |
| LiveIsActive | `false` | whether live polling is running |
| LiveInterval | `2.0` | poll interval in seconds |
| MetadataFile | `''` | path to separate .mat file for metadata |
| MetadataVars | `{}` | cell array of variable names to extract |
| MetadataLineIndex | `1` | which line index to attach metadata to |
| DeferDraw | `false` | skip drawnow during batch render |
| ShowProgress | `true` | show console progress bar during render |
| XScale | `'linear'` | 'linear' or 'log' — X axis scale |
| YScale | `'linear'` | 'linear' or 'log' — Y axis scale |
| ViolationsVisible | `true` | global toggle for violation markers |
| ShowThresholdLabels | `false` | show inline name labels on threshold lines |
| ShowEventMarkers | `true` | toggle event round-marker overlay (EVENT-07) |
| EventStore | `[]` | EventStore handle for event overlay queries |
| MinPointsForDownsample | `5000` | below this, plot raw data |
| DownsampleFactor | `2` | points per pixel (min + max) |
| PyramidReduction | `100` | reduction factor per pyramid level |
| DefaultDownsampleMethod | `'minmax'` | 'minmax' or 'lttb' |
| StorageMode | `'auto'` | 'auto', 'memory', or 'disk' |
| MemoryLimit | `500e6` | bytes; lines above this use disk (auto mode) |

### Methods

#### `resetColorIndex(obj)`

RESETCOLORINDEX Reset the auto color cycling counter.
  fp.RESETCOLORINDEX() resets the internal color counter to zero.
  The next addLine() call without an explicit 'Color' option
  will use the first color from the theme palette.

#### `reapplyTheme(obj)`

REAPPLYTHEME Re-apply the current Theme to axes and figure.
  fp.REAPPLYTHEME() refreshes all visual properties (background,
  foreground, grid, font, line widths) from the current Theme
  struct. Call this after changing fp.Theme on an already-rendered
  plot to update the display without re-rendering.

#### `setScale(obj, varargin)`

SETSCALE Set axis scale (linear or log) for X and/or Y.
  fp.SETSCALE('YScale', 'log') switches Y axis to logarithmic.
  fp.SETSCALE('XScale', 'log', 'YScale', 'linear') sets both.

#### `addLine(obj, x, y, varargin)`

ADDLINE Add a data line to the plot.
  fp.ADDLINE(x, y) adds a line with auto-assigned color.
  fp.ADDLINE(x, y, 'Color', 'r', 'DisplayName', 'Sensor1')
  adds a red line labeled 'Sensor1' in the legend.
  fp.ADDLINE(x, y, 'DownsampleMethod', 'lttb') uses the
  Largest-Triangle-Three-Buckets algorithm instead of MinMax.

#### `addThreshold(obj, varargin)`

ADDTHRESHOLD Add a threshold line (scalar or time-varying).
  fp.ADDTHRESHOLD(value) adds a constant horizontal threshold.
  fp.ADDTHRESHOLD(value, 'Direction', 'upper', 'ShowViolations', true)
  adds an upper threshold with violation markers at crossings.
  fp.ADDTHRESHOLD(thX, thY, 'Direction', 'upper', 'ShowViolations', true)
  adds a time-varying (step-function) threshold.

#### `addBand(obj, yLow, yHigh, varargin)`

ADDBAND Add a horizontal band fill (constant y bounds).
  fp.ADDBAND(yLow, yHigh) adds a shaded horizontal band
  spanning the full X range between yLow and yHigh, using
  theme defaults for color and alpha.
  fp.ADDBAND(yLow, yHigh, 'FaceColor', [1 0.9 0.9], 'FaceAlpha', 0.3)
  uses custom color and transparency.

#### `addMarker(obj, x, y, varargin)`

ADDMARKER Add custom event markers at specific positions.
  fp.ADDMARKER(x, y) plots marker symbols at the given (x,y)
  positions using theme defaults.
  fp.ADDMARKER(x, y, 'Marker', 'v', 'MarkerSize', 8, 'Color', [1 0 0])
  plots red downward-pointing triangles of size 8.

#### `setShowEventMarkers(obj, tf)`

SETSHOWEVENTMARKERS Toggle event-marker overlay post-render.
  fp.SETSHOWEVENTMARKERS(true|false) flips ShowEventMarkers and
  either deletes existing markers (tf=false) or re-runs
  renderEventLayer_ (tf=true) so markers appear/disappear in
  place without a full re-render. No-op if not yet rendered;
  the next render() honours the new flag automatically.

#### `addShaded(obj, x, y1, y2, varargin)`

ADDSHADED Add a shaded region between two curves.
  fp.ADDSHADED(x, y_upper, y_lower) fills the area between
  y_upper and y_lower over the common X axis.
  fp.ADDSHADED(x, y1, y2, 'FaceColor', [0 0 1], 'FaceAlpha', 0.2)
  fills with blue at 20% opacity.

#### `addFill(obj, x, y, varargin)`

ADDFILL Add an area fill from a line to a baseline.
  fp.ADDFILL(x, y) fills the area between y and a baseline
  of zero using default shading colors.
  fp.ADDFILL(x, y, 'Baseline', -1, 'FaceColor', [0 0.5 1])
  fills between y and y=-1 with a custom color.

#### `addTag(obj, tag, varargin)`

ADDTAG Polymorphic dispatch — route a Tag to the correct render path.
  fp.ADDTAG(sensorTag)     — routes to addLine via tag.getXY
  fp.ADDTAG(stateTag)      — routes to a staircase line (numeric Y)
  fp.ADDTAG(monitorTag)    — routes to addLine via tag.getXY (0/1 binary series)
  fp.ADDTAG(compositeTag)  — routes to addLine via tag.getXY (aggregated 0/1 or 0..1 series)
  fp.ADDTAG(derivedTag)    — routes to addLine via tag.getXY (continuous derived series)

#### `addStateTagAsStaircase_(obj, tag, varargin)`

ADDSTATETAGASSTAIRCASE_ Render a numeric StateTag as a stepped line.
  Private helper (name ends in _) invoked by addTag for the
  'state' kind. Expands (X, Y) pairs into an interleaved
  2N-1 staircase and delegates to addLine. Cellstr Y is not
  supported in Phase 1005 (deferred).

#### `render(obj, progressBar)`

RENDER Create the plot with all configured lines and annotations.
  fp.RENDER() finalizes the plot and displays it. This method:
    1. Creates a figure and axes (or uses ParentAxes)
    2. Applies the Theme (background, grid, font)
    3. Renders bands and shaded regions (back layer)
    4. Downsamples all lines to screen pixel resolution
    5. Draws threshold lines and violation markers
    6. Draws custom markers (front layer)
    7. Sets axis limits with 5% padding
    8. Installs XLim/resize listeners for dynamic re-downsample
    9. Schedules async refinement for large datasets
    10. Registers in LinkGroup for synchronized zoom/pan

#### `result = lookupMetadata(obj, lineIdx, xValue)`

LOOKUPMETADATA Get active metadata at a given X value (forward-fill).
  result = fp.LOOKUPMETADATA(lineIdx, xValue) returns a struct
  containing the metadata values that were active at xValue,
  using forward-fill (last-observation-carried-forward) logic.

#### `updateData(obj, lineIdx, newX, newY, varargin)`

UPDATEDATA Replace data for a line and re-downsample.
  fp.UPDATEDATA(lineIdx, newX, newY) replaces the raw X/Y
  data for the specified line and refreshes the display.
  fp.UPDATEDATA(lineIdx, newX, newY, 'Metadata', meta)
  also replaces the line's metadata struct.
  fp.UPDATEDATA(lineIdx, newX, newY, 'SkipViewMode', true)
  replaces data without applying LiveViewMode adjustments.

#### `startLive(obj, filepath, updateFcn, varargin)`

STARTLIVE Start live mode — poll a .mat file for changes.
  fp.STARTLIVE(filepath, updateFcn) begins polling filepath
  at the default interval. When the file's modification date
  changes, it loads the .mat and calls updateFcn(fp, data).
  fp.STARTLIVE(filepath, updateFcn, 'Interval', 2)
  fp.STARTLIVE(filepath, updateFcn, 'ViewMode', 'follow')

#### `stopLive(obj)`

STOPLIVE Stop live mode polling.
  fp.STOPLIVE() stops the live timer, cleans up the deferred
  timer, and sets LiveIsActive to false. Safe to call even if
  live mode is not active. Also stops the refinement timer.

#### `refresh(obj)`

REFRESH Manual one-shot reload from LiveFile.
  fp.REFRESH() loads the current LiveFile, calls LiveUpdateFcn,
  and updates the LiveFileDate timestamp. Also reloads the
  MetadataFile if configured. Useful for triggering a manual
  update without waiting for the live timer.

#### `setViewMode(obj, mode)`

SETVIEWMODE Change the live view mode at runtime.
  fp.SETVIEWMODE(mode) sets the LiveViewMode property, which
  controls how the X-axis adjusts when new data arrives.

#### `runLive(obj)`

RUNLIVE Blocking poll loop for live mode (Octave compatibility).
  fp.RUNLIVE() enters a blocking loop that polls LiveFile for
  changes at LiveInterval. This is required on Octave where
  MATLAB timer objects are not available.

#### `onLiveTimerPublic(obj)`

ONLIVETIMERPUBLIC Public wrapper for testing live timer callback.
  fp.ONLIVETIMERPUBLIC() delegates to the private onLiveTimer
  method. Exists solely to allow unit tests to invoke the
  timer callback directly without relying on real timers.

#### `setLineMetadata(obj, lineIdx, meta)`

SETLINEMETADATA Set metadata on a line after construction.
  fp.SETLINEMETADATA(lineIdx, meta) attaches or replaces the
  metadata struct on the specified line. Primarily used by
  FastSenseGrid to attach metadata loaded from a separate
  file after the plot has been rendered.

#### `setViolationsVisible(obj, on)`

SETVIOLATIONSVISIBLE Show or hide all violation markers.
  fp.SETVIOLATIONSVISIBLE(true) shows violation markers on all
  thresholds that have ShowViolations enabled, forcing a
  recomputation from the currently displayed line data.
  fp.SETVIOLATIONSVISIBLE(false) hides all violation markers
  without recomputing them.

#### `openLoupe(obj)`

OPENLOUPE Open a standalone enlarged copy of this tile.
  fp.OPENLOUPE() creates a new FastSense in a separate figure
  containing deep copies of all lines, thresholds, bands,
  shadings, and markers from the current plot. The new figure
  preserves the current zoom state (XLim/YLim), is offset
  by [+30, -30] pixels from the source figure, and receives
  its own FastSenseToolbar.

#### `exportData(obj, filepath, format)`

EXPORTDATA Export raw line and threshold data as CSV or MAT.
  EXPORTDATA(obj, filepath, format) writes all raw line and
  threshold data from the plot to the file at filepath.

#### `refreshEventLayer(obj)`

REFRESHEVENTLAYER Public thin wrapper — rebuild the event marker layer.
  Calls the private renderEventLayer_ so external consumers
  (e.g. FastSenseWidget.refresh()) can trigger a marker rebuild
  without exposing the implementation method directly.

#### `n = lineNumPoints(obj, i)`

LINENUMPOINTS Return total point count for line i.

#### `[xMin, xMax] = lineXRange(obj, i)`

LINEXRANGE Return X endpoints for line i.

#### `onEventMarkerClick_(obj, src, ~)`

ONEVENTMARKERCLICK_ ButtonDownFcn dispatcher for event markers.
  Hidden public so TestFastSenseEventClick can call it for
  direct-dispatch testing of the click -> details-popup path.

#### `openEventDetails_(obj, ev)`

OPENEVENTDETAILS_ Open a separate floating figure with event fields.
  Phase 1012 refit: standalone figure (OS-native drag/close), light
  theme with standard font, read-only field list on top and an
  editable Notes box at the bottom. Saving the notes mutates
  ev.Notes (handle persists across the MATLAB session) and calls
  EventStore.save() when a FilePath is configured (disk persistence).

#### `fitDetailsTableColumns_(~, hTable)`

FITDETAILSTABLECOLUMNS_ Split the uitable width ~1:2 between
  Field and Value columns based on the parent FIGURE's
  current pixel width. Deriving from the figure rather than
  reading the table's own Position avoids a race where the
  table layout hasn't settled when SizeChangedFcn fires.

#### `saveEventNotes_(obj, ev, hNotesControl)`

SAVEEVENTNOTES_ Commit the Notes textarea to ev.Notes and persist.
  Mutates the Event handle (in-session persistence) and calls
  obj.EventStore.save() when available so notes survive MATLAB
  restarts. Updates the status label to confirm.

#### `closeEventDetails_(obj)`

CLOSEEVENTDETAILS_ Dismiss the popup figure.

#### `onKeyPressForDetailsDismiss_(obj, eventData)`

ONKEYPRESSFORDETAILSDISMISS_ Close popup on ESC key.

#### `tbl = buildEventFieldsTable_(~, ev)`

BUILDEVENTFIELDSTABLE_ Nx2 cell array for the uitable in the
  details popup. Columns are {Field, Value}. Empty statistics
  rows are skipped. Section separators use a blank-label row
  with a bullet '·' value to maintain visual grouping without
  relying on cell-level styling (not portable across MATLAB
  versions).

#### `txt = formatEventFields_(~, ev)`

FORMATEVENTFIELDS_ Produce a grouped, readable listing of event fields.
  Sections: TIMING / STATISTICS / CLASSIFICATION / TAGS / THRESHOLD.
  Empty-valued statistics rows are hidden (they carry no
  information and clutter the popup). IsOpen=true displays
  "Open" for EndTime and Duration so the test contract in
  TestFastSenseEventClick.testFormatEventFieldsShowsOpenForOpenEvent
  still holds.

#### `s = formatSection(header, rows, labelWidth)`

### Static Methods

#### `FastSense.fp = plot(x, y, varargin)`

PLOT One-liner convenience for quick plotting.
  FastSense.plot(x, y)
  FastSense.plot(x, y, 'DisplayName', 'Signal', 'Theme', 'dark')

#### `FastSense.resetDefaults()`

RESETDEFAULTS Force reload of FastSenseDefaults on next use.
  FastSense.RESETDEFAULTS() clears the cached defaults struct
  so the next FastSense constructor will re-read
  FastSenseDefaults.m. Useful after editing the defaults file
  in a running session.

#### `FastSense.distFig(varargin)`

DISTFIG Distribute figure windows across the screen.
  FastSense.DISTFIG() auto-arranges all open figure windows
  in a grid that fills the screen. Figures are sorted by
  number and tiled left-to-right, top-to-bottom.
  FastSense.DISTFIG('Rows', 2, 'Cols', 3) uses a 2-by-3 grid.

---

## `FastSenseDock` --- Tabbed container for multiple FastSenseGrid dashboards.

> Inherits from: `handle`

Manages multiple FastSenseGrid instances as switchable tabs in a
  single window. Each tab has its own panel, toolbar, close button,
  and undock button. Tabs can be dynamically added, removed, or
  popped out into standalone figures.

  dock = FastSenseDock()
  dock = FastSenseDock('Theme', 'dark')
  dock = FastSenseDock('Theme', 'dark', 'Name', 'My Dock')

### Constructor

```matlab
obj = FastSenseDock(varargin)
```

FASTSENSEDOCK Construct a tabbed dock container.
  dock = FastSenseDock()
  dock = FastSenseDock('Theme', 'dark', 'Name', 'My Dock')

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| Theme | `[]` | FastSenseTheme struct |
| hFigure | `[]` | shared figure handle |
| ShowProgress | `true` | show console progress bar during renderAll |
| TabBarHeight | `0.03` | normalized height of tab bar |
| MinTabWidth | `0.10` | minimum normalized width per tab |

### Methods

#### `addTab(obj, fig, name)`

ADDTAB Register a FastSenseGrid as a tab.
  dock.addTab(fig, name) adds a FastSenseGrid as a new tab
  in the dock. The figure's ParentFigure and hFigure are
  redirected to the dock's shared figure. A uipanel is created
  for the tab's content, offset below the tab bar.

#### `render(obj)`

RENDER Render active tab, create tab bar, show first tab.
  dock.render() renders only the first tab (lazy rendering),
  creates tab bar buttons for all tabs, attaches a shared
  FastSenseToolbar, selects tab 1, and makes the figure visible.
  Subsequent tabs are rendered on-demand when selectTab is called.

#### `renderAll(obj)`

RENDERALL Eagerly render all tabs with hierarchical progress.
  dock.renderAll() renders every tab upfront (not lazily).
  Shows hierarchical console progress: tab headers + per-tile
  progress bars. After all tabs are rendered, creates the tab
  bar, shared toolbar, and selects tab 1.

#### `selectTab(obj, n)`

SELECTTAB Switch to tab n, rendering it lazily if needed.
  dock.selectTab(n) hides the currently active tab, renders
  tab n if it hasn't been rendered yet, rebinds the shared
  toolbar to the new tab's FastSenseGrid, and shows tab n.

#### `removeTab(obj, n)`

REMOVETAB Close and remove tab n.
  dock.removeTab(n) stops live mode on the tab, deletes its
  panel and UI buttons, removes it from all internal arrays,
  and rebuilds the tab bar. If the removed tab was active, the
  nearest remaining tab is selected. If no tabs remain, the
  toolbar is also deleted.

#### `undockTab(obj, n)`

UNDOCKTAB Pop tab n out into its own standalone figure.
  dock.undockTab(n) creates a new standalone figure, stops
  live mode, reparents all tile axes from the dock panel to
  the new figure, recomputes tile positions for standalone
  layout, creates a fresh FastSenseToolbar, and removes the
  tab from the dock. The remaining dock tabs are reindexed
  and the tab bar is rebuilt.

#### `recomputeLayout(obj)`

RECOMPUTELAYOUT Reposition tab, undock, and close buttons on resize.
  dock.recomputeLayout() recalculates the normalized positions
  of all tab, undock (^), and close (x) buttons based on the
  current number of tabs. When the ideal tab width falls below
  MinTabWidth, scroll arrows (< >) appear and only a subset of
  tabs is shown. Called automatically on SizeChangedFcn and
  after addTabButton/rebuildTabBar.

#### `reapplyTheme(obj)`

REAPPLYTHEME Re-apply theme to dock, tab bar, panels, and all tabs.
  dock.reapplyTheme() updates the figure background, re-styles
  all tab/undock/close buttons, updates panel backgrounds, and
  propagates the theme to every tab's FastSenseGrid (calling
  reapplyTheme on rendered figures).

---

## `FastSenseToolbar` --- Interactive toolbar for FastSense and FastSenseGrid.

> Inherits from: `handle`

Adds a uitoolbar with data cursor, crosshair, grid/legend toggles,
  Y-axis autoscale, PNG export, live mode controls, and metadata
  display. Integrates with MATLAB's built-in datacursormode for
  enhanced tooltips.

  tb = FastSenseToolbar(fp)   — attach to a FastSense instance
  tb = FastSenseToolbar(fig)  — attach to a FastSenseGrid instance

  Toolbar buttons:
    Data Cursor  — click to snap to nearest data point, shows value
    Crosshair    — tracks mouse position with coordinate readout
    Grid         — toggle grid on/off (active axes or all)
    Legend        — toggle legend visibility
    Autoscale Y  — fit Y-axis to visible data range
    Export PNG   — save figure as PNG with file dialog
    Export Data  — save raw data as CSV or MAT with file dialog
    Refresh      — manual one-shot data reload
    Live Mode    — toggle automatic file polling
    Metadata     — show/hide metadata in data cursor tooltips
    Violations   — toggle violation marker visibility

### Constructor

```matlab
obj = FastSenseToolbar(target)
```

FASTSENSETOOLBAR Construct and attach a toolbar to a plot target.
  tb = FastSenseToolbar(fp)   — FastSense instance
  tb = FastSenseToolbar(fig)  — FastSenseGrid instance

### Methods

#### `toggleGrid(obj)`

TOGGLEGRID Toggle grid visibility on all managed axes.

#### `toggleLegend(obj)`

TOGGLELEGEND Toggle legend visibility on all managed axes.

#### `autoscaleY(obj)`

AUTOSCALEY Fit Y-axis limits to visible data on all axes.

#### `exportPNG(obj, filepath)`

EXPORTPNG Save figure as PNG image at 150 DPI.
  tb.exportPNG()          — opens file dialog
  tb.exportPNG(filepath)  — saves directly to path

#### `exportData(obj, filepath)`

EXPORTDATA Export raw plot data as CSV or MAT file.
  tb.exportData()          — opens file dialog
  tb.exportData(filepath)  — saves directly (format from extension)

#### `setCrosshair(obj, on)`

SETCROSSHAIR Enable or disable crosshair tracking mode.
  tb.setCrosshair(true)  — activate crosshair, disable zoom
  tb.setCrosshair(false) — deactivate, re-enable zoom

#### `setCursor(obj, on)`

SETCURSOR Enable or disable data cursor snap mode.
  tb.setCursor(true)  — activate cursor, disable zoom
  tb.setCursor(false) — deactivate, re-enable zoom

#### `refresh(obj)`

REFRESH Trigger a manual data refresh.

#### `toggleLive(obj)`

TOGGLELIVE Toggle live mode on/off.

#### `setMetadata(obj, on)`

SETMETADATA Enable or disable metadata display in tooltips.
  tb.setMetadata(true)  — show metadata fields in cursor
  tb.setMetadata(false) — hide metadata

#### `setViolationsVisible(obj, on)`

SETVIOLATIONSVISIBLE Toggle violation markers on all tiles.
  setViolationsVisible(obj, on) iterates over all managed
  FastSense instances and calls setViolationsVisible(on) on
  each, then syncs the toolbar toggle button state.

#### `rebind(obj, target)`

REBIND Switch toolbar to a new target without recreating HG objects.
  tb.rebind(newTarget)

#### `label = buildCursorLabel(obj, fp, sx, sy, lineIdx)`

BUILDCURSORLABEL Build the text label for data cursor.

#### `[sx, sy, lineIdx] = snapToNearest(~, fp, xClick, yClick)`

SNAPTONEAREST Find the closest data point to a click position.
  [sx, sy, lineIdx] = tb.snapToNearest(fp, xClick, yClick)

### Static Methods

#### `FastSenseToolbar.icon = makeIcon(name)`

MAKEICON Generate a 16x16x3 RGB icon for toolbar buttons.
  icon = FastSenseToolbar.makeIcon(name)

#### `FastSenseToolbar.initIcons()`

INITICONS Pre-warm the icon cache for all toolbar buttons.

#### `FastSenseToolbar.s = formatX(xVal, xType)`

FORMATX Format an X value based on XType.
  s = FastSenseToolbar.formatX(xVal, 'datenum')
  s = FastSenseToolbar.formatX(xVal, 'numeric')

---

## `FastSenseDataStore` --- SQLite-backed data storage for large time series.

> Inherits from: `handle`

Stores X/Y data in a temporary SQLite database via mksqlite using
  chunked typed BLOBs for fast bulk insert and range-based retrieval.
  This avoids loading full datasets into MATLAB memory, preventing
  out-of-memory errors on Windows and memory-constrained systems.

  Data is split into chunks of ~100K points. Each chunk is stored as
  a pair of typed BLOBs (X and Y arrays) with the chunk's X range
  indexed for fast overlap queries. On zoom/pan, only the chunks
  overlapping the visible range are loaded, then trimmed to the exact
  view window.

  Additional data columns (cell, char, string, categorical, logical,
  or any numeric type) can be attached via addColumn / getColumn.

  Requires mksqlite. If not available, falls back to binary file
  storage (extra columns require mksqlite).

### Constructor

```matlab
obj = FastSenseDataStore(x, y)
```

FASTSENSEDATASTORE Create a disk-backed store from X/Y arrays.

### Methods

#### `[xOut, yOut] = getRange(obj, xMin, xMax)`

GETRANGE Read data within an X range (with one-point padding).

#### `[xOut, yOut] = readSlice(obj, startIdx, endIdx)`

READSLICE Read a contiguous slice of data by row index.

#### `addColumn(obj, name, data)`

ADDCOLUMN Store an extra data column alongside X/Y.
  Categorical arrays auto-convert to codes+categories struct.
  String arrays auto-convert to cell of char.

#### `data = getColumnRange(obj, name, xMin, xMax)`

GETCOLUMNRANGE Read a column's data within an X range.
  Converts the X range to a point-offset range using chunk
  metadata (no x_data BLOB fetch), then delegates to slice.

#### `data = getColumnSlice(obj, name, startIdx, endIdx)`

GETCOLUMNSLICE Read a column slice by point index range.

#### `names = listColumns(obj)`

LISTCOLUMNS Return names of all stored extra columns.

#### `idx = findIndex(obj, xVal, side)`

FINDINDEX Binary search for a global point index by X value.
  idx = ds.findIndex(xVal, 'left') returns the first index
  where X(idx) >= xVal.  idx = ds.findIndex(xVal, 'right')
  returns the last index where X(idx) <= xVal.

#### `[violX, violY] = findViolations(obj, startIdx, endIdx, threshold, isUpper)`

FINDVIOLATIONS Find violation points using chunk-level Y filtering.
  [vx, vy] = ds.findViolations(lo, hi, thresh, true) finds all
  points in [lo, hi] where Y > thresh (upper violation).
  [vx, vy] = ds.findViolations(lo, hi, thresh, false) finds
  points where Y < thresh (lower violation).

#### `enableWAL(obj)`

ENABLEWAL Switch database to WAL journal mode for concurrent reads.

#### `disableWAL(obj)`

DISABLEWAL Revert database to DELETE journal mode.

#### `storeResolved(obj, resolvedTh, resolvedViol)`

STORERESOLVED Cache pre-computed resolve() results in SQLite.
  ds.storeResolved(resolvedTh, resolvedViol) stores the
  threshold and violation struct arrays produced by
  Sensor.resolve() into the database for instant retrieval.

#### `[resolvedTh, resolvedViol] = loadResolved(obj)`

LOADRESOLVED Load pre-computed resolve() results from SQLite.
  Returns empty arrays if no cached results exist.

#### `clearResolved(obj)`

CLEARRESOLVED Invalidate pre-computed resolve() cache.

#### `storeMonitor(obj, key, X, Y, parentKey, parentNumPts, parentXMin, parentXMax)`

STOREMONITOR Cache a MonitorTag's derived (X, Y) plus staleness quad.
  ds.storeMonitor(key, X, Y, parentKey, parentNumPts, parentXMin, parentXMax)
  upserts a monitors row. The quad (parent_key, num_points,
  parent_xmin, parent_xmax) is stamped at write time and is
  compared at load time by MonitorTag.cacheIsStale_.

#### `[X, Y, meta] = loadMonitor(obj, key)`

LOADMONITOR Retrieve cached MonitorTag (X, Y) + staleness metadata.
  [X, Y, meta] = ds.loadMonitor(key) returns X=[] on miss.
  Callers must verify freshness via the returned meta struct
  (fields: parent_key, num_points, parent_xmin, parent_xmax,
  computed_at).

#### `clearMonitor(obj, key)`

CLEARMONITOR Delete a cached MonitorTag row by key.

#### `cleanup(obj)`

CLEANUP Close the database and delete temp files.

#### `ensureOpenForTest(obj)`

ENSUREOPENFORTEST Test-only hook to force-reopen the DB handle.
  Exposes the private ensureOpen() lifecycle helper so WAL-mode
  tests can query journal_mode via mksqlite(DbId, ...) without
  hitting MethodRestricted. Hidden (rather than narrower
  Access = {?matlab.unittest.TestCase}) so Octave parsing
  survives — Octave has no matlab.unittest.

### Static Methods

#### `FastSenseDataStore.c = toCategorical(s)`

TOCATEGORICAL Convert a codes+categories struct back to categorical.

#### `FastSenseDataStore.c = fromCategorical(data)`

FROMCATEGORICAL Convert a MATLAB categorical to codes+categories struct.

---

## `NavigatorOverlay` --- Zoom rectangle, dimming, and drag interaction on navigator axes.

> Inherits from: `handle`

ov = NavigatorOverlay(hAxes)

  Properties (read-only):
    hRegion, hDimLeft, hDimRight, hEdgeLeft, hEdgeRight — graphics handles

  Methods:
    setRange(xMin, xMax) — update the visible region rectangle
    delete()             — clean up all handles and callbacks

### Constructor

```matlab
obj = NavigatorOverlay(hAxes, varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| OnRangeChanged |  | Callback: @(xMin, xMax) |

### Methods

#### `setRange(obj, xMin, xMax)`

Clamp to data limits

---

## `SensorDetailPlot` --- Two-panel sensor overview+detail plot with interactive navigator.

> Inherits from: `handle`

sdp = SensorDetailPlot(tag)
  sdp = SensorDetailPlot(tag, Name, Value, ...)

  Name-Value Options:
    'Theme'              - FastSense theme (default: 'default')
    'NavigatorHeight'    - Fraction 0-1 for navigator (default: 0.20)
    'ShowThresholds'     - Show thresholds in main plot (default: true)
    'ShowThresholdBands' - Show threshold bands in navigator (default: true)
    'Events'             - EventStore or Event array (default: [])
    'ShowEventLabels'    - Reserved, no effect (default: false)
    'Parent'             - uipanel handle for embedding (default: [])
    'Title'              - Plot title (default: tag.Name)
    'XType'              - 'numeric' or 'datenum' (default: 'numeric')

### Constructor

```matlab
obj = SensorDetailPlot(tag, varargin)
```

Accept Tag (v2.0) only.
Tag class is the abstract base — uses isa(x, 'Tag'), NOT
isa-on-subclass-name (Pitfall 1).

### Methods

#### `render(obj)`

#### `setZoomRange(obj, xMin, xMax)`

#### `[xMin, xMax] = getZoomRange(obj)`

---

## `ConsoleProgressBar` --- Single-line console progress bar with indentation.

> Inherits from: `handle`

A lightweight progress indicator that renders an ASCII/Unicode bar
  on a single console line, overwriting itself on each update via
  backspace characters. Supports optional leading indentation so
  multiple bars can be stacked hierarchically.

  The typical lifecycle is:  construct -> start -> update (loop) ->
  freeze or finish. Calling freeze() prints a newline to make the
  current state permanent, allowing a subsequent bar to render on a
  fresh line below. Calling finish() sets progress to 100 % and
  freezes automatically.

  On GNU Octave the bar uses ASCII characters (# and -). On MATLAB
  it uses Unicode block characters for a smoother appearance.

### Constructor

```matlab
obj = ConsoleProgressBar(indent)
```

CONSOLEPROGRESSBAR Construct a progress bar instance.
  pb = ConsoleProgressBar() creates a bar with no indentation.

### Methods

#### `start(obj)`

START Initialize and render the progress bar for the first time.
  pb.start() resets the frozen/started state and prints the
  initial (empty) bar. Must be called before update() will
  have any visible effect.

#### `update(obj, current, total, label)`

UPDATE Set progress counters and redraw the bar.
  pb.update(current, total) updates the progress fraction
  to current/total and redraws the bar in-place.

#### `freeze(obj)`

FREEZE Make the current bar state permanent by printing a newline.
  pb.freeze() redraws the bar one final time, appends a
  newline character, and sets IsFrozen to true. Subsequent
  calls to update() are silently ignored. Use this when you
  want the bar to remain visible while a new bar starts on
  the next line.

#### `finish(obj)`

FINISH Set progress to 100 %, freeze, and mark the bar done.
  pb.finish() fills the bar to completion, prints a newline
  (if not already frozen), and sets IsStarted to false. This
  is a convenience shortcut equivalent to calling
  pb.update(total, total) followed by pb.freeze().

---

## `FastSenseGrid` --- Tiled layout manager for FastSense dashboards.

> Inherits from: `handle`

Creates a grid of FastSense tiles in a single figure window with
  configurable spacing, per-tile theme overrides, and tile spanning.
  Supports live mode that synchronizes file polling across all tiles.

  For widget-based dashboards with gauges, numbers, status indicators,
  and edit mode, see DashboardEngine.

  fig = FastSenseGrid(rows, cols)
  fig = FastSenseGrid(rows, cols, 'Theme', 'dark')
  fig = FastSenseGrid(rows, cols, 'ParentFigure', hFig)

### Constructor

```matlab
obj = FastSenseGrid(rows, cols, varargin)
```

FASTSENSEGRID Construct a tiled dashboard.
  fig = FastSenseGrid(rows, cols)
  fig = FastSenseGrid(rows, cols, 'Theme', 'dark')

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| Grid | `[1 1]` | [rows, cols] |
| Theme | `[]` | FastSenseTheme struct |
| hFigure | `[]` | figure handle |
| ParentFigure | `[]` | external figure handle (skip figure creation) |
| ContentOffset | `[0 0 1 1]` | [left bottom width height] normalized content area |
| LiveViewMode | `''` | 'preserve' \| 'follow' \| 'reset' |
| LiveFile | `''` | path to .mat file |
| LiveUpdateFcn | `[]` | @(fig, data) callback |
| LiveIsActive | `false` | whether polling is running |
| LiveInterval | `2.0` | poll interval in seconds |
| MetadataFile | `''` | path to metadata .mat file |
| MetadataVars | `{}` | variable names to extract |
| MetadataLineIndex | `1` | line index within the tile |
| MetadataTileIndex | `1` | which tile to attach metadata to |
| ShowProgress | `true` | show console progress bar during renderAll |
| Padding | `[0.06 0.04 0.01 0.02]` | [left bottom right top] normalized |
| GapH | `0.03` | horizontal gap between tiles |
| GapV | `0.06` | vertical gap between tiles |

### Methods

#### `fp = tile(obj, n)`

TILE Get or create the FastSense instance for tile n.
  fp = fig.tile(n) returns the FastSense for tile n, creating
  it (and its axes) on first access. Tile themes are merged
  from the figure theme and any per-tile overrides.

#### `ax = axes(obj, n)`

AXES Get or create a raw MATLAB axes for tile n.
  ax = fig.axes(n) returns a themed MATLAB axes handle at the
  position for tile n. Use for non-FastSense plot types (bar,
  scatter, histogram, stem, etc.). The axes gets theme colors
  applied but no FastSense optimization.

#### `hp = tilePanel(obj, n)`

TILEPANEL  Get or create a uipanel for tile n.
  hp = fig.tilePanel(n) returns a uipanel handle at the
  computed grid position for tile n. Use this to embed
  composite widgets (e.g. SensorDetailPlot) into a tile.

#### `setTileSpan(obj, n, span)`

SETTILESPAN Set the row/column span for tile n.
  fig.setTileSpan(n, span) configures tile n to occupy
  multiple rows and/or columns in the grid layout.

#### `setTileTheme(obj, n, themeOverrides)`

SETTILETHEME Set per-tile theme overrides.
  fig.setTileTheme(n, themeOverrides) stores a partial theme
  struct for tile n. When the tile is created or re-themed,
  these overrides are merged on top of the figure-level theme.

#### `setTileTitle(obj, n, str)`

SETTILETITLE Set title for tile n.
  fig.setTileTitle(n, str) sets the axes title on tile n using
  the figure theme's TitleFontSize and ForegroundColor.
  Can be called before or after render().

#### `setTileXLabel(obj, n, str)`

SETTILEXLABEL Set xlabel for tile n.
  fig.setTileXLabel(n, str) sets the X-axis label on tile n
  using the figure theme's ForegroundColor.
  Can be called before or after render().

#### `setTileYLabel(obj, n, str)`

SETTILEYLABEL Set ylabel for tile n.
  fig.setTileYLabel(n, str) sets the Y-axis label on tile n
  using the figure theme's ForegroundColor.
  Can be called before or after render().

#### `renderAll(obj, parentProgressBar)`

RENDERALL Render all tiles that haven't been rendered yet.
  fig.renderAll() renders all tiles and makes the figure visible.
  fig.renderAll(parentProgressBar) renders as a child of a
  dock or parent progress context (skips figure show/drawnow).

#### `render(obj)`

RENDER Alias for renderAll.
  fig.render() is a convenience alias for fig.renderAll().

#### `reapplyTheme(obj)`

REAPPLYTHEME Re-apply theme to figure and all rendered tiles.
  fig.reapplyTheme() updates the figure background and
  propagates the current Theme to every rendered tile.
  Per-tile theme overrides (from setTileTheme) are merged
  on top of the figure-level theme before propagation.

#### `startLive(obj, filepath, updateFcn, varargin)`

STARTLIVE Start live mode on the dashboard.
  fig.startLive(filepath, updateFcn)
  fig.startLive(filepath, updateFcn, 'Interval', 1)

#### `stopLive(obj)`

STOPLIVE Stop live polling.
  fig.stopLive() stops and deletes the internal timer, then
  sets LiveIsActive to false. Safe to call when not active.

#### `refresh(obj)`

REFRESH Manual one-shot reload.
  fig.refresh() loads the LiveFile, calls LiveUpdateFcn,
  and reloads the metadata file if configured. Errors if
  no live source has been configured via startLive().

#### `setViewMode(obj, mode)`

SETVIEWMODE Set view mode on all tiles.
  fig.setViewMode(mode) sets LiveViewMode on the figure and
  propagates it to every non-empty tile.

#### `runLive(obj)`

RUNLIVE Blocking poll loop for live mode (Octave compatibility).
  fig.runLive() enters a blocking while-loop that polls
  LiveFile at LiveInterval. On MATLAB, this is a no-op if
  the timer is already running. On Octave (which lacks the
  timer object), this provides equivalent functionality.
  The loop exits when LiveIsActive becomes false or the
  figure is closed. An onCleanup guard calls stopLive().

#### `pos = computeTilePosition(obj, n)`

COMPUTETILEPOSITION Calculate normalized [x y w h] for tile n.
  pos = computeTilePosition(obj, n) computes the normalized
  position vector for tile n, accounting for grid position,
  Padding, GapH, GapV, tile spanning (TileSpans), and
  ContentOffset. Tiles are numbered in row-major order with
  top-left origin, then converted to MATLAB's bottom-left
  coordinate system.

