function test_icon_card_widget_tag()
%TEST_ICON_CARD_WIDGET_TAG Octave flat tests for IconCardWidget Tag migration.
%   Phase 1009 Plan 02 — verifies IconCardWidget.Tag property (inherited
%   from DashboardWidget base), Tag-first value/state precedence, and
%   toStruct/fromStruct round-trip.
%
%   Octave cannot instantiate DashboardWidget subclasses (see Plan 1009-01
%   deferred-items.md).  Pitfall 1 grep gate runs on both interpreters;
%   classdef-dependent assertions are MATLAB-only.
%
%   See also TestIconCardWidgetTag, makePhase1009Fixtures.

    add_icon_card_widget_tag_path();

    test_pitfall1_no_isa_in_widget();

    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('    Pitfall 1 grep gate passed (classdef-dependent tests SKIPPED on Octave — known DashboardWidget limitation)\n');
        return;
    end

    TagRegistry.clear();
    test_tag_property_render();
    test_tag_ok_state();
    test_tag_precedence();
    test_tag_round_trip();
    test_legacy_threshold_path();
    test_legacy_sensor_path();

    TagRegistry.clear();
    fprintf('    All 7 icon_card_widget_tag tests passed.\n');
end

function test_pitfall1_no_isa_in_widget()
    here = fileparts(mfilename('fullpath'));
    widgetFile = fullfile(here, '..', 'libs', 'Dashboard', 'IconCardWidget.m');
    src = fileread(widgetFile);
    badKinds = {'SensorTag', 'MonitorTag', 'StateTag', 'CompositeTag'};
    for i = 1:numel(badKinds)
        pattern = ['isa\([^,]+,\s*''', badKinds{i}, ''''];
        matches = regexp(src, pattern, 'once');
        assert(isempty(matches), ...
            sprintf('test_icon_card_widget_tag: Pitfall 1 violation — isa(.., ''%s'') in IconCardWidget.m', ...
                    badKinds{i}));
    end
end

function test_tag_property_render()
    st = makePhase1009Fixtures.makeSensorTag('icw_f_a_src', 'X', 1:5, 'Y', [1 1 1 1 20]);
    m  = makePhase1009Fixtures.makeMonitorTag('icw_f_a_mon', st);

    w = IconCardWidget('Title', 'P', 'Tag', m);
    fig = figure('Visible', 'off');
    cleanup = onCleanup(@() close(fig));  %#ok<NASGU>
    hp = uipanel(fig, 'Position', [0 0 1 1]);
    theme = DashboardTheme('dark');
    w.ParentTheme = theme;
    w.render(hp);
    assert(strcmp(w.CurrentState, 'alarm'));
    fc = get(w.hIconShape, 'FaceColor');
    assert(max(abs(fc(:) - theme.StatusAlarmColor(:))) < 0.01);
end

function test_tag_ok_state()
    st = makePhase1009Fixtures.makeSensorTag('icw_f_ok_src', 'X', 1:5, 'Y', [1 1 1 1 1]);
    m  = makePhase1009Fixtures.makeMonitorTag('icw_f_ok_mon', st);
    w = IconCardWidget('Title', 'P', 'Tag', m);
    fig = figure('Visible', 'off');
    cleanup = onCleanup(@() close(fig));  %#ok<NASGU>
    hp = uipanel(fig, 'Position', [0 0 1 1]);
    w.ParentTheme = DashboardTheme('dark');
    w.render(hp);
    assert(strcmp(w.CurrentState, 'ok'));
end

function test_tag_precedence()
    st = makePhase1009Fixtures.makeSensorTag('icw_f_pr_src', 'X', 1:5, 'Y', [1 1 1 1 20]);
    m  = makePhase1009Fixtures.makeMonitorTag('icw_f_pr_mon', st);
    t = Threshold('icw_f_pr_thr', 'Direction', 'upper');
    t.addCondition(struct(), 10);

    w = IconCardWidget('Title', 'P', 'Tag', m, 'Threshold', t);
    assert(isempty(w.Threshold), 'Tag precedence clears Threshold');
    assert(~isempty(w.Tag));
end

function test_tag_round_trip()
    st = makePhase1009Fixtures.makeSensorTag('icw_f_rt_src');
    m  = makePhase1009Fixtures.makeMonitorTag('icw_f_rt_mon', st);
    w = IconCardWidget('Title', 'RT', 'Tag', m);
    s = w.toStruct();
    assert(isfield(s, 'source'));
    assert(strcmp(s.source.type, 'tag'));
    assert(strcmp(s.source.key, 'icw_f_rt_mon'));

    w2 = IconCardWidget.fromStruct(s);
    assert(~isempty(w2.Tag));
    assert(strcmp(w2.Tag.Key, 'icw_f_rt_mon'));
end

function test_legacy_threshold_path()
    t = Threshold('icw_f_legacy_thr', 'Direction', 'upper');
    t.addCondition(struct(), 10);
    w = IconCardWidget('Title', 'L', 'Threshold', t, 'StaticValue', 42);
    fig = figure('Visible', 'off');
    cleanup = onCleanup(@() close(fig));  %#ok<NASGU>
    hp = uipanel(fig, 'Position', [0 0 1 1]);
    w.ParentTheme = DashboardTheme('dark');
    w.render(hp);
    assert(strcmp(w.CurrentState, 'alarm'));
end

function test_legacy_sensor_path()
    s = SensorTag('icw_f_legacy_s', 'Name', 'L');
    s.updateData(1:10, (1:10) * 1.0);
    w = IconCardWidget('Title', 'S', 'Sensor', s);
    fig = figure('Visible', 'off');
    cleanup = onCleanup(@() close(fig));  %#ok<NASGU>
    hp = uipanel(fig, 'Position', [0 0 1 1]);
    w.ParentTheme = DashboardTheme('dark');
    w.render(hp);
    assert(~isempty(w.hPanel));
end

function add_icon_card_widget_tag_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root);
    install();
    addpath(fullfile(repo_root, 'tests', 'suite'));
end
