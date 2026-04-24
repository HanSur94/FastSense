classdef TestEventConfig < matlab.unittest.TestCase
    %TESTEVENTCONFIG EventConfig surface tests.
    %
    %   All legacy-pipeline methods (cfg.addTag + cfg.runDetection +
    %   Threshold class) were deleted in Phase 1014 Plan 05: the
    %   Sensor/Threshold/StateChannel pipeline was removed in Phase 1011
    %   and EventConfig.addSensor now throws 'EventConfig:legacyRemoved'.
    %
    %   Live-path event detection lives on MonitorTag + EventStore,
    %   covered by TestMonitorTag* and TestEventStoreRw.

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testConstructorDefaults(testCase)
            cfg = EventConfig();
            testCase.verifyEmpty(cfg.Sensors, 'defaults: Sensors empty');
            testCase.verifyEmpty(cfg.SensorData, 'defaults: SensorData empty');
            testCase.verifyEqual(cfg.MinDuration, 0, 'defaults: MinDuration');
            testCase.verifyEqual(cfg.MaxCallsPerEvent, 1, 'defaults: MaxCallsPerEvent');
            testCase.verifyEmpty(cfg.OnEventStart, 'defaults: OnEventStart');
            testCase.verifyEqual(cfg.AutoOpenViewer, false, 'defaults: AutoOpenViewer');
        end

        function testSetColor(testCase)
            cfg = EventConfig();
            cfg.setColor('warn', [1 0 0]);
            testCase.verifyEqual(cfg.ThresholdColors('warn'), [1 0 0], 'setColor: stored');
        end

        function testBuildDetector(testCase)
            cfg = EventConfig();
            cfg.MinDuration = 5;
            cfg.MaxCallsPerEvent = 3;
            cfg.OnEventStart = @(e) disp(e);
            det = cfg.buildDetector();
            testCase.verifyTrue(isa(det, 'EventDetector'), 'buildDetector: class');
            testCase.verifyEqual(det.MinDuration, 5, 'buildDetector: MinDuration');
            testCase.verifyEqual(det.MaxCallsPerEvent, 3, 'buildDetector: MaxCallsPerEvent');
            testCase.verifyNotEmpty(det.OnEventStart, 'buildDetector: OnEventStart');
        end
    end
end
