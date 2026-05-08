function test_companion_apply_theme_walker()
%TEST_COMPANION_APPLY_THEME_WALKER Regression test for applyThemeToChildren_ walker coverage.
%   Builds a hidden uifigure containing one of every widget class that
%   Companion uses today (uilistbox, uieditfield, uilabel, uibutton,
%   uidropdown, uispinner, uitable) plus every class added by the
%   260508-d7k fix (uitextarea, uicheckbox, uistatebutton, uitogglebutton,
%   uiradiobutton+uibuttongroup, uinumericeditfield). Asserts that
%   BackgroundColor and/or FontColor flip correctly through dark->light->dark.
%
%   Key regression assertion: uilistbox.BackgroundColor MUST equal
%   theme.WidgetBackground after dark apply (the single check that would
%   have caught the original fall-through bug).
%
%   MATLAB-only -- skipped on Octave (uifigure + UIControl classes absent).
%
%   See also applyThemeToChildren_, CompanionTheme.

    if exist('OCTAVE_VERSION', 'builtin') ~= 0
        fprintf('  Skipping test_companion_apply_theme_walker on Octave (uifigure not supported).\n');
        return;
    end

    % --- Path setup ---
    add_companion_private_path();
    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();

    nPassed = 0;

    % --- Build hidden uifigure with all widget classes ---
    hFig = uifigure('Visible', 'off');
    clean = onCleanup(@() delete(hFig));  %#ok<NASGU>

    % Root grid for most widgets
    hGrid = uigridlayout(hFig, [4 3]);
    hGrid.ColumnWidth = {'1x', '1x', '1x'};
    hGrid.RowHeight   = {'1x', '1x', '1x', '1x'};
    hGrid.Padding     = [4 4 4 4];

    % --- Already-covered widgets ---
    hLabel = uilabel(hGrid);
    hLabel.Layout.Row = 1; hLabel.Layout.Column = 1;
    hEdit  = uieditfield(hGrid, 'text');
    hEdit.Layout.Row = 1; hEdit.Layout.Column = 2;
    hDrop  = uidropdown(hGrid);
    hDrop.Layout.Row = 1; hDrop.Layout.Column = 3;
    hSpin  = uispinner(hGrid);
    hSpin.Layout.Row = 2; hSpin.Layout.Column = 1;
    hBtn   = uibutton(hGrid, 'push');
    hBtn.Layout.Row = 2; hBtn.Layout.Column = 2;
    hTbl   = uitable(hGrid);
    hTbl.Layout.Row = 2; hTbl.Layout.Column = 3;

    % --- NEW: uilistbox (the reported bug) ---
    hList  = uilistbox(hGrid);
    hList.Layout.Row = 3; hList.Layout.Column = 1;

    % --- NEW prophylactic: uitextarea ---
    hArea = tryMakeWidget(@() makeTextArea(hGrid));

    % --- NEW prophylactic: uicheckbox ---
    hChk = tryMakeWidget(@() makeCheckBox(hGrid));

    % --- NEW prophylactic: uistatebutton (absent in some MATLAB versions) ---
    hState = tryMakeWidget(@() makeStateButton(hGrid));

    % --- NEW prophylactic: uinumericeditfield (absent in some MATLAB versions) ---
    hNum = tryMakeWidget(@() makeNumericEdit(hGrid));

    % --- NEW prophylactic: uibuttongroup with uitogglebutton ---
    % uibuttongroup must be direct child of uifigure / uipanel in many builds
    hBgToggle = tryMakeWidget(@() uibuttongroup(hFig));
    hToggle   = [];
    if ~isempty(hBgToggle)
        hToggle = tryMakeWidget(@() uitogglebutton(hBgToggle));
    end

    % --- NEW prophylactic: uibuttongroup with uiradiobutton ---
    hBgRadio = tryMakeWidget(@() uibuttongroup(hFig));
    hRadio   = [];
    if ~isempty(hBgRadio)
        hRadio = tryMakeWidget(@() uiradiobutton(hBgRadio));
    end

    % --- Dark theme apply ---
    darkTheme  = CompanionTheme.get('dark');
    lightTheme = CompanionTheme.get('light');

    applyThemeToChildren_(hFig, darkTheme);

    % Test 1-2: uilistbox BackgroundColor + FontColor = dark (the bug fix)
    assertColorEqual(hList.BackgroundColor, darkTheme.WidgetBackground, ...
        'uilistbox BackgroundColor after dark apply');
    assertColorEqual(hList.FontColor, darkTheme.ForegroundColor, ...
        'uilistbox FontColor after dark apply');
    nPassed = nPassed + 2;

    % Tests 3-4: uitextarea (if available)
    if ~isempty(hArea)
        assertColorEqual(hArea.BackgroundColor, darkTheme.WidgetBackground, ...
            'uitextarea BackgroundColor after dark apply');
        assertColorEqual(hArea.FontColor, darkTheme.ForegroundColor, ...
            'uitextarea FontColor after dark apply');
        nPassed = nPassed + 2;
    end

    % Test 5: uicheckbox FontColor only (inherits bg from parent)
    if ~isempty(hChk)
        assertColorEqual(hChk.FontColor, darkTheme.ForegroundColor, ...
            'uicheckbox FontColor after dark apply');
        nPassed = nPassed + 1;
    end

    % Tests 6-7: uistatebutton (if available)
    if ~isempty(hState)
        assertColorEqual(hState.BackgroundColor, darkTheme.WidgetBorderColor, ...
            'uistatebutton BackgroundColor after dark apply');
        assertColorEqual(hState.FontColor, darkTheme.ForegroundColor, ...
            'uistatebutton FontColor after dark apply');
        nPassed = nPassed + 2;
    end

    % Tests 8-9: uinumericeditfield (if available)
    if ~isempty(hNum)
        assertColorEqual(hNum.BackgroundColor, darkTheme.WidgetBackground, ...
            'uinumericeditfield BackgroundColor after dark apply');
        assertColorEqual(hNum.FontColor, darkTheme.ForegroundColor, ...
            'uinumericeditfield FontColor after dark apply');
        nPassed = nPassed + 2;
    end

    % Tests 10-11: uitogglebutton (if available)
    if ~isempty(hToggle)
        assertColorEqual(hToggle.BackgroundColor, darkTheme.WidgetBorderColor, ...
            'uitogglebutton BackgroundColor after dark apply');
        assertColorEqual(hToggle.FontColor, darkTheme.ForegroundColor, ...
            'uitogglebutton FontColor after dark apply');
        nPassed = nPassed + 2;
    end

    % Test 12: uibuttongroup BackgroundColor (if available)
    if ~isempty(hBgToggle)
        assertColorEqual(hBgToggle.BackgroundColor, darkTheme.WidgetBackground, ...
            'uibuttongroup BackgroundColor after dark apply');
        nPassed = nPassed + 1;
    end

    % Test 13: uiradiobutton FontColor only (if available)
    if ~isempty(hRadio)
        assertColorEqual(hRadio.FontColor, darkTheme.ForegroundColor, ...
            'uiradiobutton FontColor after dark apply');
        nPassed = nPassed + 1;
    end

    % Regression: already-covered widgets still work
    assertColorEqual(hEdit.BackgroundColor, darkTheme.WidgetBackground, ...
        'uieditfield BackgroundColor regression (dark)');
    assertColorEqual(hLabel.FontColor, darkTheme.ForegroundColor, ...
        'uilabel FontColor regression (dark)');
    assertColorEqual(hBtn.FontColor, darkTheme.ForegroundColor, ...
        'uibutton FontColor regression (dark)');
    nPassed = nPassed + 3;

    % --- Switch to light ---
    applyThemeToChildren_(hFig, lightTheme);

    assertColorEqual(hList.BackgroundColor, lightTheme.WidgetBackground, ...
        'uilistbox BackgroundColor after light apply');
    if ~isempty(hArea)
        assertColorEqual(hArea.BackgroundColor, lightTheme.WidgetBackground, ...
            'uitextarea BackgroundColor after light apply');
        nPassed = nPassed + 1;
    end
    if ~isempty(hChk)
        assertColorEqual(hChk.FontColor, lightTheme.ForegroundColor, ...
            'uicheckbox FontColor after light apply');
        nPassed = nPassed + 1;
    end
    assertColorEqual(hEdit.BackgroundColor, lightTheme.WidgetBackground, ...
        'uieditfield BackgroundColor regression (light)');
    nPassed = nPassed + 2;

    % --- Switch back to dark (verify not one-shot) ---
    applyThemeToChildren_(hFig, darkTheme);

    assertColorEqual(hList.BackgroundColor, darkTheme.WidgetBackground, ...
        'uilistbox BackgroundColor after second dark apply');
    if ~isempty(hArea)
        assertColorEqual(hArea.BackgroundColor, darkTheme.WidgetBackground, ...
            'uitextarea BackgroundColor after second dark apply');
        nPassed = nPassed + 1;
    end
    nPassed = nPassed + 1;

    fprintf('    All %d tests passed.\n', nPassed);
end

% ---------------------------------------------------------------------------
function add_companion_private_path()
%ADD_COMPANION_PRIVATE_PATH Add libs/FastSenseCompanion/private to path.
%   Private functions (applyThemeToChildren_, etc.) are only natively
%   visible to callers inside libs/FastSenseCompanion. Tests must add
%   the private folder explicitly via addpath so the walker is reachable.
    testDir = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(testDir);
    privDir = fullfile(repoRoot, 'libs', 'FastSenseCompanion', 'private');
    w = warning('off', 'all');
    addpath(privDir);
    warning(w);
    % Fallback for R2025b+ where addpath('private') is rejected
    dirs = strsplit(path, pathsep);
    if ~any(strcmp(dirs, privDir))
        tmpDir = fullfile(tempdir, 'fastsense_companion_private_proxy');
        if ~exist(tmpDir, 'dir')
            mkdir(tmpDir);
        end
        exts = {'*.m', '*.mex', '*.mexmaci64', '*.mexmaca64', '*.mexa64'};
        for e = 1:numel(exts)
            files = dir(fullfile(privDir, exts{e}));
            for fi = 1:numel(files)
                src = fullfile(privDir, files(fi).name);
                dst = fullfile(tmpDir, files(fi).name);
                copyfile(src, dst);
            end
        end
        addpath(tmpDir);
    end
end

% ---------------------------------------------------------------------------
function assertColorEqual(actual, expected, ctxMsg)
%ASSERTCOLOREQUAL Assert two RGB triples are equal within 1e-6 tolerance.
%   Throws FastSenseCompanion:themeWalkerAssertion on mismatch.
    if max(abs(actual(:) - expected(:))) >= 1e-6
        error('FastSenseCompanion:themeWalkerAssertion', ...
            '%s was [%.4f %.4f %.4f], expected [%.4f %.4f %.4f]', ...
            ctxMsg, actual(1), actual(2), actual(3), ...
            expected(1), expected(2), expected(3));
    end
end

% ---------------------------------------------------------------------------
function h = tryMakeWidget(ctorHandle)
%TRYMAKEWIDGET Try to construct a widget; return [] if class is unavailable.
%   Wraps construction in try/catch so MATLAB versions lacking certain
%   UIControl classes do not abort the test.
    try
        h = ctorHandle();
    catch
        h = [];
    end
end

% ---------------------------------------------------------------------------
function h = makeTextArea(parent)
%MAKETEXTAREA Create a uitextarea parented to given grid.
    h = uitextarea(parent);
    h.Layout.Row    = 3;
    h.Layout.Column = 2;
end

% ---------------------------------------------------------------------------
function h = makeCheckBox(parent)
%MAKECHECKBOX Create a uicheckbox parented to given grid.
    h = uicheckbox(parent);
    h.Layout.Row    = 3;
    h.Layout.Column = 3;
end

% ---------------------------------------------------------------------------
function h = makeStateButton(parent)
%MAKESTATEBUTTON Create a uistatebutton parented to given grid.
    h = uistatebutton(parent);
    h.Layout.Row    = 4;
    h.Layout.Column = 1;
end

% ---------------------------------------------------------------------------
function h = makeNumericEdit(parent)
%MAKENUMERICEDIT Create a uinumericeditfield parented to given grid.
    h = uinumericeditfield(parent);
    h.Layout.Row    = 4;
    h.Layout.Column = 2;
end
