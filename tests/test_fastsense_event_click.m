function test_fastsense_event_click
    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(root); install();
    nPassed = 0; nFailed = 0;

    % --- Helper: find event-marker line handles by Tag (shape-agnostic) ---
    % Phase 1012 uses '^' (triangle) markers tagged 'FastSenseEventMarker'.
    function handles = findRoundMarkers(fig)
        allLines = findall(fig, 'Type', 'line');
        handles = {};
        for ci = 1:numel(allLines)
            try
                if strcmp(get(allLines(ci), 'Tag'), 'FastSenseEventMarker')
                    handles{end+1} = allLines(ci); %#ok<AGROW>
                end
            catch
            end
        end
    end

    % --- Build fixture ---
    function [fp_, ev_, fig_] = mkFixture(isOpen)
        fig_ = figure('Visible', 'off');
        ax = axes('Parent', fig_);
        parent = SensorTag('p');
        parent.updateData([0 1 2 3 4 5], [0 0 0 10 10 0]);
        es = EventStore('');
        if isOpen
            ev_ = Event(3, NaN, 'p', 'hi', 5, 'upper'); ev_.IsOpen = true;
        else
            ev_ = Event(3, 4, 'p', 'hi', 5, 'upper');
        end
        ev_.Severity = 2;
        es.append(ev_);
        ev_.TagKeys = {'p'};
        EventBinding.attach(ev_.Id, 'p');
        fp_ = FastSense('Parent', ax);
        fp_.addTag(parent);
        fp_.ShowEventMarkers = true;
        fp_.EventStore = es;
        fp_.render();
    end

    % testPerMarkerButtonDownFcnIsSet
    try
        [fp, ~, fig] = mkFixture(false);
        markers = findRoundMarkers(fig);
        assert(numel(markers) >= 1, 'Expected at least 1 round marker, got 0');
        bd = get(markers{1}, 'ButtonDownFcn');
        assert(isa(bd, 'function_handle'), 'ButtonDownFcn must be a function_handle');
        delete(fig);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testPerMarkerButtonDownFcnIsSet: %s\n', err.message); nFailed = nFailed + 1;
    end

    % testUserDataHoldsEventId
    try
        [fp, ev, fig] = mkFixture(false);
        markers = findRoundMarkers(fig);
        assert(numel(markers) >= 1, 'Expected at least 1 round marker');
        ud = get(markers{1}, 'UserData');
        assert(isstruct(ud), 'UserData must be a struct');
        assert(isfield(ud, 'eventId'), 'UserData must have eventId field');
        assert(strcmp(ud.eventId, ev.Id), 'UserData.eventId must match Event.Id');
        delete(fig);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testUserDataHoldsEventId: %s\n', err.message); nFailed = nFailed + 1;
    end

    % testOpenEventMarkerIsHollow
    try
        [fp, ~, fig] = mkFixture(true);
        markers = findRoundMarkers(fig);
        assert(numel(markers) >= 1, 'Expected at least 1 round marker');
        faceColor = get(markers{1}, 'MarkerFaceColor');
        assert(strcmp(faceColor, 'none'), 'Open event marker must be hollow (MarkerFaceColor=none)');
        delete(fig);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testOpenEventMarkerIsHollow: %s\n', err.message); nFailed = nFailed + 1;
    end

    % testClosedEventMarkerIsFilled
    try
        [fp, ~, fig] = mkFixture(false);
        markers = findRoundMarkers(fig);
        assert(numel(markers) >= 1, 'Expected at least 1 round marker');
        faceColor = get(markers{1}, 'MarkerFaceColor');
        assert(~ischar(faceColor) || ~strcmp(faceColor, 'none'), ...
            'Closed event marker must be filled (MarkerFaceColor != none)');
        delete(fig);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testClosedEventMarkerIsFilled: %s\n', err.message); nFailed = nFailed + 1;
    end

    % testFormatEventFieldsShowsOpenForOpenEvent
    if ~exist('OCTAVE_VERSION', 'builtin')
        try
            ev = Event(5, NaN, 's1', 'hi', 5, 'upper'); ev.IsOpen = true;
            fp = FastSense();
            txt = fp.formatEventFields_(ev);
            assert(~isempty(strfind(txt, 'EndTime:        Open')));
            assert(~isempty(strfind(txt, 'Duration:       Open')));
            nPassed = nPassed + 1;
        catch err
            fprintf('    FAIL testFormatEventFieldsShowsOpenForOpenEvent: %s\n', err.message); nFailed = nFailed + 1;
        end
    else
        fprintf('    SKIP testFormatEventFieldsShowsOpenForOpenEvent: Octave private-access enforcement.\n');
    end

    fprintf('    SKIP testClickOpensDetailsPanel: GUI + JVM required.\n');
    fprintf('    SKIP testEscDismissesDetailsPanel: GUI + JVM required.\n');
    fprintf('    SKIP testXButtonDismissesDetailsPanel: GUI + JVM required.\n');

    fprintf('    %d passed, %d failed (3 GUI skipped).\n', nPassed, nFailed);
    if nFailed > 0, error('test_fastsense_event_click:failures', '%d failed', nFailed); end
end
