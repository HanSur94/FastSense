classdef TestEventViewerExtras < matlab.unittest.TestCase
%TESTEVENTVIEWEREXTRAS Coverage for EventViewer surfaces beyond the
%   construction + filter tests in TestEventViewer. Targets:
%
%     - EventViewer.fromFile static (error paths + happy path)
%     - refreshFromFile (file-driven update, missing file no-op)
%     - startAutoRefresh / stopAutoRefresh lifecycle (timer creation,
%       no-op when no SourceFile, double-stop safety)
%     - update() with empty events
%     - getSensorNames / getThresholdLabels with empty event arrays
%
%   Existing TestEventViewer covers constructor variants, filter discovery,
%   and BarPositions caching. This file is additive.

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)

        % ------------------------------------------------------------- %
        %  EventViewer.fromFile static
        % ------------------------------------------------------------- %

        function testFromFileMissingPathErrors(testCase)
            % tempname returns a unique non-existent path; appending a
            % suffix keeps it unique without invoking Java.
            bogus = [tempname, '_does_not_exist.mat'];
            testCase.assertFalse(exist(bogus, 'file') == 2, ...
                'precondition: bogus path must not exist');
            testCase.verifyError(@() EventViewer.fromFile(bogus), ...
                'EventViewer:fileNotFound');
        end

        function testFromFileWithoutEventsFieldErrors(testCase)
            tmp = [tempname, '.mat'];
            testCase.addTeardown(@() TestEventViewerExtras.safeDelete(tmp));
            % Build a .mat file that has variables but no 'events'
            unrelated = struct('foo', 1); %#ok<NASGU>
            save(tmp, 'unrelated');
            testCase.verifyError(@() EventViewer.fromFile(tmp), ...
                'EventViewer:invalidFile');
        end

        function testFromFileRoundtrip(testCase)
            [events, sensorData] = TestEventViewerExtras.makeFixtureEvents();

            tmp = [tempname, '.mat'];
            testCase.addTeardown(@() TestEventViewerExtras.safeDelete(tmp));
            store = EventStore(tmp, 'MaxBackups', 0);
            store.append(events);
            store.SensorData = sensorData;
            store.Timestamp = datetime('now');
            store.save();

            viewer = EventViewer.fromFile(tmp);
            testCase.addTeardown(@() TestEventViewerExtras.safeClose(viewer));

            testCase.verifyNotEmpty(viewer.Events, 'fromFile: events loaded');
            testCase.verifyNotEmpty(viewer.SensorData, 'fromFile: sensorData loaded');
            testCase.verifyEqual(viewer.SourceFile, tmp, 'fromFile: SourceFile recorded');
        end

        % ------------------------------------------------------------- %
        %  refreshFromFile
        % ------------------------------------------------------------- %

        function testRefreshFromFilePicksUpNewEvents(testCase)
            [eventsA, sensorData] = TestEventViewerExtras.makeFixtureEvents();
            eventsB = [eventsA, Event(80, 90, 'Pressure', 'low alarm', 5, 'lower')];
            eventsB(end).setStats(2.0, 60, 1.5, 4.0, 3.0, 3.2, 0.6);

            tmp = [tempname, '.mat'];
            testCase.addTeardown(@() TestEventViewerExtras.safeDelete(tmp));
            store = EventStore(tmp, 'MaxBackups', 0);
            store.append(eventsA);
            store.SensorData = sensorData;
            store.save();

            viewer = EventViewer.fromFile(tmp);
            testCase.addTeardown(@() TestEventViewerExtras.safeClose(viewer));
            countA = numel(viewer.Events);

            % Append a new event to the store and re-save
            store.append(eventsB(end));
            store.save();

            viewer.refreshFromFile();
            testCase.verifyEqual(numel(viewer.Events), countA + 1, ...
                'refreshFromFile: new event picked up');
        end

        function testRefreshFromFileNoOpWhenSourceFileEmpty(testCase)
            % Viewer constructed without fromFile() has no SourceFile.
            % refreshFromFile must be a clean no-op (no errors).
            [events, ~] = TestEventViewerExtras.makeFixtureEvents();
            viewer = EventViewer(events);
            testCase.addTeardown(@() TestEventViewerExtras.safeClose(viewer));
            % Should not throw
            viewer.refreshFromFile();
            testCase.verifyEqual(numel(viewer.Events), numel(events), ...
                'refreshFromFile no-op: events unchanged');
        end

        function testRefreshFromFileNoOpWhenFileMissing(testCase)
            % SourceFile is set but the file has been deleted under us.
            [events, sensorData] = TestEventViewerExtras.makeFixtureEvents();
            tmp = [tempname, '.mat'];
            store = EventStore(tmp, 'MaxBackups', 0);
            store.append(events);
            store.SensorData = sensorData;
            store.save();

            viewer = EventViewer.fromFile(tmp);
            testCase.addTeardown(@() TestEventViewerExtras.safeClose(viewer));

            % Delete the file out from under the viewer
            delete(tmp);

            % Should not throw
            viewer.refreshFromFile();
            testCase.verifyEqual(numel(viewer.Events), numel(events), ...
                'refreshFromFile missing-file: events unchanged');
        end

        % ------------------------------------------------------------- %
        %  startAutoRefresh / stopAutoRefresh
        % ------------------------------------------------------------- %

        function testStopAutoRefreshSafeWhenNotStarted(testCase)
            [events, ~] = TestEventViewerExtras.makeFixtureEvents();
            viewer = EventViewer(events);
            testCase.addTeardown(@() TestEventViewerExtras.safeClose(viewer));
            % Should not throw
            viewer.stopAutoRefresh();
            testCase.verifyEmpty(viewer.RefreshTimer, ...
                'stopAutoRefresh: timer remains empty when not started');
        end

        function testStartAutoRefreshNoOpWithoutSourceFile(testCase)
            % startAutoRefresh requires a SourceFile (fromFile path);
            % otherwise it must early-return without creating a timer.
            [events, ~] = TestEventViewerExtras.makeFixtureEvents();
            viewer = EventViewer(events);
            testCase.addTeardown(@() TestEventViewerExtras.safeClose(viewer));

            viewer.startAutoRefresh(0.1);
            testCase.verifyEmpty(viewer.RefreshTimer, ...
                'startAutoRefresh: no timer when SourceFile empty');
        end

        function testStartStopAutoRefreshLifecycle(testCase)
            [events, sensorData] = TestEventViewerExtras.makeFixtureEvents();
            tmp = [tempname, '.mat'];
            testCase.addTeardown(@() TestEventViewerExtras.safeDelete(tmp));
            store = EventStore(tmp, 'MaxBackups', 0);
            store.append(events);
            store.SensorData = sensorData;
            store.save();

            viewer = EventViewer.fromFile(tmp);
            testCase.addTeardown(@() TestEventViewerExtras.safeClose(viewer));

            viewer.startAutoRefresh(60);  % 60s interval — won't fire during test
            testCase.verifyNotEmpty(viewer.RefreshTimer, ...
                'startAutoRefresh: timer object created');

            viewer.stopAutoRefresh();
            testCase.verifyEmpty(viewer.RefreshTimer, ...
                'stopAutoRefresh: timer cleared');
            % Double-stop should be safe
            viewer.stopAutoRefresh();
            testCase.verifyEmpty(viewer.RefreshTimer, ...
                'stopAutoRefresh: idempotent');
        end

        % ------------------------------------------------------------- %
        %  update / get* with degenerate inputs
        % ------------------------------------------------------------- %

        function testUpdateWithEmptyEvents(testCase)
            [events, ~] = TestEventViewerExtras.makeFixtureEvents();
            viewer = EventViewer(events);
            testCase.addTeardown(@() TestEventViewerExtras.safeClose(viewer));
            % Should not throw
            viewer.update([]);
            testCase.verifyEmpty(viewer.Events, 'update []: events cleared');
        end

        function testGetSensorNamesEmptyArray(testCase)
            % An empty event array yields a 0-element sensor name list.
            viewer = EventViewer([]);
            testCase.addTeardown(@() TestEventViewerExtras.safeClose(viewer));
            names = viewer.getSensorNames();
            testCase.verifyEqual(numel(names), 0, ...
                'getSensorNames: empty for empty events');
        end

        function testGetThresholdLabelsEmptyArray(testCase)
            viewer = EventViewer([]);
            testCase.addTeardown(@() TestEventViewerExtras.safeClose(viewer));
            labels = viewer.getThresholdLabels();
            testCase.verifyEqual(numel(labels), 0, ...
                'getThresholdLabels: empty for empty events');
        end
    end

    methods (Static, Access = private)
        function [events, sensorData] = makeFixtureEvents()
            e1 = Event(10, 25, 'Temperature', 'warning high', 80, 'upper');
            e1.setStats(95.2, 150, 72, 95.2, 87.3, 88.1, 4.21);
            e2 = Event(50, 55, 'Pressure', 'low alarm', 5, 'lower');
            e2.setStats(2.1, 50, 2.1, 6.8, 4.5, 4.7, 1.2);
            events = [e1, e2];

            sensorData(1).name = 'Temperature';
            sensorData(1).t = 1:100;
            sensorData(1).y = 50 + 30 * sin((1:100) / 10);
            sensorData(2).name = 'Pressure';
            sensorData(2).t = 1:100;
            sensorData(2).y = 10 + 5 * sin((1:100) / 8);
        end

        function safeClose(viewer)
            try
                viewer.stopAutoRefresh();
            catch
            end
            try
                if ~isempty(viewer.hFigure) && ishandle(viewer.hFigure)
                    close(viewer.hFigure);
                end
            catch
            end
        end

        function safeDelete(path)
            try
                if exist(path, 'file'); delete(path); end
                bak = [path, '.bak'];
                if exist(bak, 'file'); delete(bak); end
            catch
            end
        end
    end
end
