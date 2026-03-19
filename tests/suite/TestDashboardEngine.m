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
            testCase.verifyTrue(contains(content, 'DashboardEngine'));
            testCase.verifyTrue(contains(content, 'Pressure'));
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

        function testAddWidgetWithSensor(testCase)
            s = Sensor('T-401', 'Name', 'Temperature');
            s.X = 1:100;
            s.Y = rand(1,100);
            s.addThresholdRule(struct(), 80, 'Direction', 'upper', 'Label', 'Hi');
            s.resolve();

            d = DashboardEngine('Sensor Test');
            d.addWidget('fastsense', 'Sensor', s, 'Position', [1 1 16 3]);
            testCase.verifyEqual(d.Widgets{1}.Title, 'Temperature');
            testCase.verifyEqual(d.Widgets{1}.Sensor, s);
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
    end
end
