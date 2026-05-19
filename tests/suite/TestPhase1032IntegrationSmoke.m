classdef TestPhase1032IntegrationSmoke < matlab.unittest.TestCase
%TESTPHASE1032INTEGRATIONSMOKE Class-based MATLAB-only end-to-end Phase 1032 smoke.
%   Mirrors tests/test_phase_1032_integration_smoke.m at the class-based level
%   PLUS one additional method (testRealTimerRoundTrip) that exercises the
%   REAL timer path (Interval=0.2s + pause(0.6) so the timer fires in real
%   time and the listener round-trip is exercised end-to-end without
%   synchronous tick_() / notify() injection).
%
%   install() contract: deliberately omits any manual addpath of
%   libs/PlantLog or libs/Dashboard so install.m's libs-block is the
%   regression gate.
%
%   Coverage (see test_phase_1032_integration_smoke for the requirement
%   cross-reference table):
%     - testPathPickup                              (cross-runtime baseline)
%     - testPropertyDefaultAndSerialize             (PLOG-VIZ-03)
%     - testToggleAndOverlay                        (PLOG-VIZ-04 + 05)
%     - testHoverMetadata                           (PLOG-VIZ-07)
%     - testLiveTailFanOut                          (PLOG-VIZ-04 + 08)
%     - testDetachParity                            (Decision G)
%     - testTickFansOutToBoth                       (Decision G end-to-end)
%     - testCleanup                                 (no orphans)
%     - testRealTimerRoundTrip                      (extra: real timer end-to-end)

    properties
        Engines  = {}
        Figures  = {}
        Tails    = {}
        Widgets  = {}
    end

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            thisDir  = fileparts(mfilename('fullpath'));
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
            for k = 1:numel(testCase.Engines)
                try
                    if ~isempty(testCase.Engines{k}) && isvalid(testCase.Engines{k})
                        delete(testCase.Engines{k});
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
            for k = 1:numel(testCase.Figures)
                try
                    if ishandle(testCase.Figures{k})
                        delete(testCase.Figures{k});
                    end
                catch
                end
            end
            testCase.Tails    = {};
            testCase.Engines  = {};
            testCase.Widgets  = {};
            testCase.Figures  = {};
        end
    end

    methods (Access = private)
        function [f, panel] = makeFigPanel_(testCase)
            f = figure('Visible', 'off');
            testCase.Figures{end+1} = f;
            panel = uipanel(f, 'Position', [0 0 1 1]);
        end

        function w = makeRenderedFsWidget_(testCase, panel, xLim, title)
            % Build a FastSenseWidget backed by a SensorTag so DetachedMirror
            % can re-render the clone via restoreLiveRefs (copies Sensor
            % handle). Inline XData/YData would be lost after the
            % toStruct/fromStruct + stripSensorRefs cycle.
            sensorKey = sprintf('__smoke_%s_%d__', title, randi(1e9));
            x = linspace(xLim(1), xLim(2), 100);
            y = sin(x * 0.1);
            try
                sensor = TagRegistry.get(sensorKey);
            catch
                sensor = SensorTag(sensorKey, 'Name', title, 'X', x, 'Y', y);
                try
                    TagRegistry.register(sensorKey, sensor);
                catch
                end
            end
            w = FastSenseWidget('Title', title, 'Position', [1 1 12 3], ...
                'Sensor', sensor);
            w.render(panel);
            set(w.FastSenseObj.hAxes, 'XLim', xLim);
            testCase.Widgets{end+1} = w;
        end

        function s = makePopulatedStore_(testCase, timestamps, messages) %#ok<INUSL>
            s = PlantLogStore('synthetic.csv');
            if isempty(timestamps), return; end
            md = struct('unit', 'ZK-12', 'shift', 'B', 'operator', 'jdoe');
            n = numel(timestamps);
            es = repmat(PlantLogEntry('Timestamp', timestamps(1), ...
                'Message', messages{1}, 'Metadata', md), 1, n);
            for k = 2:n
                es(k) = PlantLogEntry('Timestamp', timestamps(k), ...
                    'Message', messages{k}, 'Metadata', md);
            end
            s.addEntries(es);
        end
    end

    methods (Test)

        function testPathPickup(testCase)
            % Cross-runtime: every Phase 1032 class plus the Phase 1029-1031
            % dependencies must resolve via install() alone.
            testCase.verifyNotEmpty(which('FastSenseWidget'));
            testCase.verifyNotEmpty(which('DashboardEngine'));
            testCase.verifyNotEmpty(which('DashboardLayout'));
            testCase.verifyNotEmpty(which('DetachedMirror'));
            testCase.verifyNotEmpty(which('PlantLogWidgetHover'));
            testCase.verifyNotEmpty(which('PlantLogSliderHover'));
            testCase.verifyNotEmpty(which('PlantLogStore'));
            testCase.verifyNotEmpty(which('PlantLogEntry'));
            testCase.verifyNotEmpty(which('PlantLogReader'));
            testCase.verifyNotEmpty(which('PlantLogLiveTail'));
        end

        function testPropertyDefaultAndSerialize(testCase)
            % Cross-runtime: ShowPlantLog default false + toStruct omit +
            % fromStruct restore. No graphics needed.
            w = FastSenseWidget('Title', 'x', 'XData', 1:10, 'YData', 1:10);
            testCase.Widgets{end+1} = w;
            testCase.verifyTrue(isprop(w, 'ShowPlantLog'));
            testCase.verifyFalse(logical(w.ShowPlantLog));
            s = w.toStruct();
            testCase.verifyFalse(isfield(s, 'showPlantLog'), ...
                'toStruct must omit showPlantLog when default false');
            w.ShowPlantLog = true;
            s2 = w.toStruct();
            testCase.verifyTrue(isfield(s2, 'showPlantLog') && logical(s2.showPlantLog), ...
                'toStruct must write showPlantLog=true when set');
            sIn = struct('type', 'fastsense', 'title', 't', ...
                'position', struct('col', 1, 'row', 1, 'width', 12, 'height', 3), ...
                'showPlantLog', true);
            w2 = FastSenseWidget.fromStruct(sIn);
            testCase.Widgets{end+1} = w2;
            testCase.verifyTrue(logical(w2.ShowPlantLog));
        end

        function testToggleAndOverlay(testCase)
            % MATLAB-only: toggle ShowPlantLog=true on a rendered widget with
            % an attached store; assert 8 WidgetPlantLogMarker handles drawn
            % + engine.WidgetHovers_ wired to one pair.
            [~, panel] = testCase.makeFigPanel_();
            w = testCase.makeRenderedFsWidget_(panel, [0 100], 'W1');
            e = DashboardEngine('SmokeToggle');
            testCase.Engines{end+1} = e;

            store = testCase.makePopulatedStore_( ...
                [10 20 30 40 50 60 70 80], ...
                {'a','b','c','d','e','f','g','h'});
            e.setPlantLogStoreForTest_(store);

            w.setShowPlantLog(true, e);
            ax = w.FastSenseObj.hAxes;
            testCase.verifyEqual( ...
                numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')), 8);
            testCase.verifyNotEmpty(e.WidgetHovers_);
            testCase.verifyEqual(numel(e.WidgetHovers_), 1);
        end

        function testHoverMetadata(testCase)
            % MATLAB-only: simulateHoverAt_ must return a non-empty pick AND
            % tooltip String must contain the entry message + metadata column.
            [~, panel] = testCase.makeFigPanel_();
            w = testCase.makeRenderedFsWidget_(panel, [0 100], 'W1');
            e = DashboardEngine('SmokeHover');
            testCase.Engines{end+1} = e;
            store = testCase.makePopulatedStore_([10 20 30], ...
                {'pump on', 'pump off', 'valve open'});
            e.setPlantLogStoreForTest_(store);

            w.setShowPlantLog(true, e);
            pair = e.WidgetHovers_{1};
            hover = pair{2};
            testCase.verifyTrue(isa(hover, 'PlantLogWidgetHover'));
            picks = hover.simulateHoverAt_(20);
            testCase.verifyNotEmpty(picks);
            tipStr = hover.getCurrentTooltipString_();
            testCase.verifyNotEmpty(tipStr);
            tipFlat = flattenTooltipString_(tipStr);
            testCase.verifyNotEmpty(strfind(tipFlat, 'pump off'));
            % Either metadata key or its value should be in the tooltip.
            hasMd = ~isempty(strfind(tipFlat, 'unit')) || ...
                ~isempty(strfind(tipFlat, 'ZK-12')); %#ok<STREMP>
            testCase.verifyTrue(hasMd);
        end

        function testLiveTailFanOut(testCase)
            % MATLAB-only: tail tick (via notify) fans out to the widget's
            % overlay refresh -- marker count increases by appended entries.
            [~, panel] = testCase.makeFigPanel_();
            w = testCase.makeRenderedFsWidget_(panel, [0 100], 'W1');
            e = DashboardEngine('SmokeFanOut');
            testCase.Engines{end+1} = e;
            e.addWidget(w);  % engine must know the widget for fan-out.
            store = testCase.makePopulatedStore_( ...
                [10 20 30 40 50 60 70 80], ...
                {'a','b','c','d','e','f','g','h'});
            e.setPlantLogStoreForTest_(store);
            w.setShowPlantLog(true, e);
            ax = w.FastSenseObj.hAxes;
            testCase.verifyEqual( ...
                numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')), 8);

            mapping = struct('TimestampColumn', 'ts', 'MessageColumn', 'msg');
            tail = PlantLogLiveTail(store, 'synthetic.csv', mapping);
            testCase.Tails{end+1} = tail;
            e.setPlantLogLiveTailForTest_(tail);

            md = struct('unit', 'ZK-12', 'shift', 'B', 'operator', 'jdoe');
            store.addEntries([ ...
                PlantLogEntry('Timestamp', 85, 'Message', 'append-1', 'Metadata', md), ...
                PlantLogEntry('Timestamp', 90, 'Message', 'append-2', 'Metadata', md)]);
            notify(tail, 'PlantLogTailTick');

            testCase.verifyEqual( ...
                numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')), 10);
            e.setPlantLogLiveTailForTest_([]);
        end

        function testDetachParity(testCase)
            % MATLAB-only: detach a ShowPlantLog=true widget; verify the
            % mirror's cloned widget has ShowPlantLog=true AND drew its own
            % markers AND has its own hover in engine.WidgetHovers_.
            [~, panel] = testCase.makeFigPanel_();
            w = testCase.makeRenderedFsWidget_(panel, [0 100], 'W1');
            e = DashboardEngine('SmokeDetach');
            testCase.Engines{end+1} = e;
            store = testCase.makePopulatedStore_( ...
                [10 20 30 40 50 60 70 80], ...
                {'a','b','c','d','e','f','g','h'});
            e.setPlantLogStoreForTest_(store);
            w.setShowPlantLog(true, e);

            e.detachWidget(w);
            testCase.verifyEqual(numel(e.DetachedMirrors), 1);
            mirror = e.DetachedMirrors{1};
            testCase.Figures{end+1} = mirror.hFigure;

            cw = mirror.Widget;
            testCase.verifyTrue(isa(cw, 'FastSenseWidget'));
            testCase.verifyTrue(logical(cw.ShowPlantLog), ...
                'mirror.Widget.ShowPlantLog must inherit true');
            mirrorAx = cw.FastSenseObj.hAxes;
            testCase.verifyEqual( ...
                numel(findobj(mirrorAx, 'Tag', 'WidgetPlantLogMarker')), 8, ...
                'mirror must draw 8 markers after detach');
            testCase.verifyGreaterThanOrEqual(numel(e.WidgetHovers_), 2);
            hasMirrorHover = false;
            for hi = 1:numel(e.WidgetHovers_)
                pair = e.WidgetHovers_{hi};
                if numel(pair) == 2 && pair{1} == cw
                    hasMirrorHover = true; break;
                end
            end
            testCase.verifyTrue(hasMirrorHover);
        end

        function testTickFansOutToBoth(testCase)
            % MATLAB-only: with both source and detached mirror, a single
            % PlantLogTailTick must refresh BOTH axes (Decision G).
            [~, panel] = testCase.makeFigPanel_();
            w = testCase.makeRenderedFsWidget_(panel, [0 100], 'W1');
            e = DashboardEngine('SmokeFanBoth');
            testCase.Engines{end+1} = e;
            e.addWidget(w);  % source must be in engine.Widgets for fan-out.
            store = testCase.makePopulatedStore_( ...
                [10 20 30 40 50 60 70 80], ...
                {'a','b','c','d','e','f','g','h'});
            e.setPlantLogStoreForTest_(store);
            w.setShowPlantLog(true, e);
            e.detachWidget(w);
            mirror = e.DetachedMirrors{1};
            testCase.Figures{end+1} = mirror.hFigure;

            mapping = struct('TimestampColumn', 'ts', 'MessageColumn', 'msg');
            tail = PlantLogLiveTail(store, 'synthetic.csv', mapping);
            testCase.Tails{end+1} = tail;
            e.setPlantLogLiveTailForTest_(tail);

            sourceAx = w.FastSenseObj.hAxes;
            mirrorAx = mirror.Widget.FastSenseObj.hAxes;
            testCase.verifyEqual(numel(findobj(sourceAx, 'Tag', 'WidgetPlantLogMarker')), 8);
            testCase.verifyEqual(numel(findobj(mirrorAx, 'Tag', 'WidgetPlantLogMarker')), 8);

            md = struct('unit', 'ZK-12', 'shift', 'B', 'operator', 'jdoe');
            store.addEntries(PlantLogEntry('Timestamp', 95, ...
                'Message', 'late append', 'Metadata', md));
            notify(tail, 'PlantLogTailTick');

            testCase.verifyEqual(numel(findobj(sourceAx, 'Tag', 'WidgetPlantLogMarker')), 9);
            testCase.verifyEqual(numel(findobj(mirrorAx, 'Tag', 'WidgetPlantLogMarker')), 9);

            e.setPlantLogLiveTailForTest_([]);
        end

        function testCleanup(testCase)
            % MATLAB-only: toggle off + close mirror + delete engine; no
            % orphan listeners, hovers, or timers above baseline.
            baselineTimers = numel(timerfindall());

            [~, panel] = testCase.makeFigPanel_();
            w = testCase.makeRenderedFsWidget_(panel, [0 100], 'W1');
            e = DashboardEngine('SmokeCleanup');
            store = testCase.makePopulatedStore_([10 20 30], {'a','b','c'});
            e.setPlantLogStoreForTest_(store);
            w.setShowPlantLog(true, e);
            e.detachWidget(w);
            mirror = e.DetachedMirrors{1};
            testCase.verifyEqual(numel(e.WidgetHovers_), 2);

            w.setShowPlantLog(false, e);
            testCase.verifyEmpty(w.PlantLogXLimListener_);
            testCase.verifyEqual( ...
                numel(findobj(w.FastSenseObj.hAxes, 'Tag', 'WidgetPlantLogMarker')), 0);

            delete(mirror.hFigure);
            e.removeDetached();
            testCase.verifyEqual(numel(e.DetachedMirrors), 0);
            testCase.verifyEqual(numel(e.WidgetHovers_), 0);

            delete(e);
            delete(w);
            % Remove from teardown tracking since we've already deleted.
            testCase.Engines = {};
            testCase.Widgets = {};

            afterTimers = numel(timerfindall());
            testCase.verifyTrue(afterTimers <= baselineTimers, sprintf( ...
                'after cleanup, timerfindall must not exceed baseline; got %d > %d', ...
                afterTimers, baselineTimers));
        end

        function testRealTimerRoundTrip(testCase)
            % MATLAB-only: real timer end-to-end. Interval=0.2s,
            % StartImmediately=true, pause(0.6) so at least one tick fires
            % via the real timer + listener chain. Uses a real CSV file with
            % parseable datenum timestamps so the PlantLogReader.openInteractive
            % headless path succeeds inside the live-tail tick.
            ts1 = datenum('2025-01-15 10:00:00'); %#ok<DATNM>
            ts2 = datenum('2025-01-15 10:05:00'); %#ok<DATNM>
            ts3 = datenum('2025-01-15 10:10:00'); %#ok<DATNM>
            ts4 = datenum('2025-01-15 10:15:00'); %#ok<DATNM>
            ts5 = datenum('2025-01-15 10:20:00'); %#ok<DATNM>

            [~, panel] = testCase.makeFigPanel_();
            % Widget axes must contain the entry timestamps; create a custom
            % SensorTag whose X span covers ts1..ts5.
            sensorKey = sprintf('__rt_%d__', randi(1e9));
            xx = linspace(ts1 - 1, ts5 + 1, 100);
            yy = sin(xx);
            sensor = SensorTag(sensorKey, 'Name', 'rt', 'X', xx, 'Y', yy);
            try
                TagRegistry.register(sensorKey, sensor);
            catch
            end
            w = FastSenseWidget('Title', 'RT', 'Position', [1 1 12 3], ...
                'Sensor', sensor);
            w.render(panel);
            set(w.FastSenseObj.hAxes, 'XLim', [ts1 - 1, ts5 + 1]);
            testCase.Widgets{end+1} = w;

            e = DashboardEngine('SmokeRealTimer');
            testCase.Engines{end+1} = e;
            e.addWidget(w);   % source must be in engine.Widgets for fan-out.

            % Start with an empty store so the first real timer tick populates
            % it from the file (avoids dedup confusion).
            store = PlantLogStore('synthetic.csv');
            e.setPlantLogStoreForTest_(store);
            w.setShowPlantLog(true, e);
            e.detachWidget(w);
            mirror = e.DetachedMirrors{1};
            testCase.Figures{end+1} = mirror.hFigure;
            % Mirror axes need the same XLim as source so markers land
            % inside the visible range.
            set(mirror.Widget.FastSenseObj.hAxes, 'XLim', [ts1 - 1, ts5 + 1]);

            % Write a CSV with 3 initial entries.
            csvPath = [tempname '.csv'];
            cleanupP = onCleanup(@() try_delete_path_real_timer_(csvPath));
            writeRealTimerCsvDatenum_(csvPath, [ts1 ts2 ts3]);

            mapping = struct( ...
                'TimestampColumn', 'timestamp', ...
                'MessageColumn',   'message', ...
                'TimestampFormat', '');
            tail = PlantLogLiveTail(store, csvPath, mapping, ...
                'Interval', 0.2, 'StartImmediately', true);
            testCase.Tails{end+1} = tail;
            e.setPlantLogLiveTailForTest_(tail);

            % Append two more rows to the file before letting the timer run.
            appendRealTimerCsvDatenum_(csvPath, [ts4 ts5]);

            % Poll up to ~6 s for the real timer to read all 5 entries.
            % Verification key: the STORE count (5 — independent of pixel
            % coalescing) plus a sanity check that BOTH axes received the
            % fan-out (>=4 markers each, since adjacent 5-min timestamps
            % across a 2-day XLim can sub-pixel-coalesce on some renders).
            sourceAx = w.FastSenseObj.hAxes;
            mirrorAx = mirror.Widget.FastSenseObj.hAxes;
            deadline = cputime() + 6;
            nSource = 0; nMirror = 0; storeCount = 0;
            while cputime() < deadline
                storeCount = store.getCount();
                nSource = numel(findobj(sourceAx, 'Tag', 'WidgetPlantLogMarker'));
                nMirror = numel(findobj(mirrorAx, 'Tag', 'WidgetPlantLogMarker'));
                if storeCount >= 5 && nSource >= 4 && nMirror >= 4
                    break;
                end
                pause(0.2);
            end
            % Live-tail tick contract: every entry reaches the store.
            testCase.verifyEqual(storeCount, 5, sprintf( ...
                'after real timer tick, store must have 5 entries; got %d', storeCount));
            % Fan-out contract: both source + mirror axes get refreshed.
            % Allow sub-pixel coalescing (CONTEXT decision D) — bucket
            % count may be <5 when adjacent timestamps share a pixel.
            testCase.verifyGreaterThanOrEqual(nSource, 4, sprintf( ...
                'source axes must have >=4 markers (5 minus possible coalesce); got %d', nSource));
            testCase.verifyGreaterThanOrEqual(nMirror, 4, sprintf( ...
                'mirror axes must have >=4 markers (5 minus possible coalesce); got %d', nMirror));
            testCase.verifyEqual(nSource, nMirror, ...
                'fan-out must produce identical marker counts on source + mirror');

            tail.stop();
            e.setPlantLogLiveTailForTest_([]);
            clear cleanupP;
        end

    end
end

% =========================================================================
% LOCAL HELPER FUNCTIONS for testRealTimerRoundTrip
% =========================================================================

function s = flattenTooltipString_(raw)
    % Tooltip String can be char, cell of char rows, string array, or char
    % matrix. Flatten to a single char row so strfind works on all variants.
    if ischar(raw)
        if size(raw, 1) > 1
            rows = cell(1, size(raw, 1));
            for r = 1:size(raw, 1)
                rows{r} = raw(r, :);
            end
            s = strjoin(rows, ' ');
        else
            s = raw;
        end
        return;
    end
    if iscell(raw)
        flat = cell(1, numel(raw));
        for k = 1:numel(raw)
            flat{k} = char(raw{k});
        end
        s = strjoin(flat, ' ');
        return;
    end
    if isstring(raw)
        s = char(strjoin(raw, ' '));
        return;
    end
    s = char(raw);
end

function writeRealTimerCsvDatenum_(path, dnums)
    fid = fopen(path, 'w');
    fprintf(fid, 'timestamp,message\n');
    for k = 1:numel(dnums)
        tsStr = datestr(dnums(k), 'yyyy-mm-dd HH:MM:SS'); %#ok<DATST>
        fprintf(fid, '%s,%s\n', tsStr, sprintf('row-%d', k));
    end
    fclose(fid);
end

function appendRealTimerCsvDatenum_(path, dnums)
    fid = fopen(path, 'a');
    for k = 1:numel(dnums)
        tsStr = datestr(dnums(k), 'yyyy-mm-dd HH:MM:SS'); %#ok<DATST>
        fprintf(fid, '%s,%s\n', tsStr, sprintf('append-%d', k));
    end
    fclose(fid);
end

function try_delete_path_real_timer_(p)
    try
        if exist(p, 'file') == 2
            delete(p);
        end
    catch
    end
end
