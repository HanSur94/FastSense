# Phase 999.3: Graph Data Export (.mat / .csv) - Context

**Gathered:** 2026-04-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Add data export capabilities to FastSense plots, allowing users to export all line and threshold data from any graph as .mat or .csv files. Accessible via FastSenseToolbar button and public API method on FastSense.

</domain>

<decisions>
## Implementation Decisions

### Export Scope & Data
- Export raw (full-resolution) data, not downsampled/view-limited data
- Export all lines in the plot automatically (no per-line selection dialog)
- Include threshold data as extra columns/fields in the export

### Trigger Mechanism
- Add export button to FastSenseToolbar (per-graph), next to existing Export PNG button
- Add public `exportData(filepath, format)` method on FastSense, consistent with `exportPNG(filepath)` pattern on FastSenseToolbar
- Use dropdown filter in uiputfile dialog (`{'*.csv';'*.mat'}`) for format selection

### CSV & MAT Format
- CSV: single file with time column + one Y column per line, using line DisplayName as header
- Mismatched X arrays across lines: union of all X values, NaN-fill for missing points
- MAT: one struct per line (`lines(i).X`, `.Y`, `.Name`) plus `thresholds` struct
- Datetime X-axis: export as datenum + ISO 8601 string column for cross-tool compatibility

### Claude's Discretion
- Internal helper organization (private methods vs. standalone functions)
- Error message wording and edge case handling (empty plots, no lines)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `FastSenseToolbar` already has Export PNG button pattern (`onExportPNG`, `exportPNG(filepath)`) — follow same dual API (toolbar callback + public method)
- `FastSenseToolbar.makeIcon('export')` icon exists — can reuse or create 'exportdata' variant
- `FastSense.Lines` struct has `.X`, `.Y`, `.Options` (contains DisplayName), `.HasNaN`, `.Metadata`
- `FastSense.Thresholds` struct has `.Value`, `.X`, `.Y`, `.Direction`, `.Label`
- `FastSense.IsDatetime` flag indicates if X data was datetime (converted to datenum internally)

### Established Patterns
- Toolbar buttons use `uipushtool` with CData icons and ClickedCallback
- Public API methods on toolbar accept optional filepath (dialog if omitted)
- `print()` used for PNG export — analogous `save()`/`writetable()` for data export
- Properties are `SetAccess = private` on Lines/Thresholds — export method must be on FastSense itself or access via public getter

### Integration Points
- `FastSenseToolbar.createToolbar()` — add new button after Export PNG button
- `FastSense` class — add `exportData()` public method
- `FastSenseToolbar` — add `onExportData()` private callback + `exportData()` public wrapper

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches following existing toolbar/export patterns.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>
