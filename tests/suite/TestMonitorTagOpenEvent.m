classdef TestMonitorTagOpenEvent < matlab.unittest.TestCase
    %TESTMONITORTAGOPENEVENT Phase 1012 Plan 02 — MonitorTag live-emission tests.
    %   Tests rising-edge IsOpen=true emission, falling-edge closeEvent,
    %   running-stats accumulation, and short-circuit preservation.

    methods (TestClassSetup)
        function addPaths(~)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(root); install();
        end
    end

    methods (Test)
        function testRisingEdgeEmitsOpenEvent(tc)
            [~, mon, es] = TestMonitorTagOpenEvent.makeFixture();
            % Append y values that rise above threshold at t=2 (start with 1, then 3 samples of 10)
            mon.appendData([1 2 3 4], [1 10 10 10]);
            stored = es.getEvents();
            tc.verifyNumElements(stored, 1);
            tc.verifyTrue(stored(1).IsOpen);
            tc.verifyTrue(isnan(stored(1).EndTime));
            tc.verifyEqual(stored(1).StartTime, 2);
        end

        function testOpenEventAppendedToStoreWithId(tc)
            [~, mon, es] = TestMonitorTagOpenEvent.makeFixture();
            mon.appendData([1 2], [1 10]);
            stored = es.getEvents();
            tc.verifyNotEmpty(stored(1).Id);
            tc.verifyTrue(startsWith(stored(1).Id, 'evt_'));
        end

        function testFallingEdgeCallsCloseEvent(tc)
            [~, mon, es] = TestMonitorTagOpenEvent.makeFixture();
            mon.appendData([1 2 3 4], [1 10 10 10]);       % rise at t=2, still open
            mon.appendData([5 6 7 8], [10 10 1 1]);         % fall at t=7
            stored = es.getEvents();
            tc.verifyNumElements(stored, 1);
            tc.verifyFalse(stored(1).IsOpen);
            tc.verifyEqual(stored(1).EndTime, 6);   % last 1-bin index is t=6
            tc.verifyEqual(stored(1).Duration, 4);
        end

        function testRunningStatsAccumulateDuringOpenRun(tc)
            [~, mon, es] = TestMonitorTagOpenEvent.makeFixture();
            mon.appendData([1 2 3], [1 10 12]);     % open at t=2, peak 12
            mon.appendData([4 5], [15 14]);          % still open, peak should climb to 15
            mon.appendData([6 7], [13 0]);           % close at t=7, last alarm at t=6
            stored = es.getEvents();
            tc.verifyEqual(stored(1).PeakValue, 15);
            tc.verifyEqual(stored(1).MaxValue, 15);
            tc.verifyEqual(stored(1).MinValue, 10);
            tc.verifyEqual(stored(1).NumPoints, 5);   % 10,12,15,14,13
        end

        function testOpenRunStatsFinalizedOnClose(tc)
            [~, mon, es] = TestMonitorTagOpenEvent.makeFixture();
            mon.appendData([1 2 3 4 5], [1 10 10 10 1]);   % rise at t=2, fall at t=5
            stored = es.getEvents();
            tc.verifyFalse(stored(1).IsOpen);
            tc.verifyGreaterThan(stored(1).NumPoints, 0);
            tc.verifyTrue(~isempty(stored(1).PeakValue));
            tc.verifyTrue(~isempty(stored(1).MeanValue));
        end

        function testClosingRunResetsOpenEventIdAndOpenStats(tc)
            [~, mon, es] = TestMonitorTagOpenEvent.makeFixture();
            mon.appendData([1 2 3], [1 10 10]);      % open
            mon.appendData([4 5], [1 1]);             % close
            mon.appendData([6 7 8], [1 10 10]);       % new open — should be a NEW event
            stored = es.getEvents();
            tc.verifyNumElements(stored, 2);
            tc.verifyFalse(stored(1).IsOpen);
            tc.verifyTrue(stored(2).IsOpen);
            tc.verifyNotEqual(stored(1).Id, stored(2).Id);
        end

        function testShortCircuitNoEmissionWhenAllHooksEmpty(tc)
            % Build a MonitorTag with NO EventStore, NO OnEventStart, NO OnEventEnd.
            parent = SensorTag('p');
            parent.updateData([0], [0]);
            mon = MonitorTag('m', parent, @(x, y) y > 5);
            mon.getXY();  % warm up cache
            mon.appendData([1 2 3], [1 10 10]);
            % Short-circuit preserved — no error, no state change.
            [x, y] = mon.getXY();
            tc.verifyNotEmpty(x);
            tc.verifyEqual(numel(x), numel(y));
        end
    end

    methods (Static)
        function [parent, mon, es] = makeFixture()
            parent = SensorTag('p');
            parent.updateData([0], [0]);
            es = EventStore('');
            mon = MonitorTag('m', parent, @(x, y) y > 5, 'EventStore', es);
            % Warm up cache so subsequent appendData calls use the incremental path.
            mon.getXY();
        end
    end
end
