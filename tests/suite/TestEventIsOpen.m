classdef TestEventIsOpen < matlab.unittest.TestCase
    %TESTEVENTISOPEN Phase 1012 schema + EventStore.closeEvent tests.

    methods (TestClassSetup)
        function addPaths(tc) %#ok<MANU>
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(root);
            install();
        end
    end

    methods (Test)
        function testIsOpenDefaultFalse(tc)
            ev = Event(0, 10, 's1', 'hi', 5, 'upper');
            tc.verifyFalse(ev.IsOpen);
        end

        function testIsOpenIsWritable(tc)
            ev = Event(0, 10, 's1', 'hi', 5, 'upper');
            ev.IsOpen = true;
            tc.verifyTrue(ev.IsOpen);
        end

        function testConstructorAcceptsNaNEndTime(tc)
            ev = Event(5, NaN, 's1', 'hi', 5, 'upper');
            tc.verifyTrue(isnan(ev.EndTime));
            tc.verifyTrue(isnan(ev.Duration));
        end

        function testConstructorStillRejectsInvalidFiniteRange(tc)
            tc.verifyError(@() Event(10, 5, 's1', 'hi', 5, 'upper'), ...
                'Event:invalidTimeRange');
        end

        function testCloseUpdatesInPlace(tc)
            ev = Event(5, NaN, 's1', 'hi', 5, 'upper');
            ev.IsOpen = true;
            stats = struct('PeakValue', 8, 'NumPoints', 3, 'MinValue', 6, ...
                           'MaxValue', 8, 'MeanValue', 7, 'RmsValue', 7.1, 'StdValue', 1);
            ev.close(12, stats);
            tc.verifyEqual(ev.EndTime, 12);
            tc.verifyEqual(ev.Duration, 7);
            tc.verifyFalse(ev.IsOpen);
            tc.verifyEqual(ev.PeakValue, 8);
            tc.verifyEqual(ev.NumPoints, 3);
        end

        function testCloseAcceptsEmptyStats(tc)
            ev = Event(5, NaN, 's1', 'hi', 5, 'upper');
            ev.IsOpen = true;
            ev.close(12, []);
            tc.verifyEqual(ev.EndTime, 12);
            tc.verifyFalse(ev.IsOpen);
        end

        function testCloseDoubleThrows(tc)
            ev = Event(5, NaN, 's1', 'hi', 5, 'upper');
            ev.IsOpen = true;
            ev.close(12, []);
            tc.verifyError(@() ev.close(13, []), 'Event:closedOpenEvent');
        end

        function testEventStoreCloseEventUpdatesInPlace(tc)
            es = EventStore('');
            ev = Event(5, NaN, 's1', 'hi', 5, 'upper');
            ev.IsOpen = true;
            es.append(ev);
            es.closeEvent(ev.Id, 15, struct('PeakValue', 9, 'NumPoints', 4, ...
                'MinValue', 6, 'MaxValue', 9, 'MeanValue', 7.5, 'RmsValue', 7.7, 'StdValue', 1.3));
            stored = es.getEvents();
            tc.verifyEqual(stored(1).EndTime, 15);
            tc.verifyEqual(stored(1).Duration, 10);
            tc.verifyFalse(stored(1).IsOpen);
            tc.verifyEqual(stored(1).PeakValue, 9);
        end

        function testEventStoreCloseEventUnknownIdThrows(tc)
            es = EventStore('');
            ev = Event(0, 10, 's1', 'hi', 5, 'upper');
            es.append(ev);
            tc.verifyError(@() es.closeEvent('evt_999', 10, []), ...
                'EventStore:unknownEventId');
        end

        function testEventStoreCloseEventAlreadyClosedThrows(tc)
            es = EventStore('');
            ev = Event(0, 10, 's1', 'hi', 5, 'upper'); % IsOpen default false
            es.append(ev);
            tc.verifyError(@() es.closeEvent(ev.Id, 11, []), ...
                'EventStore:alreadyClosed');
        end

        function testEventStoreCloseEventEmptyStoreThrows(tc)
            es = EventStore('');
            tc.verifyError(@() es.closeEvent('evt_1', 10, []), ...
                'EventStore:unknownEventId');
        end

        function testBackwardCompatOldEventMatLoadsWithDefaultIsOpen(tc)
            % Simulate: pre-Phase-1012 Event handle array saved without IsOpen.
            % On load, MATLAB/Octave materializes missing IsOpen property to its class default (false).
            ev = Event(0, 10, 's1', 'hi', 5, 'upper');
            tmp = [tempname '.mat'];
            cleaner = onCleanup(@() delete(tmp));
            events = ev; %#ok<NASGU>
            builtin('save', tmp, 'events');
            data = builtin('load', tmp);
            tc.verifyFalse(data.events(1).IsOpen);  % default-on-read contract
        end
    end
end
