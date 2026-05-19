function test_companion_tag_status_table()
%TEST_COMPANION_TAG_STATUS_TABLE Pure-logic unit tests for TagStatusTableWindow.
%   Function-style tests (Octave-compatible) for the three static helper methods
%   on TagStatusTableWindow:
%     - buildRow_(tag) : 1x12 cell row, handles every Tag subclass + throwing tags.
%     - filterRows_(rows, query) : case-insensitive substring filter on Key+Name.
%     - countEventsForTag_(tag) : O(1)-when-empty event count.
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
        @testFilterRows_subsetFixture, ...
        @testFilterRows_matchesUnitsField, ...
        @testFilterRows_matchesLabelsField, ...
        @testFilterRows_chipFiltersAndSemantics, ...
        @testFilterRows_emptyChipGroupExcludesAll, ...
        @testCountEventsForTag_noEventStore, ...
        @testCountEventsForTag_withStubbedEvents, ...
        @testBuildRow_includesEventsCountAtCol10, ...
        @testBuildRow_eventCountsByKeyBucketedMapWins };
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
    assertSize_(row, [1 12]);
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
    assertEqual_(row{9},  'Inactive',   'Activity (unanchored X)');
    assertEqual_(row{10}, '0',          'Events (no EventStore bound)');
    assertEqual_(row{11}, '3',          'Samples');
    assertEqual_(row{12}, '',           'Labels');
end

function testBuildRowForSensorTag_emptyData()
    resetRegistry_();
    tag = SensorTag('k_empty', 'Name', 'Empty', 'Units', 'A');

    row = TagStatusTableWindow.buildRow_(tag);
    em = char(8212);
    assertEqual_(row{1},  'k_empty',  'Key');
    assertEqual_(row{6},  em,         'Latest');
    assertEqual_(row{7},  em,         'Status');
    assertEqual_(row{8},  em,         'Last updated');
    assertEqual_(row{9},  'Inactive', 'Activity (empty XY)');
    assertEqual_(row{10}, '0',        'Events (no EventStore bound)');
    assertEqual_(row{11}, '0',        'Samples');
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
    assertEqual_(row{6},  em,         'Latest');
    assertEqual_(row{7},  em,         'Status');
    assertEqual_(row{8},  em,         'Last updated');
    assertEqual_(row{9},  'Inactive', 'Activity (empty state)');
    assertEqual_(row{10}, '0',        'Events (no EventStore bound)');
    assertEqual_(row{11}, '0',        'Samples');
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
    assertEqual_(row{1},  'throw_tag',  'Key');
    % Type/Crit/Units/Labels are from the stub's properties — still readable.
    assertEqual_(row{6},  em,           'Latest');
    assertEqual_(row{7},  em,           'Status');
    assertEqual_(row{8},  em,           'Last updated');
    assertEqual_(row{9},  'Inactive',   'Activity (throwing getXY)');
    assertEqual_(row{10}, '0',          'Events (no EventStore bound)');
    assertEqual_(row{11}, '0',          'Samples');
end

function testFilterRows_caseInsensitive()
    % 12-column fixture (Events col inserted at idx 10; Labels now at idx 12).
    rows = { ...
        'press_a', 'Pressure A', 'Sensor', 'medium', '', '', '', '', '', '', '', ''; ...
        'temp_b',  'Temp B',     'Sensor', 'medium', '', '', '', '', '', '', '', '' };

    kept = TagStatusTableWindow.filterRows_(rows, 'PRESS');
    assertEqual_(size(kept, 1), 1, 'filter PRESS keeps 1 row');
    assertEqual_(kept{1, 1}, 'press_a', 'kept row Key');

    kept2 = TagStatusTableWindow.filterRows_(rows, '');
    assertEqual_(size(kept2, 1), 2, 'empty filter keeps all rows');

    kept3 = TagStatusTableWindow.filterRows_(rows, '   ');
    assertEqual_(size(kept3, 1), 2, 'whitespace-only filter keeps all rows');
end

function testFilterRows_matchesKeyOrName()
    rows = {'tag_x', 'Foo', 'Sensor', '', '', '', '', '', '', '', '', ''};

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
    assertEqual_(row{11}, '0',         'Samples should be 0');
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
        'pressure_inlet',  'Pressure Inlet',  'Sensor',  '', '', '', '', '', '', '', '', ''; ...
        'pressure_outlet', 'Pressure Outlet', 'Sensor',  '', '', '', '', '', '', '', '', ''; ...
        'temp_a',          'Temperature A',   'Sensor',  '', '', '', '', '', '', '', '', ''; ...
        'state_machine',   'State Machine',   'State',   '', '', '', '', '', '', '', '', ''; ...
        'alarm_high',      'Alarm High',      'Monitor', '', '', '', '', '', '', '', '', '' };

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

% ===================== Broader search + chip filters (260519-bs4-04 patch) =====================

function testFilterRows_matchesUnitsField()
    % Search now matches the Units column (column 5). Mirrors the user's
    % "search for °C" workflow: a row with Units='°C' must match.
    rows = { ...
        'temp_a',  'Temp A',     'Sensor', 'medium', char([176, 67]), '', '', '', '', '', '', ''; ...
        'press_a', 'Pressure A', 'Sensor', 'medium', 'bar',           '', '', '', '', '', '', '' };

    keptDegree = TagStatusTableWindow.filterRows_(rows, char([176, 67]));
    assertEqual_(size(keptDegree, 1), 1, 'filter on Units degC keeps the temperature row');
    assertEqual_(keptDegree{1, 1}, 'temp_a', 'matched row key');

    keptBar = TagStatusTableWindow.filterRows_(rows, 'bar');
    assertEqual_(size(keptBar, 1), 1, 'filter ''bar'' on Units keeps press_a');
    assertEqual_(keptBar{1, 1}, 'press_a', 'matched row key');
end

function testFilterRows_matchesLabelsField()
    % Search must match the Labels column (column 12 since 260519-bs4-06),
    % which is a joined comma-separated string when there is more than one
    % label.
    rows = { ...
        'k1', 'Tag 1', 'Sensor', 'medium', '', '', '', '', '', '', '', 'plant, north'; ...
        'k2', 'Tag 2', 'Sensor', 'medium', '', '', '', '', '', '', '', 'plant, south'; ...
        'k3', 'Tag 3', 'Sensor', 'medium', '', '', '', '', '', '', '', '' };

    keptNorth = TagStatusTableWindow.filterRows_(rows, 'north');
    assertEqual_(size(keptNorth, 1), 1, 'filter ''north'' on Labels keeps 1 row');
    assertEqual_(keptNorth{1, 1}, 'k1', 'matched row key');

    keptPlant = TagStatusTableWindow.filterRows_(rows, 'plant');
    assertEqual_(size(keptPlant, 1), 2, 'filter ''plant'' on Labels keeps 2 rows');
end

function testFilterRows_chipFiltersAndSemantics()
    % Verifies AND-across-groups, OR-within-group semantics for the chip
    % filters. Build a small fixture with diverse Type/Crit/Activity cells.
    % 12-column shape: ..., Activity(9), Events(10), Samples(11), Labels(12).
    rows = { ...
        'k1', 'Sensor Hi Live',   'Sensor',    'high',   '', '', '', '', 'Live',     '', '', ''; ...
        'k2', 'Sensor Med Live',  'Sensor',    'medium', '', '', '', '', 'Live',     '', '', ''; ...
        'k3', 'Sensor Hi Inact',  'Sensor',    'high',   '', '', '', '', 'Inactive', '', '', ''; ...
        'k4', 'Monitor Hi Live',  'Monitor',   'high',   '', '', '', '', 'Live',     '', '', ''; ...
        'k5', 'Compos Low Live',  'Composite', 'low',    '', '', '', '', 'Live',     '', '', ''; ...
        'k6', 'State Med Inact',  'State',     'medium', '', '', '', '', 'Inactive', '', '', '' };

    % Type=Sensor only (OR within Type group), all crits, all activities.
    kept = TagStatusTableWindow.filterRows_(rows, '', ...
        {'sensor'}, {'low', 'medium', 'high', 'safety'}, {'live', 'inactive'});
    assertEqual_(size(kept, 1), 3, 'Type=Sensor keeps 3 sensor rows');

    % Type=Sensor AND Crit=high -> only rows with both.
    kept2 = TagStatusTableWindow.filterRows_(rows, '', ...
        {'sensor'}, {'high'}, {'live', 'inactive'});
    assertEqual_(size(kept2, 1), 2, 'Sensor+high keeps k1 and k3');
    assertTrue_(any(strcmp(kept2(:, 1), 'k1')), 'kept includes k1');
    assertTrue_(any(strcmp(kept2(:, 1), 'k3')), 'kept includes k3');

    % Type=Sensor AND Crit=high AND Activity=Live -> only k1.
    kept3 = TagStatusTableWindow.filterRows_(rows, '', ...
        {'sensor'}, {'high'}, {'live'});
    assertEqual_(size(kept3, 1), 1, 'Sensor+high+Live keeps only k1');
    assertEqual_(kept3{1, 1}, 'k1', 'kept row is k1');

    % OR-within-group: Type=Sensor OR Monitor, all else permissive.
    kept4 = TagStatusTableWindow.filterRows_(rows, '', ...
        {'sensor', 'monitor'}, {'low', 'medium', 'high', 'safety'}, ...
        {'live', 'inactive'});
    assertEqual_(size(kept4, 1), 4, 'Type=Sensor OR Monitor keeps 4 rows');

    % Combined with search: "Hi" + Type=Sensor.
    kept5 = TagStatusTableWindow.filterRows_(rows, 'Hi', ...
        {'sensor'}, {'low', 'medium', 'high', 'safety'}, ...
        {'live', 'inactive'});
    assertEqual_(size(kept5, 1), 2, 'search ''Hi'' + Type=Sensor keeps k1+k3');
end

function testFilterRows_emptyChipGroupExcludesAll()
    % "Zero chips selected in any group" -> table shows nothing.
    rows = { ...
        'k1', 'A', 'Sensor', 'high',   '', '', '', '', 'Live',     '', '', ''; ...
        'k2', 'B', 'Sensor', 'medium', '', '', '', '', 'Inactive', '', '', '' };

    % Empty Type group.
    kept = TagStatusTableWindow.filterRows_(rows, '', ...
        {}, {'low', 'medium', 'high', 'safety'}, {'live', 'inactive'});
    assertEqual_(size(kept, 1), 0, 'empty Type chip group excludes all rows');

    % Empty Criticality group.
    kept2 = TagStatusTableWindow.filterRows_(rows, '', ...
        {'sensor', 'monitor', 'composite', 'state', 'derived'}, {}, {'live', 'inactive'});
    assertEqual_(size(kept2, 1), 0, 'empty Criticality chip group excludes all rows');

    % Empty Activity group.
    kept3 = TagStatusTableWindow.filterRows_(rows, '', ...
        {'sensor', 'monitor', 'composite', 'state', 'derived'}, ...
        {'low', 'medium', 'high', 'safety'}, {});
    assertEqual_(size(kept3, 1), 0, 'empty Activity chip group excludes all rows');
end

% ===================== Events column (260519-bs4-06 patch) =====================

function testCountEventsForTag_noEventStore()
    % A vanilla SensorTag has no EventStore bound -> count is 0.
    resetRegistry_();
    tag = SensorTag('plain_sensor', 'Name', 'Plain');
    tag.updateData([1 2 3], [10 20 30]);

    n = TagStatusTableWindow.countEventsForTag_(tag);
    assertEqual_(n, 0, 'countEventsForTag_ must return 0 for tag with no EventStore');
end

function testCountEventsForTag_withStubbedEvents()
    % Bind an EventStore with N events tagged to tag.Key. countEventsForTag_
    % must return N. Uses the same EventBinding.attach path that MonitorTag
    % uses in production, so this exercises the real query path end to end.
    resetRegistry_();
    EventBinding.clear();
    store = EventStore('');
    tag = SensorTag('binds_events', 'Name', 'Has Events');
    tag.updateData([1 2 3], [10 20 30]);
    tag.EventStore = store;

    nExpected = 4;
    for i = 1:nExpected
        ev = Event(i * 10, i * 10 + 1, 'binds_events', 'thr_label', NaN, 'upper');
        store.append(ev);
        ev.TagKeys = {'binds_events'};
        EventBinding.attach(ev.Id, 'binds_events');
    end

    n = TagStatusTableWindow.countEventsForTag_(tag);
    assertEqual_(n, nExpected, ...
        sprintf('countEventsForTag_ must return %d for a tag with %d stubbed events', ...
            nExpected, nExpected));
end

function testBuildRow_includesEventsCountAtCol10()
    % buildRow_ must put the integer event count at column 10 of the row.
    resetRegistry_();
    EventBinding.clear();
    store = EventStore('');
    tag = SensorTag('row_events', 'Name', 'Row Events');
    tag.updateData([1 2 3], [10 20 30]);
    tag.EventStore = store;

    % Append 2 events bound to the tag.
    for i = 1:2
        ev = Event(i, i + 0.5, 'row_events', 'thr', NaN, 'upper');
        store.append(ev);
        ev.TagKeys = {'row_events'};
        EventBinding.attach(ev.Id, 'row_events');
    end

    row = TagStatusTableWindow.buildRow_(tag);
    assertSize_(row, [1 12]);
    assertEqual_(row{10}, '2', 'Events count must appear at column 10');
end

function testBuildRow_eventCountsByKeyBucketedMapWins()
    % When the precomputed eventCountsByKey map carries a value for the
    % tag's Key, buildRow_ must read from the map and NOT call the per-tag
    % query path. We verify this by passing a value that DIFFERS from
    % what the per-tag query would compute (here: 42 vs the real 0,
    % since the tag has no EventStore bound).
    resetRegistry_();
    tag = SensorTag('cache_hit', 'Name', 'Cache Hit');
    tag.updateData([1 2 3], [10 20 30]);

    bucket = containers.Map('KeyType', 'char', 'ValueType', 'double');
    bucket('cache_hit') = 42;

    row = TagStatusTableWindow.buildRow_(tag, [], bucket);
    assertEqual_(row{10}, '42', ...
        'buildRow_ must read Events count from eventCountsByKey when present');

    % And when the key is missing from the bucket, buildRow_ must fall
    % back to per-tag query (which returns 0 for a tag without an EventStore).
    bucketMissing = containers.Map('KeyType', 'char', 'ValueType', 'double');
    bucketMissing('other_key') = 99;

    row2 = TagStatusTableWindow.buildRow_(tag, [], bucketMissing);
    assertEqual_(row2{10}, '0', ...
        'buildRow_ must fall back to per-tag query when bucket lacks the key');
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
    if isnumeric(actual) && isscalar(actual) && isnumeric(expected) && isscalar(expected) && ...
            actual == expected
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
