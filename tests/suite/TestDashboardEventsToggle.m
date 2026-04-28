classdef TestDashboardEventsToggle < matlab.unittest.TestCase
    %TESTDASHBOARDEVENTSTOGGLE Coverage for quick 260424-jf5 (global Events
    %   toolbar toggle). Mirrors the Octave function-based test so both
    %   runners exercise the new code paths.

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testEngineDefaultTrue(testCase)
            d = DashboardEngine('ToggleDefault');
            testCase.verifyTrue(isprop(d, 'EventMarkersVisible'));
            testCase.verifyTrue(d.EventMarkersVisible);
        end

        function testEngineFlagFlip(testCase)
            d = DashboardEngine('ToggleFlagFlip');
            d.setEventMarkersVisible(false);
            testCase.verifyFalse(d.EventMarkersVisible);
            d.setEventMarkersVisible(true);
            testCase.verifyTrue(d.EventMarkersVisible);
        end

        function testToolbarButtonExists(testCase)
            d = DashboardEngine('EventsBtnExists');
            d.addWidget('number', 'Title', 'T', ...
                'Position', [1 1 6 2], 'StaticValue', 1);
            d.render();
            hFig = d.hFigure;
            testCase.addTeardown(@() closeFigSafe(hFig));
            set(hFig, 'Visible', 'off');

            testCase.verifyNotEmpty(d.Toolbar.hEventsBtn);
            testCase.verifyTrue(ishandle(d.Toolbar.hEventsBtn));
            testCase.verifyNotEmpty(d.Toolbar.hEventsPanel);
            testCase.verifyTrue(ishandle(d.Toolbar.hEventsPanel));
            tip = get(d.Toolbar.hEventsBtn, 'TooltipString');
            testCase.verifyNotEmpty(tip, ...
                'Events button must have a tooltip');
        end

        function testIndicatorBorderSwap(testCase)
            d = DashboardEngine('EventsBorder');
            d.addWidget('number', 'Title', 'T', ...
                'Position', [1 1 6 2], 'StaticValue', 1);
            d.render();
            hFig = d.hFigure;
            testCase.addTeardown(@() closeFigSafe(hFig));
            set(hFig, 'Visible', 'off');

            theme = d.getCachedTheme();

            d.Toolbar.setEventsActiveIndicator(true);
            onColor = get(d.Toolbar.hEventsPanel, 'HighlightColor');
            testCase.verifyLessThan(max(abs(onColor - theme.InfoColor)), 1e-6);

            d.Toolbar.setEventsActiveIndicator(false);
            offColor = get(d.Toolbar.hEventsPanel, 'HighlightColor');
            testCase.verifyLessThan(max(abs(offColor - theme.ToolbarBackground)), 1e-6);
        end

        function testFastSenseToggleClearsAndRepopulates(testCase)
            EventBinding.clear();
            f = figure('Visible', 'off');
            testCase.addTeardown(@() closeFigSafe(f));
            ax = axes('Parent', f);
            es = EventStore('');
            tag = SensorTag('tgl_fs', 'X', 1:100, 'Y', sin((1:100)/10)*30 + 40);
            tag.EventStore = es;
            tag.addManualEvent(20, 25, 'ev_a', '');
            tag.addManualEvent(60, 65, 'ev_b', '');

            fp = FastSense('Parent', ax);
            fp.EventStore = es;
            fp.addTag(tag);
            fp.render();

            fp.setShowEventMarkers(false);
            testCase.verifyFalse(fp.ShowEventMarkers);
            testCase.verifyEqual(countRoundMarkers(ax), 0, ...
                'round markers should be gone after toggle off');

            fp.setShowEventMarkers(true);
            testCase.verifyTrue(fp.ShowEventMarkers);
            testCase.verifyGreaterThanOrEqual(countRoundMarkers(ax), 1, ...
                'round markers should repopulate after toggle on');
        end

        function testFastSenseWidgetPreRenderNoOp(testCase)
            w = FastSenseWidget('Title', 'PreRender', 'Position', [1 1 6 2]);
            % No FastSenseObj yet — must not error.
            w.setEventMarkersVisible(false);
            w.setEventMarkersVisible(true);
            testCase.verifyTrue(true);  % reaching here = success
        end

        function testEventTimelineWidgetIsExempt(testCase)
            tw = EventTimelineWidget('Title', 'Tml', 'Position', [1 1 6 2]);
            testCase.verifyFalse(ismethod(tw, 'setEventMarkersVisible'), ...
                ['EventTimelineWidget must NOT implement setEventMarkersVisible ' ...
                 '— it exists solely to display events, so the engine fan-out ' ...
                 'skips it via ismethod().']);
        end

        function testFanoutUpdatesToolbarIndicator(testCase)
            d = DashboardEngine('FanoutIndicator');
            d.addWidget('number', 'Title', 'T', ...
                'Position', [1 1 6 2], 'StaticValue', 1);
            d.render();
            hFig = d.hFigure;
            testCase.addTeardown(@() closeFigSafe(hFig));
            set(hFig, 'Visible', 'off');

            theme = d.getCachedTheme();

            d.setEventMarkersVisible(false);
            borderOff = get(d.Toolbar.hEventsPanel, 'HighlightColor');
            testCase.verifyLessThan(max(abs(borderOff - theme.ToolbarBackground)), 1e-6);
            testCase.verifyFalse(d.EventMarkersVisible);

            d.setEventMarkersVisible(true);
            borderOn = get(d.Toolbar.hEventsPanel, 'HighlightColor');
            testCase.verifyLessThan(max(abs(borderOn - theme.InfoColor)), 1e-6);
        end

        function testTagRegistryEventStoreRoundTrip(testCase)
            % Phase 1017: setEventStore/getEventStore handle round-trip.
            TagRegistry.clear();
            EventBinding.clear();
            tempPath = [tempname, '.mat'];
            cleanup = onCleanup(@() deleteIfExists(tempPath)); %#ok<NASGU>
            s = EventStore(tempPath);
            TagRegistry.setEventStore(s);
            got = TagRegistry.getEventStore();
            testCase.verifyTrue(isequal(got, s));
        end

        function testTagRegistryEventStoreEmptyDefault(testCase)
            % Phase 1017: getEventStore() returns [] before any setEventStore call.
            TagRegistry.clear();
            EventBinding.clear();
            testCase.verifyEmpty(TagRegistry.getEventStore());
        end

        function testTagRegistryEventStoreOverwrite(testCase)
            % Phase 1017: second setEventStore overwrites first.
            TagRegistry.clear();
            EventBinding.clear();
            p1 = [tempname, '.mat']; p2 = [tempname, '.mat'];
            cleanup = onCleanup(@() cellfun(@deleteIfExists, {p1, p2})); %#ok<NASGU>
            s1 = EventStore(p1); s2 = EventStore(p2);
            TagRegistry.setEventStore(s1);
            TagRegistry.setEventStore(s2);
            testCase.verifyTrue(isequal(TagRegistry.getEventStore(), s2));
        end

        function testTagRegistryClearResetsEventStore(testCase)
            % Phase 1017: clear() wipes the registry-default EventStore slot.
            TagRegistry.clear();
            EventBinding.clear();
            tempPath = [tempname, '.mat'];
            cleanup = onCleanup(@() deleteIfExists(tempPath)); %#ok<NASGU>
            TagRegistry.setEventStore(EventStore(tempPath));
            TagRegistry.clear();
            testCase.verifyEmpty(TagRegistry.getEventStore());
        end

        function testTagRegistryEventStoreSetEmptyClears(testCase)
            % Phase 1017: setEventStore([]) clears the slot explicitly.
            TagRegistry.clear();
            EventBinding.clear();
            tempPath = [tempname, '.mat'];
            cleanup = onCleanup(@() deleteIfExists(tempPath)); %#ok<NASGU>
            TagRegistry.setEventStore(EventStore(tempPath));
            TagRegistry.setEventStore([]);
            testCase.verifyEmpty(TagRegistry.getEventStore());
        end

        function testMonitorTagRegistryDefaultFallback(testCase)
            % Phase 1017: MonitorTag constructor falls back to registry default.
            TagRegistry.clear();
            EventBinding.clear();
            tempPath = [tempname, '.mat'];
            cleanup = onCleanup(@() deleteIfExists(tempPath)); %#ok<NASGU>
            es = EventStore(tempPath);
            TagRegistry.setEventStore(es);
            parent = SensorTag('p');
            parent.updateData([1 2 3], [1 1 1]);
            m = MonitorTag('p.high', parent, @(x, y) y > 5);
            testCase.verifyTrue(isequal(m.EventStore, es));
        end

        function testMonitorTagExplicitOverridesRegistry(testCase)
            % Phase 1017: explicit 'EventStore' NV-pair wins over registry default.
            TagRegistry.clear();
            EventBinding.clear();
            p1 = [tempname, '.mat']; p2 = [tempname, '.mat'];
            cleanup = onCleanup(@() cellfun(@deleteIfExists, {p1, p2})); %#ok<NASGU>
            esRegistry = EventStore(p1);
            esExplicit = EventStore(p2);
            TagRegistry.setEventStore(esRegistry);
            parent = SensorTag('p');
            parent.updateData([1 2 3], [1 1 1]);
            m = MonitorTag('p.high', parent, @(x, y) y > 5, 'EventStore', esExplicit);
            testCase.verifyTrue(isequal(m.EventStore, esExplicit));
            testCase.verifyFalse(isequal(m.EventStore, esRegistry));
        end

        function testMonitorTagDualKeyEmission(testCase)
            % Phase 1017: events emitted by MonitorTag are reachable by parent.Key
            % AND monitor.Key via EventStore.getEventsForTag.
            TagRegistry.clear();
            EventBinding.clear();
            tempPath = [tempname, '.mat'];
            cleanup = onCleanup(@() deleteIfExists(tempPath)); %#ok<NASGU>
            es = EventStore(tempPath);
            TagRegistry.setEventStore(es);
            parent = SensorTag('reactor.pressure');
            parent.updateData([1 2 3], [1 1 1]);
            m = MonitorTag('reactor.pressure.critical', parent, @(x, y) y > 18);
            % Drive a closed event: append violating then non-violating Y.
            parent.updateData([1 2 3 4 5 6], [1 1 1 20 20 1]);
            m.appendData([4 5 6], [20 20 1]);
            byParent = es.getEventsForTag('reactor.pressure');
            byMonitor = es.getEventsForTag('reactor.pressure.critical');
            testCase.verifyNotEmpty(byParent);
            testCase.verifyNotEmpty(byMonitor);
        end
    end
end

function deleteIfExists(p)
    if ischar(p) && exist(p, 'file') == 2
        try
            delete(p);
        catch
        end
    end
end

function n = countRoundMarkers(ax)
    children = allchild(ax);
    n = 0;
    for i = 1:numel(children)
        try
            mk = get(children(i), 'Marker');
            ls = get(children(i), 'LineStyle');
            if strcmp(mk, 'o') && strcmp(ls, 'none')
                n = n + 1;
            end
        catch
            % non-line children — ignore
        end
    end
end

function closeFigSafe(h)
    try
        if ~isempty(h) && ishandle(h)
            close(h);
        end
    catch
        % teardown best-effort
    end
end
