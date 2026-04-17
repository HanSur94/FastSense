classdef TestEventDetectorTag < matlab.unittest.TestCase
    %TESTEVENTDETECTORTAG MATLAB unittest suite for EventDetector Tag overload.
    %   Phase 1009 Plan 03 — covers the additive 2-arg `detect(tag, threshold)`
    %   overload and proves the legacy 6-arg signature remains functional.
    %
    %   See also EventDetector, makePhase1009Fixtures, TestEventDetector.

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

        function testTagOverloadDetectsEvents(testCase)
            % SensorTag with golden Y pattern — two runs above 10 (indices
            % 4..7 and 13..15 of the fixture Y).
            st = makePhase1009Fixtures.makeSensorTag('press_a');
            thr = Threshold('warn', 'Name', 'Warn', 'Direction', 'upper');
            thr.addCondition(struct(), 10);

            det = EventDetector();
            events = det.detect(st, thr);

            testCase.verifyEqual(numel(events), 2, 'Tag overload: 2 events');
            testCase.verifyEqual(events(1).StartTime, 4, 'Tag overload: e1 start');
            testCase.verifyEqual(events(1).EndTime,   7, 'Tag overload: e1 end');
            testCase.verifyEqual(events(2).StartTime, 13, 'Tag overload: e2 start');
            testCase.verifyEqual(events(2).EndTime,   15, 'Tag overload: e2 end');
            % Carrier: sensorName should derive from the Tag
            testCase.verifyEqual(events(1).SensorName, 'press_a', ...
                'Tag overload: SensorName=Tag.Key/Name');
            testCase.verifyEqual(events(1).ThresholdLabel, 'Warn', ...
                'Tag overload: ThresholdLabel=Threshold.Name');
            testCase.verifyEqual(events(1).ThresholdValue, 10, ...
                'Tag overload: ThresholdValue from Threshold.allValues');
            testCase.verifyEqual(events(1).Direction, 'upper', ...
                'Tag overload: Direction from Threshold');
        end

        function testLegacySixArgOverloadUnchanged(testCase)
            % Exact same scenario as TestEventDetector.testMultipleEvents
            det = EventDetector();
            t      = [1 2 3 4 5 6 7 8 9 10];
            values = [12 13 5 5 5 14 15 5 5 5];
            events = det.detect(t, values, 10, 'upper', 'warn', 'temp');
            testCase.verifyEqual(numel(events), 2, 'legacy 6-arg: count');
            testCase.verifyEqual(events(1).StartTime, 1, 'legacy 6-arg: e1 start');
            testCase.verifyEqual(events(2).StartTime, 6, 'legacy 6-arg: e2 start');
            testCase.verifyEqual(events(1).SensorName, 'temp');
            testCase.verifyEqual(events(1).ThresholdLabel, 'warn');
        end

        function testNonTagNonSensorErrors(testCase)
            % Malformed input should fail cleanly — not silently corrupt.
            det = EventDetector();
            testCase.verifyError(@() det.detect(42, 'foo'), ?MException);
        end

        function testTagOverloadWithEmptyTag(testCase)
            % Empty SensorTag => empty events, no error.
            st = SensorTag('empty_tag', 'X', [], 'Y', []);
            TagRegistry.register('empty_tag', st);
            thr = Threshold('warn', 'Name', 'Warn', 'Direction', 'upper');
            thr.addCondition(struct(), 10);

            det = EventDetector();
            events = det.detect(st, thr);
            testCase.verifyEmpty(events, 'empty Tag: no events');
        end

        function testPitfall1NoSubclassIsaInDetect(testCase)
            % EventDetector.m must route via isa(..,'Tag') only — not via
            % any SensorTag/MonitorTag/CompositeTag/StateTag subclass isa.
            here = fileparts(mfilename('fullpath'));
            detectorFile = fullfile(here, '..', '..', 'libs', 'EventDetection', 'EventDetector.m');
            src = fileread(detectorFile);
            badKinds = {'SensorTag', 'MonitorTag', 'StateTag', 'CompositeTag'};
            for i = 1:numel(badKinds)
                pat = ['isa\([^,]+,\s*''', badKinds{i}, ''''];
                m   = regexp(src, pat, 'once');
                testCase.verifyEmpty(m, ...
                    sprintf('Pitfall 1 violation: isa(..,''%s'') in EventDetector.m', ...
                        badKinds{i}));
            end
        end

        % testLegacyCallersStillWork removed — legacy bridge helper
        % bridge helper deleted in Phase 1011 cleanup.

    end
end
