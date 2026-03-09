# Configuration Management Overhaul Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace duplicated varargin parsing with a shared helper, add persistent user defaults via a .m file, make performance constants configurable, warn on unknown option keys, and add resetColorIndex/reapplyTheme methods.

**Architecture:** New `FastPlotDefaults.m` function returns a config struct. Private `getDefaults.m` caches it with `persistent`. Private `parseOpts.m` replaces all inline for-loops. All classes load defaults from the cache at construction time.

**Tech Stack:** MATLAB (no external dependencies, no JSON, no inputParser)

---

### Task 1: Create `private/parseOpts.m` — the shared varargin parser

**Files:**
- Create: `private/parseOpts.m`
- Test: `tests/test_parse_opts.m`

**Step 1: Write the test file**

```matlab
function test_parse_opts()
%TEST_PARSE_OPTS Tests for the shared parseOpts helper.

    add_private_path();

    % testBasicParsing — known keys are parsed correctly
    defaults.Color = [1 0 0];
    defaults.Label = '';
    [opts, unmatched] = parseOpts(defaults, {'Color', [0 1 0], 'Label', 'test'});
    assert(isequal(opts.Color, [0 1 0]), 'testBasicParsing: Color');
    assert(strcmp(opts.Label, 'test'), 'testBasicParsing: Label');
    assert(isempty(fieldnames(unmatched)), 'testBasicParsing: no unmatched');

    % testDefaultsApplied — missing keys keep defaults
    defaults.Color = [1 0 0];
    defaults.Label = 'default';
    [opts, ~] = parseOpts(defaults, {});
    assert(isequal(opts.Color, [1 0 0]), 'testDefaultsApplied: Color');
    assert(strcmp(opts.Label, 'default'), 'testDefaultsApplied: Label');

    % testCaseInsensitive — keys are matched case-insensitively
    defaults.FaceColor = [1 0 0];
    [opts, ~] = parseOpts(defaults, {'facecolor', [0 0 1]});
    assert(isequal(opts.FaceColor, [0 0 1]), 'testCaseInsensitive');

    % testUnmatchedKeysReturned — unknown keys go to unmatched
    defaults.Color = [1 0 0];
    [opts, unmatched] = parseOpts(defaults, {'Color', [0 1 0], 'DisplayName', 'foo'});
    assert(isequal(opts.Color, [0 1 0]), 'testUnmatched: known key');
    assert(isfield(unmatched, 'DisplayName'), 'testUnmatched: unknown key returned');
    assert(strcmp(unmatched.DisplayName, 'foo'), 'testUnmatched: unknown value');

    % testVerboseWarning — warns on unknown keys when verbose is true
    defaults.Color = [1 0 0];
    lastwarn('');
    [~, ~] = parseOpts(defaults, {'Colr', [0 1 0]}, true);
    [warnMsg, ~] = lastwarn();
    assert(~isempty(warnMsg), 'testVerboseWarning: should warn on unknown key');
    assert(contains(warnMsg, 'Colr'), 'testVerboseWarning: mentions bad key');

    % testNoWarningWhenNotVerbose — silent on unknown keys by default
    defaults.Color = [1 0 0];
    lastwarn('');
    [~, ~] = parseOpts(defaults, {'Colr', [0 1 0]});
    [warnMsg, ~] = lastwarn();
    assert(isempty(warnMsg), 'testNoWarning: should not warn');

    % testEmptyVarargin — handles empty args
    defaults.Color = [1 0 0];
    [opts, unmatched] = parseOpts(defaults, {});
    assert(isequal(opts.Color, [1 0 0]), 'testEmptyVarargin');
    assert(isempty(fieldnames(unmatched)), 'testEmptyVarargin: no unmatched');

    % testMultipleUnmatchedKeys — multiple unknown keys
    defaults.Color = [1 0 0];
    [~, unmatched] = parseOpts(defaults, {'LineWidth', 2, 'DisplayName', 'foo'});
    assert(isfield(unmatched, 'LineWidth'), 'testMultiUnmatched: LineWidth');
    assert(isfield(unmatched, 'DisplayName'), 'testMultiUnmatched: DisplayName');

    fprintf('    All 8 parseOpts tests passed.\n');
end
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "cd tests; test_parse_opts"`
Expected: FAIL — `parseOpts` not found

**Step 3: Write the implementation**

```matlab
function [opts, unmatched] = parseOpts(defaults, args, verbose)
%PARSEOPTS Parse name-value pairs against a defaults struct.
%   [opts, unmatched] = parseOpts(defaults, args)
%   [opts, unmatched] = parseOpts(defaults, args, verbose)
%
%   defaults  — struct with field names as valid keys and their default values
%   args      — cell array of name-value pairs (typically varargin)
%   verbose   — (optional) logical, warn on unknown keys (default: false)
%
%   opts      — struct with defaults overridden by matched args
%   unmatched — struct of key-value pairs that didn't match any default field

    if nargin < 3; verbose = false; end

    opts = defaults;
    unmatched = struct();

    % Pre-compute lowercase field names for case-insensitive matching
    fnames = fieldnames(defaults);
    fnamesLower = lower(fnames);

    for k = 1:2:numel(args)
        key = args{k};
        val = args{k+1};
        keyLower = lower(key);

        idx = find(strcmp(fnamesLower, keyLower), 1);
        if ~isempty(idx)
            opts.(fnames{idx}) = val;
        else
            unmatched.(key) = val;
            if verbose
                warning('FastPlot:unknownOption', ...
                    'Unknown option ''%s''. Valid options: %s', ...
                    key, strjoin(fnames, ', '));
            end
        end
    end
end
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "cd tests; test_parse_opts"`
Expected: PASS — "All 8 parseOpts tests passed."

**Step 5: Commit**

```bash
git add private/parseOpts.m tests/test_parse_opts.m
git commit -m "feat: add shared parseOpts helper for name-value parsing"
```

---

### Task 2: Create `FastPlotDefaults.m` and `private/getDefaults.m`

**Files:**
- Create: `FastPlotDefaults.m`
- Create: `private/getDefaults.m`
- Test: `tests/test_defaults.m`

**Step 1: Write the test file**

```matlab
function test_defaults()
%TEST_DEFAULTS Tests for FastPlotDefaults and getDefaults caching.

    add_private_path();

    % testDefaultsReturnsStruct
    cfg = FastPlotDefaults();
    assert(isstruct(cfg), 'testDefaults: must return struct');

    % testDefaultsHasRequiredFields
    cfg = FastPlotDefaults();
    assert(isfield(cfg, 'Theme'), 'testDefaults: Theme field');
    assert(isfield(cfg, 'Verbose'), 'testDefaults: Verbose field');
    assert(isfield(cfg, 'MinPointsForDownsample'), 'testDefaults: MinPointsForDownsample');
    assert(isfield(cfg, 'DownsampleFactor'), 'testDefaults: DownsampleFactor');
    assert(isfield(cfg, 'PyramidReduction'), 'testDefaults: PyramidReduction');
    assert(isfield(cfg, 'DefaultDownsampleMethod'), 'testDefaults: DefaultDownsampleMethod');
    assert(isfield(cfg, 'DashboardPadding'), 'testDefaults: DashboardPadding');
    assert(isfield(cfg, 'DashboardGapH'), 'testDefaults: DashboardGapH');
    assert(isfield(cfg, 'DashboardGapV'), 'testDefaults: DashboardGapV');
    assert(isfield(cfg, 'TabBarHeight'), 'testDefaults: TabBarHeight');

    % testDefaultValues — verify shipped defaults match current hard-coded values
    cfg = FastPlotDefaults();
    assert(isequal(cfg.Theme, 'default'), 'testDefaultValues: Theme');
    assert(cfg.Verbose == false, 'testDefaultValues: Verbose');
    assert(cfg.MinPointsForDownsample == 5000, 'testDefaultValues: MinPointsForDownsample');
    assert(cfg.DownsampleFactor == 2, 'testDefaultValues: DownsampleFactor');
    assert(cfg.PyramidReduction == 100, 'testDefaultValues: PyramidReduction');
    assert(strcmp(cfg.DefaultDownsampleMethod, 'minmax'), 'testDefaultValues: DefaultDownsampleMethod');
    assert(cfg.DashboardPadding == 0.06, 'testDefaultValues: DashboardPadding');
    assert(cfg.DashboardGapH == 0.05, 'testDefaultValues: DashboardGapH');
    assert(cfg.DashboardGapV == 0.07, 'testDefaultValues: DashboardGapV');
    assert(cfg.TabBarHeight == 0.03, 'testDefaultValues: TabBarHeight');

    % testGetDefaultsReturnsSameStruct
    cfg1 = getDefaults();
    cfg2 = getDefaults();
    assert(isequal(cfg1, cfg2), 'testGetDefaults: cached values identical');

    % testClearDefaultsCache — after clearing, getDefaults still returns valid struct
    clearDefaultsCache();
    cfg3 = getDefaults();
    assert(isstruct(cfg3), 'testClearCache: still returns struct');
    assert(isfield(cfg3, 'Theme'), 'testClearCache: still has Theme');

    fprintf('    All 5 defaults tests passed.\n');
end
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "cd tests; test_defaults"`
Expected: FAIL — `FastPlotDefaults` not found

**Step 3: Write `FastPlotDefaults.m`**

```matlab
function cfg = FastPlotDefaults()
%FASTPLOTDEFAULTS User-editable default settings for FastPlot.
%   Edit this file to change global defaults for all FastPlot instances.
%   These values are loaded once per MATLAB session and cached.
%   Call clearDefaultsCache() to force a reload after editing.
%
%   Example: change default theme to dark and increase font size:
%       cfg.Theme = 'dark';
%       cfg.FontSize = 14;   (set in the theme, not here)

    % --- Theme ---
    cfg.Theme = 'default';              % preset name or struct
    cfg.Verbose = false;                % print diagnostics

    % --- Performance Tuning ---
    cfg.MinPointsForDownsample = 5000;  % below this, plot raw data
    cfg.DownsampleFactor = 2;           % points per pixel (min + max)
    cfg.PyramidReduction = 100;         % compression factor per pyramid level

    % --- Line Defaults ---
    cfg.DefaultDownsampleMethod = 'minmax';  % 'minmax' or 'lttb'

    % --- Dashboard Layout (normalized units) ---
    cfg.DashboardPadding = 0.06;        % padding around figure edges
    cfg.DashboardGapH = 0.05;           % horizontal gap between tiles
    cfg.DashboardGapV = 0.07;           % vertical gap between tiles

    % --- Dock Layout ---
    cfg.TabBarHeight = 0.03;            % normalized height of tab bar
end
```

**Step 4: Write `private/getDefaults.m`**

```matlab
function cfg = getDefaults()
%GETDEFAULTS Return cached FastPlotDefaults struct.
%   Uses a persistent variable so FastPlotDefaults() is called only once
%   per MATLAB session. Call clearDefaultsCache() to force a reload.

    persistent cachedCfg;
    if isempty(cachedCfg)
        cachedCfg = FastPlotDefaults();
    end
    cfg = cachedCfg;
end
```

**Step 5: Write `private/clearDefaultsCache.m`**

```matlab
function clearDefaultsCache()
%CLEARDEFAULTSCACHE Force getDefaults to reload FastPlotDefaults on next call.
%   Use after editing FastPlotDefaults.m during a session.

    clear getDefaults;
end
```

**Step 6: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "cd tests; test_defaults"`
Expected: PASS — "All 5 defaults tests passed."

**Step 7: Commit**

```bash
git add FastPlotDefaults.m private/getDefaults.m private/clearDefaultsCache.m tests/test_defaults.m
git commit -m "feat: add FastPlotDefaults and cached getDefaults loader"
```

---

### Task 3: Integrate into `FastPlot.m` — constructor, constants, parseOpts, new methods

**Files:**
- Modify: `FastPlot.m:68-72` (remove Constant properties)
- Modify: `FastPlot.m:75-97` (constructor — load defaults, use parseOpts)
- Modify: `FastPlot.m:130-152` (addLine — use parseOpts)
- Modify: `FastPlot.m:198-238` (addThreshold — use parseOpts)
- Modify: `FastPlot.m:241-276` (addBand — use parseOpts)
- Modify: `FastPlot.m:279-317` (addMarker — use parseOpts)
- Modify: `FastPlot.m:320-377` (addShaded — use parseOpts)
- Modify: `FastPlot.m:962-994` (startLive — use parseOpts)
- Modify: `FastPlot.m:917-934` (updateLine varargin parsing — use parseOpts)
- Add: `resetColorIndex()` method
- Add: `reapplyTheme()` method
- Add: `clearDefaultsCache()` static method
- Test: `tests/test_config_integration.m`

**Step 1: Write the integration test file**

```matlab
function test_config_integration()
%TEST_CONFIG_INTEGRATION Tests for config management integration in FastPlot.

    add_private_path();

    % testConstructorLoadsDefaults
    fp = FastPlot();
    assert(fp.MinPointsForDownsample == 5000, 'testConstructorDefaults: MinPointsForDownsample');
    assert(fp.DownsampleFactor == 2, 'testConstructorDefaults: DownsampleFactor');
    assert(fp.PyramidReduction == 100, 'testConstructorDefaults: PyramidReduction');

    % testConstructorOverrideConstants
    fp = FastPlot('MinPointsForDownsample', 10000, 'DownsampleFactor', 4);
    assert(fp.MinPointsForDownsample == 10000, 'testOverrideConstants: MinPointsForDownsample');
    assert(fp.DownsampleFactor == 4, 'testOverrideConstants: DownsampleFactor');

    % testResetColorIndex
    fp = FastPlot();
    fp.addLine(1:10, rand(1,10));
    fp.addLine(1:10, rand(1,10));
    c2 = fp.Lines(2).Options.Color;
    fp.resetColorIndex();
    fp.addLine(1:10, rand(1,10));
    c3 = fp.Lines(3).Options.Color;
    % After reset, next color should be the first palette color again
    expected = fp.Theme.LineColorOrder(1, :);
    assert(isequal(c3, expected), 'testResetColorIndex: color resets to first');

    % testReapplyTheme
    fp = FastPlot('Theme', 'default');
    fp.addLine(1:100, rand(1,100));
    fp.render();
    fp.Theme = FastPlotTheme('dark');
    fp.reapplyTheme();
    bgColor = get(fp.hFigure, 'Color');
    assert(all(bgColor < [0.2 0.2 0.2]), 'testReapplyTheme: figure bg updated to dark');
    axColor = get(fp.hAxes, 'Color');
    assert(all(axColor < [0.25 0.25 0.25]), 'testReapplyTheme: axes bg updated to dark');
    close(fp.hFigure);

    % testReapplyThemeBeforeRender — should not error
    fp = FastPlot('Theme', 'default');
    fp.Theme = FastPlotTheme('dark');
    fp.reapplyTheme();  % no-op before render, should not error

    % testVerboseWarnsOnUnknownKey
    lastwarn('');
    fp = FastPlot('Verbose', true);
    fp.addThreshold(5.0, 'Colr', [1 0 0]);
    [warnMsg, ~] = lastwarn();
    assert(~isempty(warnMsg), 'testVerboseWarning: should warn on Colr');

    % testSilentOnUnknownKeyByDefault
    lastwarn('');
    fp = FastPlot();
    fp.addThreshold(5.0, 'Colr', [1 0 0]);
    [warnMsg, ~] = lastwarn();
    assert(isempty(warnMsg), 'testSilent: no warn by default');

    % testBackwardCompatibility — existing API still works identically
    fp = FastPlot('Theme', 'dark', 'Verbose', true);
    fp.addLine(1:100, rand(1,100), 'Color', [1 0 0], 'DisplayName', 'Test');
    fp.addThreshold(0.5, 'Direction', 'upper', 'ShowViolations', true, 'Color', [0 1 0]);
    fp.addBand(0.2, 0.8, 'FaceColor', [0.9 0.9 0.9], 'FaceAlpha', 0.3);
    fp.addMarker(50, 0.5, 'Marker', 'v', 'MarkerSize', 8);
    fp.addShaded(1:100, rand(1,100), zeros(1,100), 'FaceColor', [0 0 1]);
    fp.render();
    assert(ishandle(fp.hAxes), 'testBackwardCompat: renders ok');
    assert(isequal(fp.Lines(1).Options.Color, [1 0 0]), 'testBackwardCompat: line color');
    assert(isequal(fp.Thresholds(1).Color, [0 1 0]), 'testBackwardCompat: threshold color');
    assert(fp.Thresholds(1).ShowViolations == true, 'testBackwardCompat: showviolations');
    close(fp.hFigure);

    % testAddLinePassthroughOptions — unknown keys in addLine pass through to line handle
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100), 'DisplayName', 'Signal', 'LineWidth', 2);
    assert(isfield(fp.Lines(1).Options, 'DisplayName'), 'testPassthrough: DisplayName');
    assert(isfield(fp.Lines(1).Options, 'LineWidth'), 'testPassthrough: LineWidth');

    % testDefaultDownsampleMethod
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100));
    assert(strcmp(fp.Lines(1).DownsampleMethod, 'minmax'), 'testDefaultDS: minmax');

    fprintf('    All 10 config integration tests passed.\n');
end
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "cd tests; test_config_integration"`
Expected: FAIL — `MinPointsForDownsample` is not a public property

**Step 3: Modify `FastPlot.m` — promote constants to properties**

In `FastPlot.m`, replace the `properties (Constant, Access = private)` block (lines 68-72):

**OLD:**
```matlab
    properties (Constant, Access = private)
        MIN_POINTS_FOR_DOWNSAMPLE = 5000  % below this, plot raw data
        DOWNSAMPLE_FACTOR = 2             % points per pixel (min + max)
        PYRAMID_REDUCTION = 100           % reduction factor per pyramid level
    end
```

**NEW:**
```matlab
    properties (Access = public)
        MinPointsForDownsample = 5000  % below this, plot raw data
        DownsampleFactor = 2           % points per pixel (min + max)
        PyramidReduction = 100         % reduction factor per pyramid level
    end
```

Then find-and-replace all references in `FastPlot.m`:
- `obj.MIN_POINTS_FOR_DOWNSAMPLE` → `obj.MinPointsForDownsample`
- `obj.DOWNSAMPLE_FACTOR` → `obj.DownsampleFactor`
- `obj.PYRAMID_REDUCTION` → `obj.PyramidReduction`

**Step 4: Modify constructor to load defaults and use parseOpts**

**OLD (lines 75-97):**
```matlab
        function obj = FastPlot(varargin)
            for k = 1:2:numel(varargin)
                switch lower(varargin{k})
                    case 'parent'
                        obj.ParentAxes = varargin{k+1};
                    case 'linkgroup'
                        obj.LinkGroup = varargin{k+1};
                    case 'theme'
                        val = varargin{k+1};
                        if ischar(val) || isstruct(val)
                            obj.Theme = FastPlotTheme(val);
                        else
                            obj.Theme = val;
                        end
                    case 'verbose'
                        obj.Verbose = varargin{k+1};
                end
            end
            % Default theme if none set
            if isempty(obj.Theme)
                obj.Theme = FastPlotTheme('default');
            end
        end
```

**NEW:**
```matlab
        function obj = FastPlot(varargin)
            % Load cached defaults
            cfg = getDefaults();
            obj.MinPointsForDownsample = cfg.MinPointsForDownsample;
            obj.DownsampleFactor = cfg.DownsampleFactor;
            obj.PyramidReduction = cfg.PyramidReduction;
            obj.Verbose = cfg.Verbose;

            % Parse constructor arguments
            defaults.Parent = [];
            defaults.LinkGroup = '';
            defaults.Theme = [];
            defaults.Verbose = obj.Verbose;
            defaults.MinPointsForDownsample = obj.MinPointsForDownsample;
            defaults.DownsampleFactor = obj.DownsampleFactor;
            defaults.PyramidReduction = obj.PyramidReduction;
            [opts, ~] = parseOpts(defaults, varargin);

            obj.ParentAxes = opts.Parent;
            obj.LinkGroup = opts.LinkGroup;
            obj.Verbose = opts.Verbose;
            obj.MinPointsForDownsample = opts.MinPointsForDownsample;
            obj.DownsampleFactor = opts.DownsampleFactor;
            obj.PyramidReduction = opts.PyramidReduction;

            % Resolve theme
            val = opts.Theme;
            if ~isempty(val)
                if ischar(val) || isstruct(val)
                    obj.Theme = FastPlotTheme(val);
                else
                    obj.Theme = val;
                end
            end
            if isempty(obj.Theme)
                obj.Theme = FastPlotTheme(cfg.Theme);
            end
        end
```

**Step 5: Modify `addLine` to use parseOpts**

**OLD (lines 130-152):**
```matlab
            dsMethod = 'minmax';
            meta = [];
            assumeSorted = false;
            hasNaNOverride = [];
            opts = struct();
            k = 1;
            while k <= numel(varargin)
                key = varargin{k};
                val = varargin{k+1};
                if strcmpi(key, 'DownsampleMethod')
                    dsMethod = val;
                elseif strcmpi(key, 'Metadata')
                    meta = val;
                elseif strcmpi(key, 'AssumeSorted')
                    assumeSorted = val;
                elseif strcmpi(key, 'HasNaN')
                    hasNaNOverride = val;
                else
                    opts.(key) = val;
                end
                k = k + 2;
            end
```

**NEW:**
```matlab
            knownDefaults.DownsampleMethod = getDefaults().DefaultDownsampleMethod;
            knownDefaults.Metadata = [];
            knownDefaults.AssumeSorted = false;
            knownDefaults.HasNaN = [];
            [known, passthrough] = parseOpts(knownDefaults, varargin, obj.Verbose);

            dsMethod = known.DownsampleMethod;
            meta = known.Metadata;
            assumeSorted = known.AssumeSorted;
            hasNaNOverride = known.HasNaN;
            opts = passthrough;
```

Note: `addLine` is special — unmatched keys are **passed through** to the MATLAB line handle (e.g., `'DisplayName'`, `'LineWidth'`, `'LineStyle'`). This is why `parseOpts` returns `unmatched` as a struct, and we use it as the line `Options`.

**Step 6: Modify `addThreshold` to use parseOpts**

**OLD (lines 209-232):**
```matlab
            t.Value          = value;
            t.Direction      = 'upper';
            t.ShowViolations = false;
            t.Color          = obj.Theme.ThresholdColor;
            t.LineStyle      = obj.Theme.ThresholdStyle;
            t.Label          = '';
            t.hLine          = [];
            t.hMarkers       = [];

            for k = 1:2:numel(varargin)
                switch lower(varargin{k})
                    case 'direction'
                        t.Direction = varargin{k+1};
                    case 'showviolations'
                        t.ShowViolations = varargin{k+1};
                    case 'color'
                        t.Color = varargin{k+1};
                    case 'linestyle'
                        t.LineStyle = varargin{k+1};
                    case 'label'
                        t.Label = varargin{k+1};
                end
            end
```

**NEW:**
```matlab
            defaults.Direction = 'upper';
            defaults.ShowViolations = false;
            defaults.Color = obj.Theme.ThresholdColor;
            defaults.LineStyle = obj.Theme.ThresholdStyle;
            defaults.Label = '';
            [parsed, ~] = parseOpts(defaults, varargin, obj.Verbose);

            t.Value          = value;
            t.Direction      = parsed.Direction;
            t.ShowViolations = parsed.ShowViolations;
            t.Color          = parsed.Color;
            t.LineStyle      = parsed.LineStyle;
            t.Label          = parsed.Label;
            t.hLine          = [];
            t.hMarkers       = [];
```

**Step 7: Modify `addBand` to use parseOpts**

**OLD (lines 251-270):**
```matlab
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
```

**NEW:**
```matlab
            defaults.FaceColor = obj.Theme.ThresholdColor;
            defaults.FaceAlpha = obj.Theme.BandAlpha;
            defaults.EdgeColor = 'none';
            defaults.Label = '';
            [parsed, ~] = parseOpts(defaults, varargin, obj.Verbose);

            b.YLow      = yLow;
            b.YHigh     = yHigh;
            b.FaceColor = parsed.FaceColor;
            b.FaceAlpha = parsed.FaceAlpha;
            b.EdgeColor = parsed.EdgeColor;
            b.Label     = parsed.Label;
            b.hPatch    = [];
```

**Step 8: Modify `addMarker` to use parseOpts**

**OLD (lines 294-311):**
```matlab
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
```

**NEW:**
```matlab
            defaults.Marker = 'o';
            defaults.MarkerSize = 6;
            defaults.Color = obj.Theme.ThresholdColor;
            defaults.Label = '';
            [parsed, ~] = parseOpts(defaults, varargin, obj.Verbose);

            m.X          = x;
            m.Y          = y;
            m.Marker     = parsed.Marker;
            m.MarkerSize = parsed.MarkerSize;
            m.Color      = parsed.Color;
            m.Label      = parsed.Label;
            m.hLine      = [];
```

**Step 9: Modify `addShaded` to use parseOpts**

**OLD (lines 353-373):**
```matlab
            s.X           = x;
            s.Y1          = y1;
            s.Y2          = y2;
            s.FaceColor   = [0 0.45 0.74];
            s.FaceAlpha   = 0.15;
            s.EdgeColor   = 'none';
            s.DisplayName = '';
            s.hPatch      = [];
            s.CacheX      = [];
            s.CacheY1     = [];
            s.CacheY2     = [];

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
```

**NEW:**
```matlab
            defaults.FaceColor = [0 0.45 0.74];
            defaults.FaceAlpha = 0.15;
            defaults.EdgeColor = 'none';
            defaults.DisplayName = '';
            [parsed, ~] = parseOpts(defaults, varargin, obj.Verbose);

            s.X           = x;
            s.Y1          = y1;
            s.Y2          = y2;
            s.FaceColor   = parsed.FaceColor;
            s.FaceAlpha   = parsed.FaceAlpha;
            s.EdgeColor   = parsed.EdgeColor;
            s.DisplayName = parsed.DisplayName;
            s.hPatch      = [];
            s.CacheX      = [];
            s.CacheY1     = [];
            s.CacheY2     = [];
```

**Step 10: Modify `updateLine` varargin parsing to use parseOpts**

**OLD (lines 917-934):**
```matlab
            skipViewMode = false;
            newMeta = [];
            hasMeta = false;
            for k = 1:2:numel(varargin)
                if islogical(varargin{k}) || isnumeric(varargin{k})
                    % Legacy: positional skipViewMode argument
                    skipViewMode = varargin{k};
                    break;
                end
                switch lower(varargin{k})
                    case 'metadata'
                        newMeta = varargin{k+1};
                        hasMeta = true;
                    case 'skipviewmode'
                        skipViewMode = varargin{k+1};
                end
            end
```

**NEW:**
```matlab
            % Handle legacy positional boolean argument
            skipViewMode = false;
            newMeta = [];
            hasMeta = false;
            if ~isempty(varargin) && (islogical(varargin{1}) || isnumeric(varargin{1}))
                skipViewMode = varargin{1};
            else
                updateDefaults.Metadata = [];
                updateDefaults.SkipViewMode = false;
                [updateOpts, ~] = parseOpts(updateDefaults, varargin, obj.Verbose);
                skipViewMode = updateOpts.SkipViewMode;
                newMeta = updateOpts.Metadata;
                hasMeta = ~isempty(newMeta);
            end
```

**Step 11: Modify `startLive` varargin parsing to use parseOpts**

**OLD (lines 980-994):**
```matlab
            for k = 1:2:numel(varargin)
                switch lower(varargin{k})
                    case 'interval'
                        obj.LiveInterval = varargin{k+1};
                    case 'viewmode'
                        obj.LiveViewMode = varargin{k+1};
                    case 'metadatafile'
                        obj.MetadataFile = varargin{k+1};
                    case 'metadatavars'
                        obj.MetadataVars = varargin{k+1};
                    case 'metadatalineindex'
                        obj.MetadataLineIndex = varargin{k+1};
                end
            end
```

**NEW:**
```matlab
            liveDefaults.Interval = obj.LiveInterval;
            liveDefaults.ViewMode = '';
            liveDefaults.MetadataFile = obj.MetadataFile;
            liveDefaults.MetadataVars = obj.MetadataVars;
            liveDefaults.MetadataLineIndex = obj.MetadataLineIndex;
            [liveOpts, ~] = parseOpts(liveDefaults, varargin, obj.Verbose);
            obj.LiveInterval = liveOpts.Interval;
            obj.LiveViewMode = liveOpts.ViewMode;
            obj.MetadataFile = liveOpts.MetadataFile;
            obj.MetadataVars = liveOpts.MetadataVars;
            obj.MetadataLineIndex = liveOpts.MetadataLineIndex;
```

**Step 12: Add `resetColorIndex()` method**

Add to the public methods section (after the constructor):

```matlab
        function resetColorIndex(obj)
            %RESETCOLORINDEX Reset the auto color cycling counter.
            %   fp.resetColorIndex()
            %   Next addLine() call without explicit Color will use the first
            %   color from the theme palette.
            obj.ColorIndex = 0;
        end
```

**Step 13: Add `reapplyTheme()` method**

Add to the public methods section:

```matlab
        function reapplyTheme(obj)
            %REAPPLYTHEME Re-apply the current Theme to axes and figure.
            %   Use after changing fp.Theme to update existing visuals.
            if ~obj.IsRendered; return; end
            obj.applyTheme();
            % Update existing line widths
            for i = 1:numel(obj.Lines)
                if ~isempty(obj.Lines(i).hLine) && ishandle(obj.Lines(i).hLine)
                    set(obj.Lines(i).hLine, 'LineWidth', obj.Theme.LineWidth);
                end
            end
        end
```

**Step 14: Add `clearDefaultsCache()` static method**

Add a `methods (Static)` section (or append to existing one):

```matlab
        function clearDefaultsCache()
            %CLEARDEFAULTSCACHE Force reload of FastPlotDefaults.
            clearDefaultsCache();
        end
```

**Step 15: Run all tests**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "cd tests; test_config_integration"`
Expected: PASS — "All 10 config integration tests passed."

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "cd tests; run_all_tests"`
Expected: All existing tests still pass.

**Step 16: Commit**

```bash
git add FastPlot.m tests/test_config_integration.m
git commit -m "feat: integrate parseOpts, configurable constants, resetColorIndex, reapplyTheme"
```

---

### Task 4: Integrate into `FastPlotFigure.m` — constructor and startLive

**Files:**
- Modify: `FastPlotFigure.m:34-38` (remove Constant properties)
- Modify: `FastPlotFigure.m:41-88` (constructor — load defaults, use parseOpts)
- Modify: `FastPlotFigure.m:200-215` (startLive — use parseOpts)
- Test: `tests/test_figure_config.m`

**Step 1: Write the test file**

```matlab
function test_figure_config()
%TEST_FIGURE_CONFIG Tests for config integration in FastPlotFigure.

    add_private_path();

    % testFigureLoadsDefaults
    fig = FastPlotFigure(2, 2);
    assert(fig.Padding == 0.06, 'testFigureDefaults: Padding');
    assert(fig.GapH == 0.05, 'testFigureDefaults: GapH');
    assert(fig.GapV == 0.07, 'testFigureDefaults: GapV');
    close(fig.hFigure);

    % testFigureDefaultTheme
    fig = FastPlotFigure(1, 1);
    assert(isstruct(fig.Theme), 'testFigureDefaultTheme: has theme');
    close(fig.hFigure);

    % testFigureCustomTheme
    fig = FastPlotFigure(1, 1, 'Theme', 'dark');
    assert(all(fig.Theme.Background < [0.2 0.2 0.2]), 'testFigureCustomTheme: dark bg');
    close(fig.hFigure);

    % testBackwardCompatibility — existing figure API works
    fig = FastPlotFigure(2, 2, 'Theme', 'dark');
    fp = fig.tile(1);
    fp.addLine(1:100, rand(1,100));
    fig.tileTitle(1, 'Test');
    fig.renderAll();
    assert(ishandle(fig.hFigure), 'testBackwardCompat: figure created');
    close(fig.hFigure);

    fprintf('    All 4 figure config tests passed.\n');
end
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "cd tests; test_figure_config"`
Expected: FAIL — `Padding` is not a public property

**Step 3: Modify `FastPlotFigure.m`**

Remove the Constant properties block and add configurable properties:

**OLD (lines 34-38):**
```matlab
    properties (Constant, Access = private)
        PADDING = 0.06
        GAP_H   = 0.05
        GAP_V   = 0.07
    end
```

**NEW:**
```matlab
    properties (Access = public)
        Padding = 0.06    % normalized padding around edges
        GapH    = 0.05    % horizontal gap between tiles
        GapV    = 0.07    % vertical gap between tiles
    end
```

Update constructor to load defaults:

**OLD (lines 41-88):**
```matlab
        function obj = FastPlotFigure(rows, cols, varargin)
            obj.Grid = [rows, cols];
            nTiles = rows * cols;
            obj.Tiles     = cell(1, nTiles);
            obj.TileAxes  = cell(1, nTiles);
            obj.TileSpans = cell(1, nTiles);
            obj.TileThemes = cell(1, nTiles);

            for i = 1:nTiles
                obj.TileSpans{i} = [1 1];
            end

            figOpts = {};
            for k = 1:2:numel(varargin)
                switch lower(varargin{k})
                    case 'theme'
                        val = varargin{k+1};
                        if ischar(val) || isstruct(val)
                            obj.Theme = FastPlotTheme(val);
                        else
                            obj.Theme = val;
                        end
                    case 'parentfigure'
                        obj.ParentFigure = varargin{k+1};
                    otherwise
                        figOpts{end+1} = varargin{k};
                        figOpts{end+1} = varargin{k+1};
                end
            end

            if isempty(obj.Theme)
                obj.Theme = FastPlotTheme('default');
            end
            ...
```

**NEW:**
```matlab
        function obj = FastPlotFigure(rows, cols, varargin)
            % Load cached defaults
            cfg = getDefaults();
            obj.Padding = cfg.DashboardPadding;
            obj.GapH = cfg.DashboardGapH;
            obj.GapV = cfg.DashboardGapV;

            obj.Grid = [rows, cols];
            nTiles = rows * cols;
            obj.Tiles     = cell(1, nTiles);
            obj.TileAxes  = cell(1, nTiles);
            obj.TileSpans = cell(1, nTiles);
            obj.TileThemes = cell(1, nTiles);

            for i = 1:nTiles
                obj.TileSpans{i} = [1 1];
            end

            % Parse known constructor options
            conDefaults.Theme = [];
            conDefaults.ParentFigure = [];
            [conOpts, figOpts] = parseOpts(conDefaults, varargin);

            % Resolve theme
            val = conOpts.Theme;
            if ~isempty(val)
                if ischar(val) || isstruct(val)
                    obj.Theme = FastPlotTheme(val);
                else
                    obj.Theme = val;
                end
            end
            obj.ParentFigure = conOpts.ParentFigure;

            if isempty(obj.Theme)
                obj.Theme = FastPlotTheme(cfg.Theme);
            end
            ...
```

**Important:** The `figOpts` unmatched struct from parseOpts needs to be converted back to a cell array of name-value pairs for passing to `figure()`. Add a helper or inline conversion:

```matlab
            % Convert unmatched struct to name-value cell array for figure()
            figOptNames = fieldnames(figOpts);
            figOptsCell = {};
            for i = 1:numel(figOptNames)
                figOptsCell{end+1} = figOptNames{i};    %#ok<AGROW>
                figOptsCell{end+1} = figOpts.(figOptNames{i});  %#ok<AGROW>
            end
```

Then use `figOptsCell` where `figOpts` was used before.

Update `computeTilePosition` — replace `obj.PADDING` → `obj.Padding`, `obj.GAP_H` → `obj.GapH`, `obj.GAP_V` → `obj.GapV`.

Update `startLive` to use parseOpts (same pattern as FastPlot.startLive).

**Step 4: Run tests**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "cd tests; test_figure_config"`
Expected: PASS

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "cd tests; run_all_tests"`
Expected: All tests pass

**Step 5: Commit**

```bash
git add FastPlotFigure.m tests/test_figure_config.m
git commit -m "feat: integrate config management into FastPlotFigure"
```

---

### Task 5: Integrate into `FastPlotDock.m`

**Files:**
- Modify: `FastPlotDock.m:19-21` (remove Constant, add configurable property)
- Modify: `FastPlotDock.m:24-54` (constructor — load defaults, use parseOpts)
- Test: `tests/test_dock_config.m`

**Step 1: Write the test file**

```matlab
function test_dock_config()
%TEST_DOCK_CONFIG Tests for config integration in FastPlotDock.

    add_private_path();

    % testDockLoadsDefaults
    dock = FastPlotDock();
    assert(dock.TabBarHeight == 0.03, 'testDockDefaults: TabBarHeight');
    close(dock.hFigure);

    % testDockDefaultTheme
    dock = FastPlotDock();
    assert(isstruct(dock.Theme), 'testDockDefaultTheme: has theme');
    close(dock.hFigure);

    % testDockCustomTheme
    dock = FastPlotDock('Theme', 'dark');
    assert(all(dock.Theme.Background < [0.2 0.2 0.2]), 'testDockCustomTheme: dark bg');
    close(dock.hFigure);

    fprintf('    All 3 dock config tests passed.\n');
end
```

**Step 2: Run test to verify it fails**

Expected: FAIL — `TabBarHeight` not public

**Step 3: Modify `FastPlotDock.m`**

**OLD (lines 19-21):**
```matlab
    properties (Constant, Access = private)
        TAB_BAR_HEIGHT = 0.03
    end
```

**NEW:**
```matlab
    properties (Access = public)
        TabBarHeight = 0.03   % normalized height of tab bar
    end
```

Update constructor:

**OLD (lines 24-54):**
```matlab
        function obj = FastPlotDock(varargin)
            figOpts = {};
            for k = 1:2:numel(varargin)
                switch lower(varargin{k})
                    case 'theme'
                        val = varargin{k+1};
                        if ischar(val) || isstruct(val)
                            obj.Theme = FastPlotTheme(val);
                        else
                            obj.Theme = val;
                        end
                    otherwise
                        figOpts{end+1} = varargin{k};
                        figOpts{end+1} = varargin{k+1};
                end
            end

            if isempty(obj.Theme)
                obj.Theme = FastPlotTheme('default');
            end
            ...
```

**NEW:**
```matlab
        function obj = FastPlotDock(varargin)
            cfg = getDefaults();
            obj.TabBarHeight = cfg.TabBarHeight;

            conDefaults.Theme = [];
            [conOpts, figOpts] = parseOpts(conDefaults, varargin);

            val = conOpts.Theme;
            if ~isempty(val)
                if ischar(val) || isstruct(val)
                    obj.Theme = FastPlotTheme(val);
                else
                    obj.Theme = val;
                end
            end

            if isempty(obj.Theme)
                obj.Theme = FastPlotTheme(cfg.Theme);
            end

            % Convert unmatched struct to name-value cell for figure()
            figOptNames = fieldnames(figOpts);
            figOptsCell = {};
            for i = 1:numel(figOptNames)
                figOptsCell{end+1} = figOptNames{i};    %#ok<AGROW>
                figOptsCell{end+1} = figOpts.(figOptNames{i});  %#ok<AGROW>
            end
            ...
```

Then find-and-replace all `obj.TAB_BAR_HEIGHT` → `obj.TabBarHeight` in the file.

**Step 4: Run tests**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "cd tests; test_dock_config"`
Expected: PASS

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "cd tests; run_all_tests"`
Expected: All tests pass

**Step 5: Commit**

```bash
git add FastPlotDock.m tests/test_dock_config.m
git commit -m "feat: integrate config management into FastPlotDock"
```

---

### Task 6: Update `run_all_tests.m` and final verification

**Files:**
- Modify: `tests/run_all_tests.m` (add new test files)

**Step 1: Add new tests to runner**

Add these lines to `run_all_tests.m`:
```matlab
test_parse_opts();
test_defaults();
test_config_integration();
test_figure_config();
test_dock_config();
```

**Step 2: Run full test suite**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "cd tests; run_all_tests"`
Expected: All tests pass, including all existing tests (backward compatibility).

**Step 3: Commit**

```bash
git add tests/run_all_tests.m
git commit -m "chore: add config management tests to test runner"
```
