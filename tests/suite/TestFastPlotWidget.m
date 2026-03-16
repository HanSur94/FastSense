classdef TestFastPlotWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
        end
    end

    methods (Test)
        function testTypeIsFastplot(testCase)
            w = FastPlotWidget();
            testCase.verifyEqual(w.Type, 'fastplot');
        end

        function testDefaultPosition(testCase)
            w = FastPlotWidget();
            testCase.verifyEqual(w.Position, [1 1 12 3], ...
                'Default FastPlotWidget size should be 12x3');
        end

        function testSensorBinding(testCase)
            s = Sensor('T-401', 'Name', 'Temperature');
            s.X = 1:100;
            s.Y = rand(1,100);

            w = FastPlotWidget('SensorObj', s);
            testCase.verifyEqual(w.SensorObj, s);
            testCase.verifyEqual(w.Title, 'Temperature', ...
                'Title should default to Sensor.Name');
        end

        function testDataStoreBinding(testCase)
            x = 1:1000;
            y = rand(1,1000);
            ds = FastPlotDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());
            w = FastPlotWidget('DataStoreObj', ds);
            testCase.verifyEqual(w.DataStoreObj, ds);
        end

        function testRenderCreatesAxes(testCase)
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));

            hp = uipanel('Parent', hFig, 'Units', 'normalized', ...
                'Position', [0 0 1 1]);

            w = FastPlotWidget();
            w.XData = 1:100;
            w.YData = rand(1,100);
            w.render(hp);

            testCase.verifyNotEmpty(w.FastPlotObj, ...
                'Should create a FastPlot instance');
            testCase.verifyTrue(isa(w.FastPlotObj, 'FastPlot'));
        end

        function testRenderWithSensor(testCase)
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));

            hp = uipanel('Parent', hFig, 'Units', 'normalized', ...
                'Position', [0 0 1 1]);

            s = Sensor('T-401', 'Name', 'Temperature');
            s.X = 1:100;
            s.Y = rand(1,100);
            s.addThresholdRule(struct(), 80, 'Direction', 'upper', 'Label', 'Hi Alarm');
            s.resolve();

            w = FastPlotWidget('SensorObj', s);
            w.render(hp);

            testCase.verifyNotEmpty(w.FastPlotObj);
            testCase.verifyGreaterThanOrEqual(numel(w.FastPlotObj.Lines), 1);
        end

        function testToStructRoundTrip(testCase)
            w = FastPlotWidget('Title', 'My Plot', 'Position', [5 2 16 3]);
            w.XData = 1:10;
            w.YData = rand(1,10);

            s = w.toStruct();
            testCase.verifyEqual(s.type, 'fastplot');
            testCase.verifyEqual(s.title, 'My Plot');
            testCase.verifyEqual(s.position.col, 5);
        end

        function testToStructWithSensor(testCase)
            sensor = Sensor('P-201', 'Name', 'Pressure');
            sensor.X = 1:100;
            sensor.Y = rand(1,100);
            w = FastPlotWidget('SensorObj', sensor);

            s = w.toStruct();
            testCase.verifyEqual(s.source.type, 'sensor');
            testCase.verifyEqual(s.source.name, 'P-201');
        end

        function testFromStructWithData(testCase)
            s = struct();
            s.type = 'fastplot';
            s.title = 'Restored Plot';
            s.position = struct('col', 1, 'row', 1, 'width', 12, 'height', 3);
            s.source = struct('type', 'data', 'x', 1:10, 'y', rand(1,10));

            w = FastPlotWidget.fromStruct(s);
            testCase.verifyEqual(w.Title, 'Restored Plot');
            testCase.verifyEqual(w.Position, [1 1 12 3]);
            testCase.verifyLength(w.XData, 10);
        end
    end
end
