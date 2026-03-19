classdef TestDashboardMSerializer < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testSaveProducesMFile(testCase)
            d = DashboardEngine('SaveTest');
            d.Theme = 'dark';
            d.LiveInterval = 3;
            d.addWidget('fastsense', 'Title', 'Temp', ...
                'Position', [1 1 12 3], 'XData', 1:10, 'YData', 1:10);

            filepath = fullfile(tempdir, 'test_save_dash.m');
            testCase.addTeardown(@() delete(filepath));
            d.save(filepath);

            testCase.verifyTrue(exist(filepath, 'file') == 2);
            content = fileread(filepath);
            testCase.verifyFalse(isempty(strfind(content, 'DashboardEngine')));
            testCase.verifyFalse(isempty(strfind(content, 'function')));
        end

        function testLoadFromMFile(testCase)
            d = DashboardEngine('LoadTest');
            d.Theme = 'dark';
            d.LiveInterval = 3;
            d.addWidget('fastsense', 'Title', 'Temp', ...
                'Position', [1 1 12 3], 'XData', 1:10, 'YData', 1:10);

            filepath = fullfile(tempdir, 'test_load_dash.m');
            testCase.addTeardown(@() delete(filepath));
            d.save(filepath);

            d2 = DashboardEngine.load(filepath);
            testCase.verifyEqual(d2.Name, 'LoadTest');
            testCase.verifyEqual(d2.Theme, 'dark');
            testCase.verifyEqual(d2.LiveInterval, 3);
            testCase.verifyEqual(numel(d2.Widgets), 1);
        end

        function testAddWidgetReturnsHandle(testCase)
            d = DashboardEngine('ReturnTest');
            w = d.addWidget('number', 'Title', 'RPM', ...
                'Position', [1 1 6 1]);
            testCase.verifyClass(w, 'NumberWidget');
            testCase.verifyEqual(w.Title, 'RPM');
        end
    end
end
