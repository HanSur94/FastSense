function test_multistatus_monitortag_bare()
%TEST_MULTISTATUS_MONITORTAG_BARE Regression test for 1015-UAT Test 1.
%   Pre-fix: MultiStatusWidget.refresh -> deriveColor throws
%   "Unrecognized method, property, or field 'Y' for class 'MonitorTag'"
%   when a bare MonitorTag handle is placed in obj.Sensors.
%   Post-fix: deriveColor dispatches on `isa(sensor, 'Tag')` and
%   routes Tag subclasses through valueAt(now). This test locks
%   that behavior in.
%
%   Octave cannot instantiate DashboardWidget subclasses (see
%   1009-01 deferred-items.md / test_multistatus_widget_tag.m for
%   the full reason). On Octave we therefore only enforce a
%   grep-based regression gate on MultiStatusWidget.m asserting
%   that deriveColor contains the `isa(sensor, 'Tag')` dispatch.

    add_paths_();

    % Grep gate (portable, runs on both MATLAB and Octave).
    test_derivecolor_has_tag_dispatch_();

    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('    Grep gate passed (classdef-dependent render tests SKIPPED on Octave).\n');
        return;
    end

    TagRegistry.clear();
    cleanup = onCleanup(@() TagRegistry.clear()); %#ok<NASGU>

    test_bare_monitortag_alarm_();
    test_bare_monitortag_ok_();
    test_bare_monitortag_does_not_throw_in_render_();

    fprintf('    All 4 multistatus_monitortag_bare tests passed.\n');
end

function test_derivecolor_has_tag_dispatch_()
    here = fileparts(mfilename('fullpath'));
    widgetFile = fullfile(here, '..', 'libs', 'Dashboard', 'MultiStatusWidget.m');
    src = fileread(widgetFile);
    % The fix MUST introduce a Tag dispatch in deriveColor.
    assert(~isempty(regexp(src, 'isa\(sensor,\s*''Tag''\)', 'once')), ...
        'test_multistatus_monitortag_bare: deriveColor missing `isa(sensor, ''Tag'')` dispatch (gap closure regressed).');
end

function test_bare_monitortag_alarm_()
    % Bare MonitorTag in alarm state -> renders alarm color.
    st = MakePhase1009Fixtures.makeSensorTag('mst_bare_alarm_src', 'X', 1:5, 'Y', [1 1 1 1 20]);
    m  = MakePhase1009Fixtures.makeMonitorTag('mst_bare_alarm_mon', st);

    w = MultiStatusWidget('Title', 'Bare Alarm');
    w.Sensors = {m};  % BARE handle, not wrapped in struct — the failing shape.

    fig = figure('Visible', 'off');
    cleanup = onCleanup(@() close(fig));  %#ok<NASGU>
    hp = uipanel(fig, 'Position', [0 0 1 1]);
    theme = DashboardTheme('dark');
    w.ParentTheme = theme;
    w.render(hp);  % Pre-fix: throws here.

    patches = findobj(w.hAxes, 'Type', 'patch');
    assert(~isempty(patches), 'render produced at least one patch');
    fc = get(patches(1), 'FaceColor');
    assert(max(abs(fc(:) - theme.StatusAlarmColor(:))) < 0.01, ...
        'bare MonitorTag alarm color matches theme.StatusAlarmColor');
end

function test_bare_monitortag_ok_()
    % Bare MonitorTag in ok state -> renders default (ok) color.
    st = MakePhase1009Fixtures.makeSensorTag('mst_bare_ok_src', 'X', 1:5, 'Y', [1 1 1 1 1]);
    m  = MakePhase1009Fixtures.makeMonitorTag('mst_bare_ok_mon', st);

    w = MultiStatusWidget('Title', 'Bare OK');
    w.Sensors = {m};

    fig = figure('Visible', 'off');
    cleanup = onCleanup(@() close(fig));  %#ok<NASGU>
    hp = uipanel(fig, 'Position', [0 0 1 1]);
    theme = DashboardTheme('dark');
    w.ParentTheme = theme;
    w.render(hp);

    patches = findobj(w.hAxes, 'Type', 'patch');
    assert(~isempty(patches));
    fc = get(patches(1), 'FaceColor');
    assert(max(abs(fc(:) - theme.StatusOkColor(:))) < 0.01, ...
        'bare MonitorTag ok color matches theme.StatusOkColor');
end

function test_bare_monitortag_does_not_throw_in_render_()
    % Demo-shape: 4 bare MonitorTag handles (mirrors buildOverviewPage.m:114-118).
    st1 = MakePhase1009Fixtures.makeSensorTag('mst_demo_a_src', 'X', 1:5, 'Y', [1 1 1 1 1]);
    st2 = MakePhase1009Fixtures.makeSensorTag('mst_demo_b_src', 'X', 1:5, 'Y', [1 1 1 1 20]);
    st3 = MakePhase1009Fixtures.makeSensorTag('mst_demo_c_src', 'X', 1:5, 'Y', [1 1 1 1 1]);
    st4 = MakePhase1009Fixtures.makeSensorTag('mst_demo_d_src', 'X', 1:5, 'Y', [1 1 1 1 20]);
    m1 = MakePhase1009Fixtures.makeMonitorTag('mst_demo_a_mon', st1);
    m2 = MakePhase1009Fixtures.makeMonitorTag('mst_demo_b_mon', st2);
    m3 = MakePhase1009Fixtures.makeMonitorTag('mst_demo_c_mon', st3);
    m4 = MakePhase1009Fixtures.makeMonitorTag('mst_demo_d_mon', st4);

    w = MultiStatusWidget('Title', 'All Monitors');
    w.Sensors = {m1, m2, m3, m4};

    fig = figure('Visible', 'off');
    cleanup = onCleanup(@() close(fig));  %#ok<NASGU>
    hp = uipanel(fig, 'Position', [0 0 1 1]);
    w.ParentTheme = DashboardTheme('dark');
    w.render(hp);
    patches = findobj(w.hAxes, 'Type', 'patch');
    assert(numel(patches) == 4, ...
        sprintf('4 bare MonitorTag handles -> 4 patches (got %d)', numel(patches)));
end

function add_paths_()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root);
    install();
    addpath(fullfile(repo_root, 'tests', 'suite'));
end
