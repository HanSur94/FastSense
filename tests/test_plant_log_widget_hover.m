function test_plant_log_widget_hover()
%TEST_PLANT_LOG_WIDGET_HOVER MATLAB-only function-style smoke for the widget hover tooltip.
%   Phase 1032 Plan 02 Task 2: PlantLogWidgetHover (chained-WBM hover helper
%   with full-metadata tooltip + overlap stacking + 40-char truncation +
%   '+N more' footer) + engine attach/detach lifecycle.
%
%   Cross-runtime SKIP on Octave because uipanel + uicontrol(text) parented
%   to a figure work very differently on Octave (and PlantLogWidgetHover
%   targets MATLAB R2020b+ uifigures).
%
%   Coverage:
%     1. Constructor input validation (PlantLogWidgetHover:invalidInput)
%     2. Bad-arg paths: nargin<3, empty parentFig, empty widgetAxes, non-function_handle lookupFn
%     3. simulateHoverAt_ returns entries within tolerance (array, not single pick)
%     4. Tooltip layout for SINGLE entry: timestamp + message + metadata-per-key
%     5. Metadata value newlines collapsed to single space
%     6. Metadata value 40 chars: NOT truncated; 41 chars: truncated to 39 + ellipsis
%     7. Long metadata KEY is never truncated
%     8. Overlap 2-10 entries: stacked with '-- ts --' headers, sorted ASC
%     9. >10 entries: first 10 shown, '+N more entries near this point' footer
%    10. delete(obj) restores prior WindowButtonMotionFcn unconditionally
%    11. Self-cleanup on widget axes destruction
%    12. Engine attach via setShowPlantLog(true, engine) populates WidgetHovers_
%    13. Engine detach via setShowPlantLog(false, engine) tears down hover

    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('    SKIP test_plant_log_widget_hover (Octave: uifigure-heavy).\n');
        return;
    end

    add_paths_via_install_only();
    nPassed = 0;

    nPassed = nPassed + test_constructor_validates_args();
    nPassed = nPassed + test_constructor_bad_arg_paths();
    nPassed = nPassed + test_simulate_returns_all_in_tolerance();
    nPassed = nPassed + test_single_entry_tooltip_layout();
    nPassed = nPassed + test_metadata_newline_collapse();
    nPassed = nPassed + test_metadata_value_truncation_boundary();
    nPassed = nPassed + test_long_metadata_key_not_truncated();
    nPassed = nPassed + test_overlap_stacking_headers();
    nPassed = nPassed + test_overlap_cap_with_plus_n_footer();
    nPassed = nPassed + test_delete_restores_wbm();
    nPassed = nPassed + test_self_cleanup_on_axes_destruction();
    nPassed = nPassed + test_engine_attaches_via_set_show_plant_log();
    nPassed = nPassed + test_engine_detaches_via_set_show_plant_log_false();

    assert(nPassed == 13, 'expected 13 sub-tests, got %d', nPassed);
    fprintf('    All 13 plant_log_widget_hover assertions passed.\n');
end

% =====================================================================
% PATH SETUP
% =====================================================================

function add_paths_via_install_only()
    thisDir = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(thisDir);
    addpath(repoRoot);
    install();
    assert(~isempty(which('PlantLogWidgetHover')), ...
        'PlantLogWidgetHover must resolve after install()');
end

% =====================================================================
% Fixture builders
% =====================================================================

function [f, ax] = make_offscreen_figure_with_axes_(xLim)
    f = figure('Visible', 'off', 'Units', 'pixels', 'Position', [10 10 800 600]);
    ax = axes('Parent', f, 'Units', 'pixels', 'Position', [40 40 700 500]);
    set(ax, 'XLim', xLim);
end

function try_delete_h(h)
    try
        if ~isempty(h) && ishandle(h), delete(h); end
    catch, end
end

function try_delete_obj(o)
    try
        if ~isempty(o) && isvalid(o), delete(o); end
    catch, end
end

function flat = flatten_tooltip_string_(str)
%FLATTEN_TOOLTIP_STRING_ Coerce uicontrol String into a single char row.
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

% =====================================================================
% Sub-tests
% =====================================================================

function n = test_constructor_validates_args()
    [f, ax] = make_offscreen_figure_with_axes_([0 100]);
    cleanupF = onCleanup(@() try_delete_h(f));
    lookup = @(t0, t1) [];
    h = PlantLogWidgetHover(f, ax, lookup);
    cleanupH = onCleanup(@() try_delete_obj(h));
    assert(isvalid(h), 'constructor must produce a valid handle');
    clear cleanupH cleanupF;
    n = 1;
end

function n = test_constructor_bad_arg_paths()
    threw = false;
    try, PlantLogWidgetHover(); catch ME, threw = strcmp(ME.identifier, 'PlantLogWidgetHover:invalidInput'); end
    assert(threw, 'nargin<3 must throw PlantLogWidgetHover:invalidInput');

    [f, ax] = make_offscreen_figure_with_axes_([0 100]);
    cleanupF = onCleanup(@() try_delete_h(f));

    threw = false;
    try, PlantLogWidgetHover([], ax, @(t0,t1) []); catch ME, threw = strcmp(ME.identifier, 'PlantLogWidgetHover:invalidInput'); end
    assert(threw, 'empty parentFig must throw');

    threw = false;
    try, PlantLogWidgetHover(f, [], @(t0,t1) []); catch ME, threw = strcmp(ME.identifier, 'PlantLogWidgetHover:invalidInput'); end
    assert(threw, 'empty widgetAxes must throw');

    threw = false;
    try, PlantLogWidgetHover(f, ax, 'not a fn'); catch ME, threw = strcmp(ME.identifier, 'PlantLogWidgetHover:invalidInput'); end
    assert(threw, 'non-function_handle lookupFn must throw');

    clear cleanupF;
    n = 1;
end

function n = test_simulate_returns_all_in_tolerance()
    [f, ax] = make_offscreen_figure_with_axes_([0 100]);
    cleanupF = onCleanup(@() try_delete_h(f));
    s = PlantLogStore('x');
    s.addEntries([ ...
        PlantLogEntry('Timestamp', 49.9, 'Message', 'a', 'Metadata', struct()), ...
        PlantLogEntry('Timestamp', 50.0, 'Message', 'b', 'Metadata', struct()), ...
        PlantLogEntry('Timestamp', 80.0, 'Message', 'c', 'Metadata', struct())]);
    h = PlantLogWidgetHover(f, ax, @(t0, t1) s.getEntriesInRange(t0, t1));
    cleanupH = onCleanup(@() try_delete_obj(h));
    picks = h.simulateHoverAt_(50.0);
    assert(numel(picks) >= 2, ...
        'expected >=2 picks within tolerance at x=50; got %d', numel(picks));
    clear cleanupH cleanupF;
    n = 1;
end

function n = test_single_entry_tooltip_layout()
    [f, ax] = make_offscreen_figure_with_axes_([0 100]);
    cleanupF = onCleanup(@() try_delete_h(f));
    ts = datenum('2025-01-15 12:34:56'); %#ok<DATNM>
    set(ax, 'XLim', [ts - 1, ts + 1]);
    md = struct('unit', 'ZK-12', 'shift', 'B', 'operator', 'jdoe');
    s = PlantLogStore('x');
    s.addEntries(PlantLogEntry('Timestamp', ts, ...
        'Message', 'pump on', 'Metadata', md));
    h = PlantLogWidgetHover(f, ax, @(t0, t1) s.getEntriesInRange(t0, t1));
    cleanupH = onCleanup(@() try_delete_obj(h));
    picks = h.simulateHoverAt_(ts);
    assert(~isempty(picks), 'must pick the single entry');
    str = h.getCurrentTooltipString_();
    flat = flatten_tooltip_string_(str);
    expectedTs = datestr(ts, 'yyyy-mm-dd HH:MM:SS'); %#ok<DATST>
    assert(~isempty(strfind(flat, expectedTs)), ...
        'tooltip must contain datestr timestamp; got "%s"', flat); %#ok<STREMP>
    assert(~isempty(strfind(flat, 'pump on')), ...
        'tooltip must contain message; got "%s"', flat); %#ok<STREMP>
    assert(~isempty(strfind(flat, 'unit: ZK-12')), ...
        'tooltip must include "unit: ZK-12" line; got "%s"', flat); %#ok<STREMP>
    assert(~isempty(strfind(flat, 'shift: B')), ...
        'tooltip must include "shift: B"; got "%s"', flat); %#ok<STREMP>
    assert(~isempty(strfind(flat, 'operator: jdoe')), ...
        'tooltip must include "operator: jdoe"; got "%s"', flat); %#ok<STREMP>
    clear cleanupH cleanupF;
    n = 1;
end

function n = test_metadata_newline_collapse()
    [f, ax] = make_offscreen_figure_with_axes_([0 100]);
    cleanupF = onCleanup(@() try_delete_h(f));
    md = struct('notes', sprintf('line1\nline2\nline3'));
    s = PlantLogStore('x');
    s.addEntries(PlantLogEntry('Timestamp', 50, 'Message', 'm', 'Metadata', md));
    h = PlantLogWidgetHover(f, ax, @(t0, t1) s.getEntriesInRange(t0, t1));
    cleanupH = onCleanup(@() try_delete_obj(h));
    h.simulateHoverAt_(50);
    str = h.getCurrentTooltipString_();
    flat = flatten_tooltip_string_(str);
    % The collapsed value should appear as a single line "notes: line1 line2 line3".
    assert(~isempty(strfind(flat, 'notes: line1 line2 line3')), ...
        'metadata embedded newlines must collapse to single space; got "%s"', flat); %#ok<STREMP>
    clear cleanupH cleanupF;
    n = 1;
end

function n = test_metadata_value_truncation_boundary()
    [f, ax] = make_offscreen_figure_with_axes_([0 100]);
    cleanupF = onCleanup(@() try_delete_h(f));
    val40 = repmat('a', 1, 40);
    val41 = repmat('b', 1, 41);
    md = struct('k40', val40, 'k41', val41);
    s = PlantLogStore('x');
    s.addEntries(PlantLogEntry('Timestamp', 50, 'Message', 'm', 'Metadata', md));
    h = PlantLogWidgetHover(f, ax, @(t0, t1) s.getEntriesInRange(t0, t1));
    cleanupH = onCleanup(@() try_delete_obj(h));
    h.simulateHoverAt_(50);
    str = h.getCurrentTooltipString_();
    flat = flatten_tooltip_string_(str);
    % 40-char value: full string present, no ellipsis added.
    assert(~isempty(strfind(flat, ['k40: ' val40])), ...
        '40-char value must be preserved verbatim; got "%s"', flat); %#ok<STREMP>
    % 41-char value: truncated to 39 chars + ellipsis (Unicode char(8230) or '...').
    truncated39 = repmat('b', 1, 39);
    has_unicode = ~isempty(strfind(flat, ['k41: ' truncated39 char(8230)])); %#ok<STREMP>
    has_ascii   = ~isempty(strfind(flat, ['k41: ' truncated39 char(8230)])); %#ok<STREMP>
    assert(has_unicode || has_ascii, ...
        '41-char value must be truncated to 39 + ellipsis; got "%s"', flat);
    assert(isempty(strfind(flat, ['k41: ' val41])), ...
        'full 41-char value must NOT appear in tooltip; got "%s"', flat); %#ok<STREMP>
    clear cleanupH cleanupF;
    n = 1;
end

function n = test_long_metadata_key_not_truncated()
    [f, ax] = make_offscreen_figure_with_axes_([0 100]);
    cleanupF = onCleanup(@() try_delete_h(f));
    % MATLAB field names cap at 63 chars; use a long but legal name.
    longKey = repmat('K', 1, 50);
    md = struct(longKey, 'v');
    s = PlantLogStore('x');
    s.addEntries(PlantLogEntry('Timestamp', 50, 'Message', 'm', 'Metadata', md));
    h = PlantLogWidgetHover(f, ax, @(t0, t1) s.getEntriesInRange(t0, t1));
    cleanupH = onCleanup(@() try_delete_obj(h));
    h.simulateHoverAt_(50);
    str = h.getCurrentTooltipString_();
    flat = flatten_tooltip_string_(str);
    assert(~isempty(strfind(flat, [longKey ': v'])), ...
        '50-char key must render verbatim; got "%s"', flat); %#ok<STREMP>
    clear cleanupH cleanupF;
    n = 1;
end

function n = test_overlap_stacking_headers()
    [f, ax] = make_offscreen_figure_with_axes_([0 100]);
    cleanupF = onCleanup(@() try_delete_h(f));
    ts1 = datenum('2026-05-13 14:32:01'); %#ok<DATNM>
    ts2 = ts1 + 2/86400;   % +2s
    ts3 = ts1 + 5/86400;   % +5s
    set(ax, 'XLim', [ts1 - 1, ts1 + 1]);
    s = PlantLogStore('x');
    s.addEntries([ ...
        PlantLogEntry('Timestamp', ts3, 'Message', 'c', 'Metadata', struct()), ...
        PlantLogEntry('Timestamp', ts1, 'Message', 'a', 'Metadata', struct()), ...
        PlantLogEntry('Timestamp', ts2, 'Message', 'b', 'Metadata', struct())]);
    h = PlantLogWidgetHover(f, ax, @(t0, t1) s.getEntriesInRange(t0, t1));
    cleanupH = onCleanup(@() try_delete_obj(h));
    picks = h.simulateHoverAt_(ts2);
    assert(numel(picks) == 3, 'expected 3 picks; got %d', numel(picks));
    str = h.getCurrentTooltipString_();
    flat = flatten_tooltip_string_(str);
    % Three '--' headers (one per stacked entry).
    headerCount = numel(strfind(flat, '-- ')); %#ok<STREMP>
    assert(headerCount >= 3, ...
        'expected at least 3 stacking headers; got %d', headerCount);
    % Order: a (ts1) before b (ts2) before c (ts3).
    aPos = strfind(flat, 'a'); %#ok<STREMP>
    bPos = strfind(flat, 'b'); %#ok<STREMP>
    cPos = strfind(flat, 'c'); %#ok<STREMP>
    assert(~isempty(aPos) && ~isempty(bPos) && ~isempty(cPos), ...
        'all three messages must appear');
    assert(aPos(1) < bPos(1) && bPos(1) < cPos(1), ...
        'entries must be sorted by Timestamp ASC; got positions %d/%d/%d', aPos(1), bPos(1), cPos(1));
    clear cleanupH cleanupF;
    n = 1;
end

function n = test_overlap_cap_with_plus_n_footer()
    [f, ax] = make_offscreen_figure_with_axes_([0 100]);
    cleanupF = onCleanup(@() try_delete_h(f));
    base = datenum('2026-05-13 14:32:01'); %#ok<DATNM>
    set(ax, 'XLim', [base - 1, base + 1]);
    s = PlantLogStore('x');
    nEntries = 13;
    arr = [];
    for k = 1:nEntries
        e = PlantLogEntry('Timestamp', base + (k-1)/86400, ...
            'Message', sprintf('msg%d', k), 'Metadata', struct());
        if isempty(arr), arr = e; else, arr(end+1) = e; end %#ok<AGROW>
    end
    s.addEntries(arr);
    h = PlantLogWidgetHover(f, ax, @(t0, t1) s.getEntriesInRange(t0, t1));
    cleanupH = onCleanup(@() try_delete_obj(h));
    picks = h.simulateHoverAt_(base + 6/86400);
    assert(numel(picks) == nEntries, ...
        'expected %d picks; got %d', nEntries, numel(picks));
    str = h.getCurrentTooltipString_();
    flat = flatten_tooltip_string_(str);
    expectedFooter = sprintf('+%d more entries near this point', nEntries - 10);
    assert(~isempty(strfind(flat, expectedFooter)), ...
        'tooltip must include the +N more footer "%s"; got "%s"', expectedFooter, flat); %#ok<STREMP>
    clear cleanupH cleanupF;
    n = 1;
end

function n = test_delete_restores_wbm()
    [f, ax] = make_offscreen_figure_with_axes_([0 100]);
    cleanupF = onCleanup(@() try_delete_h(f));
    customWBM = @(s, e) disp('original');
    set(f, 'WindowButtonMotionFcn', customWBM);
    priorWBM = get(f, 'WindowButtonMotionFcn');
    h = PlantLogWidgetHover(f, ax, @(t0, t1) []);
    duringWBM = get(f, 'WindowButtonMotionFcn');
    assert(~isequal(duringWBM, priorWBM), ...
        'WBMFcn must change while hover is alive');
    delete(h);
    afterWBM = get(f, 'WindowButtonMotionFcn');
    assert(isequal(afterWBM, priorWBM), ...
        'WBMFcn must be restored to prior value after delete');
    clear cleanupF;
    n = 1;
end

function n = test_self_cleanup_on_axes_destruction()
    [f, ax] = make_offscreen_figure_with_axes_([0 100]);
    cleanupF = onCleanup(@() try_delete_h(f));
    h = PlantLogWidgetHover(f, ax, @(t0, t1) []);
    delete(ax);
    drawnow;
    % After axes destruction, the hover should self-cleanup; calling delete
    % again must not throw.
    threw = false;
    try
        if isvalid(h), delete(h); end
    catch
        threw = true;
    end
    assert(~threw, 'delete on self-cleaned-up hover must not throw');
    clear cleanupF;
    n = 1;
end

function n = test_engine_attaches_via_set_show_plant_log()
    eng = DashboardEngine('whtest');
    cleanupE = onCleanup(@() try_delete_obj(eng));
    s = PlantLogStore('x');
    s.addEntries(PlantLogEntry('Timestamp', 100, 'Message', 'm', 'Metadata', struct()));
    eng.setPlantLogStoreForTest_(s);
    widget = FastSenseWidget('Title', 'wt', ...
        'Description', 'descr so chrome renders', 'XData', 0:10, 'YData', sin(0:10));
    widget.Position = [1 1 6 2];
    eng.addWidget(widget);
    eng.render();
    cleanupF = onCleanup(@() try_delete_h(eng.hFigure));
    try set(eng.hFigure, 'Visible', 'off'); catch, end
    widget.setShowPlantLog(true, eng);
    pairs = eng.WidgetHovers_;
    assert(~isempty(pairs), 'WidgetHovers_ must be populated after attach');
    found = false;
    for k = 1:numel(pairs)
        pair = pairs{k};
        if numel(pair) == 2 && pair{1} == widget && isa(pair{2}, 'PlantLogWidgetHover')
            found = true; break;
        end
    end
    assert(found, 'attached hover for this widget must appear in WidgetHovers_');
    clear cleanupF cleanupE;
    n = 1;
end

function n = test_engine_detaches_via_set_show_plant_log_false()
    eng = DashboardEngine('whtest2');
    cleanupE = onCleanup(@() try_delete_obj(eng));
    s = PlantLogStore('x');
    s.addEntries(PlantLogEntry('Timestamp', 100, 'Message', 'm', 'Metadata', struct()));
    eng.setPlantLogStoreForTest_(s);
    widget = FastSenseWidget('Title', 'wt', ...
        'Description', 'descr', 'XData', 0:10, 'YData', sin(0:10));
    widget.Position = [1 1 6 2];
    eng.addWidget(widget);
    eng.render();
    cleanupF = onCleanup(@() try_delete_h(eng.hFigure));
    try set(eng.hFigure, 'Visible', 'off'); catch, end
    widget.setShowPlantLog(true, eng);
    widget.setShowPlantLog(false, eng);
    pairs = eng.WidgetHovers_;
    found = false;
    for k = 1:numel(pairs)
        pair = pairs{k};
        if numel(pair) == 2 && ~isempty(pair{1}) && isvalid(pair{1}) && pair{1} == widget
            found = true; break;
        end
    end
    assert(~found, 'after setShowPlantLog(false), no hover pair for this widget must remain');
    clear cleanupF cleanupE;
    n = 1;
end
