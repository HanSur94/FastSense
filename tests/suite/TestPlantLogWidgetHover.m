classdef TestPlantLogWidgetHover < matlab.unittest.TestCase
%TESTPLANTLOGWIDGETHOVER Class-based suite for the widget-level hover tooltip.
%   Mirrors tests/test_plant_log_widget_hover.m (13 sub-tests).
%   Phase 1032 Plan 02 Task 2.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            thisFile = mfilename('fullpath');
            suiteDir = fileparts(thisFile);
            testsDir = fileparts(suiteDir);
            repoRoot = fileparts(testsDir);
            addpath(repoRoot);
            addpath(testsDir);
            install();
        end
    end

    methods (Access = private)
        function [f, ax] = makeAxes(testCase, xLim) %#ok<INUSL>
            f = figure('Visible', 'off', 'Units', 'pixels', 'Position', [10 10 800 600]);
            ax = axes('Parent', f, 'Units', 'pixels', 'Position', [40 40 700 500]);
            set(ax, 'XLim', xLim);
        end

        function flat = flatten(testCase, str) %#ok<INUSL>
            if iscell(str)
                flat = strjoin(str, ' ');
            elseif ischar(str) && size(str, 1) > 1
                rows = cell(size(str, 1), 1);
                for k = 1:size(str, 1)
                    rows{k} = strtrim(str(k, :));
                end
                flat = strjoin(rows, ' ');
            elseif ischar(str)
                flat = str;
            else
                flat = char(str);
            end
        end
    end

    methods (Test)
        function testConstructorValidatesArgs(testCase)
            [f, ax] = testCase.makeAxes([0 100]);
            cleanupF = onCleanup(@() delete(f));
            h = PlantLogWidgetHover(f, ax, @(t0, t1) []);
            cleanupH = onCleanup(@() delete(h));
            testCase.verifyTrue(isvalid(h));
        end

        function testConstructorBadArgPaths(testCase)
            testCase.verifyError(@() PlantLogWidgetHover(), ...
                'PlantLogWidgetHover:invalidInput');
            [f, ax] = testCase.makeAxes([0 100]);
            cleanupF = onCleanup(@() delete(f));
            testCase.verifyError(@() PlantLogWidgetHover([], ax, @(t0,t1) []), ...
                'PlantLogWidgetHover:invalidInput');
            testCase.verifyError(@() PlantLogWidgetHover(f, [], @(t0,t1) []), ...
                'PlantLogWidgetHover:invalidInput');
            testCase.verifyError(@() PlantLogWidgetHover(f, ax, 'not a fn'), ...
                'PlantLogWidgetHover:invalidInput');
        end

        function testSimulateReturnsAllInTolerance(testCase)
            [f, ax] = testCase.makeAxes([0 100]);
            cleanupF = onCleanup(@() delete(f));
            s = PlantLogStore('x');
            s.addEntries([ ...
                PlantLogEntry('Timestamp', 49.9, 'Message', 'a', 'Metadata', struct()), ...
                PlantLogEntry('Timestamp', 50.0, 'Message', 'b', 'Metadata', struct()), ...
                PlantLogEntry('Timestamp', 80.0, 'Message', 'c', 'Metadata', struct())]);
            h = PlantLogWidgetHover(f, ax, @(t0, t1) s.getEntriesInRange(t0, t1));
            cleanupH = onCleanup(@() delete(h));
            picks = h.simulateHoverAt_(50.0);
            testCase.verifyGreaterThanOrEqual(numel(picks), 2);
        end

        function testSingleEntryTooltipLayout(testCase)
            [f, ax] = testCase.makeAxes([0 100]);
            cleanupF = onCleanup(@() delete(f));
            ts = datenum('2025-01-15 12:34:56'); %#ok<DATNM>
            set(ax, 'XLim', [ts - 1, ts + 1]);
            md = struct('unit', 'ZK-12', 'shift', 'B', 'operator', 'jdoe');
            s = PlantLogStore('x');
            s.addEntries(PlantLogEntry('Timestamp', ts, ...
                'Message', 'pump on', 'Metadata', md));
            h = PlantLogWidgetHover(f, ax, @(t0, t1) s.getEntriesInRange(t0, t1));
            cleanupH = onCleanup(@() delete(h));
            picks = h.simulateHoverAt_(ts);
            testCase.verifyNotEmpty(picks);
            flat = testCase.flatten(h.getCurrentTooltipString_());
            testCase.verifySubstring(flat, datestr(ts, 'yyyy-mm-dd HH:MM:SS')); %#ok<DATST>
            testCase.verifySubstring(flat, 'pump on');
            testCase.verifySubstring(flat, 'unit: ZK-12');
            testCase.verifySubstring(flat, 'shift: B');
            testCase.verifySubstring(flat, 'operator: jdoe');
        end

        function testMetadataNewlineCollapse(testCase)
            [f, ax] = testCase.makeAxes([0 100]);
            cleanupF = onCleanup(@() delete(f));
            md = struct('notes', sprintf('line1\nline2\nline3'));
            s = PlantLogStore('x');
            s.addEntries(PlantLogEntry('Timestamp', 50, 'Message', 'm', 'Metadata', md));
            h = PlantLogWidgetHover(f, ax, @(t0, t1) s.getEntriesInRange(t0, t1));
            cleanupH = onCleanup(@() delete(h));
            h.simulateHoverAt_(50);
            flat = testCase.flatten(h.getCurrentTooltipString_());
            testCase.verifySubstring(flat, 'notes: line1 line2 line3');
        end

        function testMetadataValueTruncationBoundary(testCase)
            [f, ax] = testCase.makeAxes([0 100]);
            cleanupF = onCleanup(@() delete(f));
            val40 = repmat('a', 1, 40);
            val41 = repmat('b', 1, 41);
            md = struct('k40', val40, 'k41', val41);
            s = PlantLogStore('x');
            s.addEntries(PlantLogEntry('Timestamp', 50, 'Message', 'm', 'Metadata', md));
            h = PlantLogWidgetHover(f, ax, @(t0, t1) s.getEntriesInRange(t0, t1));
            cleanupH = onCleanup(@() delete(h));
            h.simulateHoverAt_(50);
            flat = testCase.flatten(h.getCurrentTooltipString_());
            testCase.verifySubstring(flat, ['k40: ' val40]);
            truncated39 = repmat('b', 1, 39);
            testCase.verifySubstring(flat, ['k41: ' truncated39]);
            testCase.verifyTrue(isempty(strfind(flat, ['k41: ' val41]))); %#ok<STREMP>
        end

        function testLongMetadataKeyNotTruncated(testCase)
            [f, ax] = testCase.makeAxes([0 100]);
            cleanupF = onCleanup(@() delete(f));
            longKey = repmat('K', 1, 50);
            md = struct(longKey, 'v');
            s = PlantLogStore('x');
            s.addEntries(PlantLogEntry('Timestamp', 50, 'Message', 'm', 'Metadata', md));
            h = PlantLogWidgetHover(f, ax, @(t0, t1) s.getEntriesInRange(t0, t1));
            cleanupH = onCleanup(@() delete(h));
            h.simulateHoverAt_(50);
            flat = testCase.flatten(h.getCurrentTooltipString_());
            testCase.verifySubstring(flat, [longKey ': v']);
        end

        function testOverlapStackingHeaders(testCase)
            [f, ax] = testCase.makeAxes([0 100]);
            cleanupF = onCleanup(@() delete(f));
            ts1 = datenum('2026-05-13 14:32:01'); %#ok<DATNM>
            ts2 = ts1 + 2/86400;
            ts3 = ts1 + 5/86400;
            set(ax, 'XLim', [ts1 - 1, ts1 + 1]);
            s = PlantLogStore('x');
            s.addEntries([ ...
                PlantLogEntry('Timestamp', ts3, 'Message', 'c', 'Metadata', struct()), ...
                PlantLogEntry('Timestamp', ts1, 'Message', 'a', 'Metadata', struct()), ...
                PlantLogEntry('Timestamp', ts2, 'Message', 'b', 'Metadata', struct())]);
            h = PlantLogWidgetHover(f, ax, @(t0, t1) s.getEntriesInRange(t0, t1));
            cleanupH = onCleanup(@() delete(h));
            picks = h.simulateHoverAt_(ts2);
            testCase.verifyEqual(numel(picks), 3);
            flat = testCase.flatten(h.getCurrentTooltipString_());
            headerCount = numel(strfind(flat, '-- '));
            testCase.verifyGreaterThanOrEqual(headerCount, 3);
            aPos = strfind(flat, 'a'); %#ok<STREMP>
            bPos = strfind(flat, 'b'); %#ok<STREMP>
            cPos = strfind(flat, 'c'); %#ok<STREMP>
            testCase.verifyLessThan(aPos(1), bPos(1));
            testCase.verifyLessThan(bPos(1), cPos(1));
        end

        function testOverlapCapWithPlusNFooter(testCase)
            [f, ax] = testCase.makeAxes([0 100]);
            cleanupF = onCleanup(@() delete(f));
            base = datenum('2026-05-13 14:32:01'); %#ok<DATNM>
            set(ax, 'XLim', [base - 1, base + 1]);
            s = PlantLogStore('x');
            arr = [];
            for k = 1:13
                e = PlantLogEntry('Timestamp', base + (k-1)/86400, ...
                    'Message', sprintf('msg%d', k), 'Metadata', struct());
                if isempty(arr), arr = e; else, arr(end+1) = e; end %#ok<AGROW>
            end
            s.addEntries(arr);
            h = PlantLogWidgetHover(f, ax, @(t0, t1) s.getEntriesInRange(t0, t1));
            cleanupH = onCleanup(@() delete(h));
            picks = h.simulateHoverAt_(base + 6/86400);
            testCase.verifyEqual(numel(picks), 13);
            flat = testCase.flatten(h.getCurrentTooltipString_());
            testCase.verifySubstring(flat, '+3 more entries near this point');
        end

        function testDeleteRestoresWbm(testCase)
            [f, ax] = testCase.makeAxes([0 100]);
            cleanupF = onCleanup(@() delete(f));
            customWBM = @(s, e) disp('original');
            set(f, 'WindowButtonMotionFcn', customWBM);
            priorWBM = get(f, 'WindowButtonMotionFcn');
            h = PlantLogWidgetHover(f, ax, @(t0, t1) []);
            duringWBM = get(f, 'WindowButtonMotionFcn');
            testCase.verifyNotEqual(duringWBM, priorWBM);
            delete(h);
            testCase.verifyEqual(get(f, 'WindowButtonMotionFcn'), priorWBM);
        end

        function testSelfCleanupOnAxesDestruction(testCase)
            [f, ax] = testCase.makeAxes([0 100]);
            cleanupF = onCleanup(@() delete(f));
            h = PlantLogWidgetHover(f, ax, @(t0, t1) []);
            delete(ax);
            drawnow;
            threw = false;
            try
                if isvalid(h), delete(h); end
            catch
                threw = true;
            end
            testCase.verifyFalse(threw);
        end

        function testEngineAttachesViaSetShowPlantLog(testCase)
            eng = DashboardEngine('whtest');
            cleanupE = onCleanup(@() delete(eng));
            s = PlantLogStore('x');
            s.addEntries(PlantLogEntry('Timestamp', 100, 'Message', 'm', 'Metadata', struct()));
            eng.setPlantLogStoreForTest_(s);
            widget = FastSenseWidget('Title', 'wt', ...
                'Description', 'descr', 'XData', 0:10, 'YData', sin(0:10));
            widget.Position = [1 1 6 2];
            eng.addWidget(widget);
            eng.render();
            cleanupF = onCleanup(@() delete(eng.hFigure));
            try set(eng.hFigure, 'Visible', 'off'); catch, end
            widget.setShowPlantLog(true, eng);
            pairs = eng.WidgetHovers_;
            testCase.verifyNotEmpty(pairs);
            found = false;
            for k = 1:numel(pairs)
                pair = pairs{k};
                if numel(pair) == 2 && pair{1} == widget && isa(pair{2}, 'PlantLogWidgetHover')
                    found = true; break;
                end
            end
            testCase.verifyTrue(found);
        end

        function testEngineDetachesViaSetShowPlantLogFalse(testCase)
            eng = DashboardEngine('whtest2');
            cleanupE = onCleanup(@() delete(eng));
            s = PlantLogStore('x');
            s.addEntries(PlantLogEntry('Timestamp', 100, 'Message', 'm', 'Metadata', struct()));
            eng.setPlantLogStoreForTest_(s);
            widget = FastSenseWidget('Title', 'wt', ...
                'Description', 'descr', 'XData', 0:10, 'YData', sin(0:10));
            widget.Position = [1 1 6 2];
            eng.addWidget(widget);
            eng.render();
            cleanupF = onCleanup(@() delete(eng.hFigure));
            try set(eng.hFigure, 'Visible', 'off'); catch, end
            widget.setShowPlantLog(true, eng);
            widget.setShowPlantLog(false, eng);
            pairs = eng.WidgetHovers_;
            found = false;
            for k = 1:numel(pairs)
                pair = pairs{k};
                if numel(pair) == 2 && ~isempty(pair{1}) && isvalid(pair{1}) && pair{1} == widget
                    found = true; break;
                end
            end
            testCase.verifyFalse(found);
        end
    end
end
