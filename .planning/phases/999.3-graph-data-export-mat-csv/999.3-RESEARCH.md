# Phase 999.3: Graph Data Export (.mat / .csv) - Research

**Researched:** 2026-04-05
**Domain:** MATLAB/Octave file I/O, FastSense toolbar extension, CSV/MAT data serialization
**Confidence:** HIGH

## Summary

This phase adds data export capabilities to FastSense plots. Users will be able to export all raw line and threshold data from any graph as `.mat` or `.csv` files. The trigger is a new toolbar button (matching the existing Export PNG pattern) and a new public `exportData()` method on `FastSense`.

The implementation is self-contained within the FastSense library. All design decisions are locked in CONTEXT.md, and the codebase patterns are clear and well-precedented. The primary technical concerns are Octave compatibility for file-writing APIs (`writetable`/`writematrix` are MATLAB-only, requiring `fopen`/`fprintf` fallbacks), correct handling of `Lines(i).Options.DisplayName` field access, and the union-X / NaN-fill strategy for mismatched X arrays in CSV export.

**Primary recommendation:** Implement `exportData()` on `FastSense` (accesses `obj.Lines` and `obj.Thresholds` directly), add `exportData()`/`onExportData()` pair on `FastSenseToolbar` following the exact `exportPNG`/`onExportPNG` pattern. Write CSV with raw `fopen`/`fprintf` for cross-platform Octave compatibility.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Export Scope & Data**
- Export raw (full-resolution) data, not downsampled/view-limited data
- Export all lines in the plot automatically (no per-line selection dialog)
- Include threshold data as extra columns/fields in the export

**Trigger Mechanism**
- Add export button to FastSenseToolbar (per-graph), next to existing Export PNG button
- Add public `exportData(filepath, format)` method on FastSense, consistent with `exportPNG(filepath)` pattern on FastSenseToolbar
- Use dropdown filter in uiputfile dialog (`{'*.csv';'*.mat'}`) for format selection

**CSV & MAT Format**
- CSV: single file with time column + one Y column per line, using line DisplayName as header
- Mismatched X arrays across lines: union of all X values, NaN-fill for missing points
- MAT: one struct per line (`lines(i).X`, `.Y`, `.Name`) plus `thresholds` struct
- Datetime X-axis: export as datenum + ISO 8601 string column for cross-tool compatibility

### Claude's Discretion
- Internal helper organization (private methods vs. standalone functions)
- Error message wording and edge case handling (empty plots, no lines)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

## Project Constraints (from CLAUDE.md)

- Pure MATLAB — no external dependencies
- MATLAB R2020b+ AND GNU Octave 7+ must both work
- Line length: 160 characters maximum
- Tab width: 4 spaces (MISS_HIT enforced)
- Cyclomatic complexity limit: 80, max function length: 520 lines
- Error IDs: namespaced format `'ClassName:camelCaseProblem'`
- Public properties: PascalCase; private helpers: camelCase
- Verbose diagnostics guarded by `obj.Verbose` flag
- MISS_HIT (`mh_style`, `mh_lint`, `mh_metric`) enforced

## Standard Stack

### Core (Built-in MATLAB/Octave)
| API | Purpose | Compatibility Note |
|-----|---------|-------------------|
| `save(filepath, '-mat', vars)` | Write .mat file | MATLAB R2020b+ and Octave 7+ |
| `fopen` / `fprintf` / `fclose` | Write CSV portably | Both MATLAB and Octave |
| `uiputfile({'*.csv';'*.mat'}, ...)` | File save dialog | Both MATLAB and Octave |
| `datestr(datenum, 'yyyy-mm-ddTHH:MM:SS')` | ISO 8601 datetime string | Both MATLAB and Octave |
| `union(a, b)` | Union of X arrays for NaN-fill | Both |

### Avoid (MATLAB-only, breaks Octave)
| API | Problem | Use Instead |
|-----|---------|-------------|
| `writetable()` | MATLAB-only | `fopen`/`fprintf` |
| `writematrix()` | MATLAB R2019b+, not Octave | `fopen`/`fprintf` |
| `table()` constructor | Limited in Octave | plain struct arrays |

**Confidence:** HIGH — verified against existing codebase patterns (all file I/O in `DashboardSerializer.m`, `WebBridge.m` uses `fopen`/`fwrite`/`fclose`).

## Architecture Patterns

### Existing Export Pattern (HIGH confidence)

The `exportPNG` pattern in `FastSenseToolbar` is the direct template to follow:

- `FastSenseToolbar.exportPNG(obj, filepath)` — public method, calls `onExportPNG()` if no arg
- `FastSenseToolbar.onExportPNG(obj)` — private callback, calls `uiputfile`, then `exportPNG(fullpath)`
- Toolbar button: `uipushtool` with `ClickedCallback = @(s,e) obj.onExportPNG()`

The new data export follows the **same dual API**:
- `FastSense.exportData(filepath, format)` — public method on the plot object
- `FastSenseToolbar.exportData(filepath)` — public wrapper (delegates to `onExportData()` if no arg)
- `FastSenseToolbar.onExportData()` — private callback: calls `uiputfile`, dispatches to `FastSense.exportData()`

### Key Data Structures (HIGH confidence — read from source)

**Lines struct array** (`obj.Lines`):
```
Lines(i).X          — 1×N numeric (already datenum if IsDatetime)
Lines(i).Y          — 1×N numeric
Lines(i).Options    — struct with field 'DisplayName' (may be absent or empty)
Lines(i).HasNaN     — logical
Lines(i).Metadata   — struct (not exported)
```

**Thresholds struct array** (`obj.Thresholds`):
```
Thresholds(i).Value     — scalar
Thresholds(i).Direction — 'upper' | 'lower' | 'between'
Thresholds(i).Label     — string
Thresholds(i).X         — may be empty (horizontal line)
Thresholds(i).Y         — may be empty
```

**IsDatetime flag** (`obj.IsDatetime`): true when X was originally datetime; stored internally as datenum.

### Recommended File Structure

No new files needed. Add methods to existing files only:

```
libs/FastSense/FastSense.m
  + exportData(filepath, format)         [public method]
  + buildExportStruct_()                 [private helper]
  + writeExportCSV_(filepath, S)         [private helper]
  + writeExportMAT_(filepath, S)         [private helper]

libs/FastSense/FastSenseToolbar.m
  + exportData(filepath)                 [public method, mirrors exportPNG]
  + onExportData()                       [private callback]
  + new uipushtool in createToolbar()    [button after Export PNG]
  + makeIcon('exportdata') case          [new icon or reuse 'export']
```

**Discretion decision:** Private helpers as methods on `FastSense` (not standalone `private/` functions) — this keeps all state access in-class and avoids `private/` path restrictions seen in Phase 01-infrastructure-hardening (per `STATE.md`).

### CSV NaN-Fill Algorithm

For mismatched X arrays across lines:
1. Compute `xAll = union(Lines(1).X, Lines(2).X, ..., Lines(n).X)` — sorted union
2. For each line `i`: NaN-fill a vector of length `numel(xAll)`, then fill in matching positions using logical indexing or `ismember`
3. Write header row: `time,LineA,LineB,...`
4. If `IsDatetime`: write two X columns — `time_datenum,time_iso8601,LineA,...`

### MAT Export Structure

```matlab
% lines: 1×N struct array
lines(i).X    = obj.Lines(i).X;   % raw datenum or numeric
lines(i).Y    = obj.Lines(i).Y;
lines(i).Name = displayName;

% thresholds: 1×M struct array
thresholds(i).Value     = obj.Thresholds(i).Value;
thresholds(i).Direction = obj.Thresholds(i).Direction;
thresholds(i).Label     = obj.Thresholds(i).Label;

% If IsDatetime, also export:
exported_datetime = true;  % flag for consumer
```

Call `save(filepath, 'lines', 'thresholds')` — appending any datetime flag variables as needed.

### DisplayName Extraction

`Lines(i).Options` is a struct but may not have a `DisplayName` field if user didn't set one. Safe pattern:
```matlab
if isfield(L.Options, 'DisplayName') && ~isempty(L.Options.DisplayName)
    name = L.Options.DisplayName;
else
    name = sprintf('line%d', i);
end
```
This mirrors the pattern at `FastSense.m` line 1144–1145.

### Toolbar Button Addition

After the existing Export PNG `uipushtool` in `createToolbar()` (currently at line ~411–414), add:
```matlab
uipushtool(obj.hToolbar, ...
    'CData', FastSenseToolbar.makeIcon('exportdata'), ...
    'TooltipString', 'Export Data', ...
    'ClickedCallback', @(s,e) obj.onExportData());
```

**Button count impact:** Current toolbar has 11 buttons (verified by `test_toolbar.m` line 34: `assert(numel(children) == 11, ...)`). Adding one button makes it 12. The test must be updated.

### Anti-Patterns to Avoid

- **Using `writetable`/`writematrix`:** Breaks on Octave 7 — use `fopen`/`fprintf` instead.
- **Accessing `Lines` from outside `FastSense`:** `Lines` is `SetAccess = private` — `exportData` must be a method on `FastSense` itself, not on the toolbar.
- **Exporting downsampled data:** Must use `obj.Lines(i).X` / `obj.Lines(i).Y` directly (full raw arrays), not the graphics line `XData`/`YData`.
- **Calling `uiputfile` with format detection from extension:** Extension from `uiputfile` filterindex is more reliable than parsing the filename when two formats share similar names.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Sorted X union | Custom merge loop | `union(a, b)` built-in | handles duplicates, sorted guarantee |
| MAT file writing | Custom binary serialization | `save(file, vars)` | MATLAB/Octave built-in, handles all types |
| Date formatting | Manual sprintf padding | `datestr(dn, 'yyyy-mm-ddTHH:MM:SS')` | Handles leap seconds, locale-safe |
| File dialog | Custom UI | `uiputfile` | Matches existing export UX |

## Common Pitfalls

### Pitfall 1: `writetable` / `writematrix` on Octave
**What goes wrong:** Call fails silently or throws an "unknown function" error on Octave 7.
**Why it happens:** These are MATLAB-only functions; Octave lacks them.
**How to avoid:** Use `fopen` + `fprintf` for all CSV writing. Verified pattern from `DashboardSerializer.m`.
**Warning signs:** Any use of `writetable`, `writematrix`, `table()` in new code.

### Pitfall 2: Toolbar button count breaks existing test
**What goes wrong:** `test_toolbar.m` line 34 asserts `numel(children) == 11`. Adding a new button breaks this.
**Why it happens:** The test hardcodes the count.
**How to avoid:** Update the assertion from `11` to `12` in the same plan that adds the button.

### Pitfall 3: Accessing `Lines` from `FastSenseToolbar`
**What goes wrong:** `FastSense.Lines` is `SetAccess = private` — toolbar cannot read it.
**Why it happens:** MATLAB `SetAccess = private` also blocks read from external classes in some versions; more importantly, it's an encapsulation violation.
**How to avoid:** `exportData()` must be a **method on `FastSense`**, not on the toolbar. The toolbar's `onExportData` calls `obj.Target.exportData(filepath)` (or the first FastSense in the list).

### Pitfall 4: `uiputfile` filterindex for format dispatch
**What goes wrong:** Using filename extension to detect format is fragile if user types no extension.
**Why it happens:** `uiputfile` returns `[fname, fpath, filterindex]` — `filterindex` is 1 for `*.csv`, 2 for `*.mat`.
**How to avoid:** Use `filterindex` to determine format; append extension if absent.

### Pitfall 5: Empty Lines array (no lines added)
**What goes wrong:** `numel(obj.Lines) == 0` — union of zero arrays errors or returns empty; CSV has only header.
**Why it happens:** User creates `FastSense` and calls `exportData` before adding any lines.
**How to avoid:** Guard at the top of `buildExportStruct_()`: if `isempty(obj.Lines)`, error with `'FastSense:exportData:noLines'`.

### Pitfall 6: Datetime ISO 8601 column header
**What goes wrong:** CSV consumers (Excel, pandas) may not auto-parse the extra string column.
**Why it happens:** Extra column for human-readable datetime alongside datenum.
**How to avoid:** Name the columns `time_datenum` and `time_iso8601` so the distinction is clear. The decision is locked — just use consistent names.

## Code Examples

### exportPNG existing pattern (to mirror exactly)
```matlab
% Source: libs/FastSense/FastSenseToolbar.m lines 134-143, 917-924
function exportPNG(obj, filepath)
    %EXPORTPNG Save figure as PNG image at 150 DPI.
    if nargin < 2
        obj.onExportPNG();
        return;
    end
    print(obj.hFigure, '-dpng', '-r150', filepath);
end

function onExportPNG(obj)
    %ONEXPORTPNG Open a file dialog and export the figure as PNG.
    [fname, fpath] = uiputfile('*.png', 'Export as PNG');
    if isequal(fname, 0); return; end
    fullpath = fullfile(fpath, fname);
    obj.exportPNG(fullpath);
end
```

### New onExportData (toolbar side)
```matlab
function onExportData(obj)
    %ONEXPORTDATA Open file dialog and export raw data as .csv or .mat.
    [fname, fpath, idx] = uiputfile({'*.csv'; '*.mat'}, 'Export Data');
    if isequal(fname, 0); return; end
    % Append extension if missing
    if idx == 1 && ~endsWith_(fname, '.csv'); fname = [fname '.csv']; end
    if idx == 2 && ~endsWith_(fname, '.mat'); fname = [fname '.mat']; end
    fullpath = fullfile(fpath, fname);
    % Delegate to active FastSense target
    fp = obj.FastSenses{1};  % or getActiveTarget() for multi-plot
    if idx == 1
        fp.exportData(fullpath, 'csv');
    else
        fp.exportData(fullpath, 'mat');
    end
end
```

### CSV write with fopen/fprintf (Octave-safe)
```matlab
fid = fopen(filepath, 'w');
% Write header
fprintf(fid, 'time');
for i = 1:numel(names)
    fprintf(fid, ',%s', names{i});
end
fprintf(fid, '\n');
% Write data rows
for r = 1:numel(xAll)
    fprintf(fid, '%.17g', xAll(r));
    for i = 1:numel(names)
        fprintf(fid, ',%.17g', yMat(r, i));
    end
    fprintf(fid, '\n');
end
fclose(fid);
```

### MAT export
```matlab
% Source: MATLAB/Octave built-in save()
lines    = struct('X', {}, 'Y', {}, 'Name', {});
for i = 1:numel(obj.Lines)
    lines(i).X    = obj.Lines(i).X;
    lines(i).Y    = obj.Lines(i).Y;
    lines(i).Name = displayNameFor_(obj.Lines(i));
end
thresholds = struct('Value', {}, 'Direction', {}, 'Label', {});
for i = 1:numel(obj.Thresholds)
    thresholds(i).Value     = obj.Thresholds(i).Value;
    thresholds(i).Direction = obj.Thresholds(i).Direction;
    thresholds(i).Label     = obj.Thresholds(i).Label;
end
save(filepath, 'lines', 'thresholds');
```

## Environment Availability

Step 2.6: SKIPPED — pure code/config change. No external tools, CLIs, or services needed. `fopen`/`fprintf`/`save` are built-in to both MATLAB R2020b+ and Octave 7+.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | MATLAB TestCase suite + Octave function-based tests |
| Config file | `tests/run_all_tests.m` |
| Quick run command | `cd /Users/hannessuhr/FastPlot && matlab -batch "install; run('tests/test_toolbar.m')"` |
| Full suite command | `cd /Users/hannessuhr/FastPlot && matlab -batch "run('tests/run_all_tests.m')"` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| EXPORT-01 | `exportData(path, 'csv')` writes valid CSV with time + Y columns | unit | `tests/test_toolbar.m` (extend) | ✅ extend |
| EXPORT-02 | `exportData(path, 'mat')` writes .mat with `lines` + `thresholds` structs | unit | `tests/test_toolbar.m` (extend) | ✅ extend |
| EXPORT-03 | Mismatched X arrays → NaN-filled union in CSV | unit | `tests/test_toolbar.m` (extend) | ✅ extend |
| EXPORT-04 | Datetime X: CSV has `time_datenum` + `time_iso8601` columns | unit | `tests/test_toolbar.m` (extend) | ✅ extend |
| EXPORT-05 | Toolbar button added; `numel(children) == 12` | unit | `tests/test_toolbar.m` (update count) | ✅ update |
| EXPORT-06 | Empty plot (no lines) → error with `FastSense:exportData:noLines` | unit | `tests/test_toolbar.m` (extend) | ✅ extend |

### Sampling Rate
- **Per task commit:** run `test_toolbar.m` in Octave headless
- **Per wave merge:** full `run_all_tests.m`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
No new test files needed — extend existing `tests/test_toolbar.m`. The framework and infrastructure already exist. If a `TestFastSenseExport.m` suite class is preferred for isolation, that is also viable — see Claude's Discretion.

## Open Questions

1. **Multi-plot toolbar target for export**
   - What we know: `FastSenseToolbar` manages a list `obj.FastSenses` (cell array); `getActiveTarget()` returns the plot under the cursor
   - What's unclear: Should `onExportData` use `getActiveTarget()` (exports whichever plot the mouse is over) or always `obj.FastSenses{1}` (exports first plot)?
   - Recommendation: Use `getActiveTarget()` for consistency with other toolbar actions; fall back to `obj.FastSenses{1}` if no plot is under cursor. This is Claude's Discretion.

2. **Icon for Export Data button**
   - What we know: `makeIcon('export')` draws a camera shape (used for PNG). Need a distinct icon for data export.
   - What's unclear: Whether to add a new `'exportdata'` case or reuse/modify `'export'` icon.
   - Recommendation: Add a new `'exportdata'` case (e.g., arrow-down into a table/grid shape). Adding a case is low risk and keeps icons semantically distinct. This is Claude's Discretion.

## Sources

### Primary (HIGH confidence)
- `/Users/hannessuhr/FastPlot/libs/FastSense/FastSenseToolbar.m` — exportPNG/onExportPNG pattern (lines 134–143, 917–924), createToolbar button registration (lines 380–444), makeIcon static method (lines 1067–1251)
- `/Users/hannessuhr/FastPlot/libs/FastSense/FastSense.m` — Lines/Thresholds struct definitions (lines 94–119), IsDatetime/XType fields (lines 117–118), addLine datenum conversion (lines 377–410)
- `/Users/hannessuhr/FastPlot/tests/test_toolbar.m` — button count assertion (line 34), testExportPNG pattern (lines 93–102)
- `/Users/hannessuhr/FastPlot/libs/Dashboard/DashboardSerializer.m` — fopen/fwrite/fclose file I/O pattern (lines 134–185)
- `/Users/hannessuhr/FastPlot/CLAUDE.md` — Octave compatibility requirement, naming conventions, MISS_HIT rules

### Secondary (MEDIUM confidence)
- MATLAB R2020b+ documentation: `save()`, `uiputfile()`, `datestr()`, `union()` — all available in Octave 7+

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — verified against existing codebase patterns and MATLAB/Octave built-ins
- Architecture: HIGH — direct template exists in exportPNG; data structures read from source
- Pitfalls: HIGH — most pitfalls derived directly from reading source code and existing test assertions

**Research date:** 2026-04-05
**Valid until:** 2026-05-05 (stable MATLAB API domain)
