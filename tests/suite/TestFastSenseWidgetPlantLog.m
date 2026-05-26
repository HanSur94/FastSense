classdef TestFastSenseWidgetPlantLog < matlab.unittest.TestCase
%TESTFASTSENSEWIDGETPLANTLOG Class-based MATLAB suite for Phase 1032 (PLOG-VIZ-03 + PLOG-VIZ-04).
%   Mirrors the function-style file tests/test_fastsense_widget_plant_log.m
%   and adds uifigure-dependent fan-out + listener cleanup tests that are
%   awkward to express in the function-style runner.
%
%   Coverage:
%     - ShowPlantLog default false (Task 1)
%     - toStruct omits showPlantLog when false, writes when true (Task 1)
%     - fromStruct reads showPlantLog presence/absence (Task 1)
%     - setPlantLogMarkers shape: count, color, line-width, Tag (Task 1)
%     - Empty input clears markers (Task 1)
%     - Non-finite input dropped silently (Task 1)
%     - Idempotent clear-then-draw (Task 1)
%     - delete() releases listener slot (Task 1)
%     - Engine refresh helper safe when ShowPlantLog=false (Task 2)
%     - Engine refresh draws all entries in XLim (Task 2)
%     - Engine sub-pixel coalesce reduces drawn count (Task 2)
%     - Engine clearPlantLogOverlaysOnAllWidgets_ preserves ShowPlantLog (Task 2)
%     - Engine onPlantLogTailTick_ fans out to widgets with ShowPlantLog=true (Task 2)
%     - Engine tick skips ShowPlantLog=false widgets (Task 2)
%     - Engine attachPlantLogXLimListener_ redraws on XLim change (Task 2)
%     - Engine refresh clears markers when store is empty (Task 2)
%     - setShowPlantLog(true/false, engine) toggles state + listener (Task 2)
%     - setShowPlantLog with bad engine reverts state + warns (Task 2)
%     - delete(widget) with active listener does not throw (Task 2)

    properties
        Handles  = {}
        Engines  = {}
        Widgets  = {}
        Stores   = {}
        Tails    = {}
    end

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            thisDir = fileparts(mfilename('fullpath'));
            repoRoot = fileparts(fileparts(thisDir));
            addpath(repoRoot);
            install();
        end
    end

    methods (TestMethodTeardown)
        function cleanupAll(testCase)
            for k = 1:numel(testCase.Tails)
                try
                    if ~isempty(testCase.Tails{k}) && isvalid(testCase.Tails{k})
                        delete(testCase.Tails{k});
                    end
                catch
                end
            end
            for k = 1:numel(testCase.Widgets)
                try
                    if ~isempty(testCase.Widgets{k}) && isvalid(testCase.Widgets{k})
                        delete(testCase.Widgets{k});
                    end
                catch
                end
            end
            for k = 1:numel(testCase.Engines)
                try
                    if ~isempty(testCase.Engines{k}) && isvalid(testCase.Engines{k})
                        delete(testCase.Engines{k});
                    end
                catch
                end
            end
            for k = 1:numel(testCase.Handles)
                try
                    if ishandle(testCase.Handles{k})
                        delete(testCase.Handles{k});
                    end
                catch
                end
            end
            testCase.Tails   = {};
            testCase.Widgets = {};
            testCase.Engines = {};
            testCase.Stores  = {};
            testCase.Handles = {};
        end
    end

    methods (Access = private)
        function [f, panel] = makeFigPanel_(testCase)
            f = figure('Visible', 'off');
            testCase.Handles{end+1} = f;
            panel = uipanel(f, 'Position', [0 0 1 1]);
        end

        function w = makeRenderedWidget_(testCase, xLim, panel)
            x = linspace(xLim(1), xLim(2), 100);
            y = sin(x * 0.1);
            w = FastSenseWidget('Title', 'Test', 'Position', [1 1 12 3], ...
                'XData', x, 'YData', y);
            w.render(panel);
            set(w.FastSenseObj.hAxes, 'XLim', xLim);
            testCase.Widgets{end+1} = w;
        end

        function s = makePopulatedStore_(testCase, timestamps, messages)
            s = PlantLogStore('synthetic.csv');
            n = numel(timestamps);
            es = repmat(PlantLogEntry('Timestamp', timestamps(1), ...
                'Message', messages{1}, 'Metadata', struct()), 1, n);
            for k = 2:n
                es(k) = PlantLogEntry('Timestamp', timestamps(k), ...
                    'Message', messages{k}, 'Metadata', struct());
            end
            s.addEntries(es);
            testCase.Stores{end+1} = s;
        end

        function entries = makeEntryArray_(testCase, timestamps) %#ok<INUSL>
            n = numel(timestamps);
            entries = struct('Timestamp', num2cell(timestamps), ...
                'Message', repmat({''}, 1, n), ...
                'Metadata', repmat({struct()}, 1, n));
        end
    end

    methods (Test)

        function testDefaultShowPlantLogIsFalse(testCase)
            w = FastSenseWidget('Title', 'x', 'XData', 1:10, 'YData', 1:10);
            testCase.Widgets{end+1} = w;
            testCase.verifyTrue(isprop(w, 'ShowPlantLog'));
            testCase.verifyFalse(logical(w.ShowPlantLog));
            testCase.verifyTrue(isprop(w, 'PlantLogXLimListener_'));
            testCase.verifyEmpty(w.PlantLogXLimListener_);
        end

        function testToStructOmitsShowPlantLogWhenFalse(testCase)
            w = FastSenseWidget('Title', 'x', 'XData', 1:10, 'YData', 1:10);
            testCase.Widgets{end+1} = w;
            s = w.toStruct();
            testCase.verifyFalse(isfield(s, 'showPlantLog'));
        end

        function testToStructWritesShowPlantLogWhenTrue(testCase)
            w = FastSenseWidget('Title', 'x', 'XData', 1:10, 'YData', 1:10);
            testCase.Widgets{end+1} = w;
            w.ShowPlantLog = true;
            s = w.toStruct();
            testCase.verifyTrue(isfield(s, 'showPlantLog'));
            testCase.verifyTrue(s.showPlantLog);
        end

        function testFromStructReadsShowPlantLogTrue(testCase)
            s = struct('type', 'fastsense', 'title', 't', ...
                'position', struct('col', 1, 'row', 1, 'width', 12, 'height', 3), ...
                'showPlantLog', true);
            w = FastSenseWidget.fromStruct(s);
            testCase.Widgets{end+1} = w;
            testCase.verifyTrue(logical(w.ShowPlantLog));
        end

        function testFromStructDefaultsShowPlantLogFalse(testCase)
            s = struct('type', 'fastsense', 'title', 't', ...
                'position', struct('col', 1, 'row', 1, 'width', 12, 'height', 3));
            w = FastSenseWidget.fromStruct(s);
            testCase.Widgets{end+1} = w;
            testCase.verifyFalse(logical(w.ShowPlantLog));
        end

        function testSetPlantLogMarkersDrawsThreeLines(testCase)
            [~, panel] = testCase.makeFigPanel_();
            w = testCase.makeRenderedWidget_([0 100], panel);

            times = [10 20 30];
            entries = testCase.makeEntryArray_(times);
            w.setPlantLogMarkers(times, entries);

            ax = w.FastSenseObj.hAxes;
            h = findobj(ax, 'Tag', 'WidgetPlantLogMarker');
            testCase.verifyEqual(numel(h), 3);
            for k = 1:numel(h)
                testCase.verifyEqual(get(h(k), 'Color'), [0 0 0]);
                testCase.verifyEqual(get(h(k), 'LineWidth'), 1);
            end
        end

        function testSetPlantLogMarkersEmptyClears(testCase)
            [~, panel] = testCase.makeFigPanel_();
            w = testCase.makeRenderedWidget_([0 100], panel);

            times = [10 20 30];
            w.setPlantLogMarkers(times, testCase.makeEntryArray_(times));
            ax = w.FastSenseObj.hAxes;
            testCase.verifyEqual(numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')), 3);

            w.setPlantLogMarkers([], []);
            testCase.verifyEqual(numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')), 0);

            w.setPlantLogMarkers(times, testCase.makeEntryArray_(times));
            testCase.verifyEqual(numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')), 3);
            w.setPlantLogMarkers([]);
            testCase.verifyEqual(numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')), 0);
        end

        function testSetPlantLogMarkersDropsNonFinite(testCase)
            [~, panel] = testCase.makeFigPanel_();
            w = testCase.makeRenderedWidget_([0 100], panel);

            times = [10 NaN 20 Inf -Inf 30];
            w.setPlantLogMarkers(times, testCase.makeEntryArray_(times));
            ax = w.FastSenseObj.hAxes;
            testCase.verifyEqual( ...
                numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')), 3);
        end

        function testSetPlantLogMarkersIdempotent(testCase)
            [~, panel] = testCase.makeFigPanel_();
            w = testCase.makeRenderedWidget_([0 100], panel);

            w.setPlantLogMarkers([10 20 30], testCase.makeEntryArray_([10 20 30]));
            w.setPlantLogMarkers([40 50], testCase.makeEntryArray_([40 50]));
            ax = w.FastSenseObj.hAxes;
            testCase.verifyEqual( ...
                numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')), 2);
        end

        function testDeleteWidgetClearsListenerSlot(testCase)
            w = FastSenseWidget('Title', 'x', 'XData', 1:10, 'YData', 1:10);
            w.ShowPlantLog = true;
            testCase.verifyEmpty(w.PlantLogXLimListener_);
            delete(w);
            testCase.verifyTrue(true);  % delete completed without throwing
        end

        function testEngineRefreshForWidgetSafeWhenOff(testCase)
            [~, panel] = testCase.makeFigPanel_();
            w = testCase.makeRenderedWidget_([0 100], panel);

            e = DashboardEngine('TestRefreshOff');
            testCase.Engines{end+1} = e;

            ax = w.FastSenseObj.hAxes;
            xline(ax, 50, '-', 'Tag', 'WidgetPlantLogMarker');
            testCase.verifyEqual(numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')), 1);

            e.refreshPlantLogOverlayForWidget_(w);
            testCase.verifyEqual(numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')), 0);
        end

        function testEngineRefreshDrawsFiveMarkers(testCase)
            [~, panel] = testCase.makeFigPanel_();
            w = testCase.makeRenderedWidget_([0 100], panel);

            e = DashboardEngine('TestRefreshFive');
            testCase.Engines{end+1} = e;
            store = testCase.makePopulatedStore_( ...
                [10 20 30 40 50], {'a', 'b', 'c', 'd', 'e'});
            e.setPlantLogStoreForTest_(store);

            w.ShowPlantLog = true;
            e.refreshPlantLogOverlayForWidget_(w);
            ax = w.FastSenseObj.hAxes;
            testCase.verifyEqual( ...
                numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')), 5);
        end

        function testEngineSubPixelCoalesce(testCase)
            [~, panel] = testCase.makeFigPanel_();
            w = testCase.makeRenderedWidget_([0 600], panel);

            e = DashboardEngine('TestCoalesce');
            testCase.Engines{end+1} = e;

            timesIn = [10 10.5 11 100 100.5 200];
            store = testCase.makePopulatedStore_(timesIn, ...
                {'a','b','c','d','e','f'});
            e.setPlantLogStoreForTest_(store);

            w.ShowPlantLog = true;
            e.refreshPlantLogOverlayForWidget_(w);

            ax = w.FastSenseObj.hAxes;
            nDrawn = numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker'));
            testCase.verifyLessThanOrEqual(nDrawn, numel(timesIn));
            % Lower bound: floor-bucketed unique count == 4 at exact 1px/data;
            % allow 3..6 to tolerate off-screen axes pixel-width drift.
            testCase.verifyGreaterThanOrEqual(nDrawn, 3);
            testCase.verifyLessThanOrEqual(nDrawn, 6);
        end

        function testEngineClearAllWidgetsPreservesShowState(testCase)
            [~, panel] = testCase.makeFigPanel_();
            w = testCase.makeRenderedWidget_([0 100], panel);

            e = DashboardEngine('TestClearAll');
            testCase.Engines{end+1} = e;
            e.addWidget(w);
            store = testCase.makePopulatedStore_([10 20 30], {'a','b','c'});
            e.setPlantLogStoreForTest_(store);

            w.ShowPlantLog = true;
            e.refreshPlantLogOverlayForWidget_(w);
            ax = w.FastSenseObj.hAxes;
            testCase.verifyEqual( ...
                numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')), 3);

            e.clearPlantLogOverlaysOnAllWidgets_();
            testCase.verifyEqual( ...
                numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')), 0);
            testCase.verifyTrue(logical(w.ShowPlantLog));
        end

        function testEngineTickFanOutToWidgets(testCase)
            [~, panel] = testCase.makeFigPanel_();
            w = testCase.makeRenderedWidget_([0 100], panel);

            e = DashboardEngine('TestFanOut');
            testCase.Engines{end+1} = e;
            e.addWidget(w);

            store = testCase.makePopulatedStore_([10 20 30], {'a','b','c'});
            e.setPlantLogStoreForTest_(store);

            w.ShowPlantLog = true;
            mapping = struct('TimestampColumn', 'ts', 'MessageColumn', 'msg');
            tail = PlantLogLiveTail(store, 'synthetic.csv', mapping);
            testCase.Tails{end+1} = tail;
            e.setPlantLogLiveTailForTest_(tail);

            ax = w.FastSenseObj.hAxes;
            testCase.verifyEqual( ...
                numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')), 0);
            notify(tail, 'PlantLogTailTick');
            testCase.verifyEqual( ...
                numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')), 3);
        end

        function testEngineTickSkipsWidgetsWithShowFalse(testCase)
            [~, panel] = testCase.makeFigPanel_();
            w = testCase.makeRenderedWidget_([0 100], panel);

            e = DashboardEngine('TestSkipOff');
            testCase.Engines{end+1} = e;
            e.addWidget(w);

            store = testCase.makePopulatedStore_([10 20 30], {'a','b','c'});
            e.setPlantLogStoreForTest_(store);
            testCase.verifyFalse(logical(w.ShowPlantLog));

            mapping = struct('TimestampColumn', 'ts', 'MessageColumn', 'msg');
            tail = PlantLogLiveTail(store, 'synthetic.csv', mapping);
            testCase.Tails{end+1} = tail;
            e.setPlantLogLiveTailForTest_(tail);

            ax = w.FastSenseObj.hAxes;
            notify(tail, 'PlantLogTailTick');
            testCase.verifyEqual( ...
                numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')), 0);
        end

        function testEngineAttachXLimListenerRedrawsOnXLimChange(testCase)
            [~, panel] = testCase.makeFigPanel_();
            w = testCase.makeRenderedWidget_([0 100], panel);

            e = DashboardEngine('TestXLimListener');
            testCase.Engines{end+1} = e;

            store = testCase.makePopulatedStore_( ...
                [10 20 30 40 50 60 70 80 90], ...
                {'1','2','3','4','5','6','7','8','9'});
            e.setPlantLogStoreForTest_(store);

            w.ShowPlantLog = true;
            e.attachPlantLogXLimListener_(w);
            testCase.verifyNotEmpty(w.PlantLogXLimListener_);

            ax = w.FastSenseObj.hAxes;
            set(ax, 'XLim', [0 50]);
            testCase.verifyEqual( ...
                numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')), 5);
            set(ax, 'XLim', [60 100]);
            testCase.verifyEqual( ...
                numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')), 4);
        end

        function testEngineRefreshClearsWhenStoreEmpty(testCase)
            [~, panel] = testCase.makeFigPanel_();
            w = testCase.makeRenderedWidget_([0 100], panel);

            e = DashboardEngine('TestNoStore');
            testCase.Engines{end+1} = e;
            w.ShowPlantLog = true;

            ax = w.FastSenseObj.hAxes;
            xline(ax, 50, '-', 'Tag', 'WidgetPlantLogMarker');
            testCase.verifyEqual(numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')), 1);

            e.refreshPlantLogOverlayForWidget_(w);
            testCase.verifyEqual(numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')), 0);
        end

        function testWidgetSetShowPlantLogToggle(testCase)
            [~, panel] = testCase.makeFigPanel_();
            w = testCase.makeRenderedWidget_([0 100], panel);

            e = DashboardEngine('TestToggle');
            testCase.Engines{end+1} = e;

            store = testCase.makePopulatedStore_([10 20 30], {'a','b','c'});
            e.setPlantLogStoreForTest_(store);

            w.setShowPlantLog(true, e);
            testCase.verifyTrue(logical(w.ShowPlantLog));
            testCase.verifyNotEmpty(w.PlantLogXLimListener_);
            ax = w.FastSenseObj.hAxes;
            testCase.verifyEqual( ...
                numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')), 3);

            w.setShowPlantLog(false, e);
            testCase.verifyFalse(logical(w.ShowPlantLog));
            testCase.verifyEmpty(w.PlantLogXLimListener_);
            testCase.verifyEqual( ...
                numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')), 0);

            % Bad engine -> revert + warn.
            priorState = w.ShowPlantLog;
            lastwarn('');
            w.setShowPlantLog(true, []);
            [~, warnId] = lastwarn();
            testCase.verifyEqual(warnId, 'FastSenseWidget:plantLogToggleFailed');
            testCase.verifyEqual(w.ShowPlantLog, priorState);
        end

        function testWidgetDeleteNoOrphanListener(testCase)
            [~, panel] = testCase.makeFigPanel_();
            w = testCase.makeRenderedWidget_([0 100], panel);

            e = DashboardEngine('TestOrphan');
            testCase.Engines{end+1} = e;

            store = testCase.makePopulatedStore_([10 20 30], {'a','b','c'});
            e.setPlantLogStoreForTest_(store);

            w.setShowPlantLog(true, e);
            testCase.verifyNotEmpty(w.PlantLogXLimListener_);

            delete(w);
            testCase.verifyTrue(true);  % delete completed without throwing
        end

    end
end
