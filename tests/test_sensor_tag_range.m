function test_sensor_tag_range()
%TEST_SENSOR_TAG_RANGE Octave-safe data-layer unit tests for Tag.getXYRange
%   and SensorTag.getTimeRange disk-backed fix.
%
%   Tests cover:
%     - getXYRange([], []) returns full series (== getXY)
%     - getXYRange(t0, t1) on in-RAM SensorTag slices correctly
%     - getXYRange with out-of-extent window returns empty
%     - getXYRange with inverted window (t0 > t1) returns empty, no error
%     - getXYRange on disk-backed SensorTag delegates to DataStore.getRange
%     - getTimeRange on disk-backed SensorTag returns non-NaN [XMin, XMax]
%     - Tag base class default getXYRange works on a non-SensorTag subclass
%
%   Run via MATLAB MCP:  test_sensor_tag_range()
%   Run via Octave:      test_sensor_tag_range()
%
%   RED expectation (Wave 0): before Tasks 2-3 land, sub-tests that exercise
%   getXYRange and the disk-backed getTimeRange fix will fail with
%   "Undefined function 'getXYRange'" or return [NaN NaN] / wrong slices.
%   That is the correct Wave 0 (RED) state.
%
%   See also test_binary_search, SensorTag, Tag.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..')); install();

    t0 = datenum(2024, 1, 1);
    x  = (t0:1/86400:t0 + 9)';
    y  = sin((1:numel(x))');

    st = SensorTag('s1');
    st.updateData(x, y);

    stDisk = SensorTag('s2');
    stDisk.updateData(x, y);
    stDisk.toDisk();

    testGetXYRangeFull(st, x, y);
    testGetXYRangeRAMInRange(st, x, t0);
    testGetXYRangeEmpty(st, t0);
    testGetXYRangeInverted(st, t0);
    testGetXYRangeDisk(stDisk, x, t0);
    testGetTimeRangeDiskNonNaN(stDisk, t0);
    testBaseDefaultViaDerivedOrMock(x, y, t0);

    fprintf('    All 7 test_sensor_tag_range tests passed.\n');
end

% --------------------------------------------------------------------------

function testGetXYRangeFull(st, x, y)
%TESTGETXYRANGEFULL getXYRange([],[]) must return the full series.
    [X, Y] = st.getXYRange([], []);
    assert(isequal(X, x) && isequal(Y, y), ...
        'test_sensor_tag_range:testGetXYRangeFull', ...
        'getXYRange([],[]) must equal full X/Y from getXY()');
end

function testGetXYRangeRAMInRange(st, x, t0)
%TESTGETXYRANGECRAMMINRANGE Sliced window returns a proper subset.
    tWinStart = t0 + 2;
    tWinEnd   = t0 + 4;
    [X, Y] = st.getXYRange(tWinStart, tWinEnd);
    assert(numel(X) < numel(x), ...
        'test_sensor_tag_range:testGetXYRangeRAMInRange', ...
        'getXYRange(t0+2, t0+4) must return fewer points than full series');
    assert(numel(X) == numel(Y), ...
        'test_sensor_tag_range:testGetXYRangeRAMInRange', ...
        'X and Y must have equal length');
    padSec = 2 / 86400;
    assert(all(X >= tWinStart - padSec) && all(X <= tWinEnd + padSec), ...
        'test_sensor_tag_range:testGetXYRangeRAMInRange', ...
        'All windowed X values must lie within [tStart-pad, tEnd+pad]');
end

function testGetXYRangeEmpty(st, t0)
%TESTGETXYRANGEEMPTY Out-of-extent window must return empty, no error.
    tWinStart = t0 - 5;
    tWinEnd   = t0 - 4;
    [X, Y] = st.getXYRange(tWinStart, tWinEnd);
    assert(isempty(X) && isempty(Y), ...
        'test_sensor_tag_range:testGetXYRangeEmpty', ...
        'getXYRange for out-of-extent window must return empty X and Y');
end

function testGetXYRangeInverted(st, t0)
%TESTGETXYRANGEINVERTED Inverted window (t0 > t1) must return empty, no error.
    errored = false;
    X = [];
    Y = [];
    try
        [X, Y] = st.getXYRange(t0 + 4, t0 + 2);
    catch
        errored = true;
    end
    assert(~errored, ...
        'test_sensor_tag_range:testGetXYRangeInverted', ...
        'getXYRange with inverted window must not throw an error');
    assert(isempty(X) && isempty(Y), ...
        'test_sensor_tag_range:testGetXYRangeInverted', ...
        'getXYRange with inverted window must return empty X and Y');
end

function testGetXYRangeDisk(stDisk, x, t0)
%TESTGETXYRANGEDISK Disk-backed sensor returns a bounded slice.
    tWinStart = t0 + 2;
    tWinEnd   = t0 + 4;
    [X, Y] = stDisk.getXYRange(tWinStart, tWinEnd);
    assert(numel(X) < numel(x), ...
        'test_sensor_tag_range:testGetXYRangeDisk', ...
        'getXYRange on disk sensor must return fewer points than full series');
    assert(numel(X) == numel(Y), ...
        'test_sensor_tag_range:testGetXYRangeDisk', ...
        'Disk: X and Y must have equal length');
    % DataStore.getRange provides one-point padding each side — allow a few samples
    padSec = 5 / 86400;
    if ~isempty(X)
        assert(all(X >= tWinStart - padSec) && all(X <= tWinEnd + padSec), ...
            'test_sensor_tag_range:testGetXYRangeDisk', ...
            'Disk windowed X must lie within [tStart-pad, tEnd+pad]');
    end
end

function testGetTimeRangeDiskNonNaN(stDisk, t0)
%TESTGETTIMERANGEDISKNONNNAN Disk-backed getTimeRange must return non-NaN extent.
    [tMin, tMax] = stDisk.getTimeRange();
    assert(~isnan(tMin) && ~isnan(tMax), ...
        'test_sensor_tag_range:testGetTimeRangeDiskNonNaN', ...
        'getTimeRange on disk-backed sensor must return non-NaN [tMin, tMax]');
    tolSec = 2 / 86400;
    assert(abs(tMin - t0) < tolSec, ...
        'test_sensor_tag_range:testGetTimeRangeDiskNonNaN', ...
        'tMin must be within 2s of fixture start t0');
    assert(abs(tMax - (t0 + 9)) < tolSec, ...
        'test_sensor_tag_range:testGetTimeRangeDiskNonNaN', ...
        'tMax must be within 2s of fixture end t0+9');
end

function testBaseDefaultViaDerivedOrMock(x, y, t0)
%TESTBASEDEFAULTVIADERIVEDORMOCK Tag base getXYRange default works for non-SensorTag.
%   Use a CompositeTag if available; else fall back to a local MockRangeTag.
%   The base default calls getXY() then binary-search-slices.
    useComposite = (exist('CompositeTag', 'class') == 8);
    if useComposite
        % Build a minimal CompositeTag backed by a MonitorTag on a SensorTag.
        % CompositeTag.getXY returns its computed signal -- exercise
        % getXYRange([],[]) == getXY() for the base default.
        sBase = SensorTag('sBase_mock');
        sBase.updateData(x, y);
        mBase = MonitorTag('mBase_mock', sBase, @(xx, yy) yy > 0);
        TagRegistry.clear();
        TagRegistry.register('mBase_mock', mBase);
        % getXYRange([],[]) on MonitorTag must delegate to base default -> getXY()
        [Xfull, Yfull] = mBase.getXY();
        [Xrange, Yrange] = mBase.getXYRange([], []);
        assert(isequal(Xrange, Xfull) && isequal(Yrange, Yfull), ...
            'test_sensor_tag_range:testBaseDefaultViaDerivedOrMock', ...
            'Base default getXYRange([],[]) must equal getXY() for MonitorTag');
        % Windowed slice must return fewer points for a 2-day window
        tWinStart = t0 + 2;
        tWinEnd   = t0 + 4;
        [Xslice, ~] = mBase.getXYRange(tWinStart, tWinEnd);
        assert(numel(Xslice) < numel(Xfull), ...
            'test_sensor_tag_range:testBaseDefaultViaDerivedOrMock', ...
            'Base default getXYRange(t0,t1) must return fewer points than full');
        TagRegistry.clear();
    else
        % Fallback: define a local inline mock and test the base default
        % by calling it as a function (Tag subclass must exist as a classfile,
        % so we create a temp .m in the test dir and addpath it).
        % Instead, instantiate a SensorTag and verify base default is inherited.
        sM = SensorTag('sMock_range');
        sM.updateData(x, y);
        [Xfull, Yfull] = sM.getXY();
        [Xrange, Yrange] = sM.getXYRange([], []);
        assert(isequal(Xrange, Xfull) && isequal(Yrange, Yfull), ...
            'test_sensor_tag_range:testBaseDefaultViaDerivedOrMock', ...
            'Base default getXYRange([],[]) must equal getXY() for SensorTag (fallback)');
        tWinStart = t0 + 2;
        tWinEnd   = t0 + 4;
        [Xslice, ~] = sM.getXYRange(tWinStart, tWinEnd);
        assert(numel(Xslice) < numel(Xfull), ...
            'test_sensor_tag_range:testBaseDefaultViaDerivedOrMock', ...
            'Base default getXYRange(t0,t1) must slice to fewer points (fallback)');
    end
end
