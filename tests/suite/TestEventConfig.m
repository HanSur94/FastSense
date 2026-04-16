classdef TestEventConfig < matlab.unittest.TestCase
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

        function testAddSensor(testCase)
            cfg = EventConfig();
            s = Sensor('temp', 'Name', 'Temperature');
            s.X = 1:10;
            s.Y = [5 5 12 14 11 13 5 5 5 5];
            t_warn = Threshold('warn', 'Name', 'warn', 'Direction', 'upper');
            t_warn.addCondition(struct(), 10);
            s.addThreshold(t_warn);
            cfg.addSensor(s);
            testCase.verifyEqual(numel(cfg.Sensors), 1, 'addSensor: count');
            testCase.verifyEqual(numel(cfg.SensorData), 1, 'addSensor: data count');
            testCase.verifyEqual(cfg.SensorData(1).name, 'Temperature', 'addSensor: data name');
            testCase.verifyEqual(cfg.SensorData(1).t, s.X, 'addSensor: data t');
            testCase.verifyEqual(cfg.SensorData(1).y, s.Y, 'addSensor: data y');
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

        function testRunDetection(testCase)
            cfg = EventConfig();
            s = Sensor('temp', 'Name', 'Temperature');
            s.X = 1:10;
            s.Y = [5 5 12 14 11 13 5 5 5 5];
            t_warn = Threshold('warn', 'Name', 'warn', 'Direction', 'upper');
            t_warn.addCondition(struct(), 10);
            s.addThreshold(t_warn);
            cfg.addSensor(s);
            events = cfg.runDetection();
            testCase.verifyGreaterThanOrEqual(numel(events), 1, 'runDetection: found events');
            testCase.verifyEqual(events(1).SensorName, 'Temperature', 'runDetection: sensor name');
        end

        function testEscalateSeverity(testCase)
            cfg = EventConfig();
            s = Sensor('temp', 'Name', 'Temperature');
            s.X = 1:10;
            s.Y = [5 5 86 96 88 87 5 5 5 5];
            t_warn = Threshold('warn', 'Name', 'warn', 'Direction', 'upper');
            t_warn.addCondition(struct(), 85);
            s.addThreshold(t_warn);
            t_critical = Threshold('critical', 'Name', 'critical', 'Direction', 'upper');
            t_critical.addCondition(struct(), 95);
            s.addThreshold(t_critical);
            cfg.addSensor(s);
            events = cfg.runDetection();
            critEvents = events(arrayfun(@(e) strcmp(e.ThresholdLabel, 'critical'), events));
            testCase.verifyGreaterThanOrEqual(numel(critEvents), 1, 'escalate: critical event exists');
            testCase.verifyGreaterThanOrEqual(critEvents(1).PeakValue, 95, 'escalate: peak above critical threshold');
        end

        function testEscalateDisabled(testCase)
            cfg2 = EventConfig();
            cfg2.EscalateSeverity = false;
            s2 = Sensor('temp', 'Name', 'Temperature');
            s2.X = 1:10;
            s2.Y = [5 5 86 96 88 87 5 5 5 5];
            t_warn = Threshold('warn', 'Name', 'warn', 'Direction', 'upper');
            t_warn.addCondition(struct(), 85);
            s2.addThreshold(t_warn);
            t_critical = Threshold('critical', 'Name', 'critical', 'Direction', 'upper');
            t_critical.addCondition(struct(), 95);
            s2.addThreshold(t_critical);
            cfg2.addSensor(s2);
            events2 = cfg2.runDetection();
            warnEvents2 = events2(arrayfun(@(e) strcmp(e.ThresholdLabel, 'warn'), events2));
            testCase.verifyGreaterThanOrEqual(numel(warnEvents2), 1, 'escalate disabled: warn event preserved');
        end

        function testEscalateLowDirection(testCase)
            cfg3 = EventConfig();
            s3 = Sensor('pres', 'Name', 'Pressure');
            s3.X = 1:10;
            s3.Y = [6 6 3.5 1.5 3.8 3.9 6 6 6 6];
            t_low = Threshold('low', 'Name', 'low', 'Direction', 'lower');
            t_low.addCondition(struct(), 4);
            s3.addThreshold(t_low);
            t_crit_low = Threshold('critical_low', 'Name', 'critical low', 'Direction', 'lower');
            t_crit_low.addCondition(struct(), 2);
            s3.addThreshold(t_crit_low);
            cfg3.addSensor(s3);
            events3 = cfg3.runDetection();
            critLow = events3(arrayfun(@(e) strcmp(e.ThresholdLabel, 'critical low'), events3));
            testCase.verifyGreaterThanOrEqual(numel(critLow), 1, 'escalate low: critical low event exists');
            testCase.verifyLessThanOrEqual(critLow(1).PeakValue, 2, 'escalate low: peak below critical threshold');
        end

        function testSaveViaEventStore(testCase)
            tmpFile = fullfile(tempdir, 'test_cfg_store_save.mat');
            if exist(tmpFile, 'file'); delete(tmpFile); end
            testCase.addTeardown(@() TestEventConfig.deleteIfExists(tmpFile));
            cfg = EventConfig();
            cfg.EventFile = tmpFile;
            cfg.MaxBackups = 0;
            s = Sensor('temp', 'Name', 'Temperature');
            s.X = 1:10;
            s.Y = [5 5 12 14 11 13 5 5 5 5];
            t_warn = Threshold('warn', 'Name', 'warn', 'Direction', 'upper');
            t_warn.addCondition(struct(), 10);
            s.addThreshold(t_warn);
            cfg.setColor('warn', [1 0 0]);
            cfg.addSensor(s);
            events = cfg.runDetection();
            testCase.verifyEqual(exist(tmpFile, 'file'), 2, 'save: file exists');
            data = load(tmpFile);
            testCase.verifyTrue(isfield(data, 'events'), 'save: has events');
            testCase.verifyTrue(isfield(data, 'sensorData'), 'save: has sensorData');
            testCase.verifyTrue(isfield(data, 'thresholdColors'), 'save: has thresholdColors');
            testCase.verifyTrue(isfield(data, 'timestamp'), 'save: has timestamp');
            testCase.verifyEqual(numel(data.events), numel(events), 'save: event count matches');
        end
    end

    methods (Static, Access = private)
        function deleteIfExists(f)
            if exist(f, 'file'); delete(f); end
        end
    end
end
