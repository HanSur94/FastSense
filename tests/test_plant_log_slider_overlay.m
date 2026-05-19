function test_plant_log_slider_overlay()
%TEST_PLANT_LOG_SLIDER_OVERLAY Function-style smoke for Phase 1031 Plan 02 slider integration.
%   Cross-runtime where possible (theme + engine guards); MATLAB-only gated
%   tests for uifigure / TimeRangeSelector graphics. Does NOT manually addpath
%   libs/Dashboard or libs/PlantLog — install() is the supported path setup.
%
%   Coverage: PLOG-VIZ-01 (slider draws plant-log lines via setPlantLogMarkers),
%             PLOG-VIZ-02 (independent storage from sev1/2/3 event markers),
%             PLOG-VIZ-08 (live-tail listener wire-up via test seam),
%             PLOG-VIZ-09 (MarkerPlantLog theme token + override).

    add_paths_via_install_only();
    nPassed = 0;

    nPassed = nPassed + test_theme_marker_plant_log_dark();
    nPassed = nPassed + test_theme_marker_plant_log_light();
    nPassed = nPassed + test_theme_marker_plant_log_override();
    nPassed = nPassed + test_theme_legacy_alias_includes_token();
    nPassed = nPassed + test_engine_no_store_guard();
    nPassed = nPassed + test_engine_test_seam_validates_store();
    nPassed = nPassed + test_engine_test_seam_validates_tail();
    nPassed = nPassed + test_selector_plant_log_independent();
    nPassed = nPassed + test_selector_plant_log_clears();

    assert(nPassed == 9, 'expected 9 sub-tests, got %d', nPassed);
    fprintf('    All 9 plant_log_slider_overlay assertions passed.\n');
end

% ----------------------------------------------------------------------------
% Path setup
% ----------------------------------------------------------------------------

function add_paths_via_install_only()
    thisDir = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(thisDir);
    addpath(repoRoot);
    install();
    assert(~isempty(which('DashboardTheme')),     'DashboardTheme must resolve after install()');
    assert(~isempty(which('TimeRangeSelector')),  'TimeRangeSelector must resolve after install()');
    assert(~isempty(which('DashboardEngine')),    'DashboardEngine must resolve after install()');
    assert(~isempty(which('PlantLogStore')),      'PlantLogStore must resolve after install()');
    assert(~isempty(which('PlantLogLiveTail')),   'PlantLogLiveTail must resolve after install()');
end

% ----------------------------------------------------------------------------
% Named cleanup helpers (NEVER inline try/catch in anonymous fns)
% ----------------------------------------------------------------------------

function try_delete_h(h)
    try
        if ishandle(h)
            delete(h);
        end
    catch
    end
end

function try_delete_obj(o)
    try
        if ~isempty(o) && isvalid(o)
            delete(o);
        end
    catch
    end
end

% ----------------------------------------------------------------------------
% Theme tests (cross-runtime; pure logic on the theme struct)
% ----------------------------------------------------------------------------

function n = test_theme_marker_plant_log_dark()
    td = DashboardTheme('dark');
    assert(isfield(td, 'MarkerPlantLog'), 'dark theme must have MarkerPlantLog field');
    assert(isequal(td.MarkerPlantLog, [0 0 0]), 'dark MarkerPlantLog must default to [0 0 0]');
    n = 1;
end

function n = test_theme_marker_plant_log_light()
    tl = DashboardTheme('light');
    assert(isfield(tl, 'MarkerPlantLog'), 'light theme must have MarkerPlantLog field');
    assert(isequal(tl.MarkerPlantLog, [0 0 0]), 'light MarkerPlantLog must default to [0 0 0]');
    n = 1;
end

function n = test_theme_marker_plant_log_override()
    to = DashboardTheme('dark', 'MarkerPlantLog', [0.2 0.2 0.2]);
    assert(isequal(to.MarkerPlantLog, [0.2 0.2 0.2]), 'varargin override path must work for MarkerPlantLog');
    n = 1;
end

function n = test_theme_legacy_alias_includes_token()
    % Legacy preset 'industrial' aliases to 'light' inside DashboardTheme;
    % the MarkerPlantLog token must come along for the ride.
    ti = DashboardTheme('industrial');
    assert(isfield(ti, 'MarkerPlantLog'), 'industrial alias must include MarkerPlantLog field');
    assert(isequal(ti.MarkerPlantLog, [0 0 0]), 'industrial MarkerPlantLog must default to [0 0 0]');
    n = 1;
end

% ----------------------------------------------------------------------------
% Engine guard + test-seam validation tests (cross-runtime; no graphics)
% ----------------------------------------------------------------------------

function n = test_engine_no_store_guard()
    e = DashboardEngine('TestNoStore');
    cleanupE = onCleanup(@() try_delete_obj(e));
    % Before render: TimeRangeSelector_ is empty; computePlantLogMarkers must
    % early-exit cleanly via the first guard. We don't need to call the method
    % directly (it's private); the test seam setPlantLogStoreForTest_([]) is
    % the documented path and itself calls computePlantLogMarkers internally.
    e.setPlantLogStoreForTest_([]);   % no error expected
    clear cleanupE;
    n = 1;
end

function n = test_engine_test_seam_validates_store()
    e = DashboardEngine('TestSeamStore');
    cleanupE = onCleanup(@() try_delete_obj(e));
    threw = false;
    try
        e.setPlantLogStoreForTest_('bogus');
    catch err
        threw = strcmp(err.identifier, 'DashboardEngine:invalidPlantLogStore');
    end
    assert(threw, 'setPlantLogStoreForTest_(bogus) must throw DashboardEngine:invalidPlantLogStore');
    clear cleanupE;
    n = 1;
end

function n = test_engine_test_seam_validates_tail()
    e = DashboardEngine('TestSeamTail');
    cleanupE = onCleanup(@() try_delete_obj(e));
    threw = false;
    try
        e.setPlantLogLiveTailForTest_('bogus');
    catch err
        threw = strcmp(err.identifier, 'DashboardEngine:invalidPlantLogLiveTail');
    end
    assert(threw, 'setPlantLogLiveTailForTest_(bogus) must throw DashboardEngine:invalidPlantLogLiveTail');
    clear cleanupE;
    n = 1;
end

% ----------------------------------------------------------------------------
% Selector graphics tests (MATLAB only — uifigure-heavy; clean-skip on Octave)
% ----------------------------------------------------------------------------

function n = test_selector_plant_log_independent()
    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('    SKIP test_selector_plant_log_independent (Octave: uifigure-heavy).\n');
        n = 1; return;
    end
    f = figure('Visible', 'off');
    cleanupF = onCleanup(@() try_delete_h(f));
    p = uipanel(f);
    s = TimeRangeSelector(p, 'Theme', DashboardTheme('dark'));
    s.setDataRange(0, 100);
    s.setEventMarkers([10 20 30]);
    s.setPlantLogMarkers([15 25]);
    assert(~isempty(s.hEventMarkers),    'event markers must remain after setPlantLogMarkers');
    assert(~isempty(s.hPlantLogMarkers), 'plant-log markers must be created');
    clear cleanupF;
    n = 1;
end

function n = test_selector_plant_log_clears()
    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('    SKIP test_selector_plant_log_clears (Octave: uifigure-heavy).\n');
        n = 1; return;
    end
    f = figure('Visible', 'off');
    cleanupF = onCleanup(@() try_delete_h(f));
    p = uipanel(f);
    s = TimeRangeSelector(p, 'Theme', DashboardTheme('dark'));
    s.setDataRange(0, 100);
    s.setEventMarkers([10 20]);
    s.setPlantLogMarkers([15 25]);
    s.setPlantLogMarkers([]);
    assert(~isempty(s.hEventMarkers), 'event markers must remain after setPlantLogMarkers([])');
    assert(isempty(s.hPlantLogMarkers), 'plant-log markers must clear');
    clear cleanupF;
    n = 1;
end
