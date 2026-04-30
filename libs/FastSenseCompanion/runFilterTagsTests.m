function runFilterTagsTests()
%RUNFILTERTAGSTESTS Execute unit tests for filterTags and groupByLabel.
%   Called by tests/test_companion_filter_tags.m.  Lives here (inside
%   libs/FastSenseCompanion) so that MATLAB's private-directory mechanism
%   makes filterTags and groupByLabel visible (private functions are
%   accessible to callers in the same folder).
%
%   See also filterTags, groupByLabel.

    nPassed = 0;

    % --- Build test fixtures ---
    % SensorTag: pressure_a -- Labels={'ProcessArea'}, Criticality='high'
    tSensorA = SensorTag('pressure_a', ...
        'Name', 'Pressure A', ...
        'Description', 'Reactor feed line pressure', ...
        'Labels', {'ProcessArea'}, ...
        'Criticality', 'high', ...
        'X', 1:5, 'Y', rand(1, 5));

    % SensorTag: temp_b -- Labels={'ProcessArea','CoolingSystem'}, Criticality='medium'
    tSensorB = SensorTag('temp_b', ...
        'Name', 'Temperature B', ...
        'Description', 'Outlet temperature', ...
        'Labels', {'ProcessArea', 'CoolingSystem'}, ...
        'Criticality', 'medium', ...
        'X', 1:5, 'Y', rand(1, 5));

    % StateTag: mode_c -- Labels={'CoolingSystem'}, Criticality='low'
    tState = StateTag('mode_c', ...
        'Name', 'Cooling Mode', ...
        'Description', 'System operating mode', ...
        'Labels', {'CoolingSystem'}, ...
        'Criticality', 'low', ...
        'X', [1 3 7], 'Y', [0 1 0]);

    % MonitorTag: alarm_d -- Labels={} (ungrouped), Criticality='safety'
    tMonitor = MonitorTag('alarm_d', tSensorA, @(x, y) y > 5, ...
        'Name', 'Alarm D', ...
        'Description', 'Safety alarm monitor', ...
        'Labels', {}, ...
        'Criticality', 'safety');

    % CompositeTag: kpi_e -- Labels={'KPI'}, Criticality='medium'
    tComposite = CompositeTag('kpi_e', 'and', ...
        'Name', 'KPI E', ...
        'Description', 'Composite KPI', ...
        'Labels', {'KPI'}, ...
        'Criticality', 'medium');

    % Mixed collection
    allTags = {tSensorA, tSensorB, tState, tMonitor, tComposite};

    % -------------------------
    % filterTags tests
    % -------------------------

    % Test 1: empty tagsCell -> filteredTags={}, byGroup is struct array with 0 elements
    [ft, bg] = filterTags({}, '', {}, {});
    assert(isempty(ft), 'Test 1: filteredTags should be empty');
    assert(isstruct(bg) && numel(bg) == 0, 'Test 1: byGroup should be empty struct array');
    nPassed = nPassed + 1;

    % Test 2: empty search + empty pills -> returns all tags (count matches input)
    [ft, ~] = filterTags(allTags, '', {}, {});
    assert(numel(ft) == numel(allTags), ...
        sprintf('Test 2: expected %d tags, got %d', numel(allTags), numel(ft)));
    nPassed = nPassed + 1;

    % Test 3: search 'pressure' (lowercase) matches tag with Key='pressure_a'
    [ft3, ~] = filterTags(allTags, 'pressure', {}, {});
    assert(numel(ft3) >= 1, 'Test 3: should match at least 1 tag');
    found = false;
    for i = 1:numel(ft3)
        if strcmp(ft3{i}.Key, 'pressure_a')
            found = true;
        end
    end
    assert(found, 'Test 3: pressure_a should be in results');
    nPassed = nPassed + 1;

    % Test 4: search 'PRESSURE' (uppercase) matches same tag (case-insensitive)
    [ft4, ~] = filterTags(allTags, 'PRESSURE', {}, {});
    assert(numel(ft4) == numel(ft3), ...
        'Test 4: case-insensitive search should return same count as lowercase');
    nPassed = nPassed + 1;

    % Test 5: search matches Description field
    [ft5, ~] = filterTags(allTags, 'Reactor', {}, {});
    assert(numel(ft5) >= 1, 'Test 5: should match tag with Reactor in Description');
    found5 = false;
    for i = 1:numel(ft5)
        if strcmp(ft5{i}.Key, 'pressure_a')
            found5 = true;
        end
    end
    assert(found5, 'Test 5: pressure_a should be found via Description match');
    nPassed = nPassed + 1;

    % Test 6: search 'xyz_nomatch' -> filteredTags is empty
    [ft6, ~] = filterTags(allTags, 'xyz_nomatch', {}, {});
    assert(isempty(ft6), 'Test 6: xyz_nomatch should return empty');
    nPassed = nPassed + 1;

    % Test 7: activeKinds={'sensor'} -> only SensorTag instances returned
    [ft7, ~] = filterTags(allTags, '', {'sensor'}, {});
    for i = 1:numel(ft7)
        assert(isa(ft7{i}, 'SensorTag'), ...
            sprintf('Test 7: result %d should be SensorTag, got %s', i, class(ft7{i})));
    end
    assert(numel(ft7) == 2, sprintf('Test 7: expected 2 SensorTags, got %d', numel(ft7)));
    nPassed = nPassed + 1;

    % Test 8: activeKinds={'sensor','monitor'} -> SensorTag OR MonitorTag
    [ft8, ~] = filterTags(allTags, '', {'sensor', 'monitor'}, {});
    for i = 1:numel(ft8)
        assert(isa(ft8{i}, 'SensorTag') || isa(ft8{i}, 'MonitorTag'), ...
            sprintf('Test 8: result %d should be SensorTag or MonitorTag', i));
    end
    nPassed = nPassed + 1;

    % Test 9: activeKinds={'sensor'} + activeCrits={'high'} -> sensor AND high
    [ft9, ~] = filterTags(allTags, '', {'sensor'}, {'high'});
    for i = 1:numel(ft9)
        assert(isa(ft9{i}, 'SensorTag'), 'Test 9: should be SensorTag');
        assert(strcmp(ft9{i}.Criticality, 'high'), 'Test 9: should have high criticality');
    end
    assert(numel(ft9) == 1, sprintf('Test 9: expected 1 (pressure_a sensor+high), got %d', numel(ft9)));
    nPassed = nPassed + 1;

    % Test 10: activeCrits={'safety'} only -> all-kind filter by criticality
    [ft10, ~] = filterTags(allTags, '', {}, {'safety'});
    for i = 1:numel(ft10)
        assert(strcmp(ft10{i}.Criticality, 'safety'), 'Test 10: all results must have safety criticality');
    end
    assert(numel(ft10) >= 1, 'Test 10: at least one safety tag expected');
    nPassed = nPassed + 1;

    % Test 10b: byGroup ordering - alphabetical by GroupName, Ungrouped last
    [~, bg10] = filterTags(allTags, '', {}, {});
    assert(isstruct(bg10) && numel(bg10) >= 1, 'Test 10b: byGroup should be non-empty');
    if numel(bg10) > 1
        lastGroup = bg10(end).GroupName;
        assert(strcmp(lastGroup, 'Ungrouped'), ...
            sprintf('Test 10b: last group should be Ungrouped, got %s', lastGroup));
        for i = 1:numel(bg10) - 1
            assert(~strcmp(bg10(i).GroupName, 'Ungrouped'), ...
                'Test 10b: Ungrouped should only appear at end');
        end
    end
    nPassed = nPassed + 1;

    % Test 10c: first-label-only - tSensorB has Labels={'ProcessArea','CoolingSystem'}
    % It should appear under ProcessArea only (NOT CoolingSystem)
    [~, bg_b] = filterTags({tSensorB}, '', {}, {});
    csFound = false;
    for i = 1:numel(bg_b)
        if strcmp(bg_b(i).GroupName, 'CoolingSystem')
            for j = 1:numel(bg_b(i).Tags)
                if strcmp(bg_b(i).Tags{j}.Key, 'temp_b')
                    csFound = true;
                end
            end
        end
    end
    assert(~csFound, 'Test 10c: temp_b must NOT appear in CoolingSystem group (first-label-only)');
    nPassed = nPassed + 1;

    % -------------------------
    % groupByLabel tests
    % -------------------------

    % Test 11: empty input -> items={'  No tags match'}, itemsData={[]}
    [items11, idata11] = groupByLabel({});
    assert(numel(items11) == 1, 'Test 11: empty should return 1 item');
    assert(strcmp(items11{1}, '  No tags match'), ...
        sprintf('Test 11: expected ''  No tags match'', got ''%s''', items11{1}));
    assert(numel(idata11) == 1, 'Test 11: itemsData should have 1 element');
    assert(isempty(idata11{1}) && isnumeric(idata11{1}), ...
        'Test 11: itemsData{1} should be [] (empty double)');
    nPassed = nPassed + 1;

    % Test 12: tags in one group -> header with GroupA and count + child rows
    tG1 = SensorTag('s1', 'Name', 'Sensor One', 'Labels', {'GroupA'}, 'X', 1:3, 'Y', rand(1, 3));
    tG2 = SensorTag('s2', 'Name', 'Sensor Two', 'Labels', {'GroupA'}, 'X', 1:3, 'Y', rand(1, 3));
    [items12, idata12] = groupByLabel({tG1, tG2});
    assert(numel(items12) == 3, sprintf('Test 12: expected 3 items (1 header + 2 rows), got %d', numel(items12)));
    actualHeader = items12{1};
    assert(~isempty(strfind(actualHeader, 'GroupA')), ...
        sprintf('Test 12: header should contain GroupA, got: %s', actualHeader));
    assert(~isempty(strfind(actualHeader, '2')), ...
        sprintf('Test 12: header should contain count 2, got: %s', actualHeader));
    nPassed = nPassed + 1;

    % Test 13: itemsData header entry is [] (scalar double, not a string)
    assert(isempty(idata12{1}) && isnumeric(idata12{1}), ...
        'Test 13: header itemsData should be [] (empty double)');
    nPassed = nPassed + 1;

    % Test 14: itemsData child entry is tag.Key char
    assert(ischar(idata12{2}), 'Test 14: child itemsData should be char');
    assert(strcmp(idata12{2}, 's1'), ...
        sprintf('Test 14: expected key s1, got %s', idata12{2}));
    nPassed = nPassed + 1;

    % Test 15: 'Ungrouped' always last (even if alphabetically first/only)
    tUngrp = SensorTag('u1', 'Name', 'Ungrouped Tag', 'Labels', {}, 'X', 1:3, 'Y', rand(1, 3));
    tZeta = SensorTag('z1', 'Name', 'Zeta Tag', 'Labels', {'Zeta'}, 'X', 1:3, 'Y', rand(1, 3));
    [items15, ~] = groupByLabel({tUngrp, tZeta});
    ungroupedIdx = 0;
    zetaIdx = 0;
    for i = 1:numel(items15)
        if ~isempty(strfind(items15{i}, 'Ungrouped'))
            ungroupedIdx = i;
        end
        if ~isempty(strfind(items15{i}, 'Zeta'))
            zetaIdx = i;
        end
    end
    assert(ungroupedIdx > 0 && zetaIdx > 0, 'Test 15: both groups should appear');
    assert(ungroupedIdx > zetaIdx, 'Test 15: Ungrouped header should appear after Zeta group');
    nPassed = nPassed + 1;

    % Test 16: multiple groups ordered alphabetically before Ungrouped
    tAlpha = SensorTag('a1', 'Name', 'Alpha Tag', 'Labels', {'Alpha'}, 'X', 1:3, 'Y', rand(1, 3));
    tZeta2 = SensorTag('z2', 'Name', 'Zeta Tag 2', 'Labels', {'Zeta'}, 'X', 1:3, 'Y', rand(1, 3));
    tUngrp2 = SensorTag('u2', 'Name', 'Ungrouped Tag 2', 'Labels', {}, 'X', 1:3, 'Y', rand(1, 3));
    [items16, ~] = groupByLabel({tZeta2, tAlpha, tUngrp2});
    alphaIdx = 0;
    zetaIdx2 = 0;
    ungroupedIdx2 = 0;
    for i = 1:numel(items16)
        if ~isempty(strfind(items16{i}, 'Alpha'))
            alphaIdx = i;
        end
        if ~isempty(strfind(items16{i}, 'Zeta'))
            zetaIdx2 = i;
        end
        if ~isempty(strfind(items16{i}, 'Ungrouped'))
            ungroupedIdx2 = i;
        end
    end
    assert(alphaIdx > 0 && zetaIdx2 > 0 && ungroupedIdx2 > 0, ...
        'Test 16: all groups should appear');
    assert(alphaIdx < zetaIdx2, 'Test 16: Alpha should come before Zeta (alphabetical)');
    assert(zetaIdx2 < ungroupedIdx2, 'Test 16: Zeta should come before Ungrouped');
    nPassed = nPassed + 1;

    fprintf('    All %d tests passed.\n', nPassed);
end
