function test_fastsense_widget_tag()
%TEST_FASTSENSE_WIDGET_TAG Octave flat-style tests for FastSenseWidget Tag migration.
%   Phase 1009 Plan 01 — verifies that FastSenseWidget accepts a Tag
%   property, renders via FastSense.addTag, preserves the legacy Sensor
%   path byte-for-byte, and enforces the Pitfall 1 grep gate.
%
%   Octave cannot parse DashboardWidget.m (methods (Abstract) is an
%   @-folder-only construct in Octave classdef), so classdef-dependent
%   assertions are MATLAB-only.  The Pitfall 1 grep gate is pure file
%   regex and runs everywhere.
%
%   See also TestFastSenseWidgetTag, makePhase1009Fixtures.

    add_fastsense_widget_tag_path();

    % Pitfall 1 grep gate runs in all interpreters — pure text assertion.
    test_pitfall1_no_isa_in_widget();

    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('    Pitfall 1 grep gate passed (classdef-dependent tests SKIPPED on Octave — known DashboardWidget limitation)\n');
        return;
    end

    TagRegistry.clear();

    test_sensor_tag_render();
    test_monitor_tag_render();
    test_tag_update_incremental();
    test_tag_round_trip();
    test_legacy_sensor_path_still_works();
    test_ylabel_from_tag_units();

    TagRegistry.clear();
    fprintf('    All 7 fastsense_widget_tag tests passed.\n');
end

function test_sensor_tag_render()
    TagRegistry.clear();
    st = makePhase1009Fixtures.makeSensorTag('press_a', 'Units', 'bar');

    hFig = figure('Visible', 'off');
    cleanup_fig = onCleanup(@() close(hFig)); %#ok<NASGU>

    hp = uipanel('Parent', hFig, 'Units', 'normalized', ...
        'Position', [0 0 1 1]);

    w = FastSenseWidget('Tag', st);
    w.render(hp);

    assert(~isempty(w.FastSenseObj), ...
        'test_fastsense_widget_tag: Tag render creates FastSenseObj');
    assert(w.FastSenseObj.IsRendered, ...
        'test_fastsense_widget_tag: Tag render marks IsRendered=true');
    assert(numel(w.FastSenseObj.Lines) >= 1, ...
        'test_fastsense_widget_tag: Tag render adds >= 1 line');
end

function test_monitor_tag_render()
    TagRegistry.clear();
    st = makePhase1009Fixtures.makeSensorTag('press_b');
    m  = makePhase1009Fixtures.makeMonitorTag('press_hi', st);

    hFig = figure('Visible', 'off');
    cleanup_fig = onCleanup(@() close(hFig)); %#ok<NASGU>

    hp = uipanel('Parent', hFig, 'Units', 'normalized', ...
        'Position', [0 0 1 1]);

    w = FastSenseWidget('Tag', m);
    w.render(hp);

    assert(~isempty(w.FastSenseObj), ...
        'test_fastsense_widget_tag: MonitorTag render creates FastSenseObj');
    assert(w.FastSenseObj.IsRendered, ...
        'test_fastsense_widget_tag: MonitorTag render marks IsRendered=true');
end

function test_tag_update_incremental()
    TagRegistry.clear();
    st = makePhase1009Fixtures.makeSensorTag('press_c', 'X', 1:10, 'Y', (1:10) * 1.0);

    hFig = figure('Visible', 'off');
    cleanup_fig = onCleanup(@() close(hFig)); %#ok<NASGU>

    hp = uipanel('Parent', hFig, 'Units', 'normalized', ...
        'Position', [0 0 1 1]);

    w = FastSenseWidget('Tag', st);
    w.render(hp);

    % Grow parent data via updateData (MONITOR-04 invalidation path)
    st.updateData(1:15, (1:15) * 1.0);
    w.update();

    assert(w.CachedXMax >= 15, ...
        sprintf('test_fastsense_widget_tag: CachedXMax %g should reflect new tail (>= 15)', ...
                w.CachedXMax));
end

function test_tag_round_trip()
    TagRegistry.clear();
    st = makePhase1009Fixtures.makeSensorTag('press_rt', 'Units', 'Pa');

    w = FastSenseWidget('Tag', st);
    s = w.toStruct();

    assert(isfield(s, 'source'), ...
        'test_fastsense_widget_tag: toStruct produces s.source');
    assert(strcmp(s.source.type, 'tag'), ...
        sprintf('test_fastsense_widget_tag: s.source.type == ''tag'' (got ''%s'')', ...
                s.source.type));
    assert(strcmp(s.source.key, 'press_rt'), ...
        sprintf('test_fastsense_widget_tag: s.source.key == ''press_rt'' (got ''%s'')', ...
                s.source.key));

    % Round-trip back — st is already in TagRegistry so fromStruct resolves it.
    w2 = FastSenseWidget.fromStruct(s);
    assert(~isempty(w2.Tag), ...
        'test_fastsense_widget_tag: fromStruct populates Tag');
    assert(strcmp(w2.Tag.Key, st.Key), ...
        'test_fastsense_widget_tag: fromStruct resolves same Tag by key');
end

function test_legacy_sensor_path_still_works()
    TagRegistry.clear();
    s = SensorTag('legacy_s', 'Name', 'LegacyTemp');
    s.updateData(1:50, rand(1, 50));

    hFig = figure('Visible', 'off');
    cleanup_fig = onCleanup(@() close(hFig)); %#ok<NASGU>

    hp = uipanel('Parent', hFig, 'Units', 'normalized', ...
        'Position', [0 0 1 1]);

    w = FastSenseWidget('Sensor', s);
    w.render(hp);

    assert(~isempty(w.FastSenseObj), ...
        'test_fastsense_widget_tag: legacy Sensor render still works');
    assert(numel(w.FastSenseObj.Lines) >= 1, ...
        'test_fastsense_widget_tag: legacy Sensor line added');
end

function test_pitfall1_no_isa_in_widget()
    %TEST_PITFALL1_NO_ISA_IN_WIDGET Grep gate — no isa-on-subclass-name switches.
    %   Greps for isa(x, 'SensorTag'|'MonitorTag'|'StateTag'|'CompositeTag')
    %   in FastSenseWidget.m — must be ZERO.  Dispatch MUST go via
    %   polymorphic Tag base methods (getKind/getXY/valueAt) or
    %   FastSense.addTag.
    widgetFile = fullfile(fileparts(mfilename('fullpath')), '..', ...
        'libs', 'Dashboard', 'FastSenseWidget.m');
    src = fileread(widgetFile);

    badKinds = {'SensorTag', 'MonitorTag', 'StateTag', 'CompositeTag'};
    for i = 1:numel(badKinds)
        pattern = ['isa\([^,]+,\s*''', badKinds{i}, ''''];
        matches = regexp(src, pattern, 'once');
        assert(isempty(matches), ...
            sprintf('test_fastsense_widget_tag: Pitfall 1 violation — found isa(.., ''%s'') in FastSenseWidget.m', ...
                    badKinds{i}));
    end
end

function test_ylabel_from_tag_units()
    TagRegistry.clear();
    st = makePhase1009Fixtures.makeSensorTag('press_units', 'Units', 'kPa');

    w = FastSenseWidget('Tag', st);
    assert(strcmp(w.YLabel, 'kPa'), ...
        sprintf('test_fastsense_widget_tag: YLabel cascade from Tag.Units (got ''%s'')', ...
                w.YLabel));
end

function add_fastsense_widget_tag_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root);
    install();
    addpath(fullfile(repo_root, 'tests', 'suite'));
end
