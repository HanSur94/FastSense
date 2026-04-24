function test_monitortag_open_event
    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(root); install();

    nPassed = 0; nFailed = 0;

    % Test 1: rising edge emits open event
    try
        parent = SensorTag('p'); parent.updateData([0], [0]);
        es = EventStore('');
        mon = MonitorTag('m', parent, @(x, y) y > 5, 'EventStore', es);
        mon.getXY();
        mon.appendData([1 2 3 4], [1 10 10 10]);
        stored = es.getEvents();
        assert(numel(stored) == 1);
        assert(stored(1).IsOpen == true);
        assert(isnan(stored(1).EndTime));
        assert(stored(1).StartTime == 2);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testRisingEdgeEmitsOpenEvent: %s\n', err.message); nFailed = nFailed + 1;
    end

    % Test 2: open event appended to store with Id
    try
        parent = SensorTag('p'); parent.updateData([0], [0]);
        es = EventStore('');
        mon = MonitorTag('m', parent, @(x, y) y > 5, 'EventStore', es);
        mon.getXY();
        mon.appendData([1 2], [1 10]);
        stored = es.getEvents();
        assert(~isempty(stored(1).Id));
        assert(strncmp(stored(1).Id, 'evt_', 4));
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testOpenEventAppendedToStoreWithId: %s\n', err.message); nFailed = nFailed + 1;
    end

    % Test 3: falling edge calls closeEvent
    try
        parent = SensorTag('p'); parent.updateData([0], [0]);
        es = EventStore('');
        mon = MonitorTag('m', parent, @(x, y) y > 5, 'EventStore', es);
        mon.getXY();
        mon.appendData([1 2 3 4], [1 10 10 10]);
        mon.appendData([5 6 7 8], [10 10 1 1]);
        stored = es.getEvents();
        assert(numel(stored) == 1);
        assert(stored(1).IsOpen == false);
        assert(stored(1).EndTime == 6);
        assert(stored(1).Duration == 4);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testFallingEdgeCallsCloseEvent: %s\n', err.message); nFailed = nFailed + 1;
    end

    % Test 4: running stats accumulate during open run
    try
        parent = SensorTag('p'); parent.updateData([0], [0]);
        es = EventStore('');
        mon = MonitorTag('m', parent, @(x, y) y > 5, 'EventStore', es);
        mon.getXY();
        mon.appendData([1 2 3], [1 10 12]);
        mon.appendData([4 5], [15 14]);
        mon.appendData([6 7], [13 0]);
        stored = es.getEvents();
        assert(stored(1).PeakValue == 15);
        assert(stored(1).MaxValue == 15);
        assert(stored(1).MinValue == 10);
        assert(stored(1).NumPoints == 5);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testRunningStatsAccumulateDuringOpenRun: %s\n', err.message); nFailed = nFailed + 1;
    end

    % Test 5: open run stats finalized on close
    try
        parent = SensorTag('p'); parent.updateData([0], [0]);
        es = EventStore('');
        mon = MonitorTag('m', parent, @(x, y) y > 5, 'EventStore', es);
        mon.getXY();
        mon.appendData([1 2 3 4 5], [1 10 10 10 1]);
        stored = es.getEvents();
        assert(stored(1).IsOpen == false);
        assert(stored(1).NumPoints > 0);
        assert(~isempty(stored(1).PeakValue));
        assert(~isempty(stored(1).MeanValue));
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testOpenRunStatsFinalizedOnClose: %s\n', err.message); nFailed = nFailed + 1;
    end

    % Test 6: closing run resets openEventId and openStats; new open = new event
    try
        parent = SensorTag('p'); parent.updateData([0], [0]);
        es = EventStore('');
        mon = MonitorTag('m', parent, @(x, y) y > 5, 'EventStore', es);
        mon.getXY();
        mon.appendData([1 2 3], [1 10 10]);
        mon.appendData([4 5], [1 1]);
        mon.appendData([6 7 8], [1 10 10]);
        stored = es.getEvents();
        assert(numel(stored) == 2);
        assert(stored(1).IsOpen == false);
        assert(stored(2).IsOpen == true);
        assert(~strcmp(stored(1).Id, stored(2).Id));
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testClosingRunResetsOpenEventIdAndOpenStats: %s\n', err.message); nFailed = nFailed + 1;
    end

    % Test 7: short-circuit when no hooks
    try
        parent = SensorTag('p');
        parent.updateData([0], [0]);
        mon = MonitorTag('m', parent, @(x, y) y > 5);  % no EventStore
        mon.getXY();  % warm up cache
        mon.appendData([1 2 3], [1 10 10]);
        [x, y] = mon.getXY();
        assert(~isempty(x));
        assert(numel(x) == numel(y));
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testShortCircuitNoEmissionWhenAllHooksEmpty: %s\n', err.message); nFailed = nFailed + 1;
    end

    fprintf('    %d passed, %d failed\n', nPassed, nFailed);
    if nFailed > 0, error('test_monitortag_open_event:failures', '%d tests failed', nFailed); end
end
