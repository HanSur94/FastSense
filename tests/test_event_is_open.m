function test_event_is_open
    %TEST_EVENT_IS_OPEN Octave-parallel Phase 1012 schema tests.
    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(root);
    install();

    nPassed = 0;
    nFailed = 0;

    try
        ev = Event(0, 10, 's1', 'hi', 5, 'upper');
        assert(ev.IsOpen == false, 'IsOpen default must be false');
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testIsOpenDefaultFalse: %s\n', err.message); nFailed = nFailed + 1;
    end

    try
        ev = Event(0, 10, 's1', 'hi', 5, 'upper');
        ev.IsOpen = true;
        assert(ev.IsOpen == true, 'IsOpen must be writable');
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testIsOpenIsWritable: %s\n', err.message); nFailed = nFailed + 1;
    end

    try
        ev = Event(5, NaN, 's1', 'hi', 5, 'upper');
        assert(isnan(ev.EndTime), 'EndTime NaN accepted');
        assert(isnan(ev.Duration), 'Duration NaN when EndTime NaN');
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testConstructorAcceptsNaNEndTime: %s\n', err.message); nFailed = nFailed + 1;
    end

    try
        threw = false;
        try Event(10, 5, 's1', 'hi', 5, 'upper'); catch, threw = true; end
        assert(threw, 'Finite reverse range must still throw');
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testConstructorStillRejectsInvalidFiniteRange: %s\n', err.message); nFailed = nFailed + 1;
    end

    try
        ev = Event(5, NaN, 's1', 'hi', 5, 'upper');
        ev.IsOpen = true;
        stats = struct('PeakValue', 8, 'NumPoints', 3, 'MinValue', 6, ...
            'MaxValue', 8, 'MeanValue', 7, 'RmsValue', 7.1, 'StdValue', 1);
        ev.close(12, stats);
        assert(ev.EndTime == 12, 'EndTime set on close');
        assert(ev.Duration == 7, 'Duration recomputed');
        assert(ev.IsOpen == false, 'IsOpen toggled');
        assert(ev.PeakValue == 8, 'PeakValue set');
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testCloseUpdatesInPlace: %s\n', err.message); nFailed = nFailed + 1;
    end

    try
        ev = Event(5, NaN, 's1', 'hi', 5, 'upper'); ev.IsOpen = true;
        ev.close(12, []);
        assert(ev.EndTime == 12); assert(ev.IsOpen == false);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testCloseAcceptsEmptyStats: %s\n', err.message); nFailed = nFailed + 1;
    end

    try
        ev = Event(5, NaN, 's1', 'hi', 5, 'upper'); ev.IsOpen = true;
        ev.close(12, []);
        threw = false;
        try ev.close(13, []); catch, threw = true; end
        assert(threw, 'double-close must throw');
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testCloseDoubleThrows: %s\n', err.message); nFailed = nFailed + 1;
    end

    try
        es = EventStore('');
        ev = Event(5, NaN, 's1', 'hi', 5, 'upper'); ev.IsOpen = true;
        es.append(ev);
        es.closeEvent(ev.Id, 15, struct('PeakValue', 9, 'NumPoints', 4, ...
            'MinValue', 6, 'MaxValue', 9, 'MeanValue', 7.5, 'RmsValue', 7.7, 'StdValue', 1.3));
        stored = es.getEvents();
        assert(stored(1).EndTime == 15); assert(stored(1).IsOpen == false);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testEventStoreCloseEventUpdatesInPlace: %s\n', err.message); nFailed = nFailed + 1;
    end

    try
        es = EventStore('');
        ev = Event(0, 10, 's1', 'hi', 5, 'upper'); es.append(ev);
        threw = false;
        try es.closeEvent('evt_999', 10, []); catch, threw = true; end
        assert(threw, 'unknown id must throw');
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testEventStoreCloseEventUnknownIdThrows: %s\n', err.message); nFailed = nFailed + 1;
    end

    try
        es = EventStore('');
        ev = Event(0, 10, 's1', 'hi', 5, 'upper');  % IsOpen default false
        es.append(ev);
        threw = false;
        try es.closeEvent(ev.Id, 11, []); catch, threw = true; end
        assert(threw, 'already-closed must throw');
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testEventStoreCloseEventAlreadyClosedThrows: %s\n', err.message); nFailed = nFailed + 1;
    end

    try
        es = EventStore('');
        threw = false;
        try es.closeEvent('evt_1', 10, []); catch, threw = true; end
        assert(threw, 'empty store must throw');
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testEventStoreCloseEventEmptyStoreThrows: %s\n', err.message); nFailed = nFailed + 1;
    end

    try
        ev = Event(0, 10, 's1', 'hi', 5, 'upper'); %#ok<NASGU>
        tmp = [tempname '.mat'];
        events = ev; %#ok<NASGU>
        builtin('save', tmp, 'events');
        data = builtin('load', tmp);
        assert(data.events(1).IsOpen == false, 'default-on-read backward compat');
        delete(tmp);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testBackwardCompatOldEventMatLoadsWithDefaultIsOpen: %s\n', err.message); nFailed = nFailed + 1;
    end

    fprintf('    %d passed, %d failed\n', nPassed, nFailed);
    if nFailed > 0, error('test_event_is_open:failures', '%d tests failed', nFailed); end
end
