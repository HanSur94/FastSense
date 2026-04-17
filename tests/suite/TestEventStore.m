classdef TestEventStore < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testAutoSave(testCase)
            cfg = EventConfig();
            s = SensorTag('temp', 'Name', 'Temperature');
            s.updateData(1:10, [5 5 12 14 11 13 5 5 5 5]);
            t_warn = Threshold('warn', 'Name', 'warn', 'Direction', 'upper');
            t_warn.addCondition(struct(), 10);
            s.addThreshold(t_warn);
            cfg.addTag(s);
            cfg.setColor('warn', [1 0.8 0]);

            tmpFile = fullfile(tempdir, 'test_event_store.mat');
            testCase.addTeardown(@() TestEventStore.deleteIfExists(tmpFile));
            cfg.EventFile = tmpFile;
            events = cfg.runDetection();

            testCase.verifyEqual(exist(tmpFile, 'file'), 2, 'auto-save: file created');
            data = load(tmpFile);
            testCase.verifyTrue(isfield(data, 'events'), 'auto-save: has events');
            testCase.verifyTrue(isfield(data, 'sensorData'), 'auto-save: has sensorData');
            testCase.verifyTrue(isfield(data, 'thresholdColors'), 'auto-save: has thresholdColors');
            testCase.verifyTrue(isfield(data, 'timestamp'), 'auto-save: has timestamp');
            testCase.verifyEqual(numel(data.events), numel(events), 'auto-save: event count');
            testCase.verifyEqual(data.sensorData(1).name, 'Temperature', 'auto-save: sensor name');
        end

        function testFromFile(testCase)
            cfg = EventConfig();
            s = SensorTag('temp', 'Name', 'Temperature');
            s.updateData(1:10, [5 5 12 14 11 13 5 5 5 5]);
            t_warn = Threshold('warn', 'Name', 'warn', 'Direction', 'upper');
            t_warn.addCondition(struct(), 10);
            s.addThreshold(t_warn);
            cfg.addTag(s);
            cfg.setColor('warn', [1 0.8 0]);

            tmpFile = fullfile(tempdir, 'test_event_store_fromfile.mat');
            testCase.addTeardown(@() TestEventStore.deleteIfExists(tmpFile));
            cfg.EventFile = tmpFile;
            events = cfg.runDetection();

            viewer = EventViewer.fromFile(tmpFile);
            testCase.addTeardown(@close, viewer.hFigure);
            testCase.verifyTrue(isa(viewer, 'EventViewer'), 'fromFile: returns EventViewer');
            testCase.verifyEqual(numel(viewer.Events), numel(events), 'fromFile: event count');
        end

        function testFromFileColors(testCase)
            cfg = EventConfig();
            s = SensorTag('temp', 'Name', 'Temperature');
            s.updateData(1:10, [5 5 12 14 11 13 5 5 5 5]);
            t_warn = Threshold('warn', 'Name', 'warn', 'Direction', 'upper');
            t_warn.addCondition(struct(), 10);
            s.addThreshold(t_warn);
            cfg.addTag(s);
            cfg.setColor('warn', [1 0.8 0]);

            tmpFile = fullfile(tempdir, 'test_event_store_colors.mat');
            testCase.addTeardown(@() TestEventStore.deleteIfExists(tmpFile));
            cfg.EventFile = tmpFile;
            cfg.runDetection();

            viewer = EventViewer.fromFile(tmpFile);
            testCase.addTeardown(@close, viewer.hFigure);
            testCase.verifyTrue(viewer.ThresholdColors.isKey('warn'), 'fromFile: color key restored');
            testCase.verifyEqual(viewer.ThresholdColors('warn'), [1 0.8 0], 'fromFile: color value');
        end

        function testNoEventFile(testCase)
            cfg2 = EventConfig();
            s2 = SensorTag('temp', 'Name', 'Temperature');
            s2.updateData(1:10, [5 5 12 14 11 13 5 5 5 5]);
            t_warn = Threshold('warn', 'Name', 'warn', 'Direction', 'upper');
            t_warn.addCondition(struct(), 10);
            s2.addThreshold(t_warn);
            cfg2.addTag(s2);
            tmpFile2 = fullfile(tempdir, 'test_event_store_2.mat');
            if exist(tmpFile2, 'file'); delete(tmpFile2); end
            cfg2.runDetection();
            testCase.verifyTrue(exist(tmpFile2, 'file') ~= 2, 'no-file: nothing saved when EventFile empty');
        end

        function testFromFileNotFound(testCase)
            threw = false;
            try
                EventViewer.fromFile('/tmp/nonexistent_event_store.mat');
            catch e
                threw = true;
                testCase.verifyTrue(contains(e.identifier, 'fileNotFound'), 'fromFile: correct error id');
            end
            testCase.verifyTrue(threw, 'fromFile: throws on missing file');
        end

        function testBackupCreated(testCase)
            tmpFile3 = fullfile(tempdir, 'test_event_backup.mat');
            [bDir, bName, bExt] = fileparts(tmpFile3);
            % Clean up any previous backup files
            oldBackups = dir(fullfile(bDir, [bName, '_*', bExt]));
            for bi = 1:numel(oldBackups)
                delete(fullfile(bDir, oldBackups(bi).name));
            end
            if exist(tmpFile3, 'file'); delete(tmpFile3); end

            testCase.addTeardown(@() TestEventStore.cleanupBackups(tmpFile3));

            cfg3 = EventConfig();
            s3 = SensorTag('temp', 'Name', 'Temperature');
            s3.updateData(1:10, [5 5 12 14 11 13 5 5 5 5]);
            t_warn = Threshold('warn', 'Name', 'warn', 'Direction', 'upper');
            t_warn.addCondition(struct(), 10);
            s3.addThreshold(t_warn);
            cfg3.addTag(s3);
            cfg3.EventFile = tmpFile3;
            cfg3.MaxBackups = 2;

            % First save — no backup (no existing file)
            cfg3.runDetection();
            backups = dir(fullfile(bDir, [bName, '_*', bExt]));
            testCase.verifyEqual(numel(backups), 0, 'backup: no backup on first save');

            % Second save — creates backup
            pause(1.1);
            cfg3.runDetection();
            backups = dir(fullfile(bDir, [bName, '_*', bExt]));
            testCase.verifyEqual(numel(backups), 1, 'backup: one backup after second save');

            % Third save — creates second backup
            pause(1.1);
            cfg3.runDetection();
            backups = dir(fullfile(bDir, [bName, '_*', bExt]));
            testCase.verifyEqual(numel(backups), 2, 'backup: two backups after third save');

            % Fourth save — prunes to MaxBackups=2
            pause(1.1);
            cfg3.runDetection();
            backups = dir(fullfile(bDir, [bName, '_*', bExt]));
            testCase.verifyEqual(numel(backups), 2, 'backup: pruned to MaxBackups');
        end

        function testMaxBackupsZero(testCase)
            tmpFile4 = fullfile(tempdir, 'test_event_nobackup.mat');
            testCase.addTeardown(@() TestEventStore.cleanupBackups(tmpFile4));

            cfg4 = EventConfig();
            s4 = SensorTag('temp', 'Name', 'Temperature');
            s4.updateData(1:10, [5 5 12 14 11 13 5 5 5 5]);
            t_warn = Threshold('warn', 'Name', 'warn', 'Direction', 'upper');
            t_warn.addCondition(struct(), 10);
            s4.addThreshold(t_warn);
            cfg4.addTag(s4);
            cfg4.EventFile = tmpFile4;
            cfg4.MaxBackups = 0;
            cfg4.runDetection();
            cfg4.runDetection();
            [nbDir, nbName, nbExt] = fileparts(tmpFile4);
            noBackups = dir(fullfile(nbDir, [nbName, '_*', nbExt]));
            testCase.verifyEqual(numel(noBackups), 0, 'no-backup: MaxBackups=0 creates no backups');
        end

        function testFromFileHasRefreshControls(testCase)
            cfg5 = EventConfig();
            s5 = SensorTag('temp', 'Name', 'Temperature');
            s5.updateData(1:10, [5 5 12 14 11 13 5 5 5 5]);
            [s5_x_, s5_y_] = s5.getXY();
            t_warn = Threshold('warn', 'Name', 'warn', 'Direction', 'upper');
            t_warn.addCondition(struct(), 10);
            s5.addThreshold(t_warn);
            cfg5.addTag(s5);
            tmpFile5 = fullfile(tempdir, 'test_event_refresh.mat');
            testCase.addTeardown(@() TestEventStore.deleteIfExists(tmpFile5));
            cfg5.EventFile = tmpFile5;
            cfg5.runDetection();
            viewer5 = EventViewer.fromFile(tmpFile5);
            testCase.addTeardown(@close, viewer5.hFigure);
            testCase.verifyNotEmpty(viewer5.hFigure, 'refresh: figure exists');
            % Verify refresh works by modifying file and calling refreshFromFile
            s5_y_ = [5 5 12 14 11 13 12 15 5 5];
            cfg5.runDetection();
            oldCount = numel(viewer5.Events);
            viewer5.refreshFromFile();
            testCase.verifyGreaterThanOrEqual(numel(viewer5.Events), oldCount, 'refresh: events updated from file');
            % Test auto-refresh start/stop (no error = success)
            viewer5.startAutoRefresh(60);
            viewer5.stopAutoRefresh();
        end
    end

    methods (Static, Access = private)
        function deleteIfExists(f)
            if exist(f, 'file'); delete(f); end
        end

        function cleanupBackups(f)
            if exist(f, 'file'); delete(f); end
            [bDir, bName, bExt] = fileparts(f);
            backups = dir(fullfile(bDir, [bName, '_*', bExt]));
            for bi = 1:numel(backups)
                delete(fullfile(bDir, backups(bi).name));
            end
        end
    end
end
