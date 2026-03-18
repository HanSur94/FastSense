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
