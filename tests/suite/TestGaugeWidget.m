classdef TestGaugeWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
        end
    end

    methods (Test)
        function testConstruction(testCase)
            w = GaugeWidget('Title', 'Pressure', ...
                'ValueFcn', @() 50, 'Range', [0 100], 'Units', 'bar');
            testCase.verifyEqual(w.Title, 'Pressure');
            testCase.verifyEqual(w.Range, [0 100]);
            testCase.verifyEqual(w.Units, 'bar');
        end

        function testDefaultPosition(testCase)
            w = GaugeWidget('Title', 'Test');
            testCase.verifyEqual(w.Position, [1 1 4 2]);
        end

        function testGetType(testCase)
            w = GaugeWidget('Title', 'Test');
            testCase.verifyEqual(w.getType(), 'gauge');
        end

        function testToStructFromStruct(testCase)
            w = GaugeWidget('Title', 'RPM', ...
                'ValueFcn', @() 3000, 'Range', [0 6000], 'Units', 'rpm');
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'gauge');
            testCase.verifyEqual(s.range, [0 6000]);
            testCase.verifyEqual(s.units, 'rpm');

            w2 = GaugeWidget.fromStruct(s);
            testCase.verifyEqual(w2.Range, [0 6000]);
            testCase.verifyEqual(w2.Units, 'rpm');
        end

        function testRender(testCase)
            w = GaugeWidget('Title', 'Temp', ...
                'ValueFcn', @() 72, 'Range', [0 100], 'Units', char(176) + "C");
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyEqual(w.CurrentValue, 72);
        end

        function testRefreshUpdatesValue(testCase)
            w = GaugeWidget('Title', 'Gauge', ...
                'StaticValue', 25, 'Range', [0 100]);
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyEqual(w.CurrentValue, 25);
            % Update static value and refresh
            w.StaticValue = 75;
            w.refresh();
            testCase.verifyEqual(w.CurrentValue, 75);
        end

        function testStaticValue(testCase)
            w = GaugeWidget('Title', 'Static', ...
                'StaticValue', 42, 'Range', [0 100]);
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyEqual(w.CurrentValue, 42);
        end
    end
end
