classdef TestDashboardSerializer < matlab.unittest.TestCase
    properties
        TempDir
    end

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
        end
    end

    methods (TestMethodSetup)
        function createTempDir(testCase)
            testCase.TempDir = tempname;
            mkdir(testCase.TempDir);
            testCase.addTeardown(@() rmdir(testCase.TempDir, 's'));
        end
    end

    methods (Test)
        function testSaveAndLoadRoundTrip(testCase)
            config = struct();
            config.name = 'Test Dashboard';
            config.theme = 'dark';
            config.liveInterval = 5;
            config.grid = struct('columns', 24);
            config.widgets = {};
            config.widgets{1} = struct('type', 'fastplot', ...
                'title', 'Temperature', ...
                'position', struct('col', 1, 'row', 1, 'width', 12, 'height', 3), ...
                'source', struct('type', 'data', 'x', 1:10, 'y', rand(1,10)));

            filepath = fullfile(testCase.TempDir, 'test_dashboard.json');
            DashboardSerializer.save(config, filepath);

            testCase.verifyTrue(exist(filepath, 'file') == 2, ...
                'JSON file should exist');

            loaded = DashboardSerializer.load(filepath);
            testCase.verifyEqual(loaded.name, 'Test Dashboard');
            testCase.verifyEqual(loaded.theme, 'dark');
            testCase.verifyEqual(loaded.liveInterval, 5);
            testCase.verifyEqual(numel(loaded.widgets), 1);
        end

        function testWidgetsToConfig(testCase)
            w1 = FastPlotWidget('Title', 'Plot 1', 'Position', [1 1 12 3]);
            w1.XData = 1:10;
            w1.YData = rand(1,10);
            w2 = FastPlotWidget('Title', 'Plot 2', 'Position', [13 1 12 3]);
            w2.XData = 1:10;
            w2.YData = rand(1,10);

            config = DashboardSerializer.widgetsToConfig('My Dashboard', 'dark', 5, {w1, w2});
            testCase.verifyEqual(config.name, 'My Dashboard');
            testCase.verifyEqual(numel(config.widgets), 2);
            testCase.verifyEqual(config.widgets{1}.title, 'Plot 1');
            testCase.verifyEqual(config.widgets{2}.title, 'Plot 2');
        end

        function testConfigToWidgets(testCase)
            config = struct();
            config.name = 'Test';
            config.theme = 'default';
            config.liveInterval = 1;
            config.grid = struct('columns', 24);

            ws = struct();
            ws.type = 'fastplot';
            ws.title = 'Temp';
            ws.position = struct('col', 1, 'row', 1, 'width', 12, 'height', 3);
            ws.source = struct('type', 'data', 'x', 1:5, 'y', [1 2 3 4 5]);
            config.widgets = {ws};

            widgets = DashboardSerializer.configToWidgets(config);
            testCase.verifyEqual(numel(widgets), 1);
            testCase.verifyTrue(isa(widgets{1}, 'FastPlotWidget'));
            testCase.verifyEqual(widgets{1}.Title, 'Temp');
        end

        function testExportScript(testCase)
            config = struct();
            config.name = 'Export Test';
            config.theme = 'dark';
            config.liveInterval = 5;
            config.grid = struct('columns', 24);

            ws = struct();
            ws.type = 'fastplot';
            ws.title = 'Temperature';
            ws.position = struct('col', 1, 'row', 1, 'width', 12, 'height', 3);
            ws.source = struct('type', 'data', 'x', 1:10, 'y', rand(1,10));
            config.widgets = {ws};

            filepath = fullfile(testCase.TempDir, 'test_export.m');
            DashboardSerializer.exportScript(config, filepath);

            testCase.verifyTrue(exist(filepath, 'file') == 2);
            content = fileread(filepath);
            testCase.verifyTrue(contains(content, 'DashboardEngine'));
            testCase.verifyTrue(contains(content, 'addWidget'));
            testCase.verifyTrue(contains(content, 'Temperature'));
        end
    end
end
