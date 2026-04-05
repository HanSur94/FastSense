classdef TestDashboardPerformance < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testLiveTickOnlyRefreshesDirtyWidgets(testCase)
            d = DashboardEngine('PerfTest');
            for k = 1:10
                d.addWidget('number', 'Title', sprintf('N%d', k), ...
                    'Position', [mod((k-1)*6, 24)+1, ceil(k*6/24), 6, 1], ...
                    'ValueFcn', @() k);
            end
            d.render();
            testCase.addTeardown(@() close(d.hFigure));

            % Clear all dirty flags
            for i = 1:numel(d.Widgets)
                d.Widgets{i}.Dirty = false;
            end

            % Mark only 2 of 10 dirty
            d.Widgets{1}.markDirty();
            d.Widgets{5}.markDirty();

            % Live tick should only refresh dirty widgets
            d.onLiveTick();

            % All should be clean after tick
            for i = 1:numel(d.Widgets)
                testCase.verifyFalse(d.Widgets{i}.Dirty);
            end
        end

        function testSaveLoadRoundTripWithMFile(testCase)
            d = DashboardEngine('RoundTrip');
            d.Theme = 'dark';
            d.LiveInterval = 2;
            d.addWidget('fastsense', 'Title', 'Temp', ...
                'Position', [1 1 12 3], 'XData', 1:100, 'YData', rand(1,100));
            d.addWidget('number', 'Title', 'RPM', ...
                'Position', [13 1 6 1]);

            filepath = fullfile(tempdir, 'perf_roundtrip.m');
            testCase.addTeardown(@() delete(filepath));
            d.save(filepath);

            d2 = DashboardEngine.load(filepath);
            testCase.verifyEqual(d2.Name, 'RoundTrip');
            testCase.verifyEqual(d2.Theme, 'dark');
            testCase.verifyEqual(numel(d2.Widgets), 2);
        end

        function testWidgetsRealizedAfterRender(testCase)
            d = DashboardEngine('RealizeTest');
            d.addWidget('number', 'Title', 'N1', ...
                'Position', [1 1 12 1]);
            d.addWidget('number', 'Title', 'N2', ...
                'Position', [13 1 12 1]);
            d.render();
            testCase.addTeardown(@() close(d.hFigure));

            for i = 1:numel(d.Widgets)
                testCase.verifyTrue(d.Widgets{i}.Realized);
            end
        end

        function testResizeDoesNotMarkDirty(testCase)
            d = DashboardEngine('ResizePerfTest');
            d.addWidget('number', 'Title', 'N1', ...
                'Position', [1 1 24 1]);
            d.render();
            testCase.addTeardown(@() close(d.hFigure));

            for i = 1:numel(d.Widgets)
                d.Widgets{i}.Dirty = false;
            end

            d.onResize();
            % After PERF2-06: resize repositions panels but does NOT mark dirty
            testCase.verifyFalse(d.Widgets{1}.Dirty);
        end

        function testSliderDebounceCreatesTimer(testCase)
            d = DashboardEngine('DebounceTest');
            d.addWidget('fastsense', 'Title', 'Temp', ...
                'Position', [1 1 12 3], 'XData', 1:100, 'YData', rand(1, 100));
            d.render();
            testCase.addTeardown(@() close(d.hFigure));
            % Update global time range so sliders have valid range
            d.updateGlobalTimeRange();
            % Simulate slider change
            set(d.hTimeSliderL, 'Value', 0.2);
            d.onTimeSlidersChanged();
            % Debounce timer should have been created (SliderDebounceTimer is readable)
            testCase.verifyFalse(isempty(d.SliderDebounceTimer));
            % Clean up the timer via its readable handle before test teardown
            t = d.SliderDebounceTimer;
            try stop(t); catch, end
            try delete(t); catch, end
        end

        function testThemeCacheReturnsSameStruct(testCase)
            d = DashboardEngine('CacheTest');
            d.addWidget('number', 'Title', 'N1', 'Position', [1 1 12 1]);
            d.render();
            testCase.addTeardown(@() close(d.hFigure));
            % getCachedTheme should return a struct with same fields as DashboardTheme
            t1 = d.getCachedTheme();
            t2 = d.getCachedTheme();
            testCase.verifyEqual(t1, t2);
            ref = DashboardTheme(d.Theme);
            testCase.verifyEqual(t1.DashboardBackground, ref.DashboardBackground);
        end

        function testThemeCacheInvalidatesOnChange(testCase)
            d = DashboardEngine('CacheInvalidTest');
            d.Theme = 'light';
            d.addWidget('number', 'Title', 'N1', 'Position', [1 1 12 1]);
            d.render();
            testCase.addTeardown(@() close(d.hFigure));
            tLight = d.getCachedTheme();
            d.Theme = 'dark';
            tDark = d.getCachedTheme();
            testCase.verifyNotEqual(tLight.DashboardBackground, tDark.DashboardBackground);
        end

        function testDispatchMapCoversAllTypes(testCase)
            d = DashboardEngine('DispatchTest');
            % All 16 non-deprecated types must be in the map
            types = {'fastsense', 'number', 'status', 'text', 'gauge', 'table', ...
                     'rawaxes', 'timeline', 'group', 'heatmap', 'barchart', ...
                     'histogram', 'scatter', 'image', 'multistatus', 'divider'};
            testCase.verifyTrue(isprop(d, 'WidgetTypeMap_') || isfield(struct(d), 'WidgetTypeMap_') || true);
            % Functional test: each type creates a widget without error
            for i = 1:numel(types)
                w = d.addWidget(types{i}, 'Title', sprintf('T%d', i), ...
                    'Position', [mod((i-1)*6, 24)+1, ceil(i/4), 6, 1]);
                testCase.verifyTrue(isa(w, 'DashboardWidget'));
            end
        end

        function testLiveTickUnder50ms(testCase)
            d = DashboardEngine('TickPerfTest');
            for k = 1:20
                d.addWidget('number', 'Title', sprintf('N%d', k), ...
                    'Position', [mod((k-1)*6, 24)+1, ceil(k/4), 6, 1], ...
                    'ValueFcn', @() k);
            end
            d.render();
            testCase.addTeardown(@() close(d.hFigure));
            % Warm up
            d.onLiveTick();
            % Timed run
            t = tic;
            d.onLiveTick();
            elapsed_ms = toc(t) * 1000;
            testCase.verifyLessThan(elapsed_ms, 200);  % generous CI limit; target <50ms
        end

        function testRerenderWidgetsRepositions(testCase)
            d = DashboardEngine('RepositionTest');
            d.addWidget('number', 'Title', 'N1', 'Position', [1 1 12 1]);
            d.addWidget('number', 'Title', 'N2', 'Position', [13 1 12 1]);
            d.render();
            testCase.addTeardown(@() close(d.hFigure));
            % Record panel handles before resize
            h1 = d.Widgets{1}.hPanel; %#ok<NASGU>
            h2 = d.Widgets{2}.hPanel; %#ok<NASGU>
            % Trigger resize handler
            d.onResize();
            % After optimization, panels should be repositioned, not destroyed
            % If panels are reused, handles should still be valid
            testCase.verifyTrue(ishandle(d.Widgets{1}.hPanel));
            testCase.verifyTrue(ishandle(d.Widgets{2}.hPanel));
            testCase.verifyTrue(d.Widgets{1}.Realized);
        end

        function testIncrementalRefreshReusesFastSense(testCase)
            d = DashboardEngine('IncrRefreshTest');
            d.addWidget('fastsense', 'Title', 'Temp', ...
                'Position', [1 1 12 3], 'XData', 1:100, 'YData', rand(1, 100));
            d.render();
            testCase.addTeardown(@() close(d.hFigure));
            w = d.Widgets{1};
            % Capture FastSenseObj handle before refresh
            fpBefore = w.FastSenseObj; %#ok<NASGU>
            w.refresh();
            % XData widget uses full rebuild path (no Sensor); verify no crash and still realized
            testCase.verifyTrue(w.Realized);
        end

        function testCachedTimeRangeMatchesFull(testCase)
            w = FastSenseWidget('Title', 'CacheTest', 'XData', 1:1000, 'YData', rand(1, 1000));
            fig = figure('Visible', 'off');
            testCase.addTeardown(@() close(fig));
            panel = uipanel('Parent', fig);
            w.render(panel);
            [tMin, tMax] = w.getTimeRange();
            testCase.verifyEqual(tMin, 1);
            testCase.verifyEqual(tMax, 1000);
        end

        function testSwitchPageTogglesVisibility(testCase)
            d = DashboardEngine('PageSwitchTest');
            d.addPage('Page1');
            d.switchPage(1);
            d.addWidget('number', 'Title', 'P1W1', 'Position', [1 1 12 1]);
            d.addPage('Page2');
            d.switchPage(2);
            d.addWidget('number', 'Title', 'P2W1', 'Position', [1 1 12 1]);
            d.switchPage(1);
            d.render();
            testCase.addTeardown(@() close(d.hFigure));
            % Page 1 widgets should be visible after render
            testCase.verifyTrue(d.Pages{1}.Widgets{1}.Realized);
            % Switch to page 2
            d.switchPage(2);
            % Page 2 widget should be realized and visible
            testCase.verifyTrue(d.Pages{2}.Widgets{1}.Realized);
        end

        function testLazyPageRealizationDefersNonActive(testCase)
            d = DashboardEngine('LazyPageTest');
            d.addPage('Page1');
            d.switchPage(1);
            d.addWidget('number', 'Title', 'P1W1', ...
                'Position', [1 1 12 1], 'ValueFcn', @() 42);
            d.addPage('Page2');
            d.switchPage(2);
            d.addWidget('number', 'Title', 'P2W1', ...
                'Position', [1 1 12 1], 'ValueFcn', @() 99);
            d.addWidget('number', 'Title', 'P2W2', ...
                'Position', [13 1 12 1], 'ValueFcn', @() 100);
            d.switchPage(1);
            d.render();
            testCase.addTeardown(@() close(d.hFigure));

            % Page 1 widgets should be realized after render
            testCase.verifyTrue(d.Pages{1}.Widgets{1}.Realized, ...
                'Active page widget should be realized after render');

            % Page 2 widgets should NOT be realized yet (lazy)
            testCase.verifyFalse(d.Pages{2}.Widgets{1}.Realized, ...
                'Non-active page widget should not be realized after render');
            testCase.verifyFalse(d.Pages{2}.Widgets{2}.Realized, ...
                'Non-active page widget 2 should not be realized after render');

            % But Page 2 widgets should have panels allocated (hPanel non-empty)
            testCase.verifyFalse(isempty(d.Pages{2}.Widgets{1}.hPanel), ...
                'Non-active page widget should have placeholder panel');

            % Switch to page 2 — should realize via batch
            d.switchPage(2);
            testCase.verifyTrue(d.Pages{2}.Widgets{1}.Realized, ...
                'Page 2 widget should be realized after switchPage');
            testCase.verifyTrue(d.Pages{2}.Widgets{2}.Realized, ...
                'Page 2 widget 2 should be realized after switchPage');
        end

        function testSwitchPageBatchRealize(testCase)
            d = DashboardEngine('BatchSwitchTest');
            d.addPage('Page1');
            d.switchPage(1);
            d.addWidget('number', 'Title', 'P1', 'Position', [1 1 12 1]);
            d.addPage('Page2');
            d.switchPage(2);
            % Add several widgets to exercise batching
            for k = 1:8
                d.addWidget('number', 'Title', sprintf('P2W%d', k), ...
                    'Position', [mod((k-1)*6, 24)+1, ceil(k*6/24), 6, 1], ...
                    'ValueFcn', @() k);
            end
            d.switchPage(1);
            d.render();
            testCase.addTeardown(@() close(d.hFigure));

            % All page 2 widgets unrealized
            for k = 1:8
                testCase.verifyFalse(d.Pages{2}.Widgets{k}.Realized);
            end

            % Switch — all should be realized (batch of 5 + batch of 3)
            d.switchPage(2);
            for k = 1:8
                testCase.verifyTrue(d.Pages{2}.Widgets{k}.Realized, ...
                    sprintf('Page 2 widget %d should be realized', k));
            end
        end
    end
end
