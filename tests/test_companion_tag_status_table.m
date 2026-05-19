function test_companion_tag_status_table()
%TEST_COMPANION_TAG_STATUS_TABLE Pure-logic unit tests for TagStatusTableWindow.
%   Function-style tests (Octave-compatible) for the two static helper methods
%   on TagStatusTableWindow:
%     - buildRow_(tag) : 1x10 cell row, handles every Tag subclass + throwing tags.
%     - filterRows_(rows, query) : case-insensitive substring filter on Key+Name.
%
%   NO UI is built; tests do not require a uifigure or graphical environment.
%
%   See also TagStatusTableWindow, test_companion_filter_tags.

    add_companion_path();

    % Cache + restore TagRegistry across the whole run so we don't pollute the
    % caller. Each test resets the registry at entry via the local helper.
    cleanup = onCleanup(@() TagRegistry.clear());

    nPassed = 0; nFailed = 0;
    tests = { ...
        @testBuildRowForSensorTag_basic, ...
        @testBuildRowForSensorTag_emptyData, ...
        @testBuildRowForMonitorTag_alarm, ...
        @testBuildRowForMonitorTag_ok, ...
        @testBuildRowForStateTag, ...
        @testBuildRowForStateTag_emptyValueAt, ...
        @testBuildRowForCompositeTag, ...
        @testBuildRowForDerivedTag, ...
        @testBuildRow_getXYThrows, ...
        @testFilterRows_caseInsensitive, ...
        @testFilterRows_matchesKeyOrName, ...
        @testActivityLive_recentPosixTimestamp, ...
        @testActivityInactive_oldDatenumTimestamp, ...
        @testActivityInactive_emptyXY, ...
        @testActivityInactive_futureTimestamp, ...
        @testFilterRows_subsetFixture };
    for i = 1:numel(tests)
        name = func2str(tests{i});
        try
            tests{i}();
            nPassed = nPassed + 1;
            fprintf('  PASS: %s\n', name);
        catch err
            nFailed = nFailed + 1;
            fprintf(2, '  FAIL: %s\n    %s\n', name, err.message);
        end
    end
    fprintf('    %d passed, %d failed.\n', nPassed, nFailed);
    if nFailed > 0
        error('test_companion_tag_status_table:failures', ...
            '%d test(s) failed.', nFailed);
    end
end

% ===================== Tests =====================

function testBuildRowForSensorTag_basic()
    resetRegistry_();
    tag = SensorTag('k', 'Name', 'SensorName', 'Units', 'V', ...
        'Criticality', 'medium', 'Labels', {});
    tag.updateData([1 2 3], [10 20 30]);

    row = TagStatusTableWindow.buildRow_(tag);
    assertSize_(row, [1 11]);
    em = char(8212);
    assertEqual_(row{1}, 'k',           'Key');
    assertEqual_(row{2}, 'SensorName',  'Name');
    assertEqual_(row{3}, 'Sensor',      'Type');
    assertEqual_(row{4}, 'medium',      'Criticality');
    assertEqual_(row{5}, 'V',           'Units');
    assertEqual_(row{6}, '30.00',       'Latest');
    assertEqual_(row{7}, em,            'Status');
    % Last updated is iso-style "yyyy-mm-dd HH:MM:SS" since X=3 lies inside
    % the valid datenum range (year 1900+). The exact value depends on how
    % datetime interprets the scalar 3 as a datenum — Year 1 (or similar)
    % is OUT of the [1971, 2100] band, so the formatter falls back to %.3f.
    assertEqual_(row{8}, sprintf('%.3f', 3), 'Last updated (numeric fallback)');
    % Activity is "Inactive" because X(end)=3 is below 7e5 (the
    % datenum-or-posix anchor threshold in computeActivity_), so we cannot
    % map it to a wall-clock time and defensively render "Inactive".
    assertEqual_(row{9}, 'Inactive',    'Activity (unanchored X)');
    assertEqual_(row{10}, '3',          'Samples');
    assertEqual_(row{11}, '',           'Labels');
end

function testBuildRowForSensorTag_emptyData()
    resetRegistry_();
    tag = SensorTag('k_empty', 'Name', 'Empty', 'Units', 'A');

    row = TagStatusTableWindow.buildRow_(tag);
    em = char(8212);
    assertEqual_(row{1}, 'k_empty',  'Key');
    assertEqual_(row{6}, em,         'Latest');
    assertEqual_(row{7}, em,         'Status');
    assertEqual_(row{8}, em,         'Last updated');
    assertEqual_(row{9}, 'Inactive', 'Activity (empty XY)');
    assertEqual_(row{10}, '0',       'Samples');
end

function testBuildRowForMonitorTag_alarm()
    resetRegistry_();
    parent = SensorTag('parent_a', 'Name', 'Parent A');
    parent.updateData([1 2 3], [0 0 1]);
    mt = MonitorTag('mon_a', parent, @(x, y) y > 0.5, 'Name', 'Mon A');

    row = TagStatusTableWindow.buildRow_(mt);
    assertEqual_(row{1}, 'mon_a',   'Key');
    assertEqual_(row{3}, 'Monitor', 'Type');
    assertEqual_(row{7}, 'ALARM',   'Status');
    % Latest should be the numeric 1 formatted via the number rule.
    assertTrue_(any(strcmp(row{6}, {'1', '1.00', '1.000'})), ...
        sprintf('Latest expected ''1''/''1.00''/''1.000'', got ''%s''', row{6}));
end

function testBuildRowForMonitorTag_ok()
    resetRegistry_();
    parent = SensorTag('parent_b', 'Name', 'Parent B');
    parent.updateData([1 2 3], [1 1 1]);
    % AlarmOff condition trivially false -> never turns off after on; but here
    % we just want the OK case: y(end) = 0.
    parent.updateData([1 2 3], [1 0 0]);
    mt = MonitorTag('mon_b', parent, @(x, y) y > 0.5);

    row = TagStatusTableWindow.buildRow_(mt);
    assertEqual_(row{7}, 'OK', 'Status');
end

function testBuildRowForStateTag()
    resetRegistry_();
    st = StateTag('st_a', 'Name', 'StateA', ...
        'X', [1 2 3], 'Y', {'idle', 'run', 'stop'});

    row = TagStatusTableWindow.buildRow_(st);
    assertEqual_(row{1}, 'st_a',  'Key');
    assertEqual_(row{3}, 'State', 'Type');
    assertEqual_(row{6}, 'stop',  'Latest');
    assertEqual_(row{7}, 'stop',  'Status');
end

function testBuildRowForStateTag_emptyValueAt()
    resetRegistry_();
    % StateTag with no data: valueAt throws StateTag:emptyState.
    % buildRow_ must absorb the throw and render em-dashes.
    st = StateTag('st_empty', 'Name', 'StateEmpty');

    row = TagStatusTableWindow.buildRow_(st);
    em = char(8212);
    assertEqual_(row{6}, em,         'Latest');
    assertEqual_(row{7}, em,         'Status');
    assertEqual_(row{8}, em,         'Last updated');
    assertEqual_(row{9}, 'Inactive', 'Activity (empty state)');
    assertEqual_(row{10}, '0',       'Samples');
end

function testBuildRowForCompositeTag()
    resetRegistry_();
    parent = SensorTag('parent_c', 'Name', 'Parent C');
    parent.updateData([1 2 3], [0 1 0]);
    mt = MonitorTag('mon_c', parent, @(x, y) y > 0.5);
    ct = CompositeTag('cmp_a', 'or', 'Name', 'Composite A');
    ct.addChild(mt);

    row = TagStatusTableWindow.buildRow_(ct);
    em = char(8212);
    assertEqual_(row{1}, 'cmp_a',     'Key');
    assertEqual_(row{3}, 'Composite', 'Type');
    assertEqual_(row{7}, em,          'Status');
end

function testBuildRowForDerivedTag()
    resetRegistry_();
    parent = SensorTag('parent_d', 'Name', 'Parent D');
    parent.updateData([1 2 3], [10 20 30]);
    dt = DerivedTag('der_a', {parent}, ...
        @(parents) localDoubleY(parents), 'Name', 'Derived A');

    row = TagStatusTableWindow.buildRow_(dt);
    em = char(8212);
    assertEqual_(row{1}, 'der_a',   'Key');
    assertEqual_(row{3}, 'Derived', 'Type');
    assertEqual_(row{7}, em,        'Status');
end

function testBuildRow_getXYThrows()
    resetRegistry_();
    stub = ThrowingTagStub_('throw_tag');

    row = TagStatusTableWindow.buildRow_(stub);
    em = char(8212);
    assertEqual_(row{1}, 'throw_tag',  'Key');
    % Type/Crit/Units/Labels are from the stub's properties — still readable.
    assertEqual_(row{6}, em,           'Latest');
    assertEqual_(row{7}, em,           'Status');
    assertEqual_(row{8}, em,           'Last updated');
    assertEqual_(row{9}, 'Inactive',   'Activity (throwing getXY)');
    assertEqual_(row{10}, '0',         'Samples');
end

function testFilterRows_caseInsensitive()
    rows = { ...
        'press_a', 'Pressure A', 'Sensor', 'medium', '', '', '', '', '', '', ''; ...
        'temp_b',  'Temp B',     'Sensor', 'medium', '', '', '', '', '', '', '' };

    kept = TagStatusTableWindow.filterRows_(rows, 'PRESS');
    assertEqual_(size(kept, 1), 1, 'filter PRESS keeps 1 row');
    assertEqual_(kept{1, 1}, 'press_a', 'kept row Key');

    kept2 = TagStatusTableWindow.filterRows_(rows, '');
    assertEqual_(size(kept2, 1), 2, 'empty filter keeps all rows');

    kept3 = TagStatusTableWindow.filterRows_(rows, '   ');
    assertEqual_(size(kept3, 1), 2, 'whitespace-only filter keeps all rows');
end

function testFilterRows_matchesKeyOrName()
    rows = {'tag_x', 'Foo', 'Sensor', '', '', '', '', '', '', '', ''};

    keptName = TagStatusTableWindow.filterRows_(rows, 'foo');
    assertEqual_(size(keptName, 1), 1, 'filter ''foo'' matches Name');

    keptKey = TagStatusTableWindow.filterRows_(rows, 'tag');
    assertEqual_(size(keptKey, 1), 1, 'filter ''tag'' matches Key');

    keptNone = TagStatusTableWindow.filterRows_(rows, 'zzz');
    assertEqual_(size(keptNone, 1), 0, 'filter ''zzz'' matches nothing');
end

% ===================== Activity column (260519-bs4 patch) =====================

function testActivityLive_recentPosixTimestamp()
    % SensorTag whose X(end) is a recent posix-time timestamp -> Activity='Live'.
    % Use a fake "now" we control via the nowSeconds optional arg.
    resetRegistry_();
    tag = SensorTag('live_recent', 'Name', 'Live Recent');
    nowSec  = 1.7e9;             % posix-time-ish (definitely > 1e9)
    xLast   = nowSec - 30;       % 30 s ago, well under 300 s threshold
    tag.updateData([xLast - 2, xLast - 1, xLast], [1 2 3]);

    row = TagStatusTableWindow.buildRow_(tag, nowSec);
    assertEqual_(row{9}, 'Live', 'Activity should be Live for recent posix X');
end

function testActivityInactive_oldDatenumTimestamp()
    % SensorTag with X(end) ~ 10 minutes old in datenum days -> Activity='Inactive'.
    resetRegistry_();
    tag = SensorTag('inactive_old', 'Name', 'Inactive Old');
    nowSec  = 1.7e9;
    % Build datenum days such that (xPosix = (xDays - epoch)*86400) is 10min behind nowSec.
    epochDays = datenum(1970, 1, 1);
    xDays   = epochDays + (nowSec - 600) / 86400;  % 10 min < 300 s threshold? NO, 600 > 300.
    tag.updateData([xDays - 1, xDays], [1 2]);

    row = TagStatusTableWindow.buildRow_(tag, nowSec);
    assertEqual_(row{9}, 'Inactive', 'Activity should be Inactive for 10min-old datenum X');
end

function testActivityInactive_emptyXY()
    % SensorTag with no data -> Activity='Inactive' (samples=0 branch).
    resetRegistry_();
    tag = SensorTag('no_data', 'Name', 'No Data');

    row = TagStatusTableWindow.buildRow_(tag, 1.7e9);
    assertEqual_(row{9},  'Inactive', 'Activity should be Inactive when XY is empty');
    assertEqual_(row{10}, '0',         'Samples should be 0');
end

function testActivityInactive_futureTimestamp()
    % X(end) in the future (clock skew) -> defensively render Inactive.
    resetRegistry_();
    tag = SensorTag('future_ts', 'Name', 'Future TS');
    nowSec  = 1.7e9;
    xLast   = nowSec + 60;       % 60 s in the future
    tag.updateData([xLast - 1, xLast], [1 2]);

    row = TagStatusTableWindow.buildRow_(tag, nowSec);
    assertEqual_(row{9}, 'Inactive', 'Activity should be Inactive for future X (defensive)');
end

function testFilterRows_subsetFixture()
    % Regression guard for the search field: filter on a multi-row fixture
    % and confirm we get exactly the expected subset.
    rows = { ...
        'pressure_inlet',  'Pressure Inlet',  'Sensor',  '', '', '', '', '', '', '', ''; ...
        'pressure_outlet', 'Pressure Outlet', 'Sensor',  '', '', '', '', '', '', '', ''; ...
        'temp_a',          'Temperature A',   'Sensor',  '', '', '', '', '', '', '', ''; ...
        'state_machine',   'State Machine',   'State',   '', '', '', '', '', '', '', ''; ...
        'alarm_high',      'Alarm High',      'Monitor', '', '', '', '', '', '', '', '' };

    kept = TagStatusTableWindow.filterRows_(rows, 'pressure');
    assertEqual_(size(kept, 1), 2, 'filter ''pressure'' keeps 2 rows');
    assertEqual_(kept{1, 1}, 'pressure_inlet',  'first kept Key');
    assertEqual_(kept{2, 1}, 'pressure_outlet', 'second kept Key');

    keptUpper = TagStatusTableWindow.filterRows_(rows, 'TEMP');
    assertEqual_(size(keptUpper, 1), 1, 'filter ''TEMP'' case-insensitive');
    assertEqual_(keptUpper{1, 1}, 'temp_a', 'matched Key for ''TEMP''');

    keptNameOnly = TagStatusTableWindow.filterRows_(rows, 'machine');
    assertEqual_(size(keptNameOnly, 1), 1, 'filter ''machine'' matches Name');
    assertEqual_(keptNameOnly{1, 1}, 'state_machine', 'matched via Name field');
end

% ===================== Helpers =====================

function add_companion_path()
    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();
end

function resetRegistry_()
    TagRegistry.clear();
end

function out = localDoubleY(parents)
    [X, Y] = parents{1}.getXY();
    out = struct('x', X, 'y', 2 * Y);
end

function stub = ThrowingTagStub_(key)
    % ThrowingTagStub lives in tests/helpers/. install() adds tests/ via
    % addpath(genpath(...)), so the helpers/ subdirectory is on path.
    stub = ThrowingTagStub(key);
end

function assertSize_(actual, expected)
    sz = size(actual);
    if ~isequal(sz, expected)
        error('assertSize_:mismatch', ...
            'size mismatch: got [%s], expected [%s]', ...
            num2str(sz), num2str(expected));
    end
end

function assertEqual_(actual, expected, label)
    if nargin < 3, label = ''; end
    if isnumeric(actual) && isnumeric(expected) && isequal(actual, expected)
        return;
    end
    if ischar(actual) && ischar(expected) && strcmp(actual, expected)
        return;
    end
    if isnumeric(actual) && isscalar(actual) && isnumeric(expected) && isscalar(expected) ...
            && actual == expected
        return;
    end
    if isequal(actual, expected)
        return;
    end
    error('assertEqual_:mismatch', ...
        '%s: got <%s>, expected <%s>', ...
        label, valueToString_(actual), valueToString_(expected));
end

function assertTrue_(cond, msg)
    if ~cond
        if nargin < 2, msg = 'expected true'; end
        error('assertTrue_:false', '%s', msg);
    end
end

function s = valueToString_(v)
    if ischar(v)
        s = ['''', v, ''''];
    elseif isnumeric(v) && isscalar(v)
        s = num2str(v);
    elseif isnumeric(v)
        s = ['[', num2str(v(:)'), ']'];
    elseif iscell(v)
        s = sprintf('<%dx%d cell>', size(v, 1), size(v, 2));
    else
        s = sprintf('<%s>', class(v));
    end
end
