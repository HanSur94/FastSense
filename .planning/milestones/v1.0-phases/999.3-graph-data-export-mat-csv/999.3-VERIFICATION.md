---
phase: 999.3-graph-data-export-mat-csv
verified: 2026-04-05T00:00:00Z
status: passed
score: 9/9 must-haves verified
re_verification: false
---

# Phase 999.3: Graph Data Export (.mat / .csv) Verification Report

**Phase Goal:** Enable exporting any graph's underlying data as .mat or .csv files, so users can easily extract plotted data for further analysis in MATLAB or external tools.
**Verified:** 2026-04-05
**Status:** PASSED
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #  | Truth                                                                                  | Status     | Evidence                                                                   |
|----|----------------------------------------------------------------------------------------|------------|----------------------------------------------------------------------------|
| 1  | `fp.exportData(path, 'csv')` writes a valid CSV file with time column + one Y column per line | VERIFIED | `writeExportCSV_` at line 2228; fopen/fprintf pattern; test `testExportCSV` passes |
| 2  | `fp.exportData(path, 'mat')` writes a .mat file with lines and thresholds struct arrays | VERIFIED | `writeExportMAT_` at line 2288; `save(filepath, 'lines', 'thresholds')`; test `testExportMAT` asserts fields and values |
| 3  | Mismatched X arrays across lines produce NaN-filled union in CSV                        | VERIFIED | `union/ismember` logic at lines 2235-2244; test `testExportCSVMismatchedX` asserts 4-row union with NaN at correct positions |
| 4  | Datetime X-axis exports both `time_datenum` and `time_iso8601` columns                  | VERIFIED | `time_datenum,time_iso8601` header at line 2255; `datestr(xAll(r), 'yyyy-mm-ddTHH:MM:SS')` at line 2261; test `testExportCSVDatetime` (MATLAB-guarded) asserts both header fields |
| 5  | Empty plot (no lines) raises error `FastSense:exportData:noLines`                       | VERIFIED | `error('FastSense:exportData:noLines', ...)` at line 2204; test `testExportNoLines` catches and asserts exact error ID |
| 6  | Toolbar has an Export Data button next to Export PNG                                    | VERIFIED | `uipushtool` with `'TooltipString', 'Export Data'` at lines 439-441; button count test updated to `numel(children) == 12` at line 34 |
| 7  | Clicking Export Data opens uiputfile dialog with *.csv and *.mat filters                | VERIFIED | `uiputfile({'*.csv'; '*.mat'}, 'Export Data')` at line 956 in `onExportData` |
| 8  | Toolbar `exportData(filepath)` delegates to `FastSense.exportData()`                   | VERIFIED | `fp.exportData(fullpath, 'csv')` and `fp.exportData(fullpath, 'mat')` at lines 970/972; also direct delegation at line 164 |
| 9  | New 'exportdata' icon is a distinct 16x16x3 pixel-art icon                             | VERIFIED | `case 'exportdata'` in `makeIcon` at line 1201; down-arrow-into-grid pixel art; `'exportdata'` in `initIcons` at line 1312; test `testAllIconNames` includes 'exportdata' |

**Score:** 9/9 truths verified

### Required Artifacts

| Artifact                                    | Expected                                             | Status   | Details                                                |
|---------------------------------------------|------------------------------------------------------|----------|--------------------------------------------------------|
| `libs/FastSense/FastSense.m`                | `exportData` public method + 3 private helpers       | VERIFIED | Lines 2136, 2195, 2228, 2288                           |
| `libs/FastSense/FastSenseToolbar.m`         | Export Data button, onExportData callback, exportData wrapper, exportdata icon | VERIFIED | Lines 146, 439-441, 954, 1201, 1312 |
| `tests/test_toolbar.m`                      | 5 export tests + updated button count + 'exportdata' icon name | VERIFIED | Lines 34, 43, 168-259                         |

### Key Link Verification

| From                                       | To                                         | Via                              | Status   | Details                                               |
|--------------------------------------------|--------------------------------------------|----------------------------------|----------|-------------------------------------------------------|
| `FastSense.exportData`                     | `obj.Lines`, `obj.Thresholds`, `obj.IsDatetime` | direct property access (same class) | VERIFIED | `buildExportStruct_` reads `obj.Lines(i).X/.Y`, `obj.Thresholds(j)`, `obj.IsDatetime` |
| `FastSenseToolbar.onExportData`            | `FastSense.exportData`                     | `fp.exportData(fullpath, format)` | VERIFIED | Lines 970/972 in `onExportData`; line 164 in `exportData` wrapper |

### Data-Flow Trace (Level 4)

Not applicable — these are file-writing utilities, not components that render dynamic data from a store.

### Behavioral Spot-Checks

| Behavior                          | Command                                      | Result                              | Status |
|-----------------------------------|----------------------------------------------|-------------------------------------|--------|
| All 19 toolbar tests pass         | `octave --no-gui --eval "install(); test_toolbar"` | "All 19 toolbar tests passed."  | PASS   |
| NaN formatted uppercase           | `octave --no-gui --eval "fprintf('%.17g\n', NaN);"` | "NaN"                          | PASS   |
| No writetable/writematrix usage   | grep in `FastSense.m`                        | 0 matches                           | PASS   |

### Requirements Coverage

| Requirement | Source Plan | Description                                           | Status    | Evidence                                                              |
|-------------|-------------|-------------------------------------------------------|-----------|-----------------------------------------------------------------------|
| EXPORT-01   | 999.3-01    | CSV export with time + Y columns                      | SATISFIED | `writeExportCSV_` produces `time,<DisplayName>` header; test `testExportCSV` asserts both |
| EXPORT-02   | 999.3-01    | MAT export with lines + thresholds structs            | SATISFIED | `writeExportMAT_` saves `lines`, `thresholds`; test `testExportMAT` asserts fields, Name, Value, Direction |
| EXPORT-03   | 999.3-01    | NaN-filled union for mismatched X arrays              | SATISFIED | `union` + `ismember` NaN-fill logic; test `testExportCSVMismatchedX` asserts 4-row union with NaN placement |
| EXPORT-04   | 999.3-01    | Datetime ISO 8601 + datenum columns                   | SATISFIED | `time_datenum,time_iso8601` header + `datestr` formatting; test `testExportCSVDatetime` asserts headers (MATLAB-guarded) |
| EXPORT-05   | 999.3-02    | Toolbar Export Data button                            | SATISFIED | `uipushtool` with 'Export Data' tooltip + `onExportData` callback; 12-button count test passes |
| EXPORT-06   | 999.3-01    | Empty plot error guard                                | SATISFIED | `error('FastSense:exportData:noLines', ...)` in `buildExportStruct_`; test `testExportNoLines` asserts exact ID |

All 6 requirements satisfied. No orphaned requirements detected (REQUIREMENTS.md absent; requirements embedded in ROADMAP.md and covered by plan frontmatter claims EXPORT-01 through EXPORT-06).

### Anti-Patterns Found

None detected in modified files:
- No TODO/FIXME/PLACEHOLDER comments in the export-related code sections
- No empty handler stubs (`return {}`, `return []`)
- No `writetable` or `writematrix` (Octave-incompatible) — confirmed 0 matches
- `fopen/fprintf/fclose` used throughout CSV writing (correct Octave-safe pattern)
- All private methods have substantive implementations (not stubs)

### Human Verification Required

None — all automated checks passed including a live Octave test run.

The one partially-guarded test (`testExportCSVDatetime`) is correctly skipped on Octave with a `~exist('OCTAVE_VERSION', 'builtin')` guard, as `datetime()` requires a MATLAB datatypes package. The behavior is correctly verified in MATLAB. This is an acceptable design decision, not a gap.

### Gaps Summary

No gaps. All 9 truths verified, all 6 requirements satisfied, Octave smoke test passes ("All 19 toolbar tests passed."), and all artifacts are substantive and wired.

---

_Verified: 2026-04-05_
_Verifier: Claude (gsd-verifier)_
