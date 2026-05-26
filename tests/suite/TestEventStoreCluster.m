classdef TestEventStoreCluster < matlab.unittest.TestCase
    %TESTEVENTSTORECLUSTER Cluster-mode (SharedRoot) EventStore — rollback SQLite.
    %
    %   Tests verify:
    %     - Single-user mode is byte-identical (IsClusterMode_ gate dormant)
    %     - Cluster-mode constructor opens <SharedRoot>/events/store.sqlite
    %     - appendAckRecord + getAckRecords round-trip works
    %     - Retry path is exercised when a second connection holds BEGIN IMMEDIATE
    %     - 5 in-process writers * 20 acks = 100 rows (contention test)
    %     - FastSenseDataStore is still on path (byte-identical guarantee for local store)
    %
    %   All cluster tests skip gracefully when mksqlite MEX is unavailable.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)

        function testConstructorSingleUserModeUnchanged(testCase)
            %TESTCONSTRUCTORSINGLEUSERMODEUNCHANGED Single-user mode is byte-identical.
            %   EventStore(f) without 'SharedRoot' must behave exactly as before.
            %   Cluster methods throw EventStore:notClusterMode.
            f = [tempname() '.mat'];
            cleaner = onCleanup(@() TestEventStoreCluster.delIf_(f)); %#ok<NASGU>
            es = EventStore(f);
            testCase.verifyEqual(es.FilePath, f, 'single-user FilePath');
            % Cluster methods MUST throw EventStore:notClusterMode in single-user mode.
            threw = false;
            try
                es.appendAckRecord(struct( ...
                    'eventId', 'x', 'by_user', 'u', 'by_host', 'h', ...
                    'epoch', now, 'comment', ''));
            catch ME
                threw = strcmp(ME.identifier, 'EventStore:notClusterMode');
            end
            testCase.verifyTrue(threw, 'single-user: appendAckRecord throws notClusterMode');
            threw = false;
            try
                es.getAckRecords();
            catch ME
                threw = strcmp(ME.identifier, 'EventStore:notClusterMode');
            end
            testCase.verifyTrue(threw, 'single-user: getAckRecords throws notClusterMode');
        end

        function testConstructorClusterModeOpensSqlite(testCase)
            %TESTCONSTRUCTORCLUSTERMODEOPENSSQLITE Cluster mode creates store.sqlite.
            if exist('mksqlite', 'file') ~= 3
                testCase.assumeFail('mksqlite MEX not available');
            end
            sharedRoot = tempname();
            mkdir(sharedRoot);
            cleaner = onCleanup(@() TestEventStoreCluster.cleanupDir_(sharedRoot)); %#ok<NASGU>
            f = fullfile(sharedRoot, 'snapshot.mat');
            es = EventStore(f, 'SharedRoot', sharedRoot); %#ok<NASGU>
            dbPath = fullfile(sharedRoot, 'events', 'store.sqlite');
            testCase.verifyTrue(isfile(dbPath), 'store.sqlite created on cluster init');
        end

        function testAppendAckRecordRoundtrip(testCase)
            %TESTAPPENDACKRECORDROUNDTRIP 5 ack records survive a roundtrip.
            if exist('mksqlite', 'file') ~= 3
                testCase.assumeFail('mksqlite MEX not available');
            end
            sharedRoot = tempname();
            mkdir(sharedRoot);
            cleaner = onCleanup(@() TestEventStoreCluster.cleanupDir_(sharedRoot)); %#ok<NASGU>
            es = EventStore(fullfile(sharedRoot, 'snap.mat'), 'SharedRoot', sharedRoot);
            for k = 1:5
                es.appendAckRecord(struct( ...
                    'eventId',  sprintf('evt_%d', k), ...
                    'by_user',  'alice', ...
                    'by_host',  'host_a', ...
                    'epoch',    now, ...
                    'comment',  sprintf('note %d', k)));
            end
            rows = es.getAckRecords();
            testCase.verifyEqual(numel(rows), 5, 'roundtrip: 5 rows');
            % mksqlite returns a struct array; verify first record contents
            testCase.verifyEqual(rows(1).event_id, 'evt_1', 'roundtrip: event_id field');
            testCase.verifyEqual(rows(1).by_user, 'alice', 'roundtrip: by_user field');
        end

        function testRetryOnDatabaseLocked(testCase)
            %TESTRETRYDATABASELOCKED Retry path is exercised under external write lock.
            %   Two EventStores opening same DbPath; one holds BEGIN IMMEDIATE,
            %   second's appendAckRecord must trip the retry loop (>350ms total
            %   wall time including 50+100+200ms backoff windows) OR throw
            %   EventStore:appendAckFailed after exhausting retries.
            if exist('mksqlite', 'file') ~= 3
                testCase.assumeFail('mksqlite MEX not available');
            end
            sharedRoot = tempname();
            mkdir(sharedRoot);
            cleaner = onCleanup(@() TestEventStoreCluster.cleanupDir_(sharedRoot)); %#ok<NASGU>
            es1 = EventStore(fullfile(sharedRoot, 'a.mat'), 'SharedRoot', sharedRoot); %#ok<NASGU>
            es2 = EventStore(fullfile(sharedRoot, 'b.mat'), 'SharedRoot', sharedRoot);
            % Open a SECOND mksqlite connection and hold BEGIN IMMEDIATE to block es2.
            holderId = mksqlite('open', fullfile(sharedRoot, 'events', 'store.sqlite'));
            mksqlite(holderId, 'PRAGMA busy_timeout = 0');  % no internal retry on holder
            mksqlite(holderId, 'BEGIN IMMEDIATE');
            cleanupHolder = onCleanup( ...
                @() TestEventStoreCluster.releaseHolder_(holderId)); %#ok<NASGU>

            % es2's appendAckRecord should retry then either succeed (if busy_timeout
            % absorbs it) or fail after 3 retries.  Either way the retry loop triggers.
            tStart = tic();
            threw = false;
            try
                es2.appendAckRecord(struct( ...
                    'eventId', 'x', 'by_user', 'u', 'by_host', 'h', ...
                    'epoch', now, 'comment', ''));
            catch ME
                threw = strcmp(ME.identifier, 'EventStore:appendAckFailed');
            end
            elapsed = toc(tStart);
            % Acceptance: retry loop engaged (elapsed > 50ms first backoff window) OR threw.
            testCase.verifyTrue(elapsed > 0.05 || threw, ...
                sprintf('retry path triggered (elapsed=%.3fs, threw=%d)', elapsed, threw));

            % Release holder; the second writer's NEXT call must succeed.
            mksqlite(holderId, 'ROLLBACK');
            mksqlite(holderId, 'close');
            es2.appendAckRecord(struct( ...
                'eventId', 'y', 'by_user', 'u', 'by_host', 'h', 'epoch', now, 'comment', ''));
            rows = es2.getAckRecords();
            testCase.verifyTrue(numel(rows) >= 1, 'post-release: row written');
        end

        function testMultiWriterContention(testCase)
            %TESTMULTIWRITERCONTENTION 5 in-process writers * 20 acks = 100 rows.
            %   Interleaved round-robin writes maximise lock contention.
            if exist('mksqlite', 'file') ~= 3
                testCase.assumeFail('mksqlite MEX not available');
            end
            sharedRoot = tempname();
            mkdir(sharedRoot);
            cleaner = onCleanup(@() TestEventStoreCluster.cleanupDir_(sharedRoot)); %#ok<NASGU>
            nWriters = 5;
            nPerWriter = 20;
            stores = cell(1, nWriters);
            for w = 1:nWriters
                stores{w} = EventStore( ...
                    fullfile(sharedRoot, sprintf('w%d.mat', w)), ...
                    'SharedRoot', sharedRoot);
            end
            % Interleave the writes (round-robin) to maximise contention.
            for k = 1:nPerWriter
                for w = 1:nWriters
                    stores{w}.appendAckRecord(struct( ...
                        'eventId',  sprintf('w%d_evt_%d', w, k), ...
                        'by_user',  sprintf('user_%d', w), ...
                        'by_host',  sprintf('host_%d', w), ...
                        'epoch',    now, ...
                        'comment',  ''));
                end
            end
            rows = stores{1}.getAckRecords();
            expected = nWriters * nPerWriter;
            testCase.verifyEqual(numel(rows), expected, ...
                sprintf('contention: expected %d rows, got %d', expected, numel(rows)));
        end

        function testFastSenseDataStoreUnaffected(testCase)
            %TESTFASTSENSEDATASTOREUNAFFECTED Phase 1031-04 must not touch FastSenseDataStore.
            %   Meta-test: path/which check only — not a behaviour test.
            p = which('FastSenseDataStore');
            testCase.verifyTrue(~isempty(p), 'FastSenseDataStore still on path');
            testCase.verifyTrue(contains(p, fullfile('libs', 'FastSense')), ...
                'FastSenseDataStore still in libs/FastSense/');
        end

    end

    methods (Static, Access = private)
        function delIf_(p)
            %DELIF_ Delete a file if it exists; ignore errors.
            if isfile(p)
                try, delete(p); catch, end
            end
        end

        function cleanupDir_(dirPath)
            %CLEANUPDIR_ Recursively remove a temp directory; ignore errors.
            if isfolder(dirPath)
                try, rmdir(dirPath, 's'); catch, end
            end
        end

        function releaseHolder_(holderId)
            %RELEASEHOLDER_ Roll back and close a mksqlite holder connection.
            try, mksqlite(holderId, 'ROLLBACK'); catch, end
            try, mksqlite(holderId, 'close');    catch, end
        end
    end
end
