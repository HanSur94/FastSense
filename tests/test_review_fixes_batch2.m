function test_review_fixes_batch2()
%TEST_REVIEW_FIXES_BATCH2 Regression tests for the 260610-hwj review-sweep fixes.
%
%   test_gauge_threshold_roundtrip   GaugeWidget restores Threshold (not Tag)
%                                    from a 'threshold' source on load
%   test_group_expanded_height       Collapsed GroupWidget can expand() after
%                                    a toStruct/fromStruct round-trip
%   test_theme_override_backfill     DashboardWidgetRegistry.fromStruct restores
%                                    themeOverride for widgets whose own
%                                    fromStruct does not
%   test_export_disk_backed_line     exportData writes full data for lines that
%                                    spilled to the SQLite DataStore

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();

    passed = 0;
    failed = 0;
    failures = {};

    % ------------------------------------------------------------------
    % GaugeWidget threshold round-trip
    % ------------------------------------------------------------------
    try
        parent = SensorTag('b2-gauge-parent', 'X', 1:100, 'Y', rand(1, 100));
        mt = MonitorTag('b2-gauge-mon', parent, @(x, y) y > 0.5, 'Name', 'B2 Mon');
        TagRegistry.register('b2-gauge-mon', mt);
        cleanupReg = onCleanup(@() TagRegistry.clear());

        w = GaugeWidget('Threshold', mt, 'Title', 'G');
        s = w.toStruct();
        assert(isfield(s, 'source') && strcmp(s.source.type, 'threshold'), ...
            'toStruct must serialize a threshold source');
        w2 = GaugeWidget.fromStruct(s);
        assert(~isempty(w2.Threshold), ...
            'fromStruct must restore Threshold (was assigned to Tag pre-fix)');
        assert(strcmp(char(w2.Threshold.Key), 'b2-gauge-mon'), ...
            'restored Threshold must resolve the serialized registry key');
        passed = passed + 1;
        fprintf('    test_gauge_threshold_roundtrip: PASS\n');
    catch ME
        failed = failed + 1;
        failures{end+1} = sprintf('test_gauge_threshold_roundtrip: %s', ME.message);
        fprintf('    test_gauge_threshold_roundtrip: FAIL: %s\n', ME.message);
    end

    % ------------------------------------------------------------------
    % GroupWidget ExpandedHeight round-trip
    % ------------------------------------------------------------------
    try
        g = GroupWidget('Label', 'B2', 'Mode', 'collapsible');
        g.Position = [1 1 12 6];
        g.collapse();
        assert(g.Position(4) < 6, 'collapse() must shrink the height');
        s = g.toStruct();
        assert(isfield(s, 'expandedHeight'), ...
            'toStruct must serialize expandedHeight for collapsed groups');
        g2 = GroupWidget.fromStruct(s);
        assert(g2.Collapsed, 'fromStruct must restore Collapsed');
        g2.expand();
        assert(g2.Position(4) == 6, ...
            sprintf('expand() after round-trip must restore height 6, got %g', ...
            g2.Position(4)));
        passed = passed + 1;
        fprintf('    test_group_expanded_height: PASS\n');
    catch ME
        failed = failed + 1;
        failures{end+1} = sprintf('test_group_expanded_height: %s', ME.message);
        fprintf('    test_group_expanded_height: FAIL: %s\n', ME.message);
    end

    % ------------------------------------------------------------------
    % themeOverride backfill via DashboardWidgetRegistry.fromStruct
    %
    % Octave gate: the registry's dispatch (feval('Class.fromStruct', s))
    % cannot resolve dotted static methods on Octave — a pre-existing
    % limitation of the registry path itself, unrelated to the backfill.
    % ------------------------------------------------------------------
    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('    test_theme_override_backfill: SKIPPED (Octave feval cannot resolve dotted statics)\n');
    else
    try
        w = NumberWidget('Title', 'N', 'ValueFcn', @() 1);
        w.ThemeOverride = struct('WidgetBackground', [0.1 0.2 0.3]);
        s = w.toStruct();
        assert(isfield(s, 'themeOverride'), 'base toStruct must write themeOverride');
        w2 = DashboardWidgetRegistry.fromStruct('number', s);
        assert(isfield(w2.ThemeOverride, 'WidgetBackground') && ...
            isequal(w2.ThemeOverride.WidgetBackground, [0.1 0.2 0.3]), ...
            'registry fromStruct must backfill themeOverride');
        passed = passed + 1;
        fprintf('    test_theme_override_backfill: PASS\n');
    catch ME
        failed = failed + 1;
        failures{end+1} = sprintf('test_theme_override_backfill: %s', ME.message);
        fprintf('    test_theme_override_backfill: FAIL: %s\n', ME.message);
    end
    end  % Octave gate

    % ------------------------------------------------------------------
    % exportData on a disk-backed line
    % ------------------------------------------------------------------
    try
        nPts = 5000;
        fig = figure('Visible', 'off');
        cleanupFig = onCleanup(@() close(fig));
        ax = axes('Parent', fig);
        fp = FastSense('Parent', ax, 'StorageMode', 'disk');  % force the DataStore path
        fp.addLine(1:nPts, sin((1:nPts) / 50), 'DisplayName', 'disky');
        fp.render();
        tmpCsv = [tempname() '.csv'];
        cleanupCsv = onCleanup(@() delete(tmpCsv));
        fp.exportData(tmpCsv, 'csv');
        data = csvread(tmpCsv, 1, 0);  % skip header row
        assert(size(data, 1) >= nPts, ...
            sprintf('disk-backed export must contain all %d rows, got %d', ...
            nPts, size(data, 1)));
        assert(any(isfinite(data(:, 2))) && any(data(:, 2) ~= 0), ...
            'exported Y column must contain real data, not blanks');
        passed = passed + 1;
        fprintf('    test_export_disk_backed_line: PASS\n');
    catch ME
        failed = failed + 1;
        failures{end+1} = sprintf('test_export_disk_backed_line: %s', ME.message);
        fprintf('    test_export_disk_backed_line: FAIL: %s\n', ME.message);
    end

    fprintf('\n    %d/%d tests passed.\n', passed, passed + failed);
    if failed > 0
        error('test_review_fixes_batch2:failed', ...
            '%d test(s) failed:\n  %s', failed, strjoin(failures, '\n  '));
    end
end
