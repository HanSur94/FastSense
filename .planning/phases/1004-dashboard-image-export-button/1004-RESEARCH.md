# Phase 1004: Dashboard Image Export Button — Research

**Researched:** 2026-04-15
**Domain:** MATLAB/Octave UI toolbar integration, figure export via `print()`
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Button Integration**
- New dedicated "Image" button — distinct semantics from existing "Export" (which saves `.m` script). Follows 999.3 "Export Data" alongside "Export PNG" precedent.
- Button label: **"Image"** (short, matches existing single-word toolbar style).
- Position: **between `Save` and `Export`** in the right-to-left button strip, keeping file-output actions grouped.
- Tooltip: **"Save dashboard as image (PNG/JPEG)"**.

**Format, Dialog & Filename**
- Formats: **PNG + JPEG** (per phase goal).
- Dialog: `uiputfile({'*.png';'*.jpg'}, 'Save Dashboard Image')`. Filter index (1=PNG, 2=JPEG) drives the `print` device flag (`-dpng` / `-djpeg`).
- Default filename: `{sanitized Engine.Name}_{yyyyMMdd_HHmmss}.png`. Sanitization replaces filesystem-unsafe characters `[/\:*?"<>|]` and whitespace with `_`.
- Resolution: **150 DPI** (`-r150`), matching `FastSenseToolbar` PNG export precedent.

**Capture Scope & Edge Cases**
- Capture target: **whole `Engine.hFigure`** via `print()` — includes the toolbar. Simplest path; matches `FastSenseToolbar` precedent at `libs/FastSense/FastSenseToolbar.m:143`.
- Multi-page dashboards: **active page only**. `DashboardEngine` uses page-visibility toggling, so `print()` naturally captures only the active page.
- Live mode: **capture as-is**; no pause/resume to avoid coordinating timer state.
- Error handling: `warndlg` on write failure, consistent with `DashboardToolbar.onEdit`.

### Claude's Discretion
- Method placement on `DashboardEngine` vs private toolbar helper: a thin `DashboardEngine.exportImage(filepath, format)` delegate is likely — parallels `DashboardEngine.save(path)` and `DashboardEngine.exportScript(path)`.
- Exact method name: `exportImage` recommended (verb-noun, matches `exportScript`).
- Filename sanitization implementation (regex vs char replacement loop): whichever is Octave-safe and shortest.
- Test file placement: new `tests/suite/TestDashboardToolbarImageExport.m` + Octave companion `tests/test_dashboard_toolbar_image_export.m`, or extend existing toolbar tests. Decide during plan.

### Deferred Ideas (OUT OF SCOPE)
- Multi-page image export (all pages at once or stitched)
- Detached mirror capture (pop-out widgets)
- PDF / SVG / vector formats
- Configurable DPI as a public property
- Content-area-only capture (excluding the toolbar)
- Pause-and-resume during live capture
- Non-interactive programmatic `exportImage(path)` API polish — the method will exist as toolbar delegate, but standalone programmatic hardening/docs is deferred
</user_constraints>

## Project Constraints (from CLAUDE.md + PROJECT.md)

- **Tech stack:** Pure MATLAB — no external dependencies introduced by this phase.
- **Runtime:** MATLAB R2020b+ AND GNU Octave 7+ must both work. `exportgraphics` is MATLAB-only (R2020a+) and MUST NOT be used.
- **Backward compatibility:** No changes to existing public APIs; no changes to serialization (image export is runtime, not persisted).
- **Style:** MISS_HIT — line length ≤160, tab width 4, PascalCase classes, camelCase methods, namespaced error IDs `ClassName:camelCaseProblem`.
- **GSD workflow:** File edits must happen inside a GSD command (this is a `/gsd:plan-phase` invocation — OK).
- **No new toolboxes.**

## Summary

This is a **mechanically straightforward toolbar-integration phase** with a proven upstream precedent (`FastSenseToolbar.exportPNG` at line 143 of `libs/FastSense/FastSenseToolbar.m`). The `print(hFigure, '-d<fmt>', '-r150', filepath)` call pattern already ships in production across two libraries (`FastSenseToolbar`, `generateEventSnapshot`), is Octave-documented, and needs no toolboxes.

CONTEXT.md locks every grey-area decision, so the plan should be three small, well-scoped tasks: (1) add `hImageBtn` to `DashboardToolbar` with position/callback, (2) add `DashboardEngine.exportImage(filepath, format)` delegate + filename-sanitization helper, (3) tests. Backward compatibility is free (additive change; no serialization, theme, or widget-contract changes).

**Primary recommendation:** Insert the new button between the existing `hSaveBtn` and `hExportBtn` declarations (lines 72–80 of `DashboardToolbar.m`) by inserting one `rightEdge = rightEdge - btnW - 0.005;` block immediately after the `onSave` button construction and before `onEdit`, plus an `hImageBtn = []` property. Add `onImage()` callback method following the `onSave`/`onExport` two-liner pattern. Add a single `exportImage(filepath, format)` method to `DashboardEngine` that calls `print(obj.hFigure, devFlag, '-r150', filepath)` wrapped in a `try/catch` that raises `warndlg` on failure.

**One critical correction to CONTEXT.md:** the date format string `yyyyMMdd_HHmmss` (ISO/`datetime` notation) will **produce wrong output with `datestr()`** — in `datestr`, lowercase `mm` = minutes and `MM` = month is not a token. The correct `datestr` pattern matching the intent is **`yyyymmdd_HHMMSS`** (see `libs/EventDetection/generateEventSnapshot.m:28` for the in-codebase precedent). The planner must use this corrected format string.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `matlab.unittest` (MATLAB suite) + function-based Octave tests |
| Config file | `tests/run_all_tests.m` |
| Quick run command | `matlab -batch "cd tests; run_all_tests()"` (full suite; no per-file runner wired) |
| Full suite command | `matlab -batch "cd tests; run_all_tests()"` and `cd tests && octave --eval "run_all_tests()"` |

No individual-file run command is wired in the repo; the MATLAB suite is invoked in bulk. For fast iteration during development, a single test method can be run via `runtests('tests/suite/TestDashboardToolbarImageExport.m')`.

### Phase Requirements → Test Map

Since `phase_req_ids` is null, must-haves are derived from CONTEXT.md `<decisions>`:

| Req (derived) | Behavior | Test Type | Automated Command | File Exists? |
|---------------|----------|-----------|-------------------|--------------|
| IMG-01 | `hImageBtn` is created between `hSaveBtn` and `hExportBtn` with label "Image" and tooltip | unit | `runtests('tests/suite/TestDashboardToolbarImageExport.m','ProcedureName','testButtonPresent')` | ❌ Wave 0 |
| IMG-02 | `Engine.exportImage(path, 'png')` writes a non-empty PNG file | unit | `runtests(...,'testExportImagePNG')` | ❌ Wave 0 |
| IMG-03 | `Engine.exportImage(path, 'jpeg')` writes a non-empty JPEG file | unit | `runtests(...,'testExportImageJPEG')` | ❌ Wave 0 |
| IMG-04 | Filename sanitization replaces `[/\:*?"<>\|]` and whitespace with `_` | unit | `runtests(...,'testSanitizeFilename')` | ❌ Wave 0 |
| IMG-05 | Unknown format raises `DashboardEngine:unknownImageFormat` | unit | `runtests(...,'testUnknownFormatError')` | ❌ Wave 0 |
| IMG-06 | Write failure on unwritable path raises warning (captured by `verifyWarning`) | unit | `runtests(...,'testWriteFailureWarns')` | ❌ Wave 0 |
| IMG-07 | `DashboardToolbar.onImage()` with user cancel (`uiputfile` returns 0) is a no-op (no error) | unit | `runtests(...,'testCancelNoOp')` — use direct method call skipping real dialog | ❌ Wave 0 |
| IMG-08 | Multi-page active-page capture: after `switchPage(2)`, `exportImage` captures page 2 content (verified via file existence, not pixel diff) | integration | `runtests(...,'testMultiPageActiveOnly')` | ❌ Wave 0 |
| IMG-09 | Live mode active → `exportImage` succeeds without stopping the timer (`IsLive` remains true after call) | integration | `runtests(...,'testLiveModeNoPause')` | ❌ Wave 0 |

**Notes on verification strategy:**
- We **do not** verify that uicontrols appear in the PNG — the `print()` default behavior excludes uicontrols in Octave (see Pitfall 1 below), and the existing `FastSenseToolbar.testExportPNG` sets the precedent: verify file exists + non-empty, not pixel content.
- Mocking `uiputfile`: the toolbar callback `onImage` can be tested by **bypassing the dialog** and calling `Engine.exportImage(path, fmt)` directly. The dialog layer itself is trivial (CONTEXT-locked branch on `idx`) and doesn't need test coverage beyond an `onImage` smoke test that fakes `uiputfile` by setting an env-var flag or by direct callback invocation — see the `FastSenseToolbar.testExportPNG` precedent which calls `tb.exportPNG(tmpFile)` directly.

### Sampling Rate
- **Per task commit:** `runtests('tests/suite/TestDashboardToolbarImageExport.m')`
- **Per wave merge:** `matlab -batch "cd tests; run_all_tests()"`
- **Phase gate:** Full suite green (both MATLAB and Octave runners) before `/gsd:verify-work`.

### Wave 0 Gaps
- [ ] `tests/suite/TestDashboardToolbarImageExport.m` — covers IMG-01…IMG-09
- [ ] `tests/test_dashboard_toolbar_image_export.m` — Octave-function-based parallel suite (minimum: IMG-02, IMG-03, IMG-04, IMG-07)
- [ ] No new shared fixtures or framework install needed (uses existing `DashboardEngine` + `addFigurePath` scaffolding via `install()`)

## Technical Findings

### 1. Octave compatibility of `print()` for PNG + JPEG

**Confidence:** HIGH

- **Both `-dpng` and `-djpeg` (alias `-djpg`) are documented Octave device flags** in the official Printing and Saving Plots docs for Octave 5.x through 11.x. Source: [Octave 7.3.0 Printing and Saving Plots](https://docs.octave.org/v7.3.0/Printing-and-Saving-Plots.html), [Octave latest Printing and Saving Plots](https://docs.octave.org/latest/Printing-and-Saving-Plots.html).
- **Syntax `print(hFigure, '-dpng', '-r150', filepath)` is valid** — "the various options and filename arguments may be given in any order, except for the figure handle argument `hfig` which must be first."
- **Codebase precedent confirms runtime behavior:**
  - `libs/FastSense/FastSenseToolbar.m:143` — `print(obj.hFigure, '-dpng', '-r150', filepath)`
  - `libs/EventDetection/generateEventSnapshot.m:99` — `print(fig, outFile, '-dpng', sprintf('-r%d', 150))`
  - `tests/test_toolbar.m:99` and `tests/suite/TestToolbar.m:110` (`testExportPNG`) pass in both MATLAB and Octave CI.
- **Resolution flag `-r150` works identically** across MATLAB and Octave; applies to bitmap output including PNG/JPEG.
- **Ghostscript on Windows:** Octave defaults to `gswin32c.exe` on Windows. However, for PNG and JPEG output, Octave uses its internal raster renderer (NOT Ghostscript) when the figure is rendered with the `"qt"` or `"fltk"` graphics toolkit. Ghostscript dependency mainly applies to PostScript/PDF output. For bitmaps, PNG/JPEG work without Ghostscript on Windows. Confidence: MEDIUM (docs imply this, but not explicitly stated in a single source).
- **`-djpeg` vs `-djpg`:** both are documented as synonyms. Stick with `-djpeg` (already what CONTEXT.md implies, and matches MATLAB's primary form).

### 2. Exact `DashboardToolbar` integration points

**Confidence:** HIGH (direct source inspection)

**Current button layout in `libs/Dashboard/DashboardToolbar.m` (right-to-left, using `rightEdge` accumulator):**

| Lines | Button | Handle | Position (accumulator step) |
|-------|--------|--------|------------------------------|
| 65–71 | Export | `hExportBtn` | `rightEdge = 0.99 - 0.06 - 0.005 = 0.925` |
| 73–79 | Save | `hSaveBtn` | `rightEdge - 0.065` |
| 81–87 | Edit | `hEditBtn` | `rightEdge - 0.065` |
| 89–96 | Live | `hLiveBtn` (togglebutton) | `rightEdge - 0.065` |
| 98–105 | Sync | `hSyncBtn` | `rightEdge - 0.065` |

All use `btnW = 0.06; btnH = 0.7; btnY = 0.15; gap = 0.005`.

**Property declaration block is lines 11–22** — add `hImageBtn = []` after `hExportBtn = []` (line 16) to keep grouped output-oriented buttons together.

**Proposed insertion point for the new Image button — between `Save` (lines 73–79) and `Export` (lines 65–71), but remember: declaration order in the file is right-to-left = Export first, then Save, etc. The "between Save and Export" in the visible strip means declare AFTER Export and BEFORE Save in the file.**

Insertion plan (file-order view):

```matlab
% Lines 65–71: existing Export button (rightmost in strip)
rightEdge = rightEdge - btnW - 0.005;
obj.hExportBtn = uicontrol(...); % existing

% NEW BLOCK — insert here (between Export and Save in file; between Save and Export visually):
rightEdge = rightEdge - btnW - 0.005;
obj.hImageBtn = uicontrol('Parent', obj.hPanel, ...
    'Style', 'pushbutton', ...
    'Units', 'normalized', ...
    'Position', [rightEdge btnY btnW btnH], ...
    'String', 'Image', ...
    'TooltipString', 'Save dashboard as image (PNG/JPEG)', ...
    'Callback', @(~,~) obj.onImage());

% Lines 73–79: existing Save button
rightEdge = rightEdge - btnW - 0.005;
obj.hSaveBtn = uicontrol(...); % existing
```

**Visual result (right-to-left in the strip):** `… Sync | Live | Edit | Save | Image | Export`

**Callback method — insert new `onImage()` after `onExport` (lines 150–155) and before `onInfo` (line 157):**

```matlab
function onImage(obj)
    [file, path, idx] = uiputfile({'*.png'; '*.jpg'}, 'Save Dashboard Image', obj.defaultImageFilename());
    if file == 0, return; end
    if idx == 2
        fmt = 'jpeg';
    else
        fmt = 'png';
    end
    obj.Engine.exportImage(fullfile(path, file), fmt);
end
```

`defaultImageFilename()` is a small private helper on `DashboardToolbar` that returns the sanitized default filename suggestion (see Finding 4).

### 3. `DashboardEngine` delegate placement

**Confidence:** HIGH

**Existing delegate patterns in `libs/Dashboard/DashboardEngine.m`:**
- `save(obj, filepath)` — lines 324–353. Dispatches on extension (`.json` vs `.m`), builds config, writes file, sets `obj.FilePath`. No check that figure is realized (save works pre-render).
- `exportScript(obj, filepath)` — lines 355–371. Similar dispatch on multi-page vs single; no figure-realization check.

**Contrast:** `showInfo()` (lines 490–563) DOES work off temp files and handles `warning` on failures.

**Recommended signature:**
```matlab
function exportImage(obj, filepath, format)
%EXPORTIMAGE Save the rendered dashboard figure as PNG or JPEG at 150 DPI.
%   d.exportImage('out.png', 'png')
%   d.exportImage('out.jpg', 'jpeg')
%
%   Requires render() to have been called. Captures the current figure
%   including toolbar (print() default). Multi-page dashboards capture
%   the active page only because non-active pages are hidden.
%
%   Inputs:
%     filepath — destination path (string). Parent directory must exist.
%     format   — 'png' or 'jpeg'. Defaults to extension-inferred if omitted.

    if nargin < 3 || isempty(format)
        [~, ~, ext] = fileparts(filepath);
        if strcmpi(ext, '.jpg') || strcmpi(ext, '.jpeg')
            format = 'jpeg';
        else
            format = 'png';
        end
    end

    if isempty(obj.hFigure) || ~ishandle(obj.hFigure)
        error('DashboardEngine:notRendered', ...
            'exportImage requires render() to have been called first.');
    end

    switch lower(format)
        case 'png'
            devFlag = '-dpng';
        case {'jpeg', 'jpg'}
            devFlag = '-djpeg';
        otherwise
            error('DashboardEngine:unknownImageFormat', ...
                'Unknown image format ''%s''. Use ''png'' or ''jpeg''.', format);
    end

    try
        print(obj.hFigure, devFlag, '-r150', filepath);
    catch ME
        error('DashboardEngine:imageWriteFailed', ...
            'Failed to write image ''%s'': %s', filepath, ME.message);
    end
end
```

**Place it:** as a public method between `exportScript` (line 371) and `preview` (line 373). Maintains verb-noun grouping with `save` → `exportScript` → `exportImage`.

**Toolbar callback on write failure:** The toolbar's `onImage()` wraps the engine call in `try/catch` and invokes `warndlg(ME.message, 'Image Export')` — consistent with `onEdit` pattern at line 164.

### 4. Filename sanitization — Octave-safe

**Confidence:** HIGH

**`regexprep` is available in both MATLAB and Octave 7+** (used already in `libs/Dashboard/MarkdownRenderer.m`). Single-line implementation replaces `[/\:*?"<>|]` AND whitespace with `_`:

```matlab
safeName = regexprep(rawName, '[/\\:*?"<>|\s]', '_');
```

Note the double-backslash for `\` because MATLAB regex strings require escaping.

**If `Engine.Name` is empty**, fall back to `'Dashboard'` to avoid a leading-underscore filename:

```matlab
rawName = obj.Engine.Name;
if isempty(rawName), rawName = 'Dashboard'; end
safeName = regexprep(rawName, '[/\\:*?"<>|\s]', '_');
stamp = datestr(now, 'yyyymmdd_HHMMSS');   % ← NOTE: correct datestr format
defaultFilename = sprintf('%s_%s.png', safeName, stamp);
```

**CRITICAL CORRECTION to CONTEXT.md:** The CONTEXT.md spec says `{yyyyMMdd_HHmmss}` — that is the newer MATLAB `datetime` format. With `datestr()`, `mm` = minutes and `MM` is not a valid token for month. The in-codebase precedent at `libs/EventDetection/generateEventSnapshot.m:28` uses **`yyyymmdd_HHMMSS`** — this is what the plan must use. Document the correction in the plan so reviewers know the CONTEXT string was illustrative, not literal.

Put the helper as a private method on `DashboardToolbar` (since it's purely filename UI sugar, not dashboard state):

```matlab
function fname = defaultImageFilename(obj)
    rawName = obj.Engine.Name;
    if isempty(rawName), rawName = 'Dashboard'; end
    safeName = regexprep(rawName, '[/\\:*?"<>|\s]', '_');
    stamp = datestr(now, 'yyyymmdd_HHMMSS');
    fname = sprintf('%s_%s.png', safeName, stamp);
end
```

**Test coverage:** single unit test that feeds `Engine.Name = 'My Dash/Board: v1'` and asserts the sanitized filename matches `My_Dash_Board__v1_YYYYMMDD_HHMMSS.png` (regex match on the timestamp portion).

### 5. Testing conventions for toolbar changes

**Confidence:** HIGH

**Existing precedent:** `tests/suite/TestToolbar.m` is the `FastSenseToolbar` test suite. It constructs real figures with `visible=on` (no explicit `off` — toolbar tests rely on `close(fp.hFigure)` teardown), calls methods directly, and verifies handle validity + file existence.

**Headless test pattern:** `TestDashboardEngine.m` line 108 uses `set(d.hFigure, 'Visible', 'off')` for render tests; `testCase.addTeardown(@() close(d.hFigure))` for cleanup. **Use this pattern** — don't inherit the `FastSenseToolbar` pattern because toolbar children inside a visible figure may behave differently under CI. Precedent at `.planning/codebase/TESTING.md:146`: "Figure-creating tests: always call `set(d.hFigure, 'Visible', 'off')`".

**Recommended test structure (`tests/suite/TestDashboardToolbarImageExport.m`):**

```matlab
classdef TestDashboardToolbarImageExport < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testButtonPresent(testCase)
            d = DashboardEngine('TestDash');
            d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'Value', 42);
            d.render();
            set(d.hFigure, 'Visible', 'off');
            testCase.addTeardown(@() close(d.hFigure));

            testCase.verifyNotEmpty(d.Toolbar.hImageBtn, 'testButtonPresent: hImageBtn');
            testCase.verifyEqual(get(d.Toolbar.hImageBtn, 'String'), 'Image', 'label');
            testCase.verifyEqual(get(d.Toolbar.hImageBtn, 'TooltipString'), ...
                'Save dashboard as image (PNG/JPEG)', 'tooltip');
        end

        function testExportImagePNG(testCase)
            d = DashboardEngine('Test');
            d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'Value', 1);
            d.render();
            set(d.hFigure, 'Visible', 'off');
            testCase.addTeardown(@() close(d.hFigure));

            tmp = [tempname '.png'];
            testCase.addTeardown(@() TestDashboardToolbarImageExport.deleteIfExists(tmp));

            d.exportImage(tmp, 'png');
            testCase.verifyEqual(exist(tmp, 'file'), 2, 'file exists');
            info = dir(tmp);
            testCase.verifyGreaterThan(info.bytes, 0, 'non-empty');
        end

        function testUnknownFormatError(testCase)
            d = DashboardEngine('X');
            d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'Value', 1);
            d.render();
            set(d.hFigure, 'Visible', 'off');
            testCase.addTeardown(@() close(d.hFigure));
            testCase.verifyError(@() d.exportImage('/tmp/x.bmp', 'bmp'), ...
                'DashboardEngine:unknownImageFormat');
        end

        % ... (IMG-03 JPEG, IMG-04 sanitize, IMG-06 writeFail,
        %      IMG-07 cancelNoOp via onImage stub, IMG-08 multipage, IMG-09 live)
    end

    methods (Static, Access = private)
        function deleteIfExists(p)
            if exist(p, 'file'); delete(p); end
        end
    end
end
```

**Testing `onImage` cancel path:** `uiputfile` cannot be mocked easily. The CONTEXT.md-locked behavior is "if `file == 0`, return" — a one-line guard. Either (a) skip test coverage for this trivial branch, or (b) extract the post-dialog portion of `onImage` into a helper `dispatchImageExport(file, path, idx)` that can be tested directly. Option (b) is cleaner and testable.

**Write-failure test (IMG-06):** call `d.exportImage('/nonexistent_dir/out.png', 'png')` and verify error ID `DashboardEngine:imageWriteFailed`.

**Octave companion (`tests/test_dashboard_toolbar_image_export.m`):** mirrors a subset (IMG-02/03/04/07) using `assert` and the `test_*` function pattern from `tests/test_toolbar.m:94–102`.

### 6. Validation architecture (Nyquist)

Captured above. The key derived acceptance criteria IMG-01…IMG-09 cover every CONTEXT.md decision. Multi-page (IMG-08) and live-mode (IMG-09) are integration-tier; the rest are unit tests. No manual-only tests required — all nine are automatable in < 30 seconds per test.

### 7. Risk callouts — MATLAB/Octave rendering differences

**Confidence:** MEDIUM-HIGH

- **RISK-1 (Octave uicontrol exclusion):** Octave's `print()` does **not** capture `uicontrol` objects by default. Source: [Octave Printing and Saving Plots docs](https://docs.octave.org/latest/Printing-and-Saving-Plots.html). This means **the toolbar, Page bar, and time-panel sliders may not appear in the exported image in Octave** — only the widget axes and uipanel backgrounds will. CONTEXT.md's decision is "capture whole figure including toolbar"; the realistic outcome is "whole figure minus uicontrols in Octave, whole figure in MATLAB." The plan should document this as a known platform difference rather than try to work around it (workarounds require `getframe` + `imwrite` and introduce their own issues — out of scope). **Recommend:** add a comment in `exportImage` noting the difference, and in the phase retrospective flag that a screenshot-based alternative could be a future phase if Octave users complain.

- **RISK-2 (MATLAB `uifigure` warning):** MATLAB issues a warning when `print()` is called on a figure containing UI components in R2023b+, and `hgexport`/`print` do not support figures created with `uifigure`. `DashboardEngine.render()` (line 240) uses plain `figure()` (NOT `uifigure`), so this is NOT triggered. Confirmed by direct source read. No action needed.

- **RISK-3 (Panel background color on export):** `print()` defaults to using the figure `Color` property as the background. `DashboardEngine` sets this via `themeStruct.DashboardBackground` (line 242). Widget `uipanel` backgrounds are theme-aware and render correctly. **No risk** — already working in `FastSenseToolbar.exportPNG` with identical mechanics.

- **RISK-4 (Anti-aliasing differences):** MATLAB and Octave use different rasterizers (MATLAB has its own; Octave uses `gl2ps`/internal). Outputs will not be pixel-identical but both will be valid PNG/JPEG of the rendered figure. Tests should check file existence + non-empty size, not pixel diffs (matches existing `testExportPNG`).

- **RISK-5 (Active-page-only capture assumption):** CONTEXT.md claims non-active pages have `Visible='off'` so `print()` naturally captures only the active page. Verified at `DashboardEngine.m:137–143` (visibility toggling in `switchPage`) and `DashboardEngine.m:286–290` (non-active panels hidden at render time). **Assumption holds.**

- **RISK-6 (Live timer interaction):** `print()` is synchronous and blocks the MATLAB thread; the `LiveTimer` callback (`onLiveTick`) cannot preempt it (MATLAB timers are cooperatively scheduled on the main thread). No race condition risk in MATLAB. In Octave, timers are less robust in general — but the test `testLiveModeNoPause` verifies `IsLive` remains true after the call, which is the only observable invariant required.

### 8. Existing tech debt or concerns

**Confidence:** HIGH

- `.planning/codebase/CONCERNS.md` lists `FastSenseToolbar.m` (1270 lines) as oversized, but that's the reference (not target) file. `DashboardToolbar.m` is only 179 lines — plenty of room for a ~15-line insertion.
- No outstanding issues, bug reports, or tech debt tickets related to image export or `print()` in the dashboard engine (verified by grepping `CONCERNS.md` for `Toolbar|print|image|PNG|export`).
- The existing `FastSenseToolbar.exportPNG` test (`testExportPNG`) is the canonical "does print work" test — it passes in CI on MATLAB AND Octave, which is strong empirical evidence that `print(hFigure, '-dpng', '-r150', filepath)` on a figure containing a `uitoolbar` + `uicontrol` works in both runtimes (even if uicontrols aren't rendered in Octave output).

## Recommended Implementation Approach

**Three small tasks, executable as a single wave:**

### Task 1 — `DashboardToolbar` button + callback
**Files:** `libs/Dashboard/DashboardToolbar.m`
**Changes:**
- Add `hImageBtn = []` property after `hExportBtn` (line 16).
- Insert new `rightEdge` + `uicontrol` block between Export (line 71) and Save (line 73).
- Add `onImage(obj)` method between `onExport` (line 155) and `onInfo` (line 157).
- Add private helper `defaultImageFilename(obj)` (regex sanitize + `datestr(now, 'yyyymmdd_HHMMSS')`).
- Optional: extract `dispatchImageExport(obj, file, path, idx)` helper to make cancel/dispatch testable without `uiputfile`.

### Task 2 — `DashboardEngine.exportImage` delegate
**Files:** `libs/Dashboard/DashboardEngine.m`
**Changes:**
- Add `exportImage(obj, filepath, format)` public method between `exportScript` (line 371) and `preview` (line 373).
- Errors: `DashboardEngine:notRendered`, `DashboardEngine:unknownImageFormat`, `DashboardEngine:imageWriteFailed`.
- Doc comment with signature, format values, platform note ("Octave may exclude uicontrols from output").

### Task 3 — Tests
**Files:** `tests/suite/TestDashboardToolbarImageExport.m` (new), `tests/test_dashboard_toolbar_image_export.m` (new, Octave companion).
**Coverage:** IMG-01…IMG-09 per Validation Architecture table.

**Ordering:** Task 2 before Task 1 (the toolbar depends on the engine delegate). Tests in Task 3 can be written concurrently with Task 1.

## Risk Register

| # | Risk | Likelihood | Impact | Mitigation |
|---|------|-----------|--------|------------|
| 1 | Octave `print()` excludes uicontrols → toolbar not in Octave output | HIGH (documented) | LOW (CONTEXT says capture is best-effort; acceptable limitation) | Document in `exportImage` comment and phase retrospective |
| 2 | `datestr` format string confusion (CONTEXT.md used ISO notation) | MEDIUM | HIGH (silent wrong output) | Call out in plan: use `'yyyymmdd_HHMMSS'`, not `'yyyyMMdd_HHmmss'` |
| 3 | Write-failure error handling inconsistency | LOW | LOW | Follow `onEdit` `warndlg` pattern; `exportImage` throws, `onImage` catches |
| 4 | Button layout clash if user's figure is < 800 px wide (6% width buttons get tight) | LOW | LOW | Existing 6-button strip already fits; adding 7th maintains fit |
| 5 | Live timer firing during `print()` | LOW (MATLAB timers are cooperative on main thread) | LOW | No action; covered by IMG-09 test |
| 6 | `regexprep` escaping subtle bugs (e.g., `\|` in character class) | LOW | MEDIUM | Test IMG-04 exercises `[/\:*?"<>|]` and whitespace explicitly |
| 7 | `uiputfile` filter-index behavior differs between MATLAB and Octave | LOW | LOW | Octave docs confirm 3-output form returns `fltidx`; behavior matches |

## Open Questions

1. **Should `exportImage` require `render()` to have been called, or should it call `render()` if needed?**
   - What we know: `save()` and `exportScript()` do NOT require render (they serialize `Widgets`, not HG state).
   - What's unclear: image export fundamentally needs `hFigure`, so requiring render is correct. The question is just error vs. auto-render.
   - Recommendation: **Require render and throw `DashboardEngine:notRendered`**. Auto-rendering would be surprising and could steal focus from the user's current figure.

2. **Should `DashboardToolbar.onImage()` suggest a default filename via the third positional arg to `uiputfile`?**
   - What we know: `uiputfile({filters}, title, defaultName)` accepts a default-name arg.
   - What's unclear: CONTEXT.md says "Default filename: `{sanitized Engine.Name}_{yyyyMMdd_HHmmss}.{ext}`" — this implies pre-populating the dialog.
   - Recommendation: **Yes — pass the default filename**. Aligns with the user-visible value proposition (one-click export). `defaultImageFilename()` helper is sized for this.

3. **Should the plan include a MISS_HIT style run as a task?**
   - Not required — MISS_HIT runs in CI. But mention "verify `mh_style libs/Dashboard/DashboardToolbar.m libs/Dashboard/DashboardEngine.m` is clean" as a task-completion check.

## Sources

### Primary (HIGH confidence)
- `libs/Dashboard/DashboardToolbar.m` (179 lines) — direct inspection
- `libs/Dashboard/DashboardEngine.m` (1328 lines) — direct inspection, save/exportScript/showInfo patterns
- `libs/FastSense/FastSenseToolbar.m:143, 944–974` — precedent for `print()` + `uiputfile` dual-format
- `libs/EventDetection/generateEventSnapshot.m:28, 99` — precedent for `datestr(now, 'yyyymmdd_HHMMSS')` and `print(fig, file, '-dpng', '-r150')`
- `tests/suite/TestToolbar.m:102–112` and `tests/test_toolbar.m:93–101` — precedent for headless `exportPNG` tests
- `tests/suite/TestDashboardEngine.m:60–93` — precedent for `save`/`exportScript` tests using tempdir + teardown
- `.planning/phases/1004-dashboard-image-export-button/1004-CONTEXT.md` — locked decisions
- `.planning/codebase/CONVENTIONS.md`, `.planning/codebase/TESTING.md` — coding and test conventions

### Secondary (HIGH confidence, external)
- [GNU Octave v7.3.0 Printing and Saving Plots](https://docs.octave.org/v7.3.0/Printing-and-Saving-Plots.html) — `print()` device flags, syntax
- [GNU Octave latest Printing and Saving Plots](https://docs.octave.org/latest/Printing-and-Saving-Plots.html) — current docs, uicontrol exclusion note
- [Octave Forge: print](https://octave.sourceforge.io/octave/function/print.html) — function reference
- [GNU Octave I/O Dialogs (latest)](https://docs.octave.org/latest/I_002fO-Dialogs.html) — `uiputfile` filter-index third-output form
- [MATLAB print documentation](https://www.mathworks.com/help/matlab/ref/print.html) — confirms `-dpng`/`-djpeg`/`-r<dpi>` and `uifigure` vs `figure` difference

### Tertiary (MEDIUM confidence)
- General `regexprep` availability in Octave — inferred from existing codebase use in `MarkdownRenderer.m` plus broad Octave compatibility; not independently verified against docs

## Metadata

**Confidence breakdown:**
- User constraints: HIGH — transcribed verbatim from CONTEXT.md, one format-string gotcha flagged
- Integration points (DashboardToolbar, DashboardEngine): HIGH — direct source read, exact line numbers provided
- Octave `print()` PNG/JPEG support: HIGH — official docs + two in-codebase precedents exercised in CI
- Octave uicontrol exclusion: HIGH — documented limitation, surfaced as RISK-1
- Test architecture: HIGH — matches established dashboard test patterns
- Sanitization approach: HIGH — `regexprep` proven in codebase

**Research date:** 2026-04-15
**Valid until:** 2026-05-15 (30 days; stable domain, no fast-moving deps)

## RESEARCH COMPLETE

**Phase:** 1004 - Dashboard Image Export Button
**Confidence:** HIGH

### Key Findings
- CONTEXT.md locks all grey-area decisions; this phase is mechanically straightforward with proven upstream precedents (`FastSenseToolbar.exportPNG` at line 143).
- **Critical correction:** CONTEXT.md's filename format `yyyyMMdd_HHmmss` (ISO / `datetime` notation) is wrong for `datestr()`. Use **`yyyymmdd_HHMMSS`** (matches in-codebase precedent at `libs/EventDetection/generateEventSnapshot.m:28`).
- **Known platform difference:** Octave `print()` does NOT capture uicontrols by default (documented). The exported PNG/JPEG in Octave will contain widget axes but NOT the toolbar/page-bar/time-panel buttons. In MATLAB it captures everything. This is an acceptable limitation under CONTEXT's "whole figure via print()" decision — document, don't work around.
- Exact integration points identified with line numbers: `DashboardToolbar.m:11–22` (properties), `71→73` (button insertion), `155→157` (callback insertion); `DashboardEngine.m:371→373` (new method).
- Nine derived acceptance criteria (IMG-01…IMG-09) covering golden path, unknown-format, write-failure, cancel, sanitization, multi-page, and live-mode. All automatable in < 30 s each.

### File Created
`.planning/phases/1004-dashboard-image-export-button/1004-RESEARCH.md`

### Confidence Assessment
| Area | Level | Reason |
|------|-------|--------|
| Standard Stack | HIGH | Pure MATLAB/Octave `print()` — no new libraries |
| Architecture | HIGH | Direct source inspection of every integration point |
| Pitfalls | HIGH | datestr format gotcha and Octave uicontrol exclusion both flagged with sources |

### Open Questions
- Require `render()` before `exportImage`, or auto-render? Recommend: require + throw `DashboardEngine:notRendered`.
- Pass default filename as 3rd arg to `uiputfile`? Recommend: yes.
- Both are minor — plan can proceed.

### Ready for Planning
Research complete. Planner can now create PLAN.md files for the three tasks (toolbar integration, engine delegate, tests).
