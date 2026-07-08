classdef TestFastSenseWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testTypeIsFastSense(testCase)
            w = FastSenseWidget();
            testCase.verifyEqual(w.Type, 'fastsense');
        end

        function testDefaultPosition(testCase)
            w = FastSenseWidget();
            testCase.verifyEqual(w.Position, [1 1 12 3], ...
                'Default FastSenseWidget size should be 12x3');
        end

        function testSensorBinding(testCase)
            s = SensorTag('T-401', 'Name', 'Temperature');
            s.updateData(1:100, rand(1,100));

            w = FastSenseWidget('Sensor', s);
            testCase.verifyEqual(w.Sensor, s);
            testCase.verifyEqual(w.Title, 'Temperature', ...
                'Title should default to Sensor.Name');
        end

        function testDataStoreBinding(testCase)
            x = 1:1000;
            y = rand(1,1000);
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());
            w = FastSenseWidget('DataStoreObj', ds);
            testCase.verifyEqual(w.DataStoreObj, ds);
        end

        function testRenderCreatesAxes(testCase)
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));

            hp = uipanel('Parent', hFig, 'Units', 'normalized', ...
                'Position', [0 0 1 1]);

            w = FastSenseWidget();
            w.XData = 1:100;
            w.YData = rand(1,100);
            w.render(hp);

            testCase.verifyNotEmpty(w.FastSenseObj, ...
                'Should create a FastSense instance');
            testCase.verifyTrue(isa(w.FastSenseObj, 'FastSense'));
        end

        function testTimeVaryingThresholdSpecReachesFastSense(testCase)
            % A 'Thresholds' entry with X/Y vectors must forward to the
            % core's time-varying addThreshold(thX, thY, ...) so dashboards
            % can draw state-dependent (dynamic) limits. NaN Y samples mean
            % "no limit here" and break the drawn line.
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Units', 'normalized', ...
                'Position', [0 0 1 1]);

            thX = 1:100;
            thY = 5 * ones(1, 100);
            thY(40:60) = NaN;   % limit inactive mid-range
            w = FastSenseWidget('Thresholds', ...
                {struct('X', thX, 'Y', thY, ...
                'Direction', 'upper', 'Label', 'UWL')});
            w.XData = 1:100;
            w.YData = rand(1, 100);
            w.render(hp);

            th = w.FastSenseObj.Thresholds;
            testCase.assertNumElements(th, 1, ...
                'X/Y spec entry must create exactly one threshold');
            testCase.verifyNumElements(th(1).Y, 100, ...
                'threshold must keep its per-sample Y series');
            testCase.verifyEmpty(th(1).Value, ...
                'time-varying threshold must not carry a scalar Value');
            testCase.verifyEqual(th(1).Direction, 'upper');
            testCase.verifyEqual(th(1).Label, 'UWL');
        end

        function testMixedScalarAndTimeVaryingThresholds(testCase)
            % Scalar Value entries and X/Y entries must coexist in one spec.
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Units', 'normalized', ...
                'Position', [0 0 1 1]);

            thX = 1:50;
            thY = [2 * ones(1, 25), NaN(1, 25)];
            w = FastSenseWidget('Thresholds', { ...
                struct('Value', 3, 'Direction', 'upper', 'Label', 'UAL'), ...
                struct('X', thX, 'Y', thY, 'Direction', 'lower')});
            w.XData = 1:50;
            w.YData = rand(1, 50);
            w.render(hp);

            th = w.FastSenseObj.Thresholds;
            testCase.assertNumElements(th, 2, ...
                'both spec entries must create thresholds');
            testCase.verifyEqual(th(1).Value, 3);
            testCase.verifyNumElements(th(2).Y, 50);
            testCase.verifyEqual(th(2).Direction, 'lower');
        end

        function testThresholdSpecStyleReachesFastSense(testCase)
            % Color / LineStyle on a Thresholds spec entry must reach the
            % core threshold (severity styling: e.g. warn yellow solid,
            % alarm red solid) for both scalar and time-varying entries.
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Units', 'normalized', ...
                'Position', [0 0 1 1]);

            warnColor = [0.93 0.69 0.13];
            alarmColor = [0.7 0 0];
            thX = 1:50;
            thY = 4 * ones(1, 50);
            w = FastSenseWidget('Thresholds', { ...
                struct('Value', 5, 'Direction', 'upper', 'Label', 'UAL', ...
                'Color', alarmColor, 'LineStyle', '-'), ...
                struct('X', thX, 'Y', thY, 'Direction', 'upper', ...
                'Label', 'UWL', 'Color', warnColor, 'LineStyle', '-')});
            w.XData = 1:50;
            w.YData = rand(1, 50);
            w.render(hp);

            th = w.FastSenseObj.Thresholds;
            testCase.assertNumElements(th, 2);
            testCase.verifyEqual(th(1).Color, alarmColor, ...
                'scalar entry Color must pass through');
            testCase.verifyEqual(th(1).LineStyle, '-', ...
                'scalar entry LineStyle must pass through');
            testCase.verifyEqual(th(2).Color, warnColor, ...
                'time-varying entry Color must pass through');
            testCase.verifyEqual(th(2).LineStyle, '-', ...
                'time-varying entry LineStyle must pass through');
        end

        function testToStructRoundTrip(testCase)
            w = FastSenseWidget('Title', 'My Plot', 'Position', [5 2 16 3]);
            w.XData = 1:10;
            w.YData = rand(1,10);

            s = w.toStruct();
            testCase.verifyEqual(s.type, 'fastsense');
            testCase.verifyEqual(s.title, 'My Plot');
            testCase.verifyEqual(s.position.col, 5);
        end

        function testToStructWithTag(testCase)
            sensor = SensorTag('P-201', 'Name', 'Pressure');
            sensor.updateData(1:100, rand(1,100));
            w = FastSenseWidget('Sensor', sensor);

            s = w.toStruct();
            testCase.verifyEqual(s.source.type, 'tag');
            testCase.verifyEqual(s.source.key, 'P-201');
        end

        function testFromStructWithData(testCase)
            s = struct();
            s.type = 'fastsense';
            s.title = 'Restored Plot';
            s.position = struct('col', 1, 'row', 1, 'width', 12, 'height', 3);
            s.source = struct('type', 'data', 'x', 1:10, 'y', rand(1,10));

            w = FastSenseWidget.fromStruct(s);
            testCase.verifyEqual(w.Title, 'Restored Plot');
            testCase.verifyEqual(w.Position, [1 1 12 3]);
            testCase.verifyLength(w.XData, 10);
        end

        function testYLimitsDefault(testCase)
            w = FastSenseWidget();
            testCase.verifyEmpty(w.YLimits);
        end

        function testYLimitsToStructOmittedWhenEmpty(testCase)
            w = FastSenseWidget('Title', 'Test');
            s = w.toStruct();
            testCase.verifyFalse(isfield(s, 'yLimits'));
        end

        function testYLimitsToStructPresent(testCase)
            w = FastSenseWidget('Title', 'Test', 'YLimits', [0 100]);
            s = w.toStruct();
            testCase.verifyEqual(s.yLimits, [0 100]);
        end

        function testYLimitsFromStruct(testCase)
            w = FastSenseWidget('Title', 'Test', 'YLimits', [0 100]);
            s = w.toStruct();
            w2 = FastSenseWidget.fromStruct(s);
            testCase.verifyEqual(w2.YLimits, [0 100]);
        end

        function testYLimitsFromStructMissing(testCase)
            w = FastSenseWidget('Title', 'Test');
            s = w.toStruct();
            w2 = FastSenseWidget.fromStruct(s);
            testCase.verifyEmpty(w2.YLimits);
        end

        function testYLimitsAppliedAfterRender(testCase)
            %TESTYLIMITSAPPLIEDAFTERRENDER Verify ylim() returns expected range after render.
            % This test requires a display. Skip gracefully in headless environments.
            try
                fig = figure('Visible', 'off');
            catch
                testCase.assumeTrue(false, 'No display available — skipping render test');
                return;
            end
            testCase.addTeardown(@() close(fig));
            hp = uipanel(fig, 'Units', 'normalized', 'Position', [0 0 1 1]);
            w = FastSenseWidget('Title', 'YLimTest', 'XData', 1:10, 'YData', rand(1,10)*50, 'YLimits', [0 100]);
            w.render(hp);
            % Find axes created by render
            ax = findobj(hp, 'Type', 'axes');
            testCase.assumeNotEmpty(ax, 'No axes found after render — skipping');
            actualYLim = ylim(ax(1));
            testCase.verifyEqual(actualYLim, [0 100], 'AbsTol', 1e-10);
        end

        function testFastSenseUnknownOptionThrows(testCase)
        %TESTFASTSENSEUNKNOWNOPTIONTHROWS P0-4: FastSense ctor rejects unknown options
        %   instead of silently discarding the typo into the unmatched struct.
            threw = false; id = '';
            try
                FastSense('Themee', 'dark');
            catch err
                threw = true; id = err.identifier;
            end
            testCase.verifyTrue(threw);
            testCase.verifyEqual(id, 'FastSense:unknownOption');
        end

        function testFastSenseGoodOptionConstructs(testCase)
        %TESTFASTSENSEGOODOPTIONCONSTRUCTS P0-4: a valid option still constructs fine.
            f = FastSense('Theme', 'dark');
            testCase.verifyClass(f, 'FastSense');
        end
    end
end
