classdef TestMonitorTagOpenEvent < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(~)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(root); install();
        end
    end
    methods (Test)
        function testRisingEdgeEmitsOpenEvent(tc)
            % Wave 0 STUB — goes GREEN in Plan 02.
            % Builds a SensorTag, wraps in MonitorTag with condition y>5;
            % appendData one rising edge; expect EventStore has 1 event
            % with IsOpen=true, EndTime=NaN.
            tc.assumeFail('Plan 1012-02 wires rising-edge open emission in MonitorTag.fireEventsInTail_');
        end
        function testFallingEdgeCallsCloseEvent(tc)
            tc.assumeFail('Plan 1012-02 wires falling-edge closeEvent in MonitorTag.fireEventsInTail_');
        end
        function testRunningStatsAccumulateDuringOpenRun(tc)
            tc.assumeFail('Plan 1012-02 extends cache_.openStats_ on each appendData tick');
        end
        function testOpenRunStatsFinalizedOnClose(tc)
            tc.assumeFail('Plan 1012-02 passes cache_.openStats_ as finalStats to EventStore.closeEvent');
        end
    end
end
