classdef TestSensorDetailPlotTag < matlab.unittest.TestCase
    %TESTSENSORDETAILPLOTTAG MATLAB unittest suite for SensorDetailPlot Tag input.
    %   Phase 1009 Plan 01 — covers the dual-input constructor that
    %   accepts either a Tag (v2.0) or a Sensor (legacy) as the first
    %   positional argument.  Mirror of test_sensor_detail_plot_tag.m.
    %
    %   See also SensorDetailPlot, makePhase1009Fixtures.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            addpath(repo);
            install();
            addpath(fullfile(repo, 'tests', 'suite'));
        end
    end

    methods (TestMethodSetup)
        function resetRegistry(testCase) %#ok<MANU>
            TagRegistry.clear();
        end
    end

    methods (TestMethodTeardown)
        function teardownRegistry(testCase) %#ok<MANU>
            TagRegistry.clear();
        end
    end

    methods (Test)

        function testSensorTagConstruct(testCase)
            st = makePhase1009Fixtures.makeSensorTag('sdp_press_a', 'Units', 'bar');
            sdp = SensorDetailPlot(st);
            testCase.verifyNotEmpty(sdp.TagRef);
            testCase.verifyEmpty(sdp.Sensor);
            testCase.verifyTrue(sdp.TagRef == st);
        end

        function testMonitorTagConstruct(testCase)
            st = makePhase1009Fixtures.makeSensorTag('sdp_press_b');
            m  = makePhase1009Fixtures.makeMonitorTag('sdp_press_hi', st);
            sdp = SensorDetailPlot(m);
            testCase.verifyNotEmpty(sdp.TagRef);
            testCase.verifyEmpty(sdp.Sensor);
        end

        function testInvalidInputError(testCase)
            testCase.verifyError(@() SensorDetailPlot(42), ...
                'SensorDetailPlot:invalidInput');
        end

        function testLegacySensorStillWorks(testCase)
            s = Sensor('sdp_legacy', 'Name', 'LegacySensor');
            s.X = 1:30;
            s.Y = (1:30) * 0.1;
            sdp = SensorDetailPlot(s);
            testCase.verifyNotEmpty(sdp.Sensor);
            testCase.verifyEmpty(sdp.TagRef);
        end

    end
end
