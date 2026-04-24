classdef TestSensorDetailPlotTag < matlab.unittest.TestCase
    %TESTSENSORDETAILPLOTTAG MATLAB unittest suite for SensorDetailPlot Tag input.
    %   Phase 1009 Plan 01 — covers the Tag-only constructor (v2.0). The
    %   legacy Sensor input path was removed in the v2.0 Tag milestone.
    %
    %   See also SensorDetailPlot, MakePhase1009Fixtures.

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
            st = MakePhase1009Fixtures.makeSensorTag('sdp_press_a', 'Units', 'bar');
            sdp = SensorDetailPlot(st);
            testCase.verifyNotEmpty(sdp.TagRef);
            testCase.verifyTrue(sdp.TagRef == st);
        end

        function testMonitorTagConstruct(testCase)
            st = MakePhase1009Fixtures.makeSensorTag('sdp_press_b');
            m  = MakePhase1009Fixtures.makeMonitorTag('sdp_press_hi', st);
            sdp = SensorDetailPlot(m);
            testCase.verifyNotEmpty(sdp.TagRef);
        end

        function testInvalidInputError(testCase)
            testCase.verifyError(@() SensorDetailPlot(42), ...
                'SensorDetailPlot:invalidInput');
        end

    end
end
