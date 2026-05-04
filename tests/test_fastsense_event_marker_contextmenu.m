function test_fastsense_event_marker_contextmenu
%TEST_FASTSENSE_EVENT_MARKER_CONTEXTMENU Right-click context menu on event markers.
%   Covers FastSense.onEventMarkerClick_ SelectionType branching: left-click
%   preserves the existing details-popup behavior; right-click builds and
%   caches a uicontextmenu with four navigation actions.
%
%   Octave note: uicontextmenu support varies on Octave; this test skips
%   cleanly there (matches the GUI-skip pattern of test_fastsense_event_click).
%
%   See also FastSense, test_fastsense_event_click, openEventDetails_.
    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(root); install();
    nPassed = 0; nFailed = 0;

    % Octave: uicontextmenu support varies; skip cleanly.
    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('    Skipping on Octave (uicontextmenu support varies).\n');
        return;
    end

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

    function [fp_, ev_, fig_] = mkFixture()
        fig_ = figure('Visible', 'off');
        ax = axes('Parent', fig_);
        parent = SensorTag('p');
        parent.updateData([0 1 2 3 4 5], [0 0 0 10 10 0]);
        es = EventStore('');
        ev_ = Event(3, 4, 'p', 'hi', 5, 'upper');
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

    % testLeftClickOpensDetails — preserves existing behavior
    try
        [fp, ~, fig] = mkFixture();
        markers = findRoundMarkers(fig);
        assert(numel(markers) >= 1, 'Expected at least 1 round marker');
        set(fig, 'SelectionType', 'normal');
        fp.onEventMarkerClick_(markers{1}, []);
        % Find spawned event-details popup figure (any figure with Name starting 'Event ').
        allFigs = findall(0, 'Type', 'figure');
        foundPopup = false;
        for i = 1:numel(allFigs)
            if ~isempty(strfind(get(allFigs(i), 'Name'), 'Event '))
                foundPopup = true;
                delete(allFigs(i));
                break;
            end
        end
        assert(foundPopup, 'Left-click must open event-details popup');
        delete(fig);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testLeftClickOpensDetails: %s\n', err.message); nFailed = nFailed + 1;
    end

    % testRightClickBuildsContextMenuWithFourLabels
    try
        [fp, ~, fig] = mkFixture();
        markers = findRoundMarkers(fig);
        set(fig, 'SelectionType', 'alt');
        fp.onEventMarkerClick_(markers{1}, []);
        cm = fp.EventContextMenu_;
        assert(~isempty(cm) && ishandle(cm), 'Right-click must build/cache uicontextmenu');
        assert(strcmp(get(cm, 'Type'), 'uicontextmenu'), 'Cached handle must be uicontextmenu');

        children = findall(cm, 'Type', 'uimenu');
        labels = arrayfun(@(h) get(h, 'Label'), children, 'UniformOutput', false);
        expected = {'Open details…', 'Jump to next violation', ...
                    'Jump to previous violation', 'Copy event ID'};
        for k = 1:numel(expected)
            assert(any(strcmp(labels, expected{k})), ...
                sprintf('Expected menu item "%s" not found', expected{k}));
        end
        delete(fig);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testRightClickBuildsContextMenuWithFourLabels: %s\n', err.message); nFailed = nFailed + 1;
    end

    % testRightClickCachesMenuAcrossInvocations
    try
        [fp, ~, fig] = mkFixture();
        markers = findRoundMarkers(fig);
        set(fig, 'SelectionType', 'alt');
        fp.onEventMarkerClick_(markers{1}, []);
        cm1 = fp.EventContextMenu_;
        fp.onEventMarkerClick_(markers{1}, []);
        cm2 = fp.EventContextMenu_;
        assert(cm1 == cm2, 'Cached uicontextmenu must be reused across right-clicks');
        delete(fig);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testRightClickCachesMenuAcrossInvocations: %s\n', err.message); nFailed = nFailed + 1;
    end

    fprintf('    %d passed, %d failed\n', nPassed, nFailed);
    if nFailed > 0
        error('test_fastsense_event_marker_contextmenu:failures', '%d failures', nFailed);
    end
end
