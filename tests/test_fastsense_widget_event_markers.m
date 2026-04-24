function test_fastsense_widget_event_markers
    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(root); install();
    nPassed = 0; nFailed = 0;

    try
        w = FastSenseWidget();
        assert(w.ShowEventMarkers == false);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testShowEventMarkersDefaultFalse: %s\n', err.message); nFailed = nFailed + 1;
    end

    try
        w = FastSenseWidget();
        assert(isempty(w.EventStore));
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testEventStorePropertyDefaultEmpty: %s\n', err.message); nFailed = nFailed + 1;
    end

    try
        w = FastSenseWidget('Title', 'x');
        s = w.toStruct();
        assert(~isfield(s, 'showEventMarkers'));
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testToStructOmitsWhenDefault: %s\n', err.message); nFailed = nFailed + 1;
    end

    try
        w = FastSenseWidget('Title', 'x');
        w.ShowEventMarkers = true;
        s = w.toStruct();
        assert(isfield(s, 'showEventMarkers'));
        assert(s.showEventMarkers == true);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testToStructIncludesWhenTrue: %s\n', err.message); nFailed = nFailed + 1;
    end

    try
        w = FastSenseWidget('Title', 'x');
        w.EventStore = EventStore('');
        s = w.toStruct();
        assert(~isfield(s, 'eventStore'));
        assert(~isfield(s, 'EventStore'));
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testToStructNeverEmitsEventStore: %s\n', err.message); nFailed = nFailed + 1;
    end

    try
        s = struct( ...
            'title', 't', 'position', struct('col', 1, 'row', 1, 'width', 6, 'height', 2), ...
            'showEventMarkers', true);
        w = FastSenseWidget.fromStruct(s);
        assert(w.ShowEventMarkers == true);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testFromStructRehydrates: %s\n', err.message); nFailed = nFailed + 1;
    end

    % GUI-dependent tests (render required)
    guiOk = usejava('jvm') || (exist('OCTAVE_VERSION', 'builtin') && ~isempty(getenv('DISPLAY')));
    if guiOk
        try
            w = FastSenseWidget();
            parent = SensorTag('p');
            parent.updateData([0 1 2 3 4 5], [0 0 0 10 10 0]);
            w.Tag = parent;
            es = EventStore('');
            w.EventStore = es;
            w.ShowEventMarkers = true;
            f = figure('Visible', 'off');
            pnl = uipanel('Parent', f);
            w.render(pnl);
            assert(w.FastSenseObj.ShowEventMarkers == w.ShowEventMarkers);
            % Octave has no overloaded == for handle classes; compare
            % identity via class + property readback instead.
            assert(isa(w.FastSenseObj.EventStore, 'EventStore'));
            assert(strcmp(w.FastSenseObj.EventStore.FilePath, es.FilePath));
            delete(f);
            nPassed = nPassed + 1;
        catch err
            fprintf('    FAIL testPropertiesForwardToInnerFastSense: %s\n', err.message); nFailed = nFailed + 1;
        end

        try
            w = FastSenseWidget();
            parent = SensorTag('p');
            parent.updateData([0 1 2 3 4 5], [0 0 0 10 10 0]);
            w.Tag = parent;
            es = EventStore('');
            w.EventStore = es;
            w.ShowEventMarkers = true;
            f = figure('Visible', 'off');
            pnl = uipanel('Parent', f);
            w.render(pnl);
            ev = Event(2, 3, 'p', 'hi', 5, 'upper');
            es.append(ev); EventBinding.attach(ev.Id, 'p');
            w.refresh();
            assert(~isempty(w.LastEventIds_));
            assert(strcmp(w.LastEventIds_{1}, ev.Id));
            delete(f);
            nPassed = nPassed + 1;
        catch err
            fprintf('    FAIL testRefreshTriggersRerenderOnAdded: %s\n', err.message); nFailed = nFailed + 1;
        end

        try
            w = FastSenseWidget();
            parent = SensorTag('p');
            parent.updateData([0 1 2 3 4 5], [0 0 0 10 10 0]);
            w.Tag = parent;
            es = EventStore('');
            w.EventStore = es;
            w.ShowEventMarkers = true;
            f = figure('Visible', 'off');
            pnl = uipanel('Parent', f);
            w.render(pnl);
            ev = Event(2, NaN, 'p', 'hi', 5, 'upper'); ev.IsOpen = true;
            es.append(ev); EventBinding.attach(ev.Id, 'p');
            w.refresh();
            assert(w.LastEventOpen_(1) == true);
            es.closeEvent(ev.Id, 3, []);
            w.refresh();
            assert(w.LastEventOpen_(1) == false);
            delete(f);
            nPassed = nPassed + 1;
        catch err
            fprintf('    FAIL testRefreshTriggersRerenderOnOpenToClosed: %s\n', err.message); nFailed = nFailed + 1;
        end
    else
        fprintf('    SKIP testPropertiesForwardToInnerFastSense: GUI unavailable.\n');
        fprintf('    SKIP testRefreshTriggersRerenderOnAdded: GUI unavailable.\n');
        fprintf('    SKIP testRefreshTriggersRerenderOnOpenToClosed: GUI unavailable.\n');
    end

    fprintf('    %d passed, %d failed.\n', nPassed, nFailed);
    if nFailed > 0, error('test_fastsense_widget_event_markers:failures', '%d failed', nFailed); end
end
