classdef TestEvent < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testConstructor(testCase)
            e = Event(10, 20, 'temp', 'warning high', 80, 'upper');
            testCase.verifyEqual(e.StartTime, 10, 'constructor: StartTime');
            testCase.verifyEqual(e.EndTime, 20, 'constructor: EndTime');
            testCase.verifyEqual(e.Duration, 10, 'constructor: Duration');
            testCase.verifyEqual(e.SensorName, 'temp', 'constructor: SensorName');
            testCase.verifyEqual(e.ThresholdLabel, 'warning high', 'constructor: ThresholdLabel');
            testCase.verifyEqual(e.ThresholdValue, 80, 'constructor: ThresholdValue');
            testCase.verifyEqual(e.Direction, 'upper', 'constructor: Direction');
        end

        function testStats(testCase)
            e = Event(1, 5, 'temp', 'warn', 80, 'upper');
            e = e.setStats(100, 3, 70, 90, 82, 83, 5);
            testCase.verifyEqual(e.PeakValue, 100, 'stats: PeakValue');
            testCase.verifyEqual(e.NumPoints, 3, 'stats: NumPoints');
            testCase.verifyEqual(e.MinValue, 70, 'stats: MinValue');
            testCase.verifyEqual(e.MaxValue, 90, 'stats: MaxValue');
            testCase.verifyLessThan(abs(e.MeanValue - 82), 1e-10, 'stats: MeanValue');
            testCase.verifyLessThan(abs(e.RmsValue - 83), 1e-10, 'stats: RmsValue');
            testCase.verifyLessThan(abs(e.StdValue - 5), 1e-10, 'stats: StdValue');
        end

        function testInvalidDirection(testCase)
            threw = false;
            try
                Event(1, 5, 'temp', 'warn', 80, 'sideways');
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'invalidDirection: should throw');
        end

        function testEndBeforeStart(testCase)
            threw = false;
            try
                Event(10, 5, 'temp', 'warn', 80, 'upper');
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'endBeforeStart: should throw');
        end
    end
end
