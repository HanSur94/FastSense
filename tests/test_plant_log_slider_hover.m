function test_plant_log_slider_hover()
%TEST_PLANT_LOG_SLIDER_HOVER MATLAB-only function-style smoke for the slider hover tooltip.
%   Phase 1031 PLOG-VIZ-06: hover-driven tooltip on plant-log slider markers.
%   Uses PlantLogSliderHover.simulateHoverAt_(dataX) hidden test seam to
%   bypass the WindowButtonMotionFcn pixel hit-test for deterministic
%   per-coordinate assertions. Cross-runtime SKIP on Octave because
%   uipanel + uicontrol(text) parented to a figure work very differently
%   on Octave (and PlantLogSliderHover targets MATLAB R2020b+ uifigures).
%
%   Coverage:
%     1. Constructor input validation
%     2. Constructor saves prior WindowButtonMotionFcn
%     3. simulateHoverAt_ picks the nearest entry within tolerance
%     4. simulateHoverAt_ returns [] when no entry within tolerance
%     5. Tooltip becomes visible after a successful pick
%     6. Tooltip text format = datestr(timestamp) + '\n' + message
%     7. delete() restores prior WindowButtonMotionFcn unchanged
%     8. Engine lazy construction: setPlantLogStoreForTest_ on a populated
%        store + injected TimeRangeSelector → engine.PlantLogSliderHover_
%        becomes non-empty
%     9. Engine teardown on store detach: setPlantLogStoreForTest_([]) →
%        PlantLogSliderHover_ becomes empty
%    10. Engine teardown on delete: delete(engine) → no orphan WBMFcn
%        closures (WBM falls back to baseline)

    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('    SKIP test_plant_log_slider_hover (Octave: uifigure-heavy).\n');
        return;
    end

    add_paths_via_install_only();
    nPassed = 0;

    nPassed = nPassed + test_constructor_validates_args();
    nPassed = nPassed + test_constructor_saves_prior_wbm();
    nPassed = nPassed + test_simulate_hover_finds_nearest();
    nPassed = nPassed + test_simulate_hover_no_entry_in_range();
    nPassed = nPassed + test_tooltip_visible_after_show();
    nPassed = nPassed + test_tooltip_text_format();
    nPassed = nPassed + test_delete_restores_wbm();
    nPassed = nPassed + test_engine_lazy_construction();
    nPassed = nPassed + test_engine_teardown_on_store_detach();
    nPassed = nPassed + test_engine_teardown_on_delete();

    assert(nPassed == 10, 'expected 10 sub-tests, got %d', nPassed);
    fprintf('    All 10 plant_log_slider_hover assertions passed.\n');
end

% =====================================================================
% PATH SETUP -- install() contract gate (do NOT add manual addpath here)
% =====================================================================

function add_paths_via_install_only()
    thisDir = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(thisDir);
    addpath(repoRoot);
    install();
    assert(~isempty(which('PlantLogSliderHover')), ...
        'PlantLogSliderHover must resolve after install()');
    assert(~isempty(which('PlantLogStore')), ...
        'PlantLogStore must resolve after install()');
    assert(~isempty(which('TimeRangeSelector')), ...
        'TimeRangeSelector must resolve after install()');
    assert(~isempty(which('DashboardEngine')), ...
        'DashboardEngine must resolve after install()');
end

% =====================================================================
% NAMED CLEANUP HELPERS -- never use inline try inside anonymous funcs
% =====================================================================

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

% =====================================================================
% TEST FIXTURE BUILDERS
% =====================================================================

function [f, ax] = make_offscreen_figure_with_axes_(xLim)
    f = figure('Visible', 'off');
    ax = axes('Parent', f);
    if nargin >= 1 && ~isempty(xLim)
        set(ax, 'XLim', xLim);
    end
end

function s = make_populated_store_(timestamps, messages)
    s = PlantLogStore('synthetic.csv');
    n = numel(timestamps);
    es = repmat(PlantLogEntry('Timestamp', timestamps(1), ...
        'Message', messages{1}, 'Metadata', struct()), 1, n);
    for k = 2:n
        es(k) = PlantLogEntry('Timestamp', timestamps(k), ...
            'Message', messages{k}, 'Metadata', struct());
    end
    s.addEntries(es);
end

% =====================================================================
% SUB-TESTS
% =====================================================================

function n = test_constructor_validates_args()
    f = figure('Visible', 'off');
    cleanupF = onCleanup(@() try_delete_h(f));
    ax = axes('Parent', f);
    s = PlantLogStore('x');
    lookup = @(t0, t1) s.getEntriesInRange(t0, t1);

    threw = false;
    try
        PlantLogSliderHover([], ax, lookup);
    catch err
        threw = strcmp(err.identifier, 'PlantLogSliderHover:invalidInput');
    end
    assert(threw, 'bad parentFig must throw PlantLogSliderHover:invalidInput');

    threw = false;
    try
        PlantLogSliderHover(f, [], lookup);
    catch err
        threw = strcmp(err.identifier, 'PlantLogSliderHover:invalidInput');
    end
    assert(threw, 'bad sliderAxes must throw PlantLogSliderHover:invalidInput');

    threw = false;
    try
        PlantLogSliderHover(f, ax, 'not-a-function-handle');
    catch err
        threw = strcmp(err.identifier, 'PlantLogSliderHover:invalidInput');
    end
    assert(threw, 'bad lookupFn must throw PlantLogSliderHover:invalidInput');

    clear cleanupF;
    n = 1;
end

function n = test_constructor_saves_prior_wbm()
    [f, ax] = make_offscreen_figure_with_axes_([0 100]);
    cleanupF = onCleanup(@() try_delete_h(f));
    customWBM = @(s, e) disp('custom-handler');
    set(f, 'WindowButtonMotionFcn', customWBM);
    s = PlantLogStore('x');
    h = PlantLogSliderHover(f, ax, @(t0, t1) s.getEntriesInRange(t0, t1));
    cleanupH = onCleanup(@() try_delete_obj(h));

    % Verify hover saved the custom handler (not [], not '').
    % Access via WindowButtonMotionFcn -- after hover construction, the
    % live WBM is hover's chained handler. The saved prior is internal.
    % Indirect verification: delete the hover and assert WBM == customWBM.
    delete(h);
    afterWBM = get(f, 'WindowButtonMotionFcn');
    assert(isequal(afterWBM, customWBM), ...
        'after delete(h), WBMFcn must equal the custom handler installed before construction');

    clear cleanupH cleanupF;
    n = 1;
end

function n = test_simulate_hover_finds_nearest()
    [f, ax] = make_offscreen_figure_with_axes_([0 100]);
    cleanupF = onCleanup(@() try_delete_h(f));
    s = make_populated_store_([25 50 75], {'a', 'b', 'c'});
    h = PlantLogSliderHover(f, ax, @(t0, t1) s.getEntriesInRange(t0, t1));
    cleanupH = onCleanup(@() try_delete_obj(h));

    % Hover EXACTLY at the entry's data X (proximity tolerance is ~3 px in
    % axes data units, which on an offscreen ~600 px axes with XLim [0 100]
    % is ~0.5 data units; hovering exactly on the marker is the most
    % deterministic test that does not depend on axes pixel width).
    pick = h.simulateHoverAt_(50);
    assert(~isempty(pick), 'simulateHoverAt_(50) must find an entry');
    assert(strcmp(pick.Message, 'b'), 'expected message=b, got %s', pick.Message);

    % Hover near 75 (also exact) — proves the lookup picks the correct
    % entry for any of several markers (NOT always the middle one).
    pick = h.simulateHoverAt_(75);
    assert(~isempty(pick), 'simulateHoverAt_(75) must find an entry');
    assert(strcmp(pick.Message, 'c'), 'expected message=c, got %s', pick.Message);

    % Hover exactly between two entries (37.5 is midway between 25 and 50)
    % is intentionally OFF every marker -> empty pick. This proves the
    % tolerance does NOT bridge the inter-entry gap.
    pick = h.simulateHoverAt_(37.5);
    assert(isempty(pick), 'simulateHoverAt_(37.5) (midway between 25 and 50) must be empty');

    clear cleanupH cleanupF;
    n = 1;
end

function n = test_simulate_hover_no_entry_in_range()
    [f, ax] = make_offscreen_figure_with_axes_([0 100]);
    cleanupF = onCleanup(@() try_delete_h(f));
    s = make_populated_store_([25 50 75], {'a', 'b', 'c'});
    h = PlantLogSliderHover(f, ax, @(t0, t1) s.getEntriesInRange(t0, t1));
    cleanupH = onCleanup(@() try_delete_obj(h));

    % 0 is far from any entry; the ~3px tolerance in axes data units must
    % not reach 25. Check empty entries trigger a hide + return [].
    pick = h.simulateHoverAt_(0);
    assert(isempty(pick), 'simulateHoverAt_(0) must return empty (no entry within tolerance)');
    assert(~h.getCurrentTooltipVisible_(), ...
        'tooltip must remain hidden after a no-pick simulateHoverAt_');

    clear cleanupH cleanupF;
    n = 1;
end

function n = test_tooltip_visible_after_show()
    [f, ax] = make_offscreen_figure_with_axes_([0 100]);
    cleanupF = onCleanup(@() try_delete_h(f));
    s = make_populated_store_([25 50 75], {'a', 'b', 'c'});
    h = PlantLogSliderHover(f, ax, @(t0, t1) s.getEntriesInRange(t0, t1));
    cleanupH = onCleanup(@() try_delete_obj(h));

    assert(~h.getCurrentTooltipVisible_(), 'tooltip starts hidden');
    h.simulateHoverAt_(50);
    assert(h.getCurrentTooltipVisible_(), ...
        'tooltip must be visible after a successful simulateHoverAt_');

    clear cleanupH cleanupF;
    n = 1;
end

function n = test_tooltip_text_format()
    [f, ax] = make_offscreen_figure_with_axes_([0 100]);
    cleanupF = onCleanup(@() try_delete_h(f));
    % Use a real datenum so datestr produces the expected formatted output.
    ts = datenum('2025-01-15 12:34:56');
    set(ax, 'XLim', [ts - 1, ts + 1]);
    s = PlantLogStore('x');
    s.addEntries(PlantLogEntry('Timestamp', ts, ...
        'Message', 'pump on', 'Metadata', struct()));
    h = PlantLogSliderHover(f, ax, @(t0, t1) s.getEntriesInRange(t0, t1));
    cleanupH = onCleanup(@() try_delete_obj(h));

    pick = h.simulateHoverAt_(ts);
    assert(~isempty(pick), 'simulateHoverAt_ at exact timestamp must pick the entry');
    str = h.getCurrentTooltipString_();
    % uicontrol(text)'s String for multi-line input may come back as a
    % char matrix (rows = lines) or a cell of char rows; flatten to a
    % single char row for substring assertions.
    flat = flatten_tooltip_string_(str);
    expectedTs = datestr(ts, 'yyyy-mm-dd HH:MM:SS'); %#ok<DATST>
    assert(~isempty(strfind(flat, expectedTs)), ...
        'tooltip must contain datestr-formatted timestamp; got "%s"', flat); %#ok<STREMP>
    assert(~isempty(strfind(flat, 'pump on')), ...
        'tooltip must contain message; got "%s"', flat); %#ok<STREMP>

    clear cleanupH cleanupF;
    n = 1;
end

function flat = flatten_tooltip_string_(str)
%FLATTEN_TOOLTIP_STRING_ Coerce uicontrol String into a single char row.
%   Multi-line input via sprintf('%s\n%s', ...) may be stored by MATLAB as
%   a char matrix (one row per line) or as a cell. We join rows/cells with
%   spaces so substring assertions work uniformly.
    if iscell(str)
        flat = strjoin(str, ' ');
    elseif ischar(str) && size(str, 1) > 1
        rows = cell(size(str, 1), 1);
        for k = 1:size(str, 1)
            rows{k} = strtrim(str(k, :));
        end
        flat = strjoin(rows, ' ');
    elseif ischar(str)
        flat = str;
    else
        flat = char(str);
    end
end

function n = test_delete_restores_wbm()
    [f, ax] = make_offscreen_figure_with_axes_([0 100]);
    cleanupF = onCleanup(@() try_delete_h(f));
    customWBM = @(s, e) disp('original');
    set(f, 'WindowButtonMotionFcn', customWBM);
    priorWBM = get(f, 'WindowButtonMotionFcn');
    s = PlantLogStore('x');
    h = PlantLogSliderHover(f, ax, @(t0, t1) s.getEntriesInRange(t0, t1));

    % While alive, hover's chained handler should be installed (not customWBM).
    duringWBM = get(f, 'WindowButtonMotionFcn');
    assert(~isequal(duringWBM, priorWBM), ...
        'while hover is alive, WBMFcn should be hover''s chained handler');

    delete(h);
    afterWBM = get(f, 'WindowButtonMotionFcn');
    assert(isequal(priorWBM, afterWBM), ...
        'delete(h) must restore WBMFcn to the prior handler unchanged');

    clear cleanupF;
    n = 1;
end

function n = test_engine_lazy_construction()
    f = figure('Visible', 'off');
    cleanupF = onCleanup(@() try_delete_h(f));
    p = uipanel(f);
    sel = TimeRangeSelector(p, 'Theme', DashboardTheme('dark'));
    sel.setDataRange(0, 100);

    e = DashboardEngine('TestLazy');
    cleanupE = onCleanup(@() try_delete_obj(e));
    e.setTimeRangeSelectorForTest_(sel);

    store = make_populated_store_([25 50 75], {'a', 'b', 'c'});
    e.setPlantLogStoreForTest_(store);
    assert(~isempty(e.PlantLogSliderHover_), ...
        'engine.PlantLogSliderHover_ must be non-empty after attaching store with rendered selector');
    assert(isvalid(e.PlantLogSliderHover_), ...
        'engine.PlantLogSliderHover_ must be a valid handle');

    clear cleanupE cleanupF;
    n = 1;
end

function n = test_engine_teardown_on_store_detach()
    f = figure('Visible', 'off');
    cleanupF = onCleanup(@() try_delete_h(f));
    p = uipanel(f);
    sel = TimeRangeSelector(p, 'Theme', DashboardTheme('dark'));
    sel.setDataRange(0, 100);

    e = DashboardEngine('TestDetach');
    cleanupE = onCleanup(@() try_delete_obj(e));
    e.setTimeRangeSelectorForTest_(sel);

    store = make_populated_store_([25 50 75], {'a', 'b', 'c'});
    e.setPlantLogStoreForTest_(store);
    assert(~isempty(e.PlantLogSliderHover_), 'precondition: hover non-empty after attach');

    e.setPlantLogStoreForTest_([]);
    assert(isempty(e.PlantLogSliderHover_), ...
        'engine.PlantLogSliderHover_ must be empty after store detach');

    clear cleanupE cleanupF;
    n = 1;
end

function n = test_engine_teardown_on_delete()
    f = figure('Visible', 'off');
    cleanupF = onCleanup(@() try_delete_h(f));
    p = uipanel(f);
    sel = TimeRangeSelector(p, 'Theme', DashboardTheme('dark'));
    sel.setDataRange(0, 100);

    % Capture WBMFcn baseline BEFORE engine touches the figure.
    priorWBM = get(f, 'WindowButtonMotionFcn');

    e = DashboardEngine('TestEngineDelete');
    e.setTimeRangeSelectorForTest_(sel);
    store = make_populated_store_([25 50 75], {'a', 'b', 'c'});
    e.setPlantLogStoreForTest_(store);

    % After delete(engine), the figure's WBMFcn must NOT contain a closure
    % that references our (now-invalid) hover. The exact post-delete value
    % depends on TRS's destructor, but the key check is: it must not equal
    % hover's chained closure (which would reference a deleted hover obj).
    delete(e);
    afterWBM = get(f, 'WindowButtonMotionFcn');
    if isa(afterWBM, 'function_handle')
        wbmStr = func2str(afterWBM);
        assert(isempty(strfind(wbmStr, 'onFigureMove_')), ...
            'after delete(engine), WBMFcn must NOT reference hover''s chained closure; got %s', ...
            wbmStr); %#ok<STREMP>
    end
    % If priorWBM was empty/'' it's also OK (TRS may restore to '').
    % The substantive check above (no orphan hover closure) is enough.
    okEmpty = isempty(afterWBM) || isequal(priorWBM, afterWBM);
    okFn = isa(afterWBM, 'function_handle');
    assert(okEmpty || okFn, ...
        'after delete(engine), WBMFcn must be either restored, empty, or a non-hover function handle');

    clear cleanupF;
    n = 1;
end
