classdef TestDashboardEngine < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testConstruction(testCase)
            d = DashboardEngine('Test Dashboard');
            testCase.verifyEqual(d.Name, 'Test Dashboard');
            testCase.verifyEqual(d.Theme, 'light');
            testCase.verifyEqual(d.LiveInterval, 5);
        end

        function testSetTheme(testCase)
            d = DashboardEngine('Test');
            d.Theme = 'dark';
            testCase.verifyEqual(d.Theme, 'dark');
        end

        function testAddWidget(testCase)
            d = DashboardEngine('Test');
            d.addWidget('fastsense', 'Title', 'Plot 1', ...
                'Position', [1 1 12 3], ...
                'XData', 1:10, 'YData', rand(1,10));
            testCase.verifyEqual(numel(d.Widgets), 1);
            testCase.verifyTrue(isa(d.Widgets{1}, 'FastSenseWidget'));
        end

        function testAddMultipleWidgets(testCase)
            d = DashboardEngine('Test');
            d.addWidget('fastsense', 'Title', 'Plot 1', ...
                'Position', [1 1 12 3], 'XData', 1:10, 'YData', rand(1,10));
            d.addWidget('fastsense', 'Title', 'Plot 2', ...
                'Position', [13 1 12 3], 'XData', 1:10, 'YData', rand(1,10));
            testCase.verifyEqual(numel(d.Widgets), 2);
        end

        function testOverlapResolution(testCase)
            d = DashboardEngine('Test');
            d.addWidget('fastsense', 'Title', 'Plot 1', ...
                'Position', [1 1 12 3], 'XData', 1:10, 'YData', rand(1,10));
            d.addWidget('fastsense', 'Title', 'Plot 2', ...
                'Position', [5 1 12 3], 'XData', 1:10, 'YData', rand(1,10));
            testCase.verifyEqual(d.Widgets{2}.Position(2), 4);
        end

        function testRender(testCase)
            d = DashboardEngine('Render Test');
            d.addWidget('fastsense', 'Title', 'Plot 1', ...
                'Position', [1 1 24 3], 'XData', 1:100, 'YData', rand(1,100));
            d.render();
            testCase.addTeardown(@() close(d.hFigure));

            testCase.verifyNotEmpty(d.hFigure);
            testCase.verifyTrue(ishandle(d.hFigure));
        end

        function testSaveAndLoad(testCase)
            d = DashboardEngine('Save Test');
            d.Theme = 'dark';
            d.LiveInterval = 3;
            d.addWidget('fastsense', 'Title', 'Temp', ...
                'Position', [1 1 12 3], 'XData', 1:10, 'YData', [1:10]);

            filepath = fullfile(tempdir, 'test_save_dashboard.m');
            testCase.addTeardown(@() delete(filepath));
            d.save(filepath);

            d2 = DashboardEngine.load(filepath);
            testCase.verifyEqual(d2.Name, 'Save Test');
            testCase.verifyEqual(d2.Theme, 'dark');
            testCase.verifyEqual(d2.LiveInterval, 3);
            testCase.verifyEqual(numel(d2.Widgets), 1);
            testCase.verifyEqual(d2.Widgets{1}.Title, 'Temp');
        end

        function testExportScript(testCase)
            d = DashboardEngine('Export Test');
            d.addWidget('fastsense', 'Title', 'Pressure', ...
                'Position', [1 1 12 3], 'XData', 1:5, 'YData', [5 4 3 2 1]);

            filepath = fullfile(tempdir, 'test_export_dashboard.m');
            testCase.addTeardown(@() delete(filepath));
            d.exportScript(filepath);

            content = fileread(filepath);
            testCase.verifyFalse(isempty(strfind(content, 'DashboardEngine')));
            testCase.verifyFalse(isempty(strfind(content, 'Pressure')));
        end

        function testLiveStartStop(testCase)
            d = DashboardEngine('Live Test');
            d.LiveInterval = 1;
            d.addWidget('fastsense', 'Title', 'Plot', ...
                'Position', [1 1 24 3], 'XData', 1:10, 'YData', rand(1,10));
            d.render();
            testCase.addTeardown(@() close(d.hFigure));

            d.startLive();
            testCase.verifyTrue(d.IsLive);
            testCase.verifyNotEmpty(d.LiveTimer);

            d.stopLive();
            testCase.verifyFalse(d.IsLive);
        end

        function testTimerContinuesAfterError(testCase)
            % Verifies onLiveTimerError restarts the timer after a TimerFcn
            % throw. Uses a ONE-SHOT TimerFcn (first tick errors, subsequent
            % ticks no-op) so we don't spin a runaway error loop that
            % outpaces teardown -- the earlier "always throw" pattern
            % produced ~500k stderr lines on MATLAB CI in certain timing
            % windows.
            d = DashboardEngine('ErrorTest');
            d.LiveInterval = 0.1;
            d.render();
            testCase.addTeardown(@() d.stopLive());
            testCase.addTeardown(@() close(d.hFigure));

            d.startLive();
            testCase.verifyTrue(d.IsLive);

            % Suppress the expected warning so test output stays clean.
            warnState = warning('off', 'DashboardEngine:timerError');
            testCase.addTeardown(@() warning(warnState));

            % Counter is a handle class (containers.Map), so mutations inside
            % the TimerFcn body persist across calls even when the TimerFcn
            % is an anonymous function (which captures by value).
            counter = containers.Map({'n'}, {int32(0)});
            set(d.LiveTimer, 'TimerFcn', @(~,~) errorOnce(counter));

            % Poll until the one-shot TimerFcn has fired, with a timeout.
            % Simple pause-based waits are fragile inside matlab.unittest --
            % the test harness sometimes services callbacks differently
            % than top-level scripts. Bounded polling is robust.
            deadline = tic;
            while counter('n') == 0 && toc(deadline) < 3.0
                pause(0.05);
            end

            % Timer must still be running (restarted inside ErrorFcn).
            testCase.verifyTrue(strcmp(d.LiveTimer.Running, 'on'));
            % Counter should show exactly one throw.
            testCase.verifyEqual(counter('n'), int32(1));
        end

        function testEngineAddGroupWidget(testCase)
            d = DashboardEngine('TestDash', 'Theme', 'dark');
            d.addWidget('group', 'Label', 'Motor Health');
            testCase.verifyLength(d.Widgets, 1);
            testCase.verifyClass(d.Widgets{1}, 'GroupWidget');
        end

        function testCloseDeletesTimer(testCase)
            d = DashboardEngine('Timer Cleanup');
            d.LiveInterval = 1;
            d.addWidget('fastsense', 'Title', 'P', ...
                'Position', [1 1 24 3], 'XData', 1:10, 'YData', rand(1,10));
            d.render();
            d.startLive();

            close(d.hFigure);
            testCase.verifyFalse(d.IsLive);
        end

        function testAddWidgetInjectsReflowCallbackForCollapsibleGroup(testCase)
            d = DashboardEngine('ReflowInjectTest');
            g = d.addWidget('group', 'Label', 'G', 'Mode', 'collapsible', 'Position', [1 1 24 4]);
            testCase.verifyNotEmpty(g.ReflowCallback);
            testCase.verifyTrue(isa(g.ReflowCallback, 'function_handle'));
        end

        function testAddWidgetDoesNotInjectReflowCallbackForPanelGroup(testCase)
            d = DashboardEngine('ReflowInjectTest2');
            g = d.addWidget('group', 'Label', 'G', 'Mode', 'panel', 'Position', [1 1 24 4]);
            testCase.verifyEmpty(g.ReflowCallback);
        end

        function testCollapseGroupWidgetReflowsGrid(testCase)
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            d = DashboardEngine('ReflowGridTest');
            g = d.addWidget('group', 'Label', 'G', 'Mode', 'collapsible', 'Position', [1 1 24 4]);
            d.addWidget('text', 'Title', 'Below', 'Position', [1 5 12 2]);
            d.render();
            g.collapse();
            w2 = d.Widgets{2};
            testCase.verifyTrue(~isempty(w2.hPanel) && ishandle(w2.hPanel));
            testCase.verifyTrue(g.Collapsed);
        end

        function testAddCollapsible(testCase)
            d = DashboardEngine('Test');
            w = d.addCollapsible('Sensors', {});
            testCase.verifyEqual(w.Mode, 'collapsible');
            testCase.verifyEqual(w.Label, 'Sensors');
            testCase.verifyTrue(isa(w, 'GroupWidget'));
        end

        function testAddCollapsibleWithChildren(testCase)
            d = DashboardEngine('Test');
            c1 = TextWidget('Title', 'A');
            c2 = TextWidget('Title', 'B');
            w = d.addCollapsible('Group', {c1, c2});
            testCase.verifyEqual(numel(w.Children), 2);
        end

        function testAddCollapsibleForwardsOptions(testCase)
            d = DashboardEngine('Test');
            w = d.addCollapsible('G', {}, 'Collapsed', true);
            testCase.verifyTrue(w.Collapsed);
        end
    end
end

function errorOnce(counter)
    %ERRORONCE Throw exactly once; no-op on subsequent calls.
    %   Used by testTimerContinuesAfterError to verify ErrorFcn restart
    %   semantics without triggering a runaway error loop. `counter` is a
    %   containers.Map (handle class) so increments persist across calls.
    n = counter('n');
    if n == 0
        counter('n') = int32(1);
        error('testError:force', 'forced test error (one-shot)');
    end
    % No-op on subsequent invocations.
end
