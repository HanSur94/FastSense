classdef TestSensorDetailPlot < matlab.unittest.TestCase
    properties (Access = private)
        sensor
    end

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (TestMethodSetup)
        function createTag(testCase)
            s = SensorTag('test_pressure', 'Name', 'Test Pressure');
            t = linspace(0, 100, 10000);
            s.updateData(t, 50 + 10*sin(2*pi*t/20) + randn(1, numel(t)));
            testCase.sensor = s;
        end
    end

    methods (TestMethodTeardown)
        function closeFigures(testCase)
            close all force;
        end
    end

    methods (Test)
        %% Construction
        function testConstructorStoresTag(testCase)
            sdp = SensorDetailPlot(testCase.sensor);
            testCase.verifyEqual(sdp.Sensor.Key, 'test_pressure');
            delete(sdp);
        end

        function testConstructorDefaultOptions(testCase)
            sdp = SensorDetailPlot(testCase.sensor);
            testCase.verifyEqual(sdp.NavigatorHeight, 0.20, 'AbsTol', 1e-10);
            testCase.verifyTrue(sdp.ShowThresholds);
            testCase.verifyTrue(sdp.ShowThresholdBands);
            testCase.verifyEmpty(sdp.Events);
            delete(sdp);
        end

        function testConstructorCustomOptions(testCase)
            sdp = SensorDetailPlot(testCase.sensor, ...
                'NavigatorHeight', 0.30, ...
                'ShowThresholds', false, ...
                'Theme', 'dark', ...
                'Title', 'Custom Title');
            testCase.verifyEqual(sdp.NavigatorHeight, 0.30, 'AbsTol', 1e-10);
            testCase.verifyFalse(sdp.ShowThresholds);
            delete(sdp);
        end

        %% Render creates two FastSense instances
        function testRenderCreatesMainAndNavigator(testCase)
            sdp = SensorDetailPlot(testCase.sensor);
            sdp.render();
            testCase.verifyClass(sdp.MainPlot, ?FastSense);
            testCase.verifyClass(sdp.NavigatorPlot, ?FastSense);
            delete(sdp);
        end

        %% Render guard
        function testRenderTwiceThrows(testCase)
            sdp = SensorDetailPlot(testCase.sensor);
            sdp.render();
            testCase.verifyError(@() sdp.render(), 'SensorDetailPlot:alreadyRendered');
            delete(sdp);
        end

        %% MainPlot has sensor data
        function testMainPlotHasSensorLine(testCase)
            sdp = SensorDetailPlot(testCase.sensor);
            sdp.render();
            testCase.verifyGreaterThanOrEqual(numel(sdp.MainPlot.Lines), 1);
            delete(sdp);
        end

        %% NavigatorPlot has data line
        function testNavigatorHasDataLine(testCase)
            sdp = SensorDetailPlot(testCase.sensor);
            sdp.render();
            testCase.verifyGreaterThanOrEqual(numel(sdp.NavigatorPlot.Lines), 1);
            delete(sdp);
        end

        %% Zoom range methods
        function testSetGetZoomRange(testCase)
            sdp = SensorDetailPlot(testCase.sensor);
            sdp.render();
            sdp.setZoomRange(20, 60);
            [xMin, xMax] = sdp.getZoomRange();
            testCase.verifyEqual(xMin, 20, 'AbsTol', 1);
            testCase.verifyEqual(xMax, 60, 'AbsTol', 1);
            delete(sdp);
        end

        %% Event shading
        function testEventShadingInMainPlot(testCase)
            s = testCase.sensor;

            % Create mock events
            ev1 = Event(20, 25, 'test_pressure', 'H Warning', 65, 'upper');
            ev2 = Event(50, 55, 'test_pressure', 'HH Alarm', 70, 'upper');

            sdp = SensorDetailPlot(s, 'Events', [ev1, ev2]);
            sdp.render();

            % Check that patches exist in the main axes with UserData
            % Use findall to include HandleVisibility='off' patches
            patches = findall(sdp.MainPlot.hAxes, 'Type', 'patch');
            patchCount = 0;
            for i = 1:numel(patches)
                ud = get(patches(i), 'UserData');
                if isstruct(ud) && isfield(ud, 'ThresholdLabel')
                    patchCount = patchCount + 1;
                end
            end
            testCase.verifyGreaterThanOrEqual(patchCount, 2);
            delete(sdp);
        end

        %% Event vertical lines in navigator
        function testEventLinesInNavigator(testCase)
            s = testCase.sensor;

            ev1 = Event(20, 25, 'test_pressure', 'H Warning', 65, 'upper');

            sdp = SensorDetailPlot(s, 'Events', [ev1]);
            sdp.render();

            % Check that a line exists at StartTime in navigator axes
            % Use findall to include HandleVisibility='off' lines
            lines = findall(sdp.NavigatorPlot.hAxes, 'Type', 'line');
            lineFound = false;
            for i = 1:numel(lines)
                xd = get(lines(i), 'XData');
                if numel(xd) == 2 && abs(xd(1) - 20) < 0.1
                    lineFound = true;
                    break;
                end
            end
            testCase.verifyTrue(lineFound);
            delete(sdp);
        end

        %% Events from EventStore
        function testEventsFromEventstore(testCase)
            s = testCase.sensor;

            % Create EventStore and append events
            tmpFile = [tempname, '.mat'];
            store = EventStore(tmpFile);
            ev1 = Event(20, 25, 'test_pressure', 'H Warning', 65, 'upper');
            ev2 = Event(30, 35, 'other_sensor', 'H Warning', 65, 'upper');
            store.append([ev1, ev2]);

            sdp = SensorDetailPlot(s, 'Events', store);
            sdp.render();

            % Only ev1 should appear (filtered by sensor key)
            % Use findall to include HandleVisibility='off' patches
            patches = findall(sdp.MainPlot.hAxes, 'Type', 'patch');
            patchCount = 0;
            for i = 1:numel(patches)
                ud = get(patches(i), 'UserData');
                if isstruct(ud) && isfield(ud, 'ThresholdLabel')
                    patchCount = patchCount + 1;
                end
            end
            testCase.verifyEqual(patchCount, 1);

            delete(sdp);
            if exist(tmpFile, 'file'); delete(tmpFile); end
        end

        %% Event color mapping
        function testEventColorHigh(testCase)
            s = testCase.sensor;
            ev = Event(20, 25, 'test_pressure', 'H Warning', 65, 'upper');
            sdp = SensorDetailPlot(s, 'Events', [ev]);
            sdp.render();

            patches = findall(sdp.MainPlot.hAxes, 'Type', 'patch');
            foundPatch = false;
            for i = 1:numel(patches)
                ud = get(patches(i), 'UserData');
                if isstruct(ud) && isfield(ud, 'Direction') && strcmp(ud.Direction, 'upper')
                    fc = get(patches(i), 'FaceColor');
                    % Should be orange-ish [1 0.6 0.2]
                    testCase.verifyGreaterThan(fc(1), 0.5);  % red channel high
                    foundPatch = true;
                    break;
                end
            end
            testCase.verifyTrue(foundPatch, 'No event patch found with Direction=upper');
            delete(sdp);
        end

        function testEventColorEscalated(testCase)
            s = testCase.sensor;
            ev = Event(20, 25, 'test_pressure', 'HH Alarm', 70, 'upper');
            sdp = SensorDetailPlot(s, 'Events', [ev]);
            sdp.render();

            patches = findall(sdp.MainPlot.hAxes, 'Type', 'patch');
            foundPatch = false;
            for i = 1:numel(patches)
                ud = get(patches(i), 'UserData');
                if isstruct(ud) && isfield(ud, 'ThresholdLabel') && ...
                   ~isempty(regexpi(ud.ThresholdLabel, 'HH'))
                    fc = get(patches(i), 'FaceColor');
                    % Should be red-ish [0.9 0.1 0.1]
                    testCase.verifyGreaterThan(fc(1), 0.7);
                    testCase.verifyLessThan(fc(2), 0.3);
                    foundPatch = true;
                    break;
                end
            end
            testCase.verifyTrue(foundPatch, 'No event patch found with HH label');
            delete(sdp);
        end

        %% UserData completeness
        function testEventPatchUserdataFields(testCase)
            s = testCase.sensor;
            ev = Event(20, 25, 'test_pressure', 'H Warning', 65, 'upper');
            % Event is a handle class with private setters -- use setStats()
            % setStats(peak, numPoints, min, max, mean, rms, std)
            ev.setStats(67, 50, 64, 67, 66, 66.1, 0.8);

            sdp = SensorDetailPlot(s, 'Events', [ev]);
            sdp.render();

            patches = findall(sdp.MainPlot.hAxes, 'Type', 'patch');
            foundPatch = false;
            for i = 1:numel(patches)
                ud = get(patches(i), 'UserData');
                if isstruct(ud) && isfield(ud, 'ThresholdLabel')
                    expectedFields = {'ThresholdLabel', 'Direction', 'Duration', ...
                        'PeakValue', 'MeanValue', 'MinValue', 'MaxValue', ...
                        'RmsValue', 'StdValue', 'NumPoints'};
                    for f = expectedFields
                        testCase.verifyTrue(isfield(ud, f{1}), ...
                            sprintf('Missing UserData field: %s', f{1}));
                    end
                    foundPatch = true;
                    break;
                end
            end
            testCase.verifyTrue(foundPatch, 'No event patch found with ThresholdLabel');
            delete(sdp);
        end

        %% FastSenseGrid tilePanel integration
        function testTilePanelReturnsUipanel(testCase)
            fig = FastSenseGrid(2, 1);
            hp = fig.tilePanel(1);
            testCase.verifyTrue(isa(hp, 'matlab.ui.container.Panel'));
            delete(fig);
        end

        function testTilePanelConflictWithTile(testCase)
            fig = FastSenseGrid(2, 1);
            fig.tile(1);  % Occupy tile 1 as FastSense
            testCase.verifyError(@() fig.tilePanel(1), 'FastSenseGrid:tileConflict');
            delete(fig);
        end

        %% Embedded in FastSenseGrid
        function testEmbeddedInFigureTile(testCase)
            s = testCase.sensor;
            fig = FastSenseGrid(1, 1);
            hp = fig.tilePanel(1);
            sdp = SensorDetailPlot(s, 'Parent', hp);
            sdp.render();
            testCase.verifyTrue(sdp.IsRendered);
            testCase.verifyClass(sdp.MainPlot, ?FastSense);
            delete(sdp);
            delete(fig);
        end
    end
end
