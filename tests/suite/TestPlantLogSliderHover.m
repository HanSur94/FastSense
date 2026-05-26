classdef TestPlantLogSliderHover < matlab.unittest.TestCase
%TESTPLANTLOGSLIDERHOVER Class-based suite for the Phase 1031 Plan 03 hover tooltip (MATLAB only).
%   Phase 1031 PLOG-VIZ-06: hovering a plant-log marker on the slider pops
%   a tooltip with timestamp + message. Mirrors HoverCrosshair's chained-WBM
%   pattern; uses the simulateHoverAt_ test seam for deterministic tests
%   without driving real mouse motion.
%
%   Coverage:
%     - Constructor input validation (3 bad-arg branches)
%     - Constructor saves prior WindowButtonMotionFcn unchanged
%     - simulateHoverAt_ picks the nearest entry within tolerance
%     - simulateHoverAt_ off-marker returns []
%     - Tooltip becomes visible after a successful pick
%     - Tooltip text format = datestr(timestamp) + '\n' + message
%     - delete() restores prior WBMFcn unchanged
%     - Engine integration: setPlantLogStoreForTest_(populated) constructs
%       the hover; setPlantLogStoreForTest_([]) tears it down
%     - delete(engine): no orphan WBMFcn closure references hover

    properties
        Handles = {}
        Engines = {}
        Hovers  = {}
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
            for k = 1:numel(testCase.Hovers)
                try
                    if ~isempty(testCase.Hovers{k}) && isvalid(testCase.Hovers{k})
                        delete(testCase.Hovers{k});
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
            testCase.Hovers  = {};
            testCase.Engines = {};
            testCase.Handles = {};
        end
    end

    methods (Test)

        function testConstructorRejectsBadParentFig(testCase)
            f = figure('Visible', 'off');
            testCase.Handles{end+1} = f;
            ax = axes('Parent', f);
            s = PlantLogStore('x');
            testCase.verifyError( ...
                @() PlantLogSliderHover([], ax, @(t0,t1) s.getEntriesInRange(t0,t1)), ...
                'PlantLogSliderHover:invalidInput');
        end

        function testConstructorRejectsBadAxes(testCase)
            f = figure('Visible', 'off');
            testCase.Handles{end+1} = f;
            s = PlantLogStore('x');
            testCase.verifyError( ...
                @() PlantLogSliderHover(f, [], @(t0,t1) s.getEntriesInRange(t0,t1)), ...
                'PlantLogSliderHover:invalidInput');
        end

        function testConstructorRejectsNonFunctionLookup(testCase)
            f = figure('Visible', 'off');
            testCase.Handles{end+1} = f;
            ax = axes('Parent', f);
            testCase.verifyError( ...
                @() PlantLogSliderHover(f, ax, 'not-a-function-handle'), ...
                'PlantLogSliderHover:invalidInput');
        end

        function testConstructorSavesPriorWBM(testCase)
            f = figure('Visible', 'off');
            testCase.Handles{end+1} = f;
            ax = axes('Parent', f);
            set(ax, 'XLim', [0 100]);
            customWBM = @(s, e) disp('custom');
            set(f, 'WindowButtonMotionFcn', customWBM);
            store = PlantLogStore('x');
            h = PlantLogSliderHover(f, ax, ...
                @(t0,t1) store.getEntriesInRange(t0, t1));
            testCase.Hovers{end+1} = h;
            % Indirect verification: delete + check WBM == customWBM.
            delete(h);
            testCase.verifyEqual(get(f, 'WindowButtonMotionFcn'), customWBM, ...
                'after delete(h), WBMFcn must equal the customWBM saved by ctor');
        end

        function testSimulateHoverFindsNearest(testCase)
            f = figure('Visible', 'off');
            testCase.Handles{end+1} = f;
            ax = axes('Parent', f);
            set(ax, 'XLim', [0 100]);
            store = makeStore_([25 50 75], {'a','b','c'});
            h = PlantLogSliderHover(f, ax, ...
                @(t0,t1) store.getEntriesInRange(t0, t1));
            testCase.Hovers{end+1} = h;
            pick = h.simulateHoverAt_(50);
            testCase.verifyNotEmpty(pick, 'simulateHoverAt_(50) must find an entry');
            testCase.verifyEqual(pick.Message, 'b');
            pick = h.simulateHoverAt_(75);
            testCase.verifyNotEmpty(pick);
            testCase.verifyEqual(pick.Message, 'c');
        end

        function testSimulateHoverOffMarkerReturnsEmpty(testCase)
            f = figure('Visible', 'off');
            testCase.Handles{end+1} = f;
            ax = axes('Parent', f);
            set(ax, 'XLim', [0 100]);
            store = makeStore_([25 50 75], {'a','b','c'});
            h = PlantLogSliderHover(f, ax, ...
                @(t0,t1) store.getEntriesInRange(t0, t1));
            testCase.Hovers{end+1} = h;
            pick = h.simulateHoverAt_(0);
            testCase.verifyEmpty(pick, ...
                'simulateHoverAt_(0) must return empty (no entry within ~3px tolerance)');
            testCase.verifyFalse(h.getCurrentTooltipVisible_(), ...
                'tooltip must remain hidden when no entry is picked');
        end

        function testTooltipVisibleAfterShow(testCase)
            f = figure('Visible', 'off');
            testCase.Handles{end+1} = f;
            ax = axes('Parent', f);
            set(ax, 'XLim', [0 100]);
            store = makeStore_([25 50 75], {'a','b','c'});
            h = PlantLogSliderHover(f, ax, ...
                @(t0,t1) store.getEntriesInRange(t0, t1));
            testCase.Hovers{end+1} = h;
            testCase.verifyFalse(h.getCurrentTooltipVisible_(), 'starts hidden');
            h.simulateHoverAt_(50);
            testCase.verifyTrue(h.getCurrentTooltipVisible_(), ...
                'tooltip must become visible after a successful pick');
        end

        function testTooltipTextFormat(testCase)
            f = figure('Visible', 'off');
            testCase.Handles{end+1} = f;
            ax = axes('Parent', f);
            ts = datenum('2025-01-15 12:34:56'); %#ok<DATNM>
            set(ax, 'XLim', [ts - 1, ts + 1]);
            store = PlantLogStore('x');
            store.addEntries(PlantLogEntry('Timestamp', ts, ...
                'Message', 'pump on', 'Metadata', struct()));
            h = PlantLogSliderHover(f, ax, ...
                @(t0,t1) store.getEntriesInRange(t0, t1));
            testCase.Hovers{end+1} = h;
            pick = h.simulateHoverAt_(ts);
            testCase.verifyNotEmpty(pick);
            str = h.getCurrentTooltipString_();
            flat = flattenString_(str);
            expectedTs = datestr(ts, 'yyyy-mm-dd HH:MM:SS'); %#ok<DATST>
            testCase.verifyTrue(~isempty(strfind(flat, expectedTs)), ...
                sprintf('tooltip must contain datestr; got "%s"', flat)); %#ok<STREMP>
            testCase.verifyTrue(~isempty(strfind(flat, 'pump on')), ...
                sprintf('tooltip must contain message; got "%s"', flat)); %#ok<STREMP>
        end

        function testDeleteRestoresWBM(testCase)
            f = figure('Visible', 'off');
            testCase.Handles{end+1} = f;
            ax = axes('Parent', f);
            set(ax, 'XLim', [0 100]);
            customWBM = @(s, e) disp('original');
            set(f, 'WindowButtonMotionFcn', customWBM);
            priorWBM = get(f, 'WindowButtonMotionFcn');
            store = PlantLogStore('x');
            h = PlantLogSliderHover(f, ax, ...
                @(t0,t1) store.getEntriesInRange(t0, t1));
            duringWBM = get(f, 'WindowButtonMotionFcn');
            testCase.verifyNotEqual(duringWBM, priorWBM, ...
                'while alive, WBM should be hover''s chained handler (not the prior)');
            delete(h);
            testCase.verifyEqual(get(f, 'WindowButtonMotionFcn'), priorWBM, ...
                'delete(h) must restore prior WBMFcn unchanged');
        end

        function testEngineLazyConstruction(testCase)
            f = figure('Visible', 'off');
            testCase.Handles{end+1} = f;
            p = uipanel(f);
            sel = TimeRangeSelector(p, 'Theme', DashboardTheme('dark'));
            sel.setDataRange(0, 100);
            e = DashboardEngine('TestLazy');
            testCase.Engines{end+1} = e;
            e.setTimeRangeSelectorForTest_(sel);
            store = makeStore_([25 50 75], {'a','b','c'});
            e.setPlantLogStoreForTest_(store);
            testCase.verifyNotEmpty(e.PlantLogSliderHover_, ...
                'engine.PlantLogSliderHover_ must be non-empty after attaching populated store');
            testCase.verifyTrue(isvalid(e.PlantLogSliderHover_));
        end

        function testEngineTeardownOnStoreDetach(testCase)
            f = figure('Visible', 'off');
            testCase.Handles{end+1} = f;
            p = uipanel(f);
            sel = TimeRangeSelector(p, 'Theme', DashboardTheme('dark'));
            sel.setDataRange(0, 100);
            e = DashboardEngine('TestDetach');
            testCase.Engines{end+1} = e;
            e.setTimeRangeSelectorForTest_(sel);
            store = makeStore_([25 50 75], {'a','b','c'});
            e.setPlantLogStoreForTest_(store);
            testCase.verifyNotEmpty(e.PlantLogSliderHover_);
            e.setPlantLogStoreForTest_([]);
            testCase.verifyEmpty(e.PlantLogSliderHover_, ...
                'engine.PlantLogSliderHover_ must be empty after store detach');
        end

        function testEngineTeardownOnDelete(testCase)
            f = figure('Visible', 'off');
            testCase.Handles{end+1} = f;
            p = uipanel(f);
            sel = TimeRangeSelector(p, 'Theme', DashboardTheme('dark'));
            sel.setDataRange(0, 100);
            e = DashboardEngine('TestEngineDelete');
            e.setTimeRangeSelectorForTest_(sel);
            store = makeStore_([25 50 75], {'a','b','c'});
            e.setPlantLogStoreForTest_(store);
            delete(e);
            % After delete(engine), the WBMFcn must NOT contain a closure
            % that references the hover (the closure would point at a
            % deleted PlantLogSliderHover handle and crash on motion).
            afterWBM = get(f, 'WindowButtonMotionFcn');
            if isa(afterWBM, 'function_handle')
                wbmStr = func2str(afterWBM);
                testCase.verifyTrue( ...
                    isempty(strfind(wbmStr, 'onFigureMove_')), ...
                    sprintf('WBMFcn must NOT reference hover''s onFigureMove_ closure; got %s', wbmStr)); %#ok<STREMP>
            else
                testCase.verifyTrue(isempty(afterWBM) || ischar(afterWBM), ...
                    'after delete(engine), WBMFcn should be empty/'''' or a non-hover function handle');
            end
        end

    end
end

% =========================================================================
% LOCAL HELPER FUNCTIONS (function file convention; outside the classdef
% block so they are file-scope helpers, callable from any test method via
% top-level dispatch).
% =========================================================================

function s = makeStore_(timestamps, messages)
%MAKESTORE_ Build a PlantLogStore populated with N (timestamp, message) pairs.
    s = PlantLogStore('synthetic.csv');
    n = numel(timestamps);
    es = repmat(PlantLogEntry('Timestamp', timestamps(1), ...
        'Message', messages{1}, 'Metadata', struct()), 1, n);
    for k = 2:n
        es(k) = PlantLogEntry('Timestamp', timestamps(k), ...
            'Message', messages{k}, 'Metadata', struct());
    end
    s.addEntries(es);
end

function flat = flattenString_(str)
%FLATTENSTRING_ Coerce uicontrol multi-line String into a single char row.
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
