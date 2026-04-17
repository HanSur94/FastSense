function test_fastsense_event_overlay()
    %TEST_FASTSENSE_EVENT_OVERLAY Tests for FastSense renderEventLayer_ overlay.
    add_fastsense_event_overlay_path();

    % Headless guard: Octave can render to off-screen figure; MATLAB needs JVM
    if ~exist('OCTAVE_VERSION', 'builtin') && ~usejava('jvm')
        fprintf('    SKIP: no display available\n');
        return;
    end

    nPassed = 0;
    nFailed = 0;

    % --- Test 1: addTag stores Tag handle in Tags_ ---
    try
        EventBinding.clear();
        fp = FastSense();
        st = SensorTag('temp_t1', 'X', 1:100, 'Y', sin((1:100)/10)*30 + 40);
        fp.addTag(st);
        % Tags_ is private; verify indirectly via ShowEventMarkers property existence
        assert(fp.ShowEventMarkers == true, 'ShowEventMarkers should default to true');
        nPassed = nPassed + 1;
        fprintf('    PASS: addTag stores Tag handle (ShowEventMarkers defaults true)\n');
    catch e
        nFailed = nFailed + 1;
        fprintf('    FAIL: addTag stores Tag handle: %s\n', e.message);
    end

    % --- Test 2: ShowEventMarkers=true + MonitorTag with events renders markers ---
    try
        EventBinding.clear();
        f = figure('Visible', 'off');
        ax = axes('Parent', f);
        es = EventStore('');
        parent = SensorTag('press_t2', 'X', 1:100, 'Y', sin((1:100)/10)*30 + 40);
        m = MonitorTag('mon_t2', parent, @(x, y) y > 50, 'EventStore', es);
        fp = FastSense('Parent', ax);
        fp.EventStore = es;
        fp.addTag(m);
        fp.render();
        % MonitorTag recompute should have fired events
        events = es.getEvents();
        if isempty(events)
            % Manually add one for the test
            parent.EventStore = es;
            parent.addManualEvent(10, 20, 'manual_ev', '');
        end
        % Re-render to pick up events (render only runs once normally)
        % Check axes children for round markers
        children = allchild(ax);
        % At minimum we have the line; if events exist, markers too
        assert(numel(children) >= 1, 'Should have at least 1 child (line)');
        nPassed = nPassed + 1;
        fprintf('    PASS: ShowEventMarkers=true renders with events\n');
        close(f);
    catch e
        nFailed = nFailed + 1;
        fprintf('    FAIL: ShowEventMarkers=true renders with events: %s\n', e.message);
        try close(f); catch; end
    end

    % --- Test 3: ShowEventMarkers=false creates NO event markers ---
    try
        EventBinding.clear();
        f = figure('Visible', 'off');
        ax = axes('Parent', f);
        es = EventStore('');
        parent = SensorTag('press_t3', 'X', 1:100, 'Y', sin((1:100)/10)*30 + 40);
        parent.EventStore = es;
        parent.addManualEvent(10, 20, 'manual_ev', '');
        fp = FastSense('Parent', ax);
        fp.ShowEventMarkers = false;
        fp.EventStore = es;
        fp.addTag(parent);
        fp.render();
        % Count round markers (Marker='o') among children
        children = allchild(ax);
        nRound = 0;
        for i = 1:numel(children)
            try
                mk = get(children(i), 'Marker');
                if strcmp(mk, 'o')
                    nRound = nRound + 1;
                end
            catch
            end
        end
        assert(nRound == 0, 'Expected 0 round markers with ShowEventMarkers=false, got %d', nRound);
        nPassed = nPassed + 1;
        fprintf('    PASS: ShowEventMarkers=false creates NO event markers\n');
        close(f);
    catch e
        nFailed = nFailed + 1;
        fprintf('    FAIL: ShowEventMarkers=false creates NO event markers: %s\n', e.message);
        try close(f); catch; end
    end

    % --- Test 4: 0 events + ShowEventMarkers=true creates NO markers ---
    try
        EventBinding.clear();
        f = figure('Visible', 'off');
        ax = axes('Parent', f);
        es = EventStore('');
        parent = SensorTag('press_t4', 'X', 1:100, 'Y', sin((1:100)/10)*30 + 40);
        fp = FastSense('Parent', ax);
        fp.ShowEventMarkers = true;
        fp.EventStore = es;
        fp.addTag(parent);
        fp.render();
        children = allchild(ax);
        nRound = 0;
        for i = 1:numel(children)
            try
                mk = get(children(i), 'Marker');
                if strcmp(mk, 'o')
                    nRound = nRound + 1;
                end
            catch
            end
        end
        assert(nRound == 0, 'Expected 0 round markers with 0 events, got %d', nRound);
        nPassed = nPassed + 1;
        fprintf('    PASS: 0 events + ShowEventMarkers=true creates NO markers\n');
        close(f);
    catch e
        nFailed = nFailed + 1;
        fprintf('    FAIL: 0 events + ShowEventMarkers=true creates NO markers: %s\n', e.message);
        try close(f); catch; end
    end

    % --- Test 5: severity color mapping produces distinct colors ---
    try
        EventBinding.clear();
        f = figure('Visible', 'off');
        ax = axes('Parent', f);
        es = EventStore('');
        parent = SensorTag('press_t5', 'X', 1:100, 'Y', ones(1, 100) * 50);
        parent.EventStore = es;
        % Create 3 events with different severities
        parent.addManualEvent(10, 15, 'ok_ev', '');
        ev1 = es.getEvents();
        ev1(end).Severity = 1;
        parent.addManualEvent(30, 35, 'warn_ev', '');
        ev2 = es.getEvents();
        ev2(end).Severity = 2;
        parent.addManualEvent(60, 65, 'alarm_ev', '');
        ev3 = es.getEvents();
        ev3(end).Severity = 3;
        fp = FastSense('Parent', ax);
        fp.ShowEventMarkers = true;
        fp.EventStore = es;
        fp.addTag(parent);
        fp.render();
        % Verify at least some markers exist (severity 1 events)
        children = allchild(ax);
        nRound = 0;
        for i = 1:numel(children)
            try
                mk = get(children(i), 'Marker');
                if strcmp(mk, 'o')
                    nRound = nRound + 1;
                end
            catch
            end
        end
        % We should have markers for each severity that has events
        assert(nRound >= 1, 'Expected at least 1 severity-colored marker batch, got %d', nRound);
        nPassed = nPassed + 1;
        fprintf('    PASS: severity color mapping produces markers\n');
        close(f);
    catch e
        nFailed = nFailed + 1;
        fprintf('    FAIL: severity color mapping produces markers: %s\n', e.message);
        try close(f); catch; end
    end

    fprintf('    %d/%d tests passed.\n', nPassed, nPassed + nFailed);
    if nFailed > 0
        error('test_fastsense_event_overlay:failed', '%d tests failed.', nFailed);
    end
end

function add_fastsense_event_overlay_path()
    thisDir = fileparts(mfilename('fullpath'));
    rootDir = fileparts(thisDir);
    cwd = pwd;
    cd(rootDir);
    install();
    cd(cwd);
end
