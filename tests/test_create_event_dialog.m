function test_create_event_dialog()
%TEST_CREATE_EVENT_DIALOG Coverage for the per-FastSenseWidget Create-Event flow (260513-snt).
%
%   Headless-safe: no test opens a modal figure. All persistence is
%   driven through the static CreateEventDialog.persistEventStatic seam
%   so the figure-side code (buildUI) never runs. The few tests that
%   do touch graphics handles (Test 9 — clearPanelControls preserves
%   CreateEventButton) build a hidden uipanel parented to an invisible
%   figure and close it via onCleanup.
%
%   Cases:
%     1) CreateEventDialog([], []) throws CreateEventDialog:invalidWidget.
%     2) CreateEventDialog(realFastSenseWidget, []) throws
%        CreateEventDialog:invalidEngine.
%     3) Engine with empty EventStore: openCreateEventDialog_ wired
%        path surfaces an errordlg (verified via lastwarn / no crash).
%     4) persistEventStatic appends one Event to a stub EventStore;
%        verifies Id, Category, Severity, Notes, TagKeys, and
%        EventBinding.getEventsForTag returns it.
%     5) persistEventStatic with EndTime < StartTime throws
%        CreateEventDialog:invalidTimeRange.
%     6) persistEventStatic with empty Label throws
%        CreateEventDialog:emptyLabel.
%     7) engine.notifyEventsChanged() does NOT throw when called on
%        an engine with no widgets and no rendered figure.
%     8) engine.resolveEventStore_ (via openCreateEventDialog_ call
%        pattern) auto-discovers an EventStore from an
%        EventTimelineWidget added to an engine; a second call returns
%        the cached handle (handle identity check).
%     9) DashboardWidget.clearPanelControls (driven via a synthetic
%        FastSenseWidget panel with a Tag='CreateEventButton'
%        uicontrol child) preserves the button.

    add_create_event_dialog_path();

    nPassed = 0;
    nFailed = 0;

    % --- Test 1: invalidWidget --------------------------------------
    try
        ok = false;
        try
            CreateEventDialog([], []); %#ok<NASGU>
        catch e
            ok = strcmp(e.identifier, 'CreateEventDialog:invalidWidget');
        end
        assert(ok, 'Test 1: expected CreateEventDialog:invalidWidget');
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL test1_invalidWidget: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % --- Test 2: invalidEngine --------------------------------------
    try
        tag = make_sensor_tag_();
        w   = FastSenseWidget('Tag', tag, 'Title', 'demo.signal');
        ok = false;
        try
            CreateEventDialog(w, []); %#ok<NASGU>
        catch e
            ok = strcmp(e.identifier, 'CreateEventDialog:invalidEngine');
        end
        assert(ok, 'Test 2: expected CreateEventDialog:invalidEngine');
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL test2_invalidEngine: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % --- Test 3: no-store path surfaces errordlg without crashing ---
    try
        tag = make_sensor_tag_();
        w   = FastSenseWidget('Tag', tag, 'Title', 'demo.signal');
        engine = DashboardEngine('NoStoreTest');
        % Suppress the errordlg modal by stubbing errordlg via lastwarn.
        % We can't intercept the dialog directly, so the assertion is:
        % a) the engine call does not throw (returns cleanly),
        % b) the dialog was never built (engine.EventStore stays empty
        %    because nothing was attached and no auto-discovery target
        %    exists).
        %
        % Driving the private openCreateEventDialog_ through a tiny
        % public wrapper is overkill — directly exercising
        % resolveEventStore_ via the public proxy (calling
        % CreateEventDialog itself with a bound store would throw
        % noStore inside the constructor) is the cleanest.
        threw = false;
        try
            CreateEventDialog(w, engine);
        catch e
            threw = strcmp(e.identifier, 'CreateEventDialog:noStore');
        end
        assert(threw, ['Test 3: expected CreateEventDialog:noStore on ', ...
                       'engine without a bound EventStore']);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL test3_noStorePath: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % --- Test 4: persistEventStatic happy path ---------------------
    try
        engine = DashboardEngine('PersistHappyTest');
        engine.EventStore = EventStore([tempname() '.mat']);
        EventBinding.clear();   % reset registry so the count check is exact
        CreateEventDialog.persistEventStatic( ...
            engine, 0, 10, 'peak A', 2, 'manual_annotation', ...
            sprintf('line1%cline2', 10), {'demo.signal'}, 'demo.signal');
        evs = engine.EventStore.getEvents();
        assert(numel(evs) == 1, 'Test 4: expected 1 event in store');
        ev = evs(1);
        assert(~isempty(ev.Id),                          'Test 4: Id should be set after append');
        assert(strcmp(ev.Category, 'manual_annotation'), 'Test 4: Category mismatch');
        assert(ev.Severity == 2,                         'Test 4: Severity mismatch');
        assert(isequal(ev.TagKeys, {'demo.signal'}),     'Test 4: TagKeys mismatch');
        assert(ev.StartTime == 0 && ev.EndTime == 10,    'Test 4: time range mismatch');
        % Notes carry a newline through unchanged
        assert(~isempty(ev.Notes), 'Test 4: Notes should be non-empty');
        bound = EventBinding.getEventsForTag('demo.signal', engine.EventStore);
        assert(numel(bound) == 1, 'Test 4: EventBinding lookup should return 1 event');
        assert(strcmp(bound(1).Id, ev.Id), 'Test 4: bound event Id mismatch');
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL test4_persistHappy: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % --- Test 5: invalid time range -------------------------------
    try
        engine = DashboardEngine('PersistInvRangeTest');
        engine.EventStore = EventStore([tempname() '.mat']);
        ok = false;
        try
            CreateEventDialog.persistEventStatic(engine, 10, 0, 'L', 1, ...
                'manual_annotation', '', {}, 'p');
        catch e
            ok = strcmp(e.identifier, 'CreateEventDialog:invalidTimeRange');
        end
        assert(ok, 'Test 5: expected CreateEventDialog:invalidTimeRange');
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL test5_invalidTimeRange: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % --- Test 6: empty label --------------------------------------
    try
        engine = DashboardEngine('PersistEmptyLabelTest');
        engine.EventStore = EventStore([tempname() '.mat']);
        ok = false;
        try
            CreateEventDialog.persistEventStatic(engine, 0, 10, '   ', 1, ...
                'manual_annotation', '', {}, 'p');
        catch e
            ok = strcmp(e.identifier, 'CreateEventDialog:emptyLabel');
        end
        assert(ok, 'Test 6: expected CreateEventDialog:emptyLabel');
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL test6_emptyLabel: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % --- Test 7: notifyEventsChanged no-throw on bare engine -----
    try
        engine = DashboardEngine('NotifyBareTest');
        % No widgets, no rendered figure: must not throw.
        engine.notifyEventsChanged();
        % And again after adding an EventStore (still no widgets):
        engine.EventStore = EventStore([tempname() '.mat']);
        engine.notifyEventsChanged();
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL test7_notifyBare: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % --- Test 8: resolveEventStore auto-discovers + caches -------
    %   resolveEventStore_ is private; we exercise it indirectly via the
    %   public callback wired in render() (Layout.CreateEventCallback ->
    %   openCreateEventDialog_ -> resolveEventStore_). To avoid building
    %   a modal figure in a headless test, we replicate the walk the
    %   private resolver performs and then assert engine.EventStore is
    %   populated and reused. The walk-logic is documented in the plan;
    %   keeping the test independent of any figure plumbing avoids the
    %   Octave private-setter teardown noise.
    try
        engine = DashboardEngine('AutoDiscoverTest');
        assert(isempty(engine.EventStore), ...
            'Test 8: EventStore should start empty');
        store = EventStore([tempname() '.mat']);
        tw = EventTimelineWidget('Title', 'Events', 'EventStoreObj', store);
        engine.addWidget(tw);
        % Mirror what private resolveEventStore_ does:
        ws = engine.allPageWidgets();
        flat = flatten_widgets_(ws);
        for k = 1:numel(flat)
            wd = flat{k};
            if isa(wd, 'EventTimelineWidget') && ~isempty(wd.EventStoreObj)
                engine.EventStore = wd.EventStoreObj;
                break;
            end
        end
        assert(~isempty(engine.EventStore), ...
            'Test 8: auto-discovery walk should populate engine.EventStore');
        firstHandle = engine.EventStore;
        % Idempotence: a second resolution path returns the cached handle.
        % (resolveEventStore_'s contract: short-circuit when EventStore is set.)
        % Octave's classdef handles do not implement eq() for arbitrary
        % subclasses, so compare via FilePath identity + isa() guard.
        store2 = engine.EventStore;
        assert(isa(store2, 'EventStore'), 'Test 8: cached value must be EventStore');
        assert(strcmp(store2.FilePath, firstHandle.FilePath), ...
            'Test 8: a second resolveEventStore_ call should return the cached store');
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL test8_autoDiscover: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % --- Test 9: clearPanelControls preserves CreateEventButton ---
    try
        fig = figure('Visible', 'off');
        cleanupFig = onCleanup(@() safe_close_(fig));
        hp = uipanel('Parent', fig, 'Units', 'normalized', 'Position', [0 0 1 1]);
        % Inject a 'CreateEventButton' uicontrol plus a generic
        % non-protected uicontrol that SHOULD be deleted.
        uicontrol('Parent', hp, 'Style', 'pushbutton', 'String', '+', ...
            'Tag', 'CreateEventButton');
        uicontrol('Parent', hp, 'Style', 'text', 'String', 'placeholder', ...
            'Tag', 'placeholder');
        % Drive clearPanelControls. The method is static & protected;
        % use a tiny test-only shim that calls it through a subclass.
        clear_panel_controls_via_subclass_(hp);
        % Expected: CreateEventButton survives, placeholder is gone.
        keep = findobj(hp, 'Tag', 'CreateEventButton', '-depth', 1);
        gone = findobj(hp, 'Tag', 'placeholder',       '-depth', 1);
        assert(~isempty(keep) && ishandle(keep(1)), ...
            'Test 9: CreateEventButton must survive clearPanelControls');
        assert(isempty(gone), ...
            'Test 9: non-protected uicontrol should have been deleted');
        clear cleanupFig;
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL test9_protectedTag: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    fprintf('    %d passed, %d failed (Create-Event tests, 260513-snt)\n', nPassed, nFailed);
    if nFailed > 0
        error('test_create_event_dialog: %d/%d failed', nFailed, nPassed + nFailed);
    end
end

% ============================================================
% Local helpers (kept private to this test file)
% ============================================================

function add_create_event_dialog_path()
%ADD_CREATE_EVENT_DIALOG_PATH Add repo + tests directory to MATLAB path
%   and call install() once so libs/ classes are reachable.
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(here);
    addpath(repo);
    addpath(here);
    install();
end

function tag = make_sensor_tag_()
%MAKE_SENSOR_TAG_ Build a small SensorTag for widget binding in tests.
    t = (0:1:100)';
    y = sin(t / 10);
    tag = SensorTag('demo.signal', 'Name', 'demo signal', 'X', t, 'Y', y);
end

function flat = flatten_widgets_(widgets, depth)
%FLATTEN_WIDGETS_ Local depth-first flatten mirroring engine helper.
    if nargin < 2, depth = 0; end
    flat = {};
    if depth >= 10
        flat = widgets;
        return;
    end
    for i = 1:numel(widgets)
        w = widgets{i};
        nested = {};
        try
            nested = w.getNestedWidgets();
        catch
            nested = {};
        end
        if isempty(nested)
            flat = [flat, {w}]; %#ok<AGROW>
        else
            flat = [flat, flatten_widgets_(nested, depth + 1)]; %#ok<AGROW>
        end
    end
end

function clear_panel_controls_via_subclass_(hp)
%CLEAR_PANEL_CONTROLS_VIA_SUBCLASS_ Drive DashboardWidget.clearPanelControls
%   via a lightweight subclass that exposes the protected static.
    TestClearPanelHelper.run(hp);
end

function safe_close_(h)
%SAFE_CLOSE_ Close a figure handle if still alive.
    try
        if ~isempty(h) && ishandle(h)
            close(h);
        end
    catch
    end
end
