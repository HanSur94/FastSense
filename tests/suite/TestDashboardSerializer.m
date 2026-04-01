classdef TestDashboardSerializer < matlab.unittest.TestCase
    properties
        TempDir
    end

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
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
            config.widgets{1} = struct('type', 'fastsense', ...
                'title', 'Temperature', ...
                'position', struct('col', 1, 'row', 1, 'width', 12, 'height', 3), ...
                'source', struct('type', 'data', 'x', 1:10, 'y', rand(1,10)));

            filepath = fullfile(testCase.TempDir, 'test_dashboard.json');
            DashboardSerializer.saveJSON(config, filepath);

            testCase.verifyTrue(exist(filepath, 'file') == 2, ...
                'JSON file should exist');

            loaded = DashboardSerializer.loadJSON(filepath);
            testCase.verifyEqual(loaded.name, 'Test Dashboard');
            testCase.verifyEqual(loaded.theme, 'dark');
            testCase.verifyEqual(loaded.liveInterval, 5);
            testCase.verifyEqual(numel(loaded.widgets), 1);
        end

        function testWidgetsToConfig(testCase)
            w1 = FastSenseWidget('Title', 'Plot 1', 'Position', [1 1 12 3]);
            w1.XData = 1:10;
            w1.YData = rand(1,10);
            w2 = FastSenseWidget('Title', 'Plot 2', 'Position', [13 1 12 3]);
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
            ws.type = 'fastsense';
            ws.title = 'Temp';
            ws.position = struct('col', 1, 'row', 1, 'width', 12, 'height', 3);
            ws.source = struct('type', 'data', 'x', 1:5, 'y', [1 2 3 4 5]);
            config.widgets = {ws};

            widgets = DashboardSerializer.configToWidgets(config);
            testCase.verifyEqual(numel(widgets), 1);
            testCase.verifyTrue(isa(widgets{1}, 'FastSenseWidget'));
            testCase.verifyEqual(widgets{1}.Title, 'Temp');
        end

        function testSerializerRoundTrip(testCase)
            g = GroupWidget('Label', 'Motors', 'Mode', 'panel');
            g.Position = [1 1 12 4];
            g.addChild(TextWidget('Title', 'RPM'));

            s = g.toStruct();
            w = DashboardSerializer.createWidgetFromStruct(s);
            testCase.verifyClass(w, 'GroupWidget');
            testCase.verifyEqual(w.Label, 'Motors');
            testCase.verifyLength(w.Children, 1);
        end

        function testExportScript(testCase)
            config = struct();
            config.name = 'Export Test';
            config.theme = 'dark';
            config.liveInterval = 5;
            config.grid = struct('columns', 24);

            ws = struct();
            ws.type = 'fastsense';
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

        function testNormalizeToCellHelper(testCase)
            % normalizeToCell lives in libs/Dashboard/private/ so it is not
            % callable directly from test files outside that directory.
            % We test its behaviour indirectly through DashboardSerializer,
            % which calls normalizeToCell in loadJSON().

            % Build a minimal JSON with a single widget and round-trip it.
            % When jsondecode parses a JSON array with one object it produces
            % a struct (not a cell), triggering the struct-array branch of
            % normalizeToCell.  DashboardSerializer.loadJSON must convert it
            % back to a cell so configToWidgets can index with {}.
            config = struct();
            config.name = 'NormTest';
            config.theme = 'default';
            config.liveInterval = 1;
            config.grid = struct('columns', 24);
            ws.type = 'text';
            ws.title = 'T1';
            ws.position = struct('col', 1, 'row', 1, 'width', 6, 'height', 2);
            config.widgets = {ws};

            filepath = fullfile(testCase.TempDir, 'norm_test.json');
            DashboardSerializer.saveJSON(config, filepath);
            loaded = DashboardSerializer.loadJSON(filepath);

            % After normalizeToCell the widgets field must be a cell array
            % regardless of whether jsondecode returned a struct or cell.
            testCase.verifyClass(loaded.widgets, 'cell', ...
                'loadJSON must return widgets as a cell array (normalizeToCell)');
            testCase.verifyGreaterThanOrEqual(numel(loaded.widgets), 1);

            % Test multi-widget case (jsondecode may return struct array for
            % homogeneous arrays — normalizeToCell must convert to cell).
            ws2.type = 'text';
            ws2.title = 'T2';
            ws2.position = struct('col', 7, 'row', 1, 'width', 6, 'height', 2);
            config.widgets = {ws, ws2};
            filepath2 = fullfile(testCase.TempDir, 'norm_test2.json');
            DashboardSerializer.saveJSON(config, filepath2);
            loaded2 = DashboardSerializer.loadJSON(filepath2);
            testCase.verifyClass(loaded2.widgets, 'cell', ...
                'loadJSON must return multi-widget list as cell array');
            testCase.verifyLength(loaded2.widgets, 2);
        end
    end
end
