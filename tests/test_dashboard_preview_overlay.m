function test_dashboard_preview_overlay()
%TEST_DASHBOARD_PREVIEW_OVERLAY Regression tests for the time-slider preview overlay.
%
%   Guards backlog item 999.3 — the lower dashboard time slider must show
%   one preview line per FastSenseWidget plus event markers across the full
%   data range. Five sub-tests:
%
%     1. Two FastSenseWidgets, 500 samples each: hPreviewLines non-empty,
%        each line has more than one point, and X data sits inside DataRange.
%     2. Single widget with only 50 samples (well below default nBuckets=200):
%        adaptive bucket count keeps hPreviewLines non-empty (this is the
%        regression that motivated this task).
%     3. Three synthetic events bound via FastSenseWidget.EventStore: after
%        render, hEventMarkers has exactly three handles.
%     4. Backward compat: an empty dashboard (number widget only, no data
%        bound) must render without error and produce zero preview lines and
%        zero markers (graceful degradation).
%     5. Performance smoke: PreviewCache_ short-circuits a second
%        getPreviewSeries call when inputs haven't changed.
%
%   On stock Octave (no Qt display) the TimeRangeSelector_ may be empty;
%   in that case the suite skips with a deliberate notice.

    thisDir = fileparts(mfilename('fullpath'));
    addpath(fullfile(thisDir, '..'));
    install();

    if ~probeTimeRangeSelectorAvailable_()
        fprintf('    test_dashboard_preview_overlay skipped: TimeRangeSelector unavailable on this runtime.\n');
        return;
    end

    nPassed = 0;
    nPassed = nPassed + runCase_(@() case_two_widgets_have_preview_lines(),       'two_widgets_have_preview_lines');
    nPassed = nPassed + runCase_(@() case_small_dataset_adaptive_buckets(),       'small_dataset_adaptive_buckets');
    nPassed = nPassed + runCase_(@() case_event_markers_from_widget_store(),      'event_markers_from_widget_store');
    nPassed = nPassed + runCase_(@() case_event_markers_colored_by_severity(),    'event_markers_colored_by_severity');
    nPassed = nPassed + runCase_(@() case_default_severity_backward_compat(),     'default_severity_backward_compat');
    nPassed = nPassed + runCase_(@() case_max_severity_wins_on_duplicate_times(), 'max_severity_wins_on_duplicate_times');
    nPassed = nPassed + runCase_(@() case_empty_dashboard_no_crash(),             'empty_dashboard_no_crash');
    nPassed = nPassed + runCase_(@() case_preview_cache_short_circuit(),          'preview_cache_short_circuit');
    nPassed = nPassed + runCase_(@() case_multipage_preview_follows_active_tab(), 'multipage_preview_follows_active_tab');
    nPassed = nPassed + runCase_(@() case_nested_group_preview_lines(),           'nested_group_preview_lines');

    try close(findall(0, 'Type', 'figure')); catch, end
    fprintf('    All %d tests passed.\n', nPassed);
end

% -------------------------------------------------------------------------

function n = runCase_(fn, name)
    try
        fn();
        n = 1;
    catch err
        fprintf('  CASE %s FAILED: %s\n', name, err.message);
        rethrow(err);
    end
end

function case_two_widgets_have_preview_lines()
    %CASE_TWO_WIDGETS_HAVE_PREVIEW_LINES Typical 500-sample dashboard.
    x  = linspace(0, 100, 500);
    y1 = sin(x * 0.1);
    y2 = cos(x * 0.1);
    d = DashboardEngine('preview-two');
    d.addWidget('fastsense', 'Title', 'w1', 'XData', x, 'YData', y1);
    d.addWidget('fastsense', 'Title', 'w2', 'XData', x, 'YData', y2);
    d.render();
    cleanup = onCleanup(@() closeDashboard_(d));  %#ok<NASGU>
    drawnow;

    sel = d.TimeRangeSelector_;
    assert(~isempty(sel.hPreviewLines), ...
        'Expected hPreviewLines non-empty after render with 500-sample widgets');
    assert(numel(sel.hPreviewLines) >= 1, ...
        sprintf('Expected at least 1 preview line, got %d', numel(sel.hPreviewLines)));

    dr = sel.DataRange;
    span = dr(2) - dr(1);
    pad = 0.05 * span;
    for k = 1:numel(sel.hPreviewLines)
        h = sel.hPreviewLines(k);
        assert(ishandle(h), sprintf('preview line %d not a valid handle', k));
        xd = get(h, 'XData');
        assert(numel(xd) > 1, sprintf('preview line %d has too few points (%d)', k, numel(xd)));
        assert(all(xd >= dr(1) - pad) && all(xd <= dr(2) + pad), ...
            sprintf('preview line %d X out of DataRange [%g %g]: [%g %g]', ...
                    k, dr(1), dr(2), min(xd), max(xd)));
    end
end

function case_small_dataset_adaptive_buckets()
    %CASE_SMALL_DATASET_ADAPTIVE_BUCKETS Regression: 50 samples must still preview.
    %   Default aggregator picks nBuckets in [50, 400]; with 50 samples,
    %   the old hard floor `if numel(x) < nBuckets, return` returned [].
    x = linspace(0, 100, 50);
    y = sin(x * 0.2);
    d = DashboardEngine('preview-small');
    d.addWidget('fastsense', 'Title', 'wsmall', 'XData', x, 'YData', y);
    d.render();
    cleanup = onCleanup(@() closeDashboard_(d));  %#ok<NASGU>
    drawnow;

    sel = d.TimeRangeSelector_;
    assert(~isempty(sel.hPreviewLines), ...
        'Adaptive bucket count failed: hPreviewLines empty for 50-sample widget');
    h = sel.hPreviewLines(1);
    xd = get(h, 'XData');
    assert(numel(xd) >= 4, ...
        sprintf('expected at least 4 buckets for 50 samples, got %d', numel(xd)));

    % Direct unit assertion: getPreviewSeries with nBuckets=200 must
    % return a non-empty struct (adaptive path engaged).
    ws = d.Widgets;
    s = ws{1}.getPreviewSeries(200);
    assert(~isempty(s), 'getPreviewSeries(200) returned [] on 50-sample widget');
    assert(isstruct(s) && isfield(s, 'xCenters'), ...
        'getPreviewSeries result missing xCenters');
    assert(numel(s.xCenters) >= 4, ...
        sprintf('expected adaptive bucket count >= 4, got %d', numel(s.xCenters)));
end

function case_event_markers_from_widget_store()
    %CASE_EVENT_MARKERS_FROM_WIDGET_STORE FastSenseWidget.EventStore -> markers.
    %   Mirrors how modern dashboards bind events: an EventStore on the
    %   widget, with ShowEventMarkers=true. Three events should produce
    %   three vertical marker handles.
    x = linspace(0, 100, 500);
    y = sin(x * 0.1);

    es = EventStore('');  % in-memory store (FilePath empty -> no save attempts)
    e1 = Event(10, 12, 'wevt', 'thr', 0.9, 'upper');
    e2 = Event(40, 42, 'wevt', 'thr', 0.9, 'upper');
    e3 = Event(80, 82, 'wevt', 'thr', 0.9, 'upper');
    es.append([e1, e2, e3]);

    d = DashboardEngine('preview-evt');
    w = FastSenseWidget('Title', 'wevt', 'XData', x, 'YData', y, ...
        'ShowEventMarkers', true, 'EventStore', es);
    d.addWidget(w);
    d.render();
    cleanup = onCleanup(@() closeDashboard_(d));  %#ok<NASGU>
    drawnow;

    sel = d.TimeRangeSelector_;
    assert(numel(sel.hEventMarkers) == 3, ...
        sprintf('expected 3 event markers, got %d', numel(sel.hEventMarkers)));

    % Sanity check: marker X positions match StartTime values.
    xs = zeros(1, numel(sel.hEventMarkers));
    for k = 1:numel(sel.hEventMarkers)
        xd = get(sel.hEventMarkers(k), 'XData');
        xs(k) = xd(1);
    end
    xs = sort(xs);
    expected = [10, 40, 80];
    assert(isequal(xs, expected), ...
        sprintf('marker X positions wrong: got %s, expected %s', mat2str(xs), mat2str(expected)));
end

function case_event_markers_colored_by_severity()
    %CASE_EVENT_MARKERS_COLORED_BY_SEVERITY Per-event severity drives marker color.
    %   Three events on one widget at distinct times, one each at
    %   Severity=1/2/3. After render the slider must contain three
    %   markers whose Color properties are all distinct from each other,
    %   and each must equal the expected severity-blended palette
    %   (StatusOk/Warn/Alarm blended 35/65 against AxesColor).
    x = linspace(0, 100, 500);
    y = sin(x * 0.1);

    es = EventStore('');
    e1 = Event(10, 12, 'wevt', 'thr', 0.9, 'upper');  e1.Severity = 1;
    e2 = Event(40, 42, 'wevt', 'thr', 0.9, 'upper');  e2.Severity = 2;
    e3 = Event(80, 82, 'wevt', 'thr', 0.9, 'upper');  e3.Severity = 3;
    es.append([e1, e2, e3]);

    d = DashboardEngine('preview-evt-color');
    w = FastSenseWidget('Title', 'wevt', 'XData', x, 'YData', y, ...
        'ShowEventMarkers', true, 'EventStore', es);
    d.addWidget(w);
    d.render();
    cleanup = onCleanup(@() closeDashboard_(d));  %#ok<NASGU>
    drawnow;

    sel = d.TimeRangeSelector_;
    assert(numel(sel.hEventMarkers) == 3, ...
        sprintf('expected 3 colored markers, got %d', numel(sel.hEventMarkers)));

    % Sort markers by X position so we can match Sev=1/2/3 deterministically.
    xs = zeros(1, 3);
    cols = zeros(3, 3);
    for k = 1:3
        xd = get(sel.hEventMarkers(k), 'XData');
        xs(k) = xd(1);
        cols(k, :) = get(sel.hEventMarkers(k), 'Color');
    end
    [~, order] = sort(xs);
    cols = cols(order, :);

    % Pairwise distinctness — three severity colors must produce three
    % visually different blended results.
    assert(~isequal(cols(1, :), cols(2, :)), 'sev1 and sev2 marker colors should differ');
    assert(~isequal(cols(2, :), cols(3, :)), 'sev2 and sev3 marker colors should differ');
    assert(~isequal(cols(1, :), cols(3, :)), 'sev1 and sev3 marker colors should differ');

    % Identity check — per-event-color path renders severityColor(theme,sev)
    % at full saturation (no AxesColor blend) so severity reads against any
    % theme background. Pinned by 260508-edd follow-up: prior 35/65 blend
    % crushed colors into the dark theme background.
    theme = d.getCachedTheme();
    expected = zeros(3, 3);
    expected(1, :) = severityColor(theme, 1);
    expected(2, :) = severityColor(theme, 2);
    expected(3, :) = severityColor(theme, 3);

    tol = 1e-6;
    for k = 1:3
        assert(max(abs(cols(k, :) - expected(k, :))) < tol, ...
            sprintf('marker %d color mismatch: got [%g %g %g], expected [%g %g %g]', ...
                    k, cols(k, 1), cols(k, 2), cols(k, 3), ...
                    expected(k, 1), expected(k, 2), expected(k, 3)));
    end
end

function case_default_severity_backward_compat()
    %CASE_DEFAULT_SEVERITY_BACKWARD_COMPAT Events without explicit Severity.
    %   Three events constructed without touching Severity (defaults to 1
    %   on the Event class). All three slider markers must therefore be
    %   the same uniform OK/info color — guards against a regression where
    %   the new colored path silently broke the legacy default-severity
    %   case.
    x = linspace(0, 100, 500);
    y = sin(x * 0.1);

    es = EventStore('');
    e1 = Event(15, 16, 'wevt', 'thr', 0.9, 'upper');  % Severity = 1 (default)
    e2 = Event(50, 51, 'wevt', 'thr', 0.9, 'upper');
    e3 = Event(85, 86, 'wevt', 'thr', 0.9, 'upper');
    es.append([e1, e2, e3]);

    d = DashboardEngine('preview-evt-default-sev');
    w = FastSenseWidget('Title', 'wevt', 'XData', x, 'YData', y, ...
        'ShowEventMarkers', true, 'EventStore', es);
    d.addWidget(w);
    d.render();
    cleanup = onCleanup(@() closeDashboard_(d));  %#ok<NASGU>
    drawnow;

    sel = d.TimeRangeSelector_;
    assert(numel(sel.hEventMarkers) == 3, ...
        sprintf('expected 3 markers (default severity), got %d', numel(sel.hEventMarkers)));

    cols = zeros(3, 3);
    for k = 1:3
        cols(k, :) = get(sel.hEventMarkers(k), 'Color');
    end
    assert(isequal(cols(1, :), cols(2, :)) && isequal(cols(2, :), cols(3, :)), ...
        'default-severity markers must all share the same uniform OK color');
end

function case_max_severity_wins_on_duplicate_times()
    %CASE_MAX_SEVERITY_WINS_ON_DUPLICATE_TIMES Cross-widget dedup picks max sev.
    %   Two FastSenseWidgets each carry an event at t=50 — one Severity=1,
    %   one Severity=3. After dedup the slider must show ONE marker at
    %   t=50 painted with the alarm-red blended color (sev=3 wins).
    x = linspace(0, 100, 500);
    y1 = sin(x * 0.1);
    y2 = cos(x * 0.1);

    esA = EventStore('');
    eA = Event(50, 51, 'wA', 'thr', 0.9, 'upper');  eA.Severity = 1;
    esA.append(eA);

    esB = EventStore('');
    eB = Event(50, 51, 'wB', 'thr', 0.9, 'upper');  eB.Severity = 3;
    esB.append(eB);

    d = DashboardEngine('preview-evt-dedup');
    wA = FastSenseWidget('Title', 'wA', 'XData', x, 'YData', y1, ...
        'ShowEventMarkers', true, 'EventStore', esA);
    wB = FastSenseWidget('Title', 'wB', 'XData', x, 'YData', y2, ...
        'ShowEventMarkers', true, 'EventStore', esB);
    d.addWidget(wA);
    d.addWidget(wB);
    d.render();
    cleanup = onCleanup(@() closeDashboard_(d));  %#ok<NASGU>
    drawnow;

    sel = d.TimeRangeSelector_;
    assert(numel(sel.hEventMarkers) == 1, ...
        sprintf('expected 1 deduped marker at t=50, got %d', numel(sel.hEventMarkers)));

    xd = get(sel.hEventMarkers(1), 'XData');
    assert(abs(xd(1) - 50) < 1e-9, ...
        sprintf('expected deduped marker at t=50, got t=%g', xd(1)));

    % Color must equal the sev=3 (alarm) full-saturation color, NOT sev=1.
    theme = d.getCachedTheme();
    expectedAlarm = severityColor(theme, 3);
    actual = get(sel.hEventMarkers(1), 'Color');
    assert(max(abs(actual - expectedAlarm)) < 1e-6, ...
        sprintf('deduped marker color must be sev=3 alarm; got [%g %g %g], expected [%g %g %g]', ...
                actual(1), actual(2), actual(3), ...
                expectedAlarm(1), expectedAlarm(2), expectedAlarm(3)));
end

function case_empty_dashboard_no_crash()
    %CASE_EMPTY_DASHBOARD_NO_CRASH Backward compat: no FastSense widgets.
    d = DashboardEngine('preview-empty');
    d.addWidget('number', 'Title', 'N', 'ValueFcn', @() 1, 'Position', [1 1 6 1]);
    d.render();
    cleanup = onCleanup(@() closeDashboard_(d));  %#ok<NASGU>
    drawnow;

    sel = d.TimeRangeSelector_;
    assert(~isempty(sel) && isa(sel, 'TimeRangeSelector'), ...
        'TimeRangeSelector_ should still construct on empty dashboards');
    assert(isempty(sel.hPreviewLines) || numel(sel.hPreviewLines) == 0, ...
        'expected no preview lines on data-less dashboard');
    assert(isempty(sel.hEventMarkers) || numel(sel.hEventMarkers) == 0, ...
        'expected no event markers on data-less dashboard');
end

function case_preview_cache_short_circuit()
    %CASE_PREVIEW_CACHE_SHORT_CIRCUIT PreviewCache_ avoids redundant minmax work.
    x  = linspace(0, 100, 1000);
    y  = sin(x * 0.1);
    w  = FastSenseWidget('Title', 'wcache', 'XData', x, 'YData', y);
    d  = DashboardEngine('preview-cache');
    d.addWidget(w);
    d.render();
    cleanup = onCleanup(@() closeDashboard_(d));  %#ok<NASGU>
    drawnow;

    s1 = w.getPreviewSeries(200);
    assert(~isempty(s1), 'first getPreviewSeries returned []');

    % Second call with identical (nBuckets, data shape) must produce a
    % bit-identical result via the cache (or an indistinguishable recompute).
    s2 = w.getPreviewSeries(200);
    assert(~isempty(s2), 'second getPreviewSeries returned []');
    assert(isequal(s1.xCenters, s2.xCenters), ...
        'cache short-circuit produced different xCenters');
    assert(isequal(s1.yMin, s2.yMin) && isequal(s1.yMax, s2.yMax), ...
        'cache short-circuit produced different yMin/yMax');

    % Light timing smoke (no hard threshold — flaky on shared runners).
    t1 = tic; for k = 1:5; w.getPreviewSeries(200); end; firstBatch = toc(t1);
    assert(firstBatch < 5.0, ...
        sprintf('preview pipeline too slow: 5 cached calls took %.3fs', firstBatch));
end

function case_multipage_preview_follows_active_tab()
    %CASE_MULTIPAGE_PREVIEW_FOLLOWS_ACTIVE_TAB KOV-01 regression.
    %   Build a 2-page dashboard with disjoint X ranges per page; assert
    %   the slider preview reflects ONLY the active page's widgets and
    %   that switching pages swaps which line is visible. Inverse of
    %   the (now-reverted) 260508-kau aggregation contract.
    x1 = linspace(0,   10,  500);
    y1 = sin(x1 * 0.1);
    x2 = linspace(200, 210, 500);
    y2 = cos(x2 * 0.1);

    d = DashboardEngine('preview-multipage-pertab');
    d.addPage('P1');
    d.addWidget('fastsense', 'Title', 'wP1', 'XData', x1, 'YData', y1);
    d.addPage('P2');
    d.switchPage(2);
    d.addWidget('fastsense', 'Title', 'wP2', 'XData', x2, 'YData', y2);
    d.switchPage(1);
    d.render();
    cleanup = onCleanup(@() closeDashboard_(d));  %#ok<NASGU>
    drawnow;

    % Initial render: P1 active. Expect a P1-range line, NO P2-range line.
    [nLow, nHigh] = classifyPreviewLines_(d.TimeRangeSelector_);
    assert(nLow  >= 1, ...
        sprintf('KOV-01 initial: expected >=1 preview line in [0,10] (active P1), got %d', nLow));
    assert(nHigh == 0, ...
        sprintf('KOV-01 initial: expected 0 preview lines in [200,210] (inactive P2), got %d', nHigh));

    % Switch to P2: P2 line appears, P1 line gone.
    d.switchPage(2);
    drawnow;
    [nLow, nHigh] = classifyPreviewLines_(d.TimeRangeSelector_);
    assert(nLow  == 0, ...
        sprintf('KOV-01 after switchPage(2): expected 0 preview lines in [0,10] (inactive P1), got %d', nLow));
    assert(nHigh >= 1, ...
        sprintf('KOV-01 after switchPage(2): expected >=1 preview line in [200,210] (active P2), got %d', nHigh));

    % Switch back to P1: P1 line returns, P2 line gone.
    d.switchPage(1);
    drawnow;
    [nLow, nHigh] = classifyPreviewLines_(d.TimeRangeSelector_);
    assert(nLow  >= 1, ...
        sprintf('KOV-01 reverse: expected >=1 preview line in [0,10] (active P1), got %d', nLow));
    assert(nHigh == 0, ...
        sprintf('KOV-01 reverse: expected 0 preview lines in [200,210] (inactive P2), got %d', nHigh));
end

function case_nested_group_preview_lines()
    %CASE_NESTED_GROUP_PREVIEW_LINES 260508-l2k regression.
    %   Build a single-page dashboard whose only top-level widget is a
    %   GroupWidget containing two FastSenseWidgets with disjoint Y
    %   ranges. Before 260508-l2k the slider preview iterated only
    %   top-level widgets and the Group's base getPreviewSeries() returns
    %   [], so no lines were drawn. After the fix the engine flattens
    %   the active page's widget list through getNestedWidgets() and
    %   each child contributes a preview line.
    x  = linspace(0, 100, 500);
    y1 = sin(x * 0.1);
    y2 = cos(x * 0.1) * 5;
    w1 = FastSenseWidget('Title', 'nestA', 'XData', x, 'YData', y1);
    w2 = FastSenseWidget('Title', 'nestB', 'XData', x, 'YData', y2);
    g  = GroupWidget('Label', 'Nested', 'Mode', 'panel');
    g.addChild(w1);
    g.addChild(w2);

    d = DashboardEngine('preview-nested-group');
    d.addWidget(g);
    d.render();
    cleanup = onCleanup(@() closeDashboard_(d));  %#ok<NASGU>
    drawnow;

    sel = d.TimeRangeSelector_;
    assert(~isempty(sel.hPreviewLines), ...
        'Expected hPreviewLines non-empty when widgets are nested in a GroupWidget (260508-l2k)');
    assert(numel(sel.hPreviewLines) == 2, ...
        sprintf('Expected 2 preview lines from nested Group children, got %d', numel(sel.hPreviewLines)));

    % Sanity check: each line's X data is non-trivial and inside the
    % overall data range. Mirrors case_two_widgets_have_preview_lines.
    dr = sel.DataRange;
    span = dr(2) - dr(1);
    pad = 0.05 * span;
    for k = 1:numel(sel.hPreviewLines)
        h = sel.hPreviewLines(k);
        assert(ishandle(h), sprintf('nested preview line %d not a valid handle', k));
        xd = get(h, 'XData');
        assert(numel(xd) > 1, sprintf('nested preview line %d has too few points (%d)', k, numel(xd)));
        assert(all(xd >= dr(1) - pad) && all(xd <= dr(2) + pad), ...
            sprintf('nested preview line %d X out of DataRange [%g %g]: [%g %g]', ...
                    k, dr(1), dr(2), min(xd), max(xd)));
    end
end

function [nLow, nHigh] = classifyPreviewLines_(sel)
    %CLASSIFYPREVIEWLINES_ Count preview lines whose X range falls in
    %   the P1 band [-1,12] (nLow) vs the P2 band [199,211] (nHigh).
    %   Mirrors the line-detection style used by case 1 / kau case.
    nLow  = 0;
    nHigh = 0;
    for k = 1:numel(sel.hPreviewLines)
        xd = get(sel.hPreviewLines(k), 'XData');
        xd = xd(:)';
        if isempty(xd), continue; end
        if all(xd >= -1) && all(xd <= 12)
            nLow = nLow + 1;
        elseif all(xd >= 199) && all(xd <= 211)
            nHigh = nHigh + 1;
        end
    end
end

% -------------------------------------------------------------------------

function tf = probeTimeRangeSelectorAvailable_()
    tf = false;
    try
        d = DashboardEngine('PreviewProbe');
        d.addWidget('number', 'Title', 'N', 'ValueFcn', @() 1, 'Position', [1 1 6 1]);
        d.render();
        tf = ~isempty(d.TimeRangeSelector_) && ...
             isa(d.TimeRangeSelector_, 'TimeRangeSelector');
        try
            if ~isempty(d.hFigure) && ishandle(d.hFigure)
                close(d.hFigure);
            end
        catch
        end
    catch
        tf = false;
    end
end

function closeDashboard_(d)
    try
        if ~isempty(d) && ~isempty(d.hFigure) && ishandle(d.hFigure)
            close(d.hFigure);
        end
    catch
    end
end
