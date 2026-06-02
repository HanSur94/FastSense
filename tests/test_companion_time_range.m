function test_companion_time_range()
%TEST_COMPANION_TIME_RANGE Unit tests for CompanionTimeRange logic.
%
%   Tests resolve/label/isDefault/toStruct/fromStruct (MATLAB + Octave).
%   The RangeChanged event-firing test requires addlistener and is
%   guarded with an Octave skip.
%
%   Run:
%     addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
%     install();
%     test_companion_time_range()
%
%   See also CompanionTimeRange.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();

    nPassed = 0;

    testResolveRelative(); nPassed = nPassed + 1;
    testResolveRelativeHours(); nPassed = nPassed + 1;
    testResolveAbsolute(); nPassed = nPassed + 1;
    testResolveAll(); nPassed = nPassed + 1;
    testLabelRelative(); nPassed = nPassed + 1;
    testLabelAbsolute(); nPassed = nPassed + 1;
    testLabelAll(); nPassed = nPassed + 1;
    testRangeChangedFires(); nPassed = nPassed + 1;
    testIsDefault(); nPassed = nPassed + 1;
    testRoundTripStruct(); nPassed = nPassed + 1;

    fprintf('    All %d test_companion_time_range tests passed.\n', nPassed);
end

function testResolveRelative()
%TESTRESOLVRELATIVE resolve() with relative spec returns [now-7, now].
    r = CompanionTimeRange();
    r.setRelative(7, 'days');
    [t0, t1] = r.resolve();
    assert(abs(t1 - now()) < 1/24, ...
        'test_companion_time_range:testResolveRelative', ...
        'testResolveRelative: t1 should be close to now()');
    assert(abs((t1 - t0) - 7) < 1e-6, ...
        'test_companion_time_range:testResolveRelative', ...
        'testResolveRelative: window width should be 7 days');
end

function testResolveRelativeHours()
%TESTRESOLVRELATIVEHOURS resolve() with 24 hours returns window of 1 day.
    r = CompanionTimeRange();
    r.setRelative(24, 'hours');
    [t0, t1] = r.resolve();
    assert(abs((t1 - t0) - 1) < 1e-6, ...
        'test_companion_time_range:testResolveRelativeHours', ...
        'testResolveRelativeHours: window width for 24 hours should be 1 day');
end

function testResolveAbsolute()
%TESTRESOLVABSOLUTE resolve() with absolute spec returns exact stored bounds.
    r = CompanionTimeRange();
    t0In = datenum(2024, 1, 1);
    t1In = datenum(2024, 3, 1);
    r.setAbsolute(t0In, t1In);
    [t0, t1] = r.resolve();
    assert(t0 == t0In, ...
        'test_companion_time_range:testResolveAbsolute', ...
        'testResolveAbsolute: t0 must equal stored t0');
    assert(t1 == t1In, ...
        'test_companion_time_range:testResolveAbsolute', ...
        'testResolveAbsolute: t1 must equal stored t1');
end

function testResolveAll()
%TESTRESOLVEALL resolve() with all spec returns empty t0 and t1.
    r = CompanionTimeRange();
    r.setAll();
    [t0, t1] = r.resolve();
    assert(isempty(t0) && isempty(t1), ...
        'test_companion_time_range:testResolveAll', ...
        'testResolveAll: setAll() must return isempty(t0) && isempty(t1)');
end

function testLabelRelative()
%TESTLABELRELATIVE label() for relative spec returns "Last N unit".
    r = CompanionTimeRange();
    r.setRelative(7, 'days');
    lbl = r.label();
    assert(strcmp(lbl, 'Last 7 days'), ...
        'test_companion_time_range:testLabelRelative', ...
        'testLabelRelative: expected "Last 7 days", got "%s"', lbl);
end

function testLabelAbsolute()
%TESTLABELABSOLUTE label() for absolute spec returns "YYYY-MM-DD to YYYY-MM-DD".
    r = CompanionTimeRange();
    r.setAbsolute(datenum(2024, 1, 1), datenum(2024, 3, 1));
    lbl = r.label();
    assert(strcmp(lbl, '2024-01-01 to 2024-03-01'), ...
        'test_companion_time_range:testLabelAbsolute', ...
        'testLabelAbsolute: expected "2024-01-01 to 2024-03-01", got "%s"', lbl);
end

function testLabelAll()
%TESTLABELALL label() for all spec returns "All data".
    r = CompanionTimeRange();
    r.setAll();
    lbl = r.label();
    assert(strcmp(lbl, 'All data'), ...
        'test_companion_time_range:testLabelAll', ...
        'testLabelAll: expected "All data", got "%s"', lbl);
end

function testRangeChangedFires()
%TESTRANGECHANGEDFIRES RangeChanged fires exactly once per setRelative call.
%   Guarded for Octave — addlistener on custom events is unreliable in Octave.
    if exist('OCTAVE_VERSION', 'builtin') ~= 0
        fprintf('  Skipping testRangeChangedFires on Octave.\n');
        return;
    end
    r = CompanionTimeRange();
    % Use containers.Map as a handle type so the closure can mutate the counter.
    cntMap = containers.Map({'n'}, {0});
    lh = addlistener(r, 'RangeChanged', @(~, ~) bumpCnt(cntMap));
    r.setRelative(7, 'days');
    assert(cntMap('n') == 1, ...
        'test_companion_time_range:testRangeChangedFires', ...
        'testRangeChangedFires: expected 1 RangeChanged event, got %d', cntMap('n'));
    delete(lh);
end

function bumpCnt(cntMap)
%BUMPCNT Increment counter in handle-typed containers.Map.
    cntMap('n') = cntMap('n') + 1;
end

function testIsDefault()
%TESTISDEFAULT isDefault() returns true for fresh object and false after change.
    r = CompanionTimeRange();
    assert(r.isDefault(), ...
        'test_companion_time_range:testIsDefault', ...
        'testIsDefault: fresh object should be default (relative 7 days)');
    r.setRelative(30, 'days');
    assert(~r.isDefault(), ...
        'test_companion_time_range:testIsDefault', ...
        'testIsDefault: after setRelative(30,days) isDefault should be false');
end

function testRoundTripStruct()
%TESTROUNDTRIPSTRUCT fromStruct(toStruct(x)) resolves identically to original.
    r = CompanionTimeRange();
    r.setRelative(30, 'days');
    s = r.toStruct();
    r2 = CompanionTimeRange.fromStruct(s);
    [t0a, t1a] = r.resolve();
    [t0b, t1b] = r2.resolve();
    assert(abs(t0a - t0b) < 1e-6, ...
        'test_companion_time_range:testRoundTripStruct', ...
        'testRoundTripStruct: t0 mismatch after round-trip');
    assert(abs(t1a - t1b) < 1e-6, ...
        'test_companion_time_range:testRoundTripStruct', ...
        'testRoundTripStruct: t1 mismatch after round-trip');

    % absolute round-trip
    r3 = CompanionTimeRange();
    r3.setAbsolute(datenum(2023, 6, 1), datenum(2023, 12, 31));
    s3 = r3.toStruct();
    r4 = CompanionTimeRange.fromStruct(s3);
    [t0c, t1c] = r3.resolve();
    [t0d, t1d] = r4.resolve();
    assert(t0c == t0d && t1c == t1d, ...
        'test_companion_time_range:testRoundTripStruct', ...
        'testRoundTripStruct: absolute round-trip mismatch');

    % all round-trip
    r5 = CompanionTimeRange();
    r5.setAll();
    s5 = r5.toStruct();
    r6 = CompanionTimeRange.fromStruct(s5);
    [t0e, t1e] = r5.resolve();
    [t0f, t1f] = r6.resolve();
    assert(isempty(t0e) && isempty(t1e) && isempty(t0f) && isempty(t1f), ...
        'test_companion_time_range:testRoundTripStruct', ...
        'testRoundTripStruct: all round-trip should produce empty t0/t1');
end
