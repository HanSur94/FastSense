function test_multistatus_widget_tag()
%TEST_MULTISTATUS_WIDGET_TAG Octave flat tests for MultiStatusWidget Tag migration.
%   Phase 1009 Plan 02 — verifies the MultiStatusWidget 'tag' item field,
%   the CompositeTag expansion branch, the Tag-key string resolution via
%   TagRegistry, and the toStruct/fromStruct round-trip.
%
%   Octave cannot instantiate any DashboardWidget subclass because
%   Octave's classdef parser chokes on `methods (Abstract)` in the base
%   class (see Plan 1009-01 deferred-items.md).  This test therefore
%   enforces the Pitfall 1 grep gate on MultiStatusWidget.m in all
%   interpreters and skips classdef-dependent assertions on Octave.
%
%   See also TestMultiStatusWidgetTag, makePhase1009Fixtures.

    add_multistatus_widget_tag_path();

    % Pitfall 1 grep gate (pure text; runs on MATLAB and Octave).
    test_pitfall1_no_isa_in_widget();

    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('    Pitfall 1 grep gate passed (classdef-dependent tests SKIPPED on Octave — known DashboardWidget limitation)\n');
        return;
    end

    TagRegistry.clear();
    test_tag_item_alarm_status();
    test_tag_item_ok_status();
    test_tag_item_string_key();
    test_tag_round_trip();
    test_legacy_threshold_item();
    test_legacy_sensor_item();
    test_composite_tag_expansion();

    TagRegistry.clear();
    fprintf('    All 8 multistatus_widget_tag tests passed.\n');
end

function test_pitfall1_no_isa_in_widget()
    here = fileparts(mfilename('fullpath'));
    widgetFile = fullfile(here, '..', 'libs', 'Dashboard', 'MultiStatusWidget.m');
    src = fileread(widgetFile);

    % The `isa(item.tag, 'CompositeTag')` inside expandSensors_ is a
    % documented SHAPE-recursion exception — parallel to the existing
    % `isa(item.threshold, 'CompositeThreshold')` branch.  Only the
    % value-dispatch kinds (Sensor/Monitor/State) are forbidden.
    badKinds = {'SensorTag', 'MonitorTag', 'StateTag'};
    for i = 1:numel(badKinds)
        pattern = ['isa\([^,]+,\s*''', badKinds{i}, ''''];
        matches = regexp(src, pattern, 'once');
        assert(isempty(matches), ...
            sprintf('test_multistatus_widget_tag: Pitfall 1 violation — isa(.., ''%s'') in MultiStatusWidget.m', ...
                    badKinds{i}));
    end
end

function test_tag_item_alarm_status()
    st = makePhase1009Fixtures.makeSensorTag('mst_f_a_src', 'X', 1:5, 'Y', [1 1 1 1 20]);
    m  = makePhase1009Fixtures.makeMonitorTag('mst_f_a_mon', st);

    w = MultiStatusWidget('Title', 'S');
    w.Sensors = {struct('label', 'mon', 'tag', m)};

    fig = figure('Visible', 'off');
    cleanup = onCleanup(@() close(fig));  %#ok<NASGU>
    hp = uipanel(fig, 'Position', [0 0 1 1]);
    theme = DashboardTheme('dark');
    w.ParentTheme = theme;
    w.render(hp);
    patches = findobj(w.hAxes, 'Type', 'patch');
    assert(~isempty(patches), 'alarm item renders a patch');
    fc = get(patches(1), 'FaceColor');
    assert(max(abs(fc(:) - theme.StatusAlarmColor(:))) < 0.01, 'alarm color');
end

function test_tag_item_ok_status()
    st = makePhase1009Fixtures.makeSensorTag('mst_f_ok_src', 'X', 1:5, 'Y', [1 1 1 1 1]);
    m  = makePhase1009Fixtures.makeMonitorTag('mst_f_ok_mon', st);

    w = MultiStatusWidget('Title', 'S');
    w.Sensors = {struct('label', 'mon', 'tag', m)};

    fig = figure('Visible', 'off');
    cleanup = onCleanup(@() close(fig));  %#ok<NASGU>
    hp = uipanel(fig, 'Position', [0 0 1 1]);
    theme = DashboardTheme('dark');
    w.ParentTheme = theme;
    w.render(hp);
    patches = findobj(w.hAxes, 'Type', 'patch');
    assert(~isempty(patches));
    fc = get(patches(1), 'FaceColor');
    assert(max(abs(fc(:) - theme.StatusOkColor(:))) < 0.01, 'ok color');
end

function test_tag_item_string_key()
    st = makePhase1009Fixtures.makeSensorTag('mst_f_sk_src', 'X', 1:5, 'Y', [1 1 1 1 20]);
    makePhase1009Fixtures.makeMonitorTag('mst_f_sk_mon', st);

    w = MultiStatusWidget('Title', 'S');
    w.Sensors = {struct('label', 'mon', 'tag', 'mst_f_sk_mon')};

    fig = figure('Visible', 'off');
    cleanup = onCleanup(@() close(fig));  %#ok<NASGU>
    hp = uipanel(fig, 'Position', [0 0 1 1]);
    theme = DashboardTheme('dark');
    w.ParentTheme = theme;
    w.render(hp);
    patches = findobj(w.hAxes, 'Type', 'patch');
    assert(~isempty(patches));
    fc = get(patches(1), 'FaceColor');
    assert(max(abs(fc(:) - theme.StatusAlarmColor(:))) < 0.01);
end

function test_tag_round_trip()
    st = makePhase1009Fixtures.makeSensorTag('mst_f_rt_src');
    m  = makePhase1009Fixtures.makeMonitorTag('mst_f_rt_mon', st);

    w = MultiStatusWidget('Title', 'S');
    w.Sensors = {struct('label', 'alpha', 'tag', m)};
    s = w.toStruct();
    assert(iscell(s.items));
    assert(strcmp(s.items{1}.type, 'tag'));
    assert(strcmp(s.items{1}.key, 'mst_f_rt_mon'));

    w2 = MultiStatusWidget.fromStruct(s);
    assert(numel(w2.Sensors) == 1);
    e = w2.Sensors{1};
    assert(isstruct(e) && isfield(e, 'tag') && ~isempty(e.tag));
    assert(strcmp(e.tag.Key, 'mst_f_rt_mon'));
end

function test_legacy_threshold_item()
    t = Threshold('mst_f_legacy_thr', 'Direction', 'upper');
    t.addCondition(struct(), 50);
    item = struct('threshold', t, 'value', 42, 'label', 'Pump');

    w = MultiStatusWidget('Title', 'S');
    w.Sensors = {item};
    fig = figure('Visible', 'off');
    cleanup = onCleanup(@() close(fig));  %#ok<NASGU>
    hp = uipanel(fig, 'Position', [0 0 1 1]);
    w.ParentTheme = DashboardTheme('dark');
    w.render(hp);
    assert(~isempty(w.hAxes));
end

function test_legacy_sensor_item()
    s = Sensor('mst_f_legacy_s', 'Name', 'L');
    s.X = 1:10;
    s.Y = (1:10) * 1.0;
    w = MultiStatusWidget('Title', 'S');
    w.Sensors = {s};
    fig = figure('Visible', 'off');
    cleanup = onCleanup(@() close(fig));  %#ok<NASGU>
    hp = uipanel(fig, 'Position', [0 0 1 1]);
    w.ParentTheme = DashboardTheme('dark');
    w.render(hp);
    assert(~isempty(w.hAxes));
end

function test_composite_tag_expansion()
    st1 = makePhase1009Fixtures.makeSensorTag('mst_f_c1_src', 'X', 1:5, 'Y', [1 1 1 1 20]);
    st2 = makePhase1009Fixtures.makeSensorTag('mst_f_c2_src', 'X', 1:5, 'Y', [1 1 1 1 20]);
    m1 = makePhase1009Fixtures.makeMonitorTag('mst_f_c1_mon', st1);
    m2 = makePhase1009Fixtures.makeMonitorTag('mst_f_c2_mon', st2);
    ct = makePhase1009Fixtures.makeCompositeTag('mst_f_comp', {m1, m2}, 'and');

    w = MultiStatusWidget('Title', 'S');
    w.Sensors = {struct('label', 'composite', 'tag', ct)};
    fig = figure('Visible', 'off');
    cleanup = onCleanup(@() close(fig));  %#ok<NASGU>
    hp = uipanel(fig, 'Position', [0 0 1 1]);
    w.ParentTheme = DashboardTheme('dark');
    w.render(hp);
    patches = findobj(w.hAxes, 'Type', 'patch');
    assert(numel(patches) >= 3, 'composite expansion >= 3 patches');
end

function add_multistatus_widget_tag_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root);
    install();
    addpath(fullfile(repo_root, 'tests', 'suite'));
end
