# Dashboard & Visual Customization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add FastSenseFigure (tiled dashboard layouts), FastSenseTheme (5 presets + custom themes), and new visual elements (addShaded, addBand, addFill, addMarker) to FastSense while maintaining full backward compatibility.

**Architecture:** Three layers — `FastSenseTheme.m` (function returning theme structs), extended `FastSense.m` (theme support + 4 new visual methods), and `FastSenseFigure.m` (figure layout manager). Theme inheritance flows: element override > tile theme > figure theme > 'default' preset. All visual enhancements use `patch()` or `line()` objects with UserData tagging and downsampling on zoom.

**Tech Stack:** Pure MATLAB/Octave — no toolboxes, no MEX. Uses `figure()`, `axes()`, `patch()`, `line()`, `set()`/`get()`.

**Test runner:** `octave --no-gui --eval "addpath('.'); addpath('tests'); addpath('private'); test_NAME;"`

---

### Task 1: FastSenseTheme — Default Preset & Merge Logic

**Files:**
- Create: `FastSenseTheme.m`
- Create: `tests/test_theme.m`

**Step 1: Write the failing test**

Create `tests/test_theme.m`:

```matlab
function test_theme()
%TEST_THEME Tests for FastSenseTheme function.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));

    % testDefaultPreset
    t = FastSenseTheme('default');
    assert(isstruct(t), 'testDefaultPreset: must return struct');
    assert(isequal(t.Background, [1 1 1]), 'testDefaultPreset: Background');
    assert(isfield(t, 'AxesColor'), 'testDefaultPreset: AxesColor field');
    assert(isfield(t, 'ForegroundColor'), 'testDefaultPreset: ForegroundColor field');
    assert(isfield(t, 'GridColor'), 'testDefaultPreset: GridColor field');
    assert(isfield(t, 'GridAlpha'), 'testDefaultPreset: GridAlpha field');
    assert(isfield(t, 'GridStyle'), 'testDefaultPreset: GridStyle field');
    assert(isfield(t, 'FontName'), 'testDefaultPreset: FontName field');
    assert(isfield(t, 'FontSize'), 'testDefaultPreset: FontSize field');
    assert(isfield(t, 'TitleFontSize'), 'testDefaultPreset: TitleFontSize field');
    assert(isfield(t, 'LineWidth'), 'testDefaultPreset: LineWidth field');
    assert(isfield(t, 'LineColorOrder'), 'testDefaultPreset: LineColorOrder field');
    assert(isfield(t, 'ThresholdColor'), 'testDefaultPreset: ThresholdColor field');
    assert(isfield(t, 'ThresholdStyle'), 'testDefaultPreset: ThresholdStyle field');
    assert(isfield(t, 'ViolationMarker'), 'testDefaultPreset: ViolationMarker field');
    assert(isfield(t, 'ViolationSize'), 'testDefaultPreset: ViolationSize field');
    assert(isfield(t, 'BandAlpha'), 'testDefaultPreset: BandAlpha field');
    assert(size(t.LineColorOrder, 2) == 3, 'testDefaultPreset: LineColorOrder must be Nx3');

    % testNoArgsReturnsDefault
    t0 = FastSenseTheme();
    t1 = FastSenseTheme('default');
    assert(isequal(t0, t1), 'testNoArgsReturnsDefault');

    % testMergeOverrides
    t = FastSenseTheme('default', 'FontSize', 14, 'LineWidth', 2.0);
    assert(t.FontSize == 14, 'testMergeOverrides: FontSize');
    assert(t.LineWidth == 2.0, 'testMergeOverrides: LineWidth');
    assert(isequal(t.Background, [1 1 1]), 'testMergeOverrides: Background unchanged');

    % testInvalidPresetErrors
    threw = false;
    try
        FastSenseTheme('nonexistent');
    catch
        threw = true;
    end
    assert(threw, 'testInvalidPresetErrors');

    fprintf('    All 4 theme tests passed.\n');
end
```

**Step 2: Run test to verify it fails**

Run: `octave --no-gui --eval "addpath('.'); addpath('tests'); addpath('private'); test_theme;"`
Expected: FAIL — `FastSenseTheme` not found

**Step 3: Write minimal implementation**

Create `FastSenseTheme.m`:

```matlab
function theme = FastSenseTheme(preset, varargin)
%FASTSENSETHEME Return a theme struct for FastSense styling.
%   theme = FastSenseTheme()              — returns 'default' preset
%   theme = FastSenseTheme('dark')        — returns named preset
%   theme = FastSenseTheme('dark', 'FontSize', 14) — preset with overrides

    if nargin == 0
        preset = 'default';
    end

    % If preset is already a struct, use it as base
    if isstruct(preset)
        theme = mergeTheme(getPreset('default'), preset);
    else
        theme = getPreset(preset);
    end

    % Apply name-value overrides
    for k = 1:2:numel(varargin)
        theme.(varargin{k}) = varargin{k+1};
    end

    % Resolve named palettes to Nx3 matrices
    if ischar(theme.LineColorOrder)
        theme.LineColorOrder = getPalette(theme.LineColorOrder);
    end
end

function t = getPreset(name)
    switch lower(name)
        case 'default'
            t = struct( ...
                'Background',      [1 1 1], ...
                'AxesColor',       [1 1 1], ...
                'ForegroundColor', [0.15 0.15 0.15], ...
                'GridColor',       [0.15 0.15 0.15], ...
                'GridAlpha',       0.15, ...
                'GridStyle',       '-', ...
                'FontName',        'Helvetica', ...
                'FontSize',        10, ...
                'TitleFontSize',   12, ...
                'LineWidth',       1.0, ...
                'LineColorOrder',  'vibrant', ...
                'ThresholdColor',  [0.8 0 0], ...
                'ThresholdStyle',  '--', ...
                'ViolationMarker', 'o', ...
                'ViolationSize',   4, ...
                'BandAlpha',       0.15 ...
            );
        case 'dark'
            t = struct( ...
                'Background',      [0.1 0.1 0.12], ...
                'AxesColor',       [0.15 0.15 0.18], ...
                'ForegroundColor', [0.85 0.85 0.85], ...
                'GridColor',       [0.35 0.35 0.35], ...
                'GridAlpha',       0.4, ...
                'GridStyle',       ':', ...
                'FontName',        'Helvetica', ...
                'FontSize',        10, ...
                'TitleFontSize',   12, ...
                'LineWidth',       1.0, ...
                'LineColorOrder',  'vibrant', ...
                'ThresholdColor',  [1 0.3 0.3], ...
                'ThresholdStyle',  '--', ...
                'ViolationMarker', 'o', ...
                'ViolationSize',   4, ...
                'BandAlpha',       0.2 ...
            );
        case 'light'
            t = struct( ...
                'Background',      [0.98 0.98 0.98], ...
                'AxesColor',       [1 1 1], ...
                'ForegroundColor', [0.25 0.25 0.25], ...
                'GridColor',       [0.8 0.8 0.8], ...
                'GridAlpha',       0.3, ...
                'GridStyle',       '-', ...
                'FontName',        'Helvetica', ...
                'FontSize',        10, ...
                'TitleFontSize',   12, ...
                'LineWidth',       1.0, ...
                'LineColorOrder',  'muted', ...
                'ThresholdColor',  [0.7 0 0], ...
                'ThresholdStyle',  '--', ...
                'ViolationMarker', 'o', ...
                'ViolationSize',   4, ...
                'BandAlpha',       0.12 ...
            );
        case 'industrial'
            t = struct( ...
                'Background',      [0.95 0.95 0.92], ...
                'AxesColor',       [1 1 0.97], ...
                'ForegroundColor', [0.1 0.1 0.1], ...
                'GridColor',       [0.6 0.6 0.55], ...
                'GridAlpha',       0.3, ...
                'GridStyle',       '-', ...
                'FontName',        'Consolas', ...
                'FontSize',        10, ...
                'TitleFontSize',   13, ...
                'LineWidth',       1.2, ...
                'LineColorOrder',  'vibrant', ...
                'ThresholdColor',  [0.9 0 0], ...
                'ThresholdStyle',  '--', ...
                'ViolationMarker', 'o', ...
                'ViolationSize',   5, ...
                'BandAlpha',       0.18 ...
            );
        case 'scientific'
            t = struct( ...
                'Background',      [1 1 1], ...
                'AxesColor',       [1 1 1], ...
                'ForegroundColor', [0 0 0], ...
                'GridColor',       [0 0 0], ...
                'GridAlpha',       0, ...
                'GridStyle',       'none', ...
                'FontName',        'Times New Roman', ...
                'FontSize',        11, ...
                'TitleFontSize',   13, ...
                'LineWidth',       0.75, ...
                'LineColorOrder',  'colorblind', ...
                'ThresholdColor',  [0.6 0 0], ...
                'ThresholdStyle',  '--', ...
                'ViolationMarker', 'o', ...
                'ViolationSize',   3, ...
                'BandAlpha',       0.1 ...
            );
        otherwise
            error('FastSenseTheme:unknownPreset', ...
                'Unknown theme preset: ''%s''. Use ''default'', ''dark'', ''light'', ''industrial'', or ''scientific''.', name);
    end
end

function colors = getPalette(name)
    switch lower(name)
        case 'vibrant'
            colors = [ ...
                0.00 0.45 0.74; ...  % blue
                0.85 0.33 0.10; ...  % red-orange
                0.93 0.69 0.13; ...  % yellow
                0.49 0.18 0.56; ...  % purple
                0.47 0.67 0.19; ...  % green
                0.30 0.75 0.93; ...  % cyan
                0.64 0.08 0.18; ...  % dark red
                0.00 0.62 0.45; ...  % teal
            ];
        case 'muted'
            colors = [ ...
                0.33 0.47 0.64; ...  % steel blue
                0.68 0.40 0.36; ...  % dusty rose
                0.55 0.55 0.36; ...  % olive
                0.58 0.44 0.65; ...  % mauve
                0.45 0.62 0.50; ...  % sage
                0.65 0.55 0.40; ...  % tan
                0.40 0.55 0.60; ...  % slate
                0.62 0.42 0.52; ...  % plum
            ];
        case 'colorblind'
            % Wong (2011) colorblind-safe palette
            colors = [ ...
                0.00 0.45 0.70; ...  % blue
                0.90 0.62 0.00; ...  % orange
                0.00 0.62 0.45; ...  % bluish green
                0.80 0.47 0.65; ...  % reddish purple
                0.94 0.89 0.26; ...  % yellow
                0.34 0.71 0.91; ...  % sky blue
                0.84 0.37 0.00; ...  % vermillion
                0.00 0.00 0.00; ...  % black
            ];
        otherwise
            error('FastSenseTheme:unknownPalette', ...
                'Unknown palette: ''%s''. Use ''vibrant'', ''muted'', or ''colorblind''.', name);
    end
end

function result = mergeTheme(base, overrides)
    result = base;
    fnames = fieldnames(overrides);
    for i = 1:numel(fnames)
        result.(fnames{i}) = overrides.(fnames{i});
    end
end
```

**Step 4: Run test to verify it passes**

Run: `octave --no-gui --eval "addpath('.'); addpath('tests'); addpath('private'); test_theme;"`
Expected: PASS — All 4 theme tests passed.

**Step 5: Commit**

```bash
git add FastSenseTheme.m tests/test_theme.m
git commit -m "Add FastSenseTheme with 5 presets, 3 palettes, and merge logic"
```

---

### Task 2: FastSenseTheme — All Presets & Palettes

**Files:**
- Modify: `tests/test_theme.m`

**Step 1: Write the failing tests**

Append to `tests/test_theme.m` (before the final fprintf):

```matlab
    % testDarkPreset
    t = FastSenseTheme('dark');
    assert(all(t.Background < [0.2 0.2 0.2]), 'testDarkPreset: Background should be dark');
    assert(all(t.ForegroundColor > [0.7 0.7 0.7]), 'testDarkPreset: ForegroundColor should be light');
    assert(size(t.LineColorOrder, 2) == 3, 'testDarkPreset: LineColorOrder Nx3');

    % testLightPreset
    t = FastSenseTheme('light');
    assert(all(t.Background > [0.9 0.9 0.9]), 'testLightPreset: Background');
    assert(size(t.LineColorOrder, 2) == 3, 'testLightPreset: LineColorOrder Nx3');

    % testIndustrialPreset
    t = FastSenseTheme('industrial');
    assert(t.LineWidth >= 1.0, 'testIndustrialPreset: LineWidth');
    assert(size(t.LineColorOrder, 2) == 3, 'testIndustrialPreset: LineColorOrder Nx3');

    % testScientificPreset
    t = FastSenseTheme('scientific');
    assert(strcmp(t.FontName, 'Times New Roman'), 'testScientificPreset: FontName');
    assert(t.GridAlpha == 0, 'testScientificPreset: no grid');
    assert(t.LineWidth < 1.0, 'testScientificPreset: thin lines');
    assert(size(t.LineColorOrder, 2) == 3, 'testScientificPreset: LineColorOrder Nx3');

    % testStructAsPreset
    custom = struct('Background', [0 0 0], 'FontSize', 16);
    t = FastSenseTheme(custom);
    assert(isequal(t.Background, [0 0 0]), 'testStructAsPreset: Background');
    assert(t.FontSize == 16, 'testStructAsPreset: FontSize');
    assert(isfield(t, 'GridColor'), 'testStructAsPreset: inherits defaults');

    % testPaletteResolution
    t = FastSenseTheme('default');
    assert(size(t.LineColorOrder, 1) >= 6, 'testPaletteResolution: at least 6 colors');

    % testCustomPaletteMatrix
    customColors = [1 0 0; 0 1 0; 0 0 1];
    t = FastSenseTheme('default', 'LineColorOrder', customColors);
    assert(isequal(t.LineColorOrder, customColors), 'testCustomPaletteMatrix');
```

Update final fprintf to count correctly:

```matlab
    fprintf('    All 11 theme tests passed.\n');
```

**Step 2: Run test to verify it passes**

Run: `octave --no-gui --eval "addpath('.'); addpath('tests'); addpath('private'); test_theme;"`
Expected: PASS — All 11 theme tests passed (implementation already handles all presets).

**Step 3: Commit**

```bash
git add tests/test_theme.m
git commit -m "Add comprehensive theme preset and palette tests"
```

---

### Task 3: FastSense Theme Integration — Constructor & applyTheme

**Files:**
- Modify: `FastSense.m:12-54` (properties + constructor)
- Modify: `FastSense.m:161-328` (render method)
- Create: `tests/test_fastsense_theme.m`

**Step 1: Write the failing test**

Create `tests/test_fastsense_theme.m`:

```matlab
function test_fastsense_theme()
%TEST_FASTSENSE_THEME Tests for FastSense theme integration.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'private'));

    % testThemeConstructorString
    fp = FastSense('Theme', 'dark');
    assert(isstruct(fp.Theme), 'testThemeConstructorString: Theme must be struct');
    assert(all(fp.Theme.Background < [0.2 0.2 0.2]), 'testThemeConstructorString: dark bg');

    % testThemeConstructorStruct
    custom = struct('Background', [0.5 0.5 0.5]);
    fp = FastSense('Theme', custom);
    assert(isequal(fp.Theme.Background, [0.5 0.5 0.5]), 'testThemeConstructorStruct');
    assert(isfield(fp.Theme, 'FontSize'), 'testThemeConstructorStruct: inherits defaults');

    % testDefaultThemeWhenNoneSpecified
    fp = FastSense();
    assert(isstruct(fp.Theme), 'testDefaultTheme: must have theme');
    assert(isequal(fp.Theme.Background, [1 1 1]), 'testDefaultTheme: default bg');

    % testThemeAppliedOnRender
    fp = FastSense('Theme', 'dark');
    fp.addLine(1:100, rand(1,100));
    fp.render();
    bgColor = get(fp.hFigure, 'Color');
    assert(all(bgColor < [0.2 0.2 0.2]), 'testThemeAppliedOnRender: figure bg');
    axColor = get(fp.hAxes, 'Color');
    assert(all(axColor < [0.25 0.25 0.25]), 'testThemeAppliedOnRender: axes bg');
    close(fp.hFigure);

    % testThemeFontApplied
    fp = FastSense('Theme', 'scientific');
    fp.addLine(1:100, rand(1,100));
    fp.render();
    assert(strcmp(get(fp.hAxes, 'FontName'), 'Times New Roman'), 'testThemeFontApplied');
    close(fp.hFigure);

    % testThemeWithParentAxes
    fig = figure('Visible', 'off');
    ax = axes('Parent', fig);
    fp = FastSense('Parent', ax, 'Theme', 'dark');
    fp.addLine(1:100, rand(1,100));
    fp.render();
    axColor = get(ax, 'Color');
    assert(all(axColor < [0.25 0.25 0.25]), 'testThemeWithParentAxes: axes bg');
    close(fig);

    % testBackwardCompatNoTheme
    fp = FastSense();
    fp.addLine(1:100, rand(1,100));
    fp.render();
    assert(isgraphics(fp.hAxes), 'testBackwardCompatNoTheme');
    close(fp.hFigure);

    fprintf('    All 7 theme integration tests passed.\n');
end
```

**Step 2: Run test to verify it fails**

Run: `octave --no-gui --eval "addpath('.'); addpath('tests'); addpath('private'); test_fastsense_theme;"`
Expected: FAIL — `fp.Theme` property does not exist

**Step 3: Write implementation**

Modify `FastSense.m`:

Add to public properties (after line 14):
```matlab
        Theme      = []        % theme struct (from FastSenseTheme)
```

Add to private properties (after line 35):
```matlab
        ColorIndex = 0         % tracks auto color cycling position
```

Modify constructor (lines 45-54) to handle 'theme':
```matlab
        function obj = FastSense(varargin)
            for k = 1:2:numel(varargin)
                switch lower(varargin{k})
                    case 'parent'
                        obj.ParentAxes = varargin{k+1};
                    case 'linkgroup'
                        obj.LinkGroup = varargin{k+1};
                    case 'theme'
                        val = varargin{k+1};
                        if ischar(val) || isstruct(val)
                            obj.Theme = FastSenseTheme(val);
                        else
                            obj.Theme = val;
                        end
                end
            end
            % Default theme if none set
            if isempty(obj.Theme)
                obj.Theme = FastSenseTheme('default');
            end
        end
```

Add private method `applyTheme` to FastSense.m (in the `methods (Access = private)` block):
```matlab
        function applyTheme(obj)
            t = obj.Theme;

            % Figure background (only if we own the figure)
            if isempty(obj.ParentAxes)
                set(obj.hFigure, 'Color', t.Background);
            end

            % Axes
            set(obj.hAxes, 'Color', t.AxesColor);
            set(obj.hAxes, 'XColor', t.ForegroundColor);
            set(obj.hAxes, 'YColor', t.ForegroundColor);
            set(obj.hAxes, 'FontName', t.FontName);
            set(obj.hAxes, 'FontSize', t.FontSize);

            % Grid
            if strcmp(t.GridStyle, 'none') || t.GridAlpha == 0
                grid(obj.hAxes, 'off');
            else
                grid(obj.hAxes, 'on');
                set(obj.hAxes, 'GridColor', t.GridColor);
                set(obj.hAxes, 'GridAlpha', t.GridAlpha);
                set(obj.hAxes, 'GridLineStyle', t.GridStyle);
            end
        end
```

In `render()`, call `obj.applyTheme()` right after creating/assigning axes (after `hold(obj.hAxes, 'on')` at line 181):
```matlab
            obj.applyTheme();
```

**Step 4: Run test to verify it passes**

Run: `octave --no-gui --eval "addpath('.'); addpath('tests'); addpath('private'); test_fastsense_theme;"`
Expected: PASS — All 7 theme integration tests passed.

**Step 5: Run existing tests to verify backward compatibility**

Run: `octave --no-gui --eval "addpath('.'); addpath('tests'); addpath('private'); run_all_tests;"`
Expected: All existing tests pass.

**Step 6: Commit**

```bash
git add FastSense.m tests/test_fastsense_theme.m
git commit -m "Add theme support to FastSense constructor and render"
```

---

### Task 4: Auto Line Color Cycling

**Files:**
- Modify: `FastSense.m` (addLine method, lines 56-116)
- Modify: `tests/test_fastsense_theme.m`

**Step 1: Write the failing test**

Append to `tests/test_fastsense_theme.m` (before final fprintf):

```matlab
    % testAutoColorCycling
    fp = FastSense();
    fp.addLine(1:10, rand(1,10));
    fp.addLine(1:10, rand(1,10));
    fp.addLine(1:10, rand(1,10));
    c1 = fp.Lines(1).Options.Color;
    c2 = fp.Lines(2).Options.Color;
    c3 = fp.Lines(3).Options.Color;
    assert(~isequal(c1, c2), 'testAutoColorCycling: colors 1 and 2 differ');
    assert(~isequal(c2, c3), 'testAutoColorCycling: colors 2 and 3 differ');

    % testExplicitColorSkipsCycle
    fp = FastSense();
    fp.addLine(1:10, rand(1,10), 'Color', [1 0 0]);
    fp.addLine(1:10, rand(1,10));
    assert(isequal(fp.Lines(1).Options.Color, [1 0 0]), 'testExplicitColorSkipsCycle: explicit');
    expected2 = fp.Theme.LineColorOrder(1, :);
    assert(isequal(fp.Lines(2).Options.Color, expected2), 'testExplicitColorSkipsCycle: auto gets first');
```

Update test count in fprintf.

**Step 2: Run test to verify it fails**

Expected: FAIL — auto-assigned colors not present in Options

**Step 3: Write implementation**

Modify `addLine` in `FastSense.m`. After the name-value parsing loop (around line 100), before building the line struct, add:

```matlab
            % Auto-assign color from theme palette if not explicitly set
            if ~isfield(opts, 'Color')
                obj.ColorIndex = obj.ColorIndex + 1;
                palette = obj.Theme.LineColorOrder;
                idx = mod(obj.ColorIndex - 1, size(palette, 1)) + 1;
                opts.Color = palette(idx, :);
            end
```

**Step 4: Run test to verify it passes**

Run: `octave --no-gui --eval "addpath('.'); addpath('tests'); addpath('private'); test_fastsense_theme;"`
Expected: PASS

**Step 5: Run all tests**

Run: `octave --no-gui --eval "addpath('.'); addpath('tests'); addpath('private'); run_all_tests;"`
Expected: All pass.

**Step 6: Commit**

```bash
git add FastSense.m tests/test_fastsense_theme.m
git commit -m "Add auto line color cycling from theme palette"
```

---

### Task 5: addBand — Horizontal Band Fill

**Files:**
- Modify: `FastSense.m` (new property struct, addBand method, render updates)
- Create: `tests/test_add_band.m`

**Step 1: Write the failing test**

Create `tests/test_add_band.m`:

```matlab
function test_add_band()
%TEST_ADD_BAND Tests for FastSense.addBand method.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'private'));

    % testAddBand
    fp = FastSense();
    fp.addBand(-1, 1, 'FaceColor', [1 0.9 0.9], 'FaceAlpha', 0.3, 'Label', 'Safe');
    assert(numel(fp.Bands) == 1, 'testAddBand: count');
    assert(fp.Bands(1).YLow == -1, 'testAddBand: YLow');
    assert(fp.Bands(1).YHigh == 1, 'testAddBand: YHigh');
    assert(strcmp(fp.Bands(1).Label, 'Safe'), 'testAddBand: Label');

    % testAddMultipleBands
    fp = FastSense();
    fp.addBand(-2, -1);
    fp.addBand(1, 2);
    assert(numel(fp.Bands) == 2, 'testAddMultipleBands');

    % testBandRendered
    fp = FastSense();
    fp.addLine(1:100, rand(1,100));
    fp.addBand(0.2, 0.8, 'FaceColor', [0 1 0], 'FaceAlpha', 0.2);
    fp.render();
    assert(~isempty(fp.Bands(1).hPatch), 'testBandRendered: hPatch created');
    assert(ishandle(fp.Bands(1).hPatch), 'testBandRendered: hPatch valid');
    ud = get(fp.Bands(1).hPatch, 'UserData');
    assert(strcmp(ud.FastSense.Type, 'band'), 'testBandRendered: UserData type');
    close(fp.hFigure);

    % testBandRejectsAfterRender
    fp = FastSense();
    fp.addLine(1:100, rand(1,100));
    fp.render();
    threw = false;
    try
        fp.addBand(0, 1);
    catch
        threw = true;
    end
    assert(threw, 'testBandRejectsAfterRender');
    close(fp.hFigure);

    % testBandDefaults
    fp = FastSense();
    fp.addBand(0, 1);
    assert(fp.Bands(1).FaceAlpha > 0, 'testBandDefaults: FaceAlpha');
    assert(numel(fp.Bands(1).FaceColor) == 3, 'testBandDefaults: FaceColor');

    fprintf('    All 5 addBand tests passed.\n');
end
```

**Step 2: Run test to verify it fails**

Expected: FAIL — `addBand` method does not exist

**Step 3: Write implementation**

Add new property struct in `FastSense.m` properties (SetAccess = private), after the Thresholds line (around line 24):

```matlab
        Bands      = struct('YLow', {}, 'YHigh', {}, 'FaceColor', {}, ...
                            'FaceAlpha', {}, 'EdgeColor', {}, 'Label', {}, ...
                            'hPatch', {})
```

Add `addBand` method in the public methods block (after `addThreshold`):

```matlab
        function addBand(obj, yLow, yHigh, varargin)
            %ADDBAND Add a horizontal band fill (constant y bounds).
            %   fp.addBand(yLow, yHigh)
            %   fp.addBand(yLow, yHigh, 'FaceColor', [1 0.9 0.9], 'FaceAlpha', 0.3)

            if obj.IsRendered
                error('FastSense:alreadyRendered', ...
                    'Cannot add bands after render() has been called.');
            end

            b.YLow      = yLow;
            b.YHigh     = yHigh;
            b.FaceColor = obj.Theme.ThresholdColor;
            b.FaceAlpha = obj.Theme.BandAlpha;
            b.EdgeColor = 'none';
            b.Label     = '';
            b.hPatch    = [];

            for k = 1:2:numel(varargin)
                switch lower(varargin{k})
                    case 'facecolor'
                        b.FaceColor = varargin{k+1};
                    case 'facealpha'
                        b.FaceAlpha = varargin{k+1};
                    case 'edgecolor'
                        b.EdgeColor = varargin{k+1};
                    case 'label'
                        b.Label = varargin{k+1};
                end
            end

            if isempty(obj.Bands)
                obj.Bands = b;
            else
                obj.Bands(end+1) = b;
            end
        end
```

In `render()`, add band rendering right after `hold(obj.hAxes, 'on')` and `applyTheme()`, **before** the data lines loop. Insert this block:

```matlab
            % --- Render bands (back layer) ---
            for i = 1:numel(obj.Bands)
                B = obj.Bands(i);
                % Will set X vertices after computing xmin/xmax below
                % For now store index, patch created after X range known
            end
```

Actually, bands need the X range which is computed later. Better approach: render bands right after computing xmin/xmax (after the X range loop around line 232). Insert after computing xmin/xmax:

```matlab
            % --- Render bands (constant y, full x span) ---
            for i = 1:numel(obj.Bands)
                B = obj.Bands(i);
                patchX = [xmin, xmax, xmax, xmin];
                patchY = [B.YLow, B.YLow, B.YHigh, B.YHigh];
                hP = patch(patchX, patchY, B.FaceColor, ...
                    'Parent', obj.hAxes, ...
                    'FaceAlpha', B.FaceAlpha, ...
                    'EdgeColor', B.EdgeColor, ...
                    'HandleVisibility', 'off');
                udB.FastSense = struct( ...
                    'Type', 'band', ...
                    'Name', B.Label, ...
                    'LineIndex', [], ...
                    'ThresholdValue', []);
                set(hP, 'UserData', udB);
                obj.Bands(i).hPatch = hP;
                % Send to back
                uistack(hP, 'bottom');
            end
```

**Step 4: Run test to verify it passes**

Run: `octave --no-gui --eval "addpath('.'); addpath('tests'); addpath('private'); test_add_band;"`
Expected: PASS — All 5 addBand tests passed.

**Step 5: Run all tests**

Run: `octave --no-gui --eval "addpath('.'); addpath('tests'); addpath('private'); run_all_tests;"`
Expected: All pass.

**Step 6: Commit**

```bash
git add FastSense.m tests/test_add_band.m
git commit -m "Add addBand for horizontal band fills"
```

---

### Task 6: addMarker — Custom Event Markers

**Files:**
- Modify: `FastSense.m` (new Markers property, addMarker method, render)
- Create: `tests/test_add_marker.m`

**Step 1: Write the failing test**

Create `tests/test_add_marker.m`:

```matlab
function test_add_marker()
%TEST_ADD_MARKER Tests for FastSense.addMarker method.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'private'));

    % testAddMarker
    fp = FastSense();
    fp.addMarker([10 20 30], [1 2 3], 'Marker', 'v', 'Color', [1 0 0], 'Label', 'Faults');
    assert(numel(fp.Markers) == 1, 'testAddMarker: count');
    assert(isequal(fp.Markers(1).X, [10 20 30]), 'testAddMarker: X');
    assert(strcmp(fp.Markers(1).Label, 'Faults'), 'testAddMarker: Label');

    % testMarkerRendered
    fp = FastSense();
    fp.addLine(1:100, rand(1,100));
    fp.addMarker([10 50], [0.5 0.8], 'Marker', 'd', 'MarkerSize', 10);
    fp.render();
    assert(~isempty(fp.Markers(1).hLine), 'testMarkerRendered: hLine');
    assert(ishandle(fp.Markers(1).hLine), 'testMarkerRendered: valid handle');
    ud = get(fp.Markers(1).hLine, 'UserData');
    assert(strcmp(ud.FastSense.Type, 'marker'), 'testMarkerRendered: UserData type');
    close(fp.hFigure);

    % testMarkerDefaults
    fp = FastSense();
    fp.addMarker([5], [1]);
    assert(~isempty(fp.Markers(1).Marker), 'testMarkerDefaults: Marker shape');
    assert(fp.Markers(1).MarkerSize > 0, 'testMarkerDefaults: MarkerSize');

    % testMarkerRejectsAfterRender
    fp = FastSense();
    fp.addLine(1:10, rand(1,10));
    fp.render();
    threw = false;
    try
        fp.addMarker([1], [1]);
    catch
        threw = true;
    end
    assert(threw, 'testMarkerRejectsAfterRender');
    close(fp.hFigure);

    fprintf('    All 4 addMarker tests passed.\n');
end
```

**Step 2: Run test to verify it fails**

Expected: FAIL — `addMarker` does not exist

**Step 3: Write implementation**

Add Markers property struct (after Bands property):

```matlab
        Markers    = struct('X', {}, 'Y', {}, 'Marker', {}, ...
                            'MarkerSize', {}, 'Color', {}, 'Label', {}, ...
                            'hLine', {})
```

Add `addMarker` method (after `addBand`):

```matlab
        function addMarker(obj, x, y, varargin)
            %ADDMARKER Add custom event markers at specific positions.
            %   fp.addMarker(x, y)
            %   fp.addMarker(x, y, 'Marker', 'v', 'MarkerSize', 8, 'Color', [1 0 0])

            if obj.IsRendered
                error('FastSense:alreadyRendered', ...
                    'Cannot add markers after render() has been called.');
            end

            if ~isrow(x); x = x(:)'; end
            if ~isrow(y); y = y(:)'; end

            m.X          = x;
            m.Y          = y;
            m.Marker     = 'o';
            m.MarkerSize = 6;
            m.Color      = obj.Theme.ThresholdColor;
            m.Label      = '';
            m.hLine      = [];

            for k = 1:2:numel(varargin)
                switch lower(varargin{k})
                    case 'marker'
                        m.Marker = varargin{k+1};
                    case 'markersize'
                        m.MarkerSize = varargin{k+1};
                    case 'color'
                        m.Color = varargin{k+1};
                    case 'label'
                        m.Label = varargin{k+1};
                end
            end

            if isempty(obj.Markers)
                obj.Markers = m;
            else
                obj.Markers(end+1) = m;
            end
        end
```

In `render()`, add marker rendering after threshold/violation markers section (right before setting axis limits):

```matlab
            % --- Render custom markers (front layer) ---
            for i = 1:numel(obj.Markers)
                M = obj.Markers(i);
                hM = line(M.X, M.Y, 'Parent', obj.hAxes, ...
                    'LineStyle', 'none', ...
                    'Marker', M.Marker, ...
                    'MarkerSize', M.MarkerSize, ...
                    'Color', M.Color, ...
                    'HandleVisibility', 'off');
                udM.FastSense = struct( ...
                    'Type', 'marker', ...
                    'Name', M.Label, ...
                    'LineIndex', [], ...
                    'ThresholdValue', []);
                set(hM, 'UserData', udM);
                obj.Markers(i).hLine = hM;
            end
```

**Step 4: Run test to verify it passes**

Run: `octave --no-gui --eval "addpath('.'); addpath('tests'); addpath('private'); test_add_marker;"`
Expected: PASS

**Step 5: Run all tests**

Run: `octave --no-gui --eval "addpath('.'); addpath('tests'); addpath('private'); run_all_tests;"`
Expected: All pass.

**Step 6: Commit**

```bash
git add FastSense.m tests/test_add_marker.m
git commit -m "Add addMarker for custom event markers"
```

---

### Task 7: addShaded — Fill Between Two Curves

**Files:**
- Modify: `FastSense.m` (new Shaded property, addShaded method, render + zoom updates)
- Create: `tests/test_add_shaded.m`

**Step 1: Write the failing test**

Create `tests/test_add_shaded.m`:

```matlab
function test_add_shaded()
%TEST_ADD_SHADED Tests for FastSense.addShaded method.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'private'));

    % testAddShaded
    x = 1:100;
    y1 = ones(1,100) * 2;
    y2 = ones(1,100) * -2;
    fp = FastSense();
    fp.addShaded(x, y1, y2, 'FaceColor', [0 0 1], 'FaceAlpha', 0.2);
    assert(numel(fp.Shadings) == 1, 'testAddShaded: count');
    assert(isequal(fp.Shadings(1).X, x), 'testAddShaded: X');
    assert(isequal(fp.Shadings(1).Y1, y1), 'testAddShaded: Y1');
    assert(isequal(fp.Shadings(1).Y2, y2), 'testAddShaded: Y2');

    % testShadedRendered
    fp = FastSense();
    fp.addLine(1:100, rand(1,100));
    fp.addShaded(1:100, ones(1,100), zeros(1,100), 'FaceColor', [1 0 0]);
    fp.render();
    assert(~isempty(fp.Shadings(1).hPatch), 'testShadedRendered: hPatch');
    assert(ishandle(fp.Shadings(1).hPatch), 'testShadedRendered: valid');
    ud = get(fp.Shadings(1).hPatch, 'UserData');
    assert(strcmp(ud.FastSense.Type, 'shaded'), 'testShadedRendered: type');
    close(fp.hFigure);

    % testShadedValidation
    fp = FastSense();
    threw = false;
    try
        fp.addShaded(1:10, 1:10, 1:5);  % mismatched lengths
    catch
        threw = true;
    end
    assert(threw, 'testShadedValidation: length mismatch');

    % testShadedMonotonicX
    fp = FastSense();
    threw = false;
    try
        fp.addShaded([3 1 2], [1 1 1], [0 0 0]);
    catch
        threw = true;
    end
    assert(threw, 'testShadedMonotonicX');

    % testShadedRejectsAfterRender
    fp = FastSense();
    fp.addLine(1:10, rand(1,10));
    fp.render();
    threw = false;
    try
        fp.addShaded(1:10, ones(1,10), zeros(1,10));
    catch
        threw = true;
    end
    assert(threw, 'testShadedRejectsAfterRender');
    close(fp.hFigure);

    % testShadedColumnVectors
    fp = FastSense();
    fp.addShaded((1:10)', (1:10)', zeros(10,1));
    assert(isrow(fp.Shadings(1).X), 'testShadedColumnVectors: X row');
    assert(isrow(fp.Shadings(1).Y1), 'testShadedColumnVectors: Y1 row');
    assert(isrow(fp.Shadings(1).Y2), 'testShadedColumnVectors: Y2 row');

    fprintf('    All 6 addShaded tests passed.\n');
end
```

**Step 2: Run test to verify it fails**

Expected: FAIL — `addShaded` does not exist

**Step 3: Write implementation**

Add Shadings property (after Markers property):

```matlab
        Shadings   = struct('X', {}, 'Y1', {}, 'Y2', {}, ...
                            'FaceColor', {}, 'FaceAlpha', {}, ...
                            'EdgeColor', {}, 'DisplayName', {}, ...
                            'hPatch', {})
```

Add `addShaded` method (after `addMarker`):

```matlab
        function addShaded(obj, x, y1, y2, varargin)
            %ADDSHADED Add a shaded region between two curves.
            %   fp.addShaded(x, y_upper, y_lower)
            %   fp.addShaded(x, y1, y2, 'FaceColor', [0 0 1], 'FaceAlpha', 0.2)

            if obj.IsRendered
                error('FastSense:alreadyRendered', ...
                    'Cannot add shaded regions after render() has been called.');
            end

            if ~isrow(x); x = x(:)'; end
            if ~isrow(y1); y1 = y1(:)'; end
            if ~isrow(y2); y2 = y2(:)'; end

            if numel(x) ~= numel(y1) || numel(x) ~= numel(y2)
                error('FastSense:sizeMismatch', ...
                    'X, Y1, and Y2 must have the same number of elements.');
            end

            if numel(x) > 1
                dx = diff(x);
                if any(dx(~isnan(dx)) < 0)
                    error('FastSense:nonMonotonicX', ...
                        'X must be monotonically increasing.');
                end
            end

            s.X           = x;
            s.Y1          = y1;
            s.Y2          = y2;
            s.FaceColor   = [0 0.45 0.74];
            s.FaceAlpha   = 0.15;
            s.EdgeColor   = 'none';
            s.DisplayName = '';
            s.hPatch      = [];

            for k = 1:2:numel(varargin)
                switch lower(varargin{k})
                    case 'facecolor'
                        s.FaceColor = varargin{k+1};
                    case 'facealpha'
                        s.FaceAlpha = varargin{k+1};
                    case 'edgecolor'
                        s.EdgeColor = varargin{k+1};
                    case 'displayname'
                        s.DisplayName = varargin{k+1};
                end
            end

            if isempty(obj.Shadings)
                obj.Shadings = s;
            else
                obj.Shadings(end+1) = s;
            end
        end
```

In `render()`, add shading rendering after bands and before data lines:

```matlab
            % --- Render shaded regions ---
            for i = 1:numel(obj.Shadings)
                S = obj.Shadings(i);
                % Build patch vertices: y1 forward, y2 backward
                patchX = [S.X, fliplr(S.X)];
                patchY = [S.Y1, fliplr(S.Y2)];
                hP = patch(patchX, patchY, S.FaceColor, ...
                    'Parent', obj.hAxes, ...
                    'FaceAlpha', S.FaceAlpha, ...
                    'EdgeColor', S.EdgeColor, ...
                    'HandleVisibility', 'off');
                udS.FastSense = struct( ...
                    'Type', 'shaded', ...
                    'Name', S.DisplayName, ...
                    'LineIndex', [], ...
                    'ThresholdValue', []);
                set(hP, 'UserData', udS);
                obj.Shadings(i).hPatch = hP;
            end
```

In `updateLines()`, add shading updates. Add a new private method `updateShadings`:

```matlab
        function updateShadings(obj)
            pw = obj.PixelWidth;
            xlims = get(obj.hAxes, 'XLim');

            for i = 1:numel(obj.Shadings)
                S = obj.Shadings(i);
                if isempty(S.hPatch) || ~ishandle(S.hPatch)
                    continue;
                end

                nTotal = numel(S.X);
                idxStart = binary_search(S.X, xlims(1), 'left');
                idxEnd   = binary_search(S.X, xlims(2), 'right');
                idxStart = max(1, idxStart - 1);
                idxEnd   = min(nTotal, idxEnd + 1);
                nVis = idxEnd - idxStart + 1;

                xVis  = S.X(idxStart:idxEnd);
                y1Vis = S.Y1(idxStart:idxEnd);
                y2Vis = S.Y2(idxStart:idxEnd);

                if nVis > obj.MIN_POINTS_FOR_DOWNSAMPLE
                    [xd, y1d] = minmax_downsample(xVis, y1Vis, pw);
                    [~, y2d]  = minmax_downsample(xVis, y2Vis, pw);
                    patchX = [xd, fliplr(xd)];
                    patchY = [y1d, fliplr(y2d)];
                else
                    patchX = [xVis, fliplr(xVis)];
                    patchY = [y1Vis, fliplr(y2Vis)];
                end

                set(S.hPatch, 'XData', patchX, 'YData', patchY);
            end
        end
```

Call `obj.updateShadings()` from `onXLimChanged` (after `obj.updateLines()`) and from `onResize` (after `obj.updateLines()`).

**Step 4: Run test to verify it passes**

Run: `octave --no-gui --eval "addpath('.'); addpath('tests'); addpath('private'); test_add_shaded;"`
Expected: PASS

**Step 5: Run all tests**

Run: `octave --no-gui --eval "addpath('.'); addpath('tests'); addpath('private'); run_all_tests;"`
Expected: All pass.

**Step 6: Commit**

```bash
git add FastSense.m tests/test_add_shaded.m
git commit -m "Add addShaded for fill between two curves with zoom downsampling"
```

---

### Task 8: addFill — Area Fill to Baseline

**Files:**
- Modify: `FastSense.m` (addFill method)
- Modify: `tests/test_add_shaded.m`

**Step 1: Write the failing test**

Append to `tests/test_add_shaded.m` (before final fprintf):

```matlab
    % testAddFill
    fp = FastSense();
    x = 1:50;
    y = rand(1,50);
    fp.addFill(x, y, 'FaceColor', [0 0.5 1], 'FaceAlpha', 0.2);
    assert(numel(fp.Shadings) == 1, 'testAddFill: creates shading');
    assert(all(fp.Shadings(1).Y2 == 0), 'testAddFill: baseline is 0');

    % testAddFillCustomBaseline
    fp = FastSense();
    fp.addFill(1:10, rand(1,10), 'Baseline', -1);
    assert(all(fp.Shadings(1).Y2 == -1), 'testAddFillCustomBaseline');

    % testAddFillRendered
    fp = FastSense();
    fp.addLine(1:100, rand(1,100));
    fp.addFill(1:100, rand(1,100), 'FaceColor', [0 1 0]);
    fp.render();
    assert(ishandle(fp.Shadings(1).hPatch), 'testAddFillRendered: valid patch');
    ud = get(fp.Shadings(1).hPatch, 'UserData');
    assert(strcmp(ud.FastSense.Type, 'shaded'), 'testAddFillRendered: type is shaded');
    close(fp.hFigure);
```

Update fprintf count.

**Step 2: Run test to verify it fails**

Expected: FAIL — `addFill` does not exist

**Step 3: Write implementation**

Add `addFill` method (after `addShaded`):

```matlab
        function addFill(obj, x, y, varargin)
            %ADDFILL Add an area fill from a line to a baseline.
            %   fp.addFill(x, y)
            %   fp.addFill(x, y, 'Baseline', -1, 'FaceColor', [0 0.5 1])

            baseline = 0;
            filteredArgs = {};
            k = 1;
            while k <= numel(varargin)
                if strcmpi(varargin{k}, 'Baseline')
                    baseline = varargin{k+1};
                    k = k + 2;
                else
                    filteredArgs{end+1} = varargin{k};   %#ok<AGROW>
                    filteredArgs{end+1} = varargin{k+1};  %#ok<AGROW>
                    k = k + 2;
                end
            end

            if ~isrow(x); x = x(:)'; end
            if ~isrow(y); y = y(:)'; end
            y2 = ones(size(x)) * baseline;
            obj.addShaded(x, y, y2, filteredArgs{:});
        end
```

**Step 4: Run test to verify it passes**

Run: `octave --no-gui --eval "addpath('.'); addpath('tests'); addpath('private'); test_add_shaded;"`
Expected: PASS

**Step 5: Run all tests**

Expected: All pass.

**Step 6: Commit**

```bash
git add FastSense.m tests/test_add_shaded.m
git commit -m "Add addFill as sugar for addShaded with baseline"
```

---

### Task 9: Theme Defaults for Thresholds & Violations

**Files:**
- Modify: `FastSense.m` (addThreshold method, render)
- Modify: `tests/test_fastsense_theme.m`

**Step 1: Write the failing test**

Append to `tests/test_fastsense_theme.m`:

```matlab
    % testThresholdUsesThemeDefaults
    fp = FastSense('Theme', struct('ThresholdColor', [0 1 0], 'ThresholdStyle', ':'));
    fp.addThreshold(5.0);
    assert(isequal(fp.Thresholds(1).Color, [0 1 0]), 'testThresholdThemeDefaults: Color');
    assert(strcmp(fp.Thresholds(1).LineStyle, ':'), 'testThresholdThemeDefaults: Style');

    % testThresholdExplicitOverridesTheme
    fp = FastSense('Theme', struct('ThresholdColor', [0 1 0]));
    fp.addThreshold(5.0, 'Color', [1 0 0]);
    assert(isequal(fp.Thresholds(1).Color, [1 0 0]), 'testThresholdOverride: Color');
```

Update fprintf count.

**Step 2: Run test to verify it fails**

Expected: FAIL — threshold defaults are hardcoded, not from theme

**Step 3: Write implementation**

Modify `addThreshold` in `FastSense.m`. Change the defaults section (around line 132-133) to use theme:

```matlab
            t.Color          = obj.Theme.ThresholdColor;
            t.LineStyle      = obj.Theme.ThresholdStyle;
```

These theme values are set in the constructor, so they're always available before `addThreshold` is called.

**Step 4: Run test to verify it passes**

Run: `octave --no-gui --eval "addpath('.'); addpath('tests'); addpath('private'); test_fastsense_theme;"`
Expected: PASS

**Step 5: Run all tests**

Expected: All pass.

**Step 6: Commit**

```bash
git add FastSense.m tests/test_fastsense_theme.m
git commit -m "Use theme defaults for threshold color and style"
```

---

### Task 10: FastSenseFigure — Basic Grid Layout

**Files:**
- Create: `FastSenseFigure.m`
- Create: `tests/test_figure_layout.m`

**Step 1: Write the failing test**

Create `tests/test_figure_layout.m`:

```matlab
function test_figure_layout()
%TEST_FIGURE_LAYOUT Tests for FastSenseFigure layout manager.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'private'));

    % testConstruction
    fig = FastSenseFigure(2, 3);
    assert(isequal(fig.Grid, [2 3]), 'testConstruction: Grid');
    assert(~isempty(fig.hFigure), 'testConstruction: hFigure');
    assert(ishandle(fig.hFigure), 'testConstruction: hFigure valid');
    close(fig.hFigure);

    % testTileReturnsFastSense
    fig = FastSenseFigure(2, 1);
    fp = fig.tile(1);
    assert(isa(fp, 'FastSense'), 'testTileReturnsFastSense');
    close(fig.hFigure);

    % testTileLazy
    fig = FastSenseFigure(2, 1);
    fp1a = fig.tile(1);
    fp1b = fig.tile(1);
    assert(fp1a == fp1b, 'testTileLazy: same object on repeat call');
    close(fig.hFigure);

    % testTileCreatesAxes
    fig = FastSenseFigure(2, 1);
    fp = fig.tile(1);
    fp.addLine(1:100, rand(1,100));
    fp.render();
    assert(~isempty(fp.hAxes), 'testTileCreatesAxes: axes exist');
    assert(ishandle(fp.hAxes), 'testTileCreatesAxes: axes valid');
    close(fig.hFigure);

    % testMultipleTiles
    fig = FastSenseFigure(2, 2);
    for i = 1:4
        fp = fig.tile(i);
        fp.addLine(1:50, rand(1,50));
    end
    fig.renderAll();
    for i = 1:4
        fp = fig.tile(i);
        assert(fp.IsRendered, sprintf('testMultipleTiles: tile %d rendered', i));
    end
    close(fig.hFigure);

    % testRenderAllSkipsRendered
    fig = FastSenseFigure(2, 1);
    fp1 = fig.tile(1);
    fp1.addLine(1:10, rand(1,10));
    fp1.render();
    fp2 = fig.tile(2);
    fp2.addLine(1:10, rand(1,10));
    fig.renderAll();  % should not error on already-rendered tile 1
    assert(fp2.IsRendered, 'testRenderAllSkipsRendered: tile 2');
    close(fig.hFigure);

    % testOutOfBoundsTileErrors
    fig = FastSenseFigure(2, 2);
    threw = false;
    try
        fig.tile(5);  % only 4 tiles in 2x2
    catch
        threw = true;
    end
    assert(threw, 'testOutOfBoundsTileErrors');
    close(fig.hFigure);

    fprintf('    All 7 figure layout tests passed.\n');
end
```

**Step 2: Run test to verify it fails**

Expected: FAIL — `FastSenseFigure` does not exist

**Step 3: Write implementation**

Create `FastSenseFigure.m`:

```matlab
classdef FastSenseFigure < handle
    %FASTSENSEFIGURE Tiled layout manager for FastSense dashboards.
    %   fig = FastSenseFigure(rows, cols)
    %   fig = FastSenseFigure(rows, cols, 'Theme', 'dark')

    properties (Access = public)
        Grid       = [1 1]      % [rows, cols]
        Theme      = []         % FastSenseTheme struct
        hFigure    = []         % figure handle
    end

    properties (SetAccess = private)
        Tiles      = {}         % cell array of FastSense instances
        TileAxes   = {}         % cell array of axes handles
        TileSpans  = {}         % cell array of [rowSpan, colSpan]
        TileThemes = {}         % cell array of theme override structs
        IsRendered = false
    end

    properties (Constant, Access = private)
        PADDING = 0.06          % normalized padding around edges
        GAP_H   = 0.05          % horizontal gap between tiles
        GAP_V   = 0.07          % vertical gap between tiles
    end

    methods (Access = public)
        function obj = FastSenseFigure(rows, cols, varargin)
            obj.Grid = [rows, cols];
            nTiles = rows * cols;
            obj.Tiles     = cell(1, nTiles);
            obj.TileAxes  = cell(1, nTiles);
            obj.TileSpans = cell(1, nTiles);
            obj.TileThemes = cell(1, nTiles);

            % Default spans: each tile is 1x1
            for i = 1:nTiles
                obj.TileSpans{i} = [1 1];
            end

            % Parse options
            figOpts = {};
            for k = 1:2:numel(varargin)
                switch lower(varargin{k})
                    case 'theme'
                        val = varargin{k+1};
                        if ischar(val) || isstruct(val)
                            obj.Theme = FastSenseTheme(val);
                        else
                            obj.Theme = val;
                        end
                    otherwise
                        figOpts{end+1} = varargin{k};   %#ok<AGROW>
                        figOpts{end+1} = varargin{k+1};  %#ok<AGROW>
                end
            end

            if isempty(obj.Theme)
                obj.Theme = FastSenseTheme('default');
            end

            obj.hFigure = figure('Visible', 'off', ...
                'Color', obj.Theme.Background, figOpts{:});
        end

        function fp = tile(obj, n)
            %TILE Get or create the FastSense instance for tile n.
            nTiles = obj.Grid(1) * obj.Grid(2);
            if n < 1 || n > nTiles
                error('FastSenseFigure:outOfBounds', ...
                    'Tile %d is out of range (1-%d).', n, nTiles);
            end

            if isempty(obj.Tiles{n})
                ax = obj.createTileAxes(n);
                obj.TileAxes{n} = ax;

                % Merge figure theme with tile-level overrides
                tileTheme = obj.Theme;
                if ~isempty(obj.TileThemes{n})
                    fnames = fieldnames(obj.TileThemes{n});
                    for i = 1:numel(fnames)
                        tileTheme.(fnames{i}) = obj.TileThemes{n}.(fnames{i});
                    end
                end

                fp = FastSense('Parent', ax, 'Theme', tileTheme);
                obj.Tiles{n} = fp;
            else
                fp = obj.Tiles{n};
            end
        end

        function setTileSpan(obj, n, span)
            %SETTILESPAN Set the row/column span for tile n.
            %   fig.setTileSpan(1, [2 1])  — tile 1 spans 2 rows, 1 col
            nTiles = obj.Grid(1) * obj.Grid(2);
            if n < 1 || n > nTiles
                error('FastSenseFigure:outOfBounds', ...
                    'Tile %d is out of range (1-%d).', n, nTiles);
            end
            obj.TileSpans{n} = span;

            % Recompute axes position if already created
            if ~isempty(obj.TileAxes{n})
                pos = obj.computeTilePosition(n);
                set(obj.TileAxes{n}, 'Position', pos);
            end
        end

        function setTileTheme(obj, n, themeOverrides)
            %SETTILETHEME Set per-tile theme overrides.
            nTiles = obj.Grid(1) * obj.Grid(2);
            if n < 1 || n > nTiles
                error('FastSenseFigure:outOfBounds', ...
                    'Tile %d is out of range (1-%d).', n, nTiles);
            end
            obj.TileThemes{n} = themeOverrides;
        end

        function tileTitle(obj, n, str)
            %TILETITLE Set title for tile n.
            fp = obj.tile(n);
            if ~isempty(fp.hAxes) && ishandle(fp.hAxes)
                title(fp.hAxes, str, 'FontSize', obj.Theme.TitleFontSize, ...
                    'Color', obj.Theme.ForegroundColor);
            end
        end

        function tileXLabel(obj, n, str)
            %TILEXLABEL Set xlabel for tile n.
            fp = obj.tile(n);
            if ~isempty(fp.hAxes) && ishandle(fp.hAxes)
                xlabel(fp.hAxes, str, 'Color', obj.Theme.ForegroundColor);
            end
        end

        function tileYLabel(obj, n, str)
            %TILEYLABEL Set ylabel for tile n.
            fp = obj.tile(n);
            if ~isempty(fp.hAxes) && ishandle(fp.hAxes)
                ylabel(fp.hAxes, str, 'Color', obj.Theme.ForegroundColor);
            end
        end

        function renderAll(obj)
            %RENDERALL Render all tiles that haven't been rendered yet.
            for i = 1:numel(obj.Tiles)
                if ~isempty(obj.Tiles{i}) && ~obj.Tiles{i}.IsRendered
                    obj.Tiles{i}.render();
                end
            end
            set(obj.hFigure, 'Visible', 'on');
            drawnow;
        end

        function render(obj)
            %RENDER Alias for renderAll.
            obj.renderAll();
        end
    end

    methods (Access = private)
        function ax = createTileAxes(obj, n)
            pos = obj.computeTilePosition(n);
            ax = axes('Parent', obj.hFigure, 'Position', pos);
        end

        function pos = computeTilePosition(obj, n)
            rows = obj.Grid(1);
            cols = obj.Grid(2);
            span = obj.TileSpans{n};
            rowSpan = span(1);
            colSpan = span(2);

            % Convert tile index to row, col (1-based, top-left origin)
            row = ceil(n / cols);
            col = mod(n - 1, cols) + 1;

            pad = obj.PADDING;
            gapH = obj.GAP_H;
            gapV = obj.GAP_V;

            % Available space after padding
            totalW = 1 - 2*pad;
            totalH = 1 - 2*pad;

            % Cell dimensions
            cellW = (totalW - (cols-1)*gapH) / cols;
            cellH = (totalH - (rows-1)*gapV) / rows;

            % Position (bottom-left origin for MATLAB)
            x = pad + (col-1) * (cellW + gapH);
            y = 1 - pad - row * cellH - (row-1) * gapV;

            % Apply span
            w = colSpan * cellW + (colSpan-1) * gapH;
            h = rowSpan * cellH + (rowSpan-1) * gapV;

            pos = [x, y, w, h];
        end
    end
end
```

**Step 4: Run test to verify it passes**

Run: `octave --no-gui --eval "addpath('.'); addpath('tests'); addpath('private'); test_figure_layout;"`
Expected: PASS — All 7 figure layout tests passed.

**Step 5: Run all tests**

Expected: All pass.

**Step 6: Commit**

```bash
git add FastSenseFigure.m tests/test_figure_layout.m
git commit -m "Add FastSenseFigure with tiled grid layout and lazy tile creation"
```

---

### Task 11: FastSenseFigure — Tile Spanning & Theme Inheritance

**Files:**
- Modify: `tests/test_figure_layout.m`

**Step 1: Write the failing tests**

Append to `tests/test_figure_layout.m` (before final fprintf):

```matlab
    % testTileSpanning
    fig = FastSenseFigure(2, 2);
    fig.setTileSpan(1, [1 2]);  % tile 1 spans both columns
    fp1 = fig.tile(1);
    fp1.addLine(1:50, rand(1,50));
    fp1.render();
    pos = get(fp1.hAxes, 'Position');
    % Spanning tile should be wider than half the figure
    assert(pos(3) > 0.4, 'testTileSpanning: wide enough');
    close(fig.hFigure);

    % testFigureThemePassedToTiles
    fig = FastSenseFigure(2, 1, 'Theme', 'dark');
    fp = fig.tile(1);
    assert(all(fp.Theme.Background < [0.2 0.2 0.2]), 'testFigureThemePassedToTiles');
    close(fig.hFigure);

    % testTileThemeOverride
    fig = FastSenseFigure(2, 1, 'Theme', 'dark');
    fig.setTileTheme(1, struct('AxesColor', [0.3 0 0]));
    fp = fig.tile(1);
    assert(isequal(fp.Theme.AxesColor, [0.3 0 0]), 'testTileThemeOverride: AxesColor');
    assert(all(fp.Theme.Background < [0.2 0.2 0.2]), 'testTileThemeOverride: inherits bg');
    close(fig.hFigure);

    % testFigureProperties
    fig = FastSenseFigure(1, 1, 'Name', 'MyDash', 'Position', [50 50 800 600]);
    name = get(fig.hFigure, 'Name');
    assert(strcmp(name, 'MyDash'), 'testFigureProperties: Name');
    close(fig.hFigure);

    % testTileLabels
    fig = FastSenseFigure(2, 1);
    fp = fig.tile(1);
    fp.addLine(1:50, rand(1,50));
    fp.render();
    fig.tileTitle(1, 'My Title');
    fig.tileYLabel(1, 'Y Axis');
    fig.tileXLabel(1, 'X Axis');
    % No error = pass
    close(fig.hFigure);
```

Update fprintf count.

**Step 2: Run tests**

Run: `octave --no-gui --eval "addpath('.'); addpath('tests'); addpath('private'); test_figure_layout;"`
Expected: PASS (implementation already handles spanning and theme inheritance).

**Step 3: Commit**

```bash
git add tests/test_figure_layout.m
git commit -m "Add tests for tile spanning, theme inheritance, and labels"
```

---

### Task 12: Integration — Run Full Test Suite & Fix Issues

**Files:**
- All files from Tasks 1-11

**Step 1: Run full test suite**

Run: `octave --no-gui --eval "addpath('.'); addpath('tests'); addpath('private'); run_all_tests;"`
Expected: All tests pass including the new test files.

**Step 2: Fix any failures**

If any tests fail, debug and fix. Common issues:
- Octave compatibility: `isgraphics` vs `ishandle`, `GridAlpha` property availability
- Property access: `SetAccess = private` vs `Access = public` for `Theme`
- Struct field ordering in comparisons

**Step 3: Commit fixes if needed**

```bash
git add -A
git commit -m "Fix integration issues from full test suite"
```

---

### Task 13: Example — Dashboard Demo

**Files:**
- Create: `examples/example_dashboard.m`

**Step 1: Write the example**

Create `examples/example_dashboard.m`:

```matlab
%% FastSense Dashboard — Tiled layout with themes and visual enhancements
% Demonstrates FastSenseFigure, theming, bands, shading, and markers

addpath(fullfile(fileparts(mfilename('fullpath')), '..'));

n = 1e6;
x = linspace(0, 300, n);

fprintf('Dashboard example: 4 tiles, %d points each, dark theme...\n', n);
tic;

fig = FastSenseFigure(2, 2, 'Theme', 'dark', ...
    'Name', 'FastSense Dashboard Demo', 'Position', [50 50 1400 800]);

% --- Tile 1: Temperature with alarm bands (spans 2 columns) ---
fig.setTileSpan(1, [1 2]);
fp1 = fig.tile(1);
y_temp = 75 + 8*sin(x*2*pi/60) + 2*randn(1,n);
fp1.addBand(85, 95, 'FaceColor', [1 0.3 0.3], 'FaceAlpha', 0.15, 'Label', 'High Alarm');
fp1.addBand(55, 65, 'FaceColor', [0.3 0.3 1], 'FaceAlpha', 0.15, 'Label', 'Low Alarm');
fp1.addLine(x, y_temp, 'DisplayName', 'Temperature');
fp1.addThreshold(90, 'Direction', 'upper', 'ShowViolations', true);
fp1.addThreshold(60, 'Direction', 'lower', 'ShowViolations', true);

% --- Tile 3: Pressure with confidence band ---
fp3 = fig.tile(3);
y_press = 100 + 15*sin(x*2*pi/120) + 5*randn(1,n);
y_upper = 100 + 15*sin(x*2*pi/120) + 10;
y_lower = 100 + 15*sin(x*2*pi/120) - 10;
fp3.addShaded(x, y_upper, y_lower, 'FaceColor', [0.3 0.7 1], 'FaceAlpha', 0.15);
fp3.addLine(x, y_press, 'DisplayName', 'Pressure');

% --- Tile 4: Vibration with event markers ---
fp4 = fig.tile(4);
y_vib = 0.5*randn(1,n);
fault_times = [50 150 250];
for ft = fault_times
    idx = round(ft*n/300):min(round((ft+3)*n/300), n);
    y_vib(idx) = y_vib(idx) + 3*randn(1, numel(idx));
end
fp4.addLine(x, y_vib, 'DisplayName', 'Vibration');
fp4.addMarker(fault_times, [3 3 3], 'Marker', 'v', 'MarkerSize', 10, ...
    'Color', [1 0.3 0.3], 'Label', 'Fault');
fp4.addThreshold(2.5, 'Direction', 'upper', 'ShowViolations', true);

fig.renderAll();

fig.tileTitle(1, 'Temperature (C)');
fig.tileTitle(3, 'Pressure (bar)');
fig.tileTitle(4, 'Vibration (mm/s)');
fig.tileXLabel(3, 'Time (s)');
fig.tileXLabel(4, 'Time (s)');

fprintf('Dashboard rendered in %.3f seconds.\n', toc);
```

**Step 2: Run the example**

Run: `octave --no-gui --eval "addpath('.'); addpath('private'); addpath('examples'); example_dashboard;"`
Expected: Renders without error, prints timing.

**Step 3: Commit**

```bash
git add examples/example_dashboard.m
git commit -m "Add dashboard example with tiled layout, bands, shading, and markers"
```

---

### Task 14: Example — Theme Comparison

**Files:**
- Create: `examples/example_themes.m`

**Step 1: Write the example**

Create `examples/example_themes.m`:

```matlab
%% FastSense Theme Comparison — All 5 built-in themes side by side
% Opens one figure per theme to compare visual styles

addpath(fullfile(fileparts(mfilename('fullpath')), '..'));

n = 1e5;
x = linspace(0, 50, n);
y1 = sin(x*2*pi/10) + 0.2*randn(1,n);
y2 = cos(x*2*pi/8) + 0.3*randn(1,n);
y3 = 0.5*sin(x*2*pi/5) + 0.15*randn(1,n);

themes = {'default', 'dark', 'light', 'industrial', 'scientific'};

for i = 1:numel(themes)
    themeName = themes{i};
    fp = FastSense('Theme', themeName);
    fp.addLine(x, y1, 'DisplayName', 'Signal A');
    fp.addLine(x, y2, 'DisplayName', 'Signal B');
    fp.addLine(x, y3, 'DisplayName', 'Signal C');
    fp.addBand(-0.5, 0.5, 'FaceColor', [0.5 0.5 0.5], 'FaceAlpha', 0.1);
    fp.addThreshold(1.2, 'Direction', 'upper', 'ShowViolations', true);
    fp.render();
    title(fp.hAxes, sprintf('Theme: %s', themeName));
end

fprintf('All 5 themes rendered. Compare the styles!\n');
```

**Step 2: Run the example**

Run: `octave --no-gui --eval "addpath('.'); addpath('private'); addpath('examples'); example_themes;"`
Expected: Renders 5 figures without error.

**Step 3: Commit**

```bash
git add examples/example_themes.m
git commit -m "Add theme comparison example showing all 5 presets"
```

---

### Task 15: Update README

**Files:**
- Modify: `README.md`

**Step 1: Update README**

Add sections for:
- FastSenseFigure (tiled layouts with spanning)
- Theming system (5 presets, custom themes, color palettes)
- New visual methods (addShaded, addBand, addFill, addMarker)
- Updated example table with new examples
- Updated architecture diagram

Key additions to the API Reference section:

```markdown
### `FastSenseFigure(rows, cols, ...)` -- Dashboard Layout

### `FastSenseTheme(preset, ...)` -- Theme Presets

### `addShaded(x, y1, y2, ...)` -- Fill Between Curves

### `addBand(yLow, yHigh, ...)` -- Horizontal Band Fill

### `addFill(x, y, ...)` -- Area Fill to Baseline

### `addMarker(x, y, ...)` -- Custom Event Markers
```

**Step 2: Verify README renders correctly**

Review markdown formatting.

**Step 3: Commit**

```bash
git add README.md
git commit -m "Update README with dashboard layouts, theming, and visual enhancements"
```
