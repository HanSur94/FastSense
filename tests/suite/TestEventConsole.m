classdef TestEventConsole < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testPrintEventSummary(testCase)
            [e1, e2] = TestEventConsole.makeEvents();
            events = [e1, e2];
            out = evalc('printEventSummary(events)');
            testCase.verifyNotEmpty(out, 'printSummary: produces output');
            testCase.verifyTrue(contains(out, 'Temperature'), 'printSummary: contains sensor name');
            testCase.verifyTrue(contains(out, 'warning high'), 'printSummary: contains threshold label');
            testCase.verifyTrue(contains(out, 'Pressure'), 'printSummary: contains second sensor');
        end

        function testPrintEventSummaryEmpty(testCase)
            out = evalc('printEventSummary([])');
            testCase.verifyTrue(contains(out, 'No events'), 'printSummaryEmpty: no events message');
        end

        function testEventLogger(testCase)
            logger = eventLogger();
            testCase.verifyTrue(isa(logger, 'function_handle'), 'eventLogger: returns function handle');
        end

        function testEventLoggerOutput(testCase)
            [e1, ~] = TestEventConsole.makeEvents();
            logger = eventLogger();
            out = evalc('logger(e1)');
            testCase.verifyNotEmpty(out, 'eventLoggerOutput: produces output');
            testCase.verifyTrue(contains(out, 'EVENT'), 'eventLoggerOutput: contains EVENT tag');
            testCase.verifyTrue(contains(out, 'Temperature'), 'eventLoggerOutput: contains sensor name');
            testCase.verifyTrue(contains(out, 'warning high'), 'eventLoggerOutput: contains label');
        end
    end

    methods (Static, Access = private)
        function [e1, e2] = makeEvents()
            e1 = Event(10, 25, 'Temperature', 'warning high', 80, 'upper');
            e1.setStats(95.2, 150, 72, 95.2, 87.3, 88.1, 4.21);
            e2 = Event(50, 55, 'Pressure', 'low alarm', 5, 'lower');
            e2.setStats(2.1, 50, 2.1, 6.8, 4.5, 4.7, 1.2);
        end
    end
end
