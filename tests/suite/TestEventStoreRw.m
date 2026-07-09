classdef TestEventStoreRw < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'libs', 'EventDetection'));
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'libs', 'SensorThreshold'));
            install();
        end
    end

    methods (Test)
        function testConstructor(testCase)
            f = [tempname '.mat'];
            store = EventStore(f);
            testCase.verifyEqual(store.FilePath, f, 'filepath');
            testCase.verifyEqual(store.MaxBackups, 5, 'default_backups');
        end

        function testAppendAndSave(testCase)
            f = [tempname '.mat'];
            testCase.addTeardown(@() TestEventStoreRw.deleteIfExists(f));
            store = EventStore(f);
            ev1 = Event(now-1, now-0.5, 'sensorA', 'HH', 100, 'upper');
            store.append(ev1);
            store.save();
            testCase.verifyTrue(isfile(f), 'file_created');
            data = load(f);
            testCase.verifyEqual(numel(data.events), 1, 'one_event');
            % Append more
            ev2 = Event(now-0.3, now-0.1, 'sensorB', 'LL', 10, 'lower');
            store.append(ev2);
            store.save();
            data = load(f);
            testCase.verifyEqual(numel(data.events), 2, 'two_events');
        end

        function testAtomicWrite(testCase)
            f = [tempname '.mat'];
            testCase.addTeardown(@() TestEventStoreRw.deleteIfExists(f));
            store = EventStore(f);
            ev = Event(now, now+0.01, 'x', 'H', 50, 'upper');
            store.append(ev);
            store.save();
            data = load(f);
            testCase.verifyTrue(isfield(data, 'events'), 'has_events');
            testCase.verifyTrue(isfield(data, 'lastUpdated'), 'has_timestamp');
        end

        function testLoadStatic(testCase)
            f = [tempname '.mat'];
            testCase.addTeardown(@() TestEventStoreRw.deleteIfExists(f));
            store = EventStore(f);
            ev = Event(now, now+0.01, 'x', 'H', 50, 'upper');
            store.append(ev);
            store.save();
            [events, meta] = EventStore.loadFile(f);
            testCase.verifyEqual(numel(events), 1, 'loaded_one');
            testCase.verifyTrue(isfield(meta, 'lastUpdated'), 'meta_timestamp');
        end

        function testLoadUnchanged(testCase)
            f = [tempname '.mat'];
            testCase.addTeardown(@() TestEventStoreRw.deleteIfExists(f));
            store = EventStore(f);
            ev = Event(now, now+0.01, 'x', 'H', 50, 'upper');
            store.append(ev);
            store.save();
            [~, ~] = EventStore.loadFile(f);
            [events, meta, changed] = EventStore.loadFile(f);
            testCase.verifyTrue(~changed, 'unchanged');
        end

        function testBackupRotation(testCase)
            f = [tempname '.mat'];
            testCase.addTeardown(@() TestEventStoreRw.cleanupBackups(f));
            store = EventStore(f, 'MaxBackups', 2);
            for i = 1:4
                ev = Event(now+i, now+i+0.01, 'x', 'H', 50, 'upper');
                store.append(ev);
                store.save();
                pause(0.1);
            end
            [fdir, fname] = fileparts(f);
            backups = dir(fullfile(fdir, [fname '_backup_*.mat']));
            testCase.verifyLessThanOrEqual(numel(backups), 2, 'max_2_backups');
        end

        function testMetadata(testCase)
            f = [tempname '.mat'];
            testCase.addTeardown(@() TestEventStoreRw.deleteIfExists(f));
            store = EventStore(f);
            store.PipelineConfig = struct('sensors', {{'a','b'}});
            ev = Event(now, now+0.01, 'x', 'H', 50, 'upper');
            store.append(ev);
            store.save();
            data = load(f);
            testCase.verifyTrue(isfield(data, 'pipelineConfig'), 'has_config');
            testCase.verifyEqual(data.pipelineConfig.sensors, {'a','b'}, 'config_matches');
        end
        % ---- Issue #360: getEvent(id) id-addressed point-read ----

        function testGetEventById(testCase)
            f = [tempname '.mat'];
            testCase.addTeardown(@() TestEventStoreRw.deleteIfExists(f));
            store = EventStore(f);
            ev1 = Event(now-1, now-0.5, 'sensorA', 'HH', 100, 'upper');
            ev2 = Event(now-0.3, now-0.1, 'sensorB', 'LL', 10, 'lower');
            store.append(ev1);
            store.append(ev2);
            got = store.getEvent(ev2.Id);
            testCase.verifyEqual(got.Id, ev2.Id, 'returns event matching id');
            testCase.verifyEqual(got.SensorName, 'sensorB', 'correct event fetched');
        end

        function testGetEventUnknownIdThrows(testCase)
            f = [tempname '.mat'];
            testCase.addTeardown(@() TestEventStoreRw.deleteIfExists(f));
            store = EventStore(f);
            store.append(Event(now, now+0.01, 'x', 'H', 50, 'upper'));
            testCase.verifyError(@() store.getEvent('no-such-id'), ...
                'EventStore:unknownEventId');
        end

        % ---- Issue #354: removeEvent(id) / removeEvents(ids) ----

        function testRemoveEventDropsOne(testCase)
            f = [tempname '.mat'];
            testCase.addTeardown(@() TestEventStoreRw.deleteIfExists(f));
            store = EventStore(f);
            ev1 = Event(now-1, now-0.5, 'a', 'HH', 100, 'upper');
            ev2 = Event(now-0.3, now-0.1, 'b', 'LL', 10, 'lower');
            store.append(ev1);
            store.append(ev2);
            n = store.removeEvent(ev1.Id);
            testCase.verifyEqual(n, 1, 'returns count removed');
            testCase.verifyEqual(store.numEvents(), 1, 'one event left');
            testCase.verifyEqual(store.getEvent(ev2.Id).Id, ev2.Id, 'survivor intact');
        end

        function testRemoveEventUnknownIdThrows(testCase)
            f = [tempname '.mat'];
            testCase.addTeardown(@() TestEventStoreRw.deleteIfExists(f));
            store = EventStore(f);
            store.append(Event(now, now+0.01, 'x', 'H', 50, 'upper'));
            testCase.verifyError(@() store.removeEvent('no-such-id'), ...
                'EventStore:unknownEventId');
        end

        function testRemoveEventsBulkSkipsUnknown(testCase)
            f = [tempname '.mat'];
            testCase.addTeardown(@() TestEventStoreRw.deleteIfExists(f));
            store = EventStore(f);
            ev1 = Event(now-1, now-0.9, 'a', 'HH', 1, 'upper');
            ev2 = Event(now-0.8, now-0.7, 'b', 'LL', 2, 'lower');
            ev3 = Event(now-0.6, now-0.5, 'c', 'HH', 3, 'upper');
            store.append(ev1); store.append(ev2); store.append(ev3);
            n = store.removeEvents({ev1.Id, 'ghost', ev3.Id});
            testCase.verifyEqual(n, 2, 'only the two known ids removed');
            testCase.verifyEqual(store.numEvents(), 1);
            testCase.verifyEqual(store.getEvents().Id, ev2.Id, 'ev2 survives');
        end

        function testRemoveEventCascadesBindingDetach(testCase)
            f = [tempname '.mat'];
            testCase.addTeardown(@() TestEventStoreRw.deleteIfExists(f));
            EventBinding.clear();
            testCase.addTeardown(@() EventBinding.clear());
            store = EventStore(f);
            ev = Event(now, now+0.01, 'a', 'H', 50, 'upper');
            store.append(ev);
            EventBinding.attach(ev.Id, 'tagA');
            testCase.verifyEqual(numel(EventBinding.getTagKeysForEvent(ev.Id)), 1, ...
                'binding present before removal');
            store.removeEvent(ev.Id);
            testCase.verifyEmpty(EventBinding.getTagKeysForEvent(ev.Id), ...
                'binding detached after removal');
        end

        function testRemoveEventRoundTripsReducedSet(testCase)
            f = [tempname '.mat'];
            testCase.addTeardown(@() TestEventStoreRw.deleteIfExists(f));
            store = EventStore(f);
            ev1 = Event(now-1, now-0.5, 'a', 'HH', 100, 'upper');
            ev2 = Event(now-0.3, now-0.1, 'b', 'LL', 10, 'lower');
            store.append(ev1); store.append(ev2);
            store.removeEvent(ev1.Id);
            store.save();
            data = load(f);
            testCase.verifyEqual(numel(data.events), 1, 'reduced set persisted');
        end

        % ---- Issue #355: editEvent(id, ...) + Event.editWindow ----

        function testEditWindowRecomputesDuration(testCase)
            ev = Event(10, 20, 'a', 'H', 5, 'upper');
            ev.editWindow(12, 30);
            testCase.verifyEqual(ev.StartTime, 12);
            testCase.verifyEqual(ev.EndTime, 30);
            testCase.verifyEqual(ev.Duration, 18, 'Duration recomputed');
        end

        function testEditWindowRejectsInverted(testCase)
            ev = Event(10, 20, 'a', 'H', 5, 'upper');
            testCase.verifyError(@() ev.editWindow(30, 12), 'Event:invalidTimeRange');
        end

        function testEditEventWindowNotesSeverity(testCase)
            f = [tempname '.mat'];
            testCase.addTeardown(@() TestEventStoreRw.deleteIfExists(f));
            store = EventStore(f);
            ev = Event(10, 20, 'a', 'H', 5, 'upper');
            store.append(ev);
            store.editEvent(ev.Id, 'StartTime', 11, 'EndTime', 25, ...
                'Notes', 'corrected', 'Severity', 2, 'Category', 'maintenance');
            got = store.getEvent(ev.Id);
            testCase.verifyEqual(got.StartTime, 11);
            testCase.verifyEqual(got.EndTime, 25);
            testCase.verifyEqual(got.Duration, 14);
            testCase.verifyEqual(got.Notes, 'corrected');
            testCase.verifyEqual(got.Severity, 2);
            testCase.verifyEqual(got.Category, 'maintenance');
        end

        function testEditEventUnknownIdThrows(testCase)
            f = [tempname '.mat'];
            testCase.addTeardown(@() TestEventStoreRw.deleteIfExists(f));
            store = EventStore(f);
            store.append(Event(1, 2, 'x', 'H', 5, 'upper'));
            testCase.verifyError(@() store.editEvent('ghost', 'Notes', 'x'), ...
                'EventStore:unknownEventId');
        end

        function testEditEventUnknownFieldThrowsAndLeavesUntouched(testCase)
            f = [tempname '.mat'];
            testCase.addTeardown(@() TestEventStoreRw.deleteIfExists(f));
            store = EventStore(f);
            ev = Event(10, 20, 'a', 'H', 5, 'upper');
            store.append(ev);
            testCase.verifyError(@() store.editEvent(ev.Id, 'Bogus', 1), ...
                'EventStore:unknownEditField');
            % Unchanged — validation happens before any mutation.
            testCase.verifyEqual(store.getEvent(ev.Id).StartTime, 10);
        end

        function testEditEventInvertedWindowLeavesUntouched(testCase)
            f = [tempname '.mat'];
            testCase.addTeardown(@() TestEventStoreRw.deleteIfExists(f));
            store = EventStore(f);
            ev = Event(10, 20, 'a', 'H', 5, 'upper');
            store.append(ev);
            testCase.verifyError(@() store.editEvent(ev.Id, 'StartTime', 30, 'EndTime', 12), ...
                'Event:invalidTimeRange');
            got = store.getEvent(ev.Id);
            testCase.verifyEqual(got.StartTime, 10, 'window unchanged after rejected edit');
            testCase.verifyEqual(got.EndTime, 20);
        end

        function testEditEventRoundTrips(testCase)
            f = [tempname '.mat'];
            testCase.addTeardown(@() TestEventStoreRw.deleteIfExists(f));
            store = EventStore(f);
            ev = Event(10, 20, 'a', 'H', 5, 'upper');
            store.append(ev);
            store.editEvent(ev.Id, 'Notes', 'persisted note', 'EndTime', 40);
            store.save();
            data = load(f);
            testCase.verifyEqual(data.events(1).Notes, 'persisted note');
            testCase.verifyEqual(data.events(1).EndTime, 40);
        end
    end

    methods (Static, Access = private)
        function deleteIfExists(f)
            if exist(f, 'file'); delete(f); end
        end

        function cleanupBackups(f)
            if exist(f, 'file'); delete(f); end
            [fdir, fname] = fileparts(f);
            backups = dir(fullfile(fdir, [fname '_backup_*.mat']));
            for b = 1:numel(backups)
                delete(fullfile(fdir, backups(b).name));
            end
        end
    end
end
