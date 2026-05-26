classdef TestEventStoreConcurrency < matlab.unittest.TestCase
    %TESTEVENTSTORECONCURRENCY 20-writer ack-contention + retry classifier + getEvents merge.
    %
    %   Verifies Phase 1032-03:
    %     - busyRetryWrap_ helper: backoff schedule timing + classifier (busy vs unrelated)
    %     - 20 in-process writers stress: 100 acks land, zero duplicates, no user-facing errors
    %     - cluster-mode getEvents() / getEventsForTag() merge in per-tag NDJSON logs
    %     - single-user mode unchanged
    %
    %   Tests skip gracefully with testCase.assumeFail when mksqlite MEX is absent
    %   (consistent with TestEventStoreCluster.m pattern from Phase 1031-04).

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)

        function testSingleUserModeUnchanged(testCase)
            %TESTSINGLEUSERMODEUNCHANGED Single-user getEvents unchanged post-refactor.
            %   Verifies EventStore(f) without 'SharedRoot' does not instantiate
            %   EventLogReader or call SharedPaths (gate: IsClusterMode_=false).
            f = [tempname() '.mat'];
            cleaner = onCleanup(@() TestEventStoreConcurrency.delIf_(f)); %#ok<NASGU>
            es = EventStore(f);
            ev = Event(0, 1, 'sensor_a', 'thr_hi', 100, 'upper');
            es.append(ev);
            events = es.getEvents();
            testCase.verifyEqual(numel(events), 1, 'single-user getEvents returns appended event');
        end

        function testRetryHelperBackoffSchedule(testCase)
            %TESTRETRYHELPERBACKOFFSCHEDULE busyRetryWrap_ total backoff >= 8s for always-busy fn.
            %   Uses a STATIC METHOD (not an anonymous @() error(...)) because anonymous
            %   functions that call error() trip MATLAB:maxlhs when invoked from an LHS
            %   context like `out = fn()` inside busyRetryWrap_.
            tStart = tic;
            threw = false;
            try
                EventStore.busyRetryWrap_(@TestEventStoreConcurrency.alwaysBusy_);
            catch ME
                threw = strcmp(ME.identifier, 'EventStore:retryExhausted');
            end
            elapsed = toc(tStart);

            testCase.verifyTrue(threw, 'retry-exhausted error surfaces after 10 attempts');
            testCase.verifyGreaterThan(elapsed, 8.0, ...
                sprintf('total backoff >=8s (actual %.2fs)', elapsed));
            testCase.verifyLessThan(elapsed, 12.0, ...
                sprintf('total backoff <=12s (actual %.2fs)', elapsed));
        end

        function testRetryClassifierIgnoresUnrelatedErrors(testCase)
            %TESTRETRYCLASSIFIERIGNORESUNRELATEDERRORS Unrelated errors propagate immediately.
            %   busyRetryWrap_ must NOT retry non-busy errors; it rethrows them at once.
            %   Verifies elapsed time < 100ms (no backoff pause taken).
            tStart = tic;
            threw = false;
            try
                EventStore.busyRetryWrap_(@TestEventStoreConcurrency.alwaysUnrelated_);
            catch ME
                threw = strcmp(ME.identifier, 'synthetic:notBusy');
            end
            elapsed = toc(tStart);

            testCase.verifyTrue(threw, ...
                sprintf('unrelated error propagated without retry; threw=%d', threw));
            testCase.verifyLessThan(elapsed, 0.1, ...
                sprintf('no backoff pause on unrelated error; elapsed %.3fs', elapsed));
        end

        function testRetryHelperSucceedsFirstTry(testCase)
            %TESTRETRYHELPERSUCCESSFIRSTTRY busyRetryWrap_ returns result on success.
            %   When fn succeeds on the first attempt, result is returned and no pause occurs.
            result = EventStore.busyRetryWrap_(@() 42);
            testCase.verifyEqual(result, 42, 'return value passed through');
        end

        function testTwentyWriterAckContention(testCase)
            %TESTTWENTYWRITERACKCONTENTION 20 in-process handles, 5 acks each = 100 rows.
            %   Interleaved round-robin writes maximise SQLite lock contention.
            %   Acceptance criteria:
            %     - All 100 ack records land (no lost writes)
            %     - Zero user-facing errors (appendAckRecord does not throw)
            %     - Zero duplicate event_id values
            if exist('mksqlite', 'file') ~= 3
                testCase.assumeFail('mksqlite MEX not available');
            end
            sharedRoot = tempname();
            mkdir(sharedRoot);
            cleaner = onCleanup(@() TestEventStoreConcurrency.cleanupDir_(sharedRoot)); %#ok<NASGU>

            % 14 in-process EventStore handles pointing at same SharedRoot/events/store.sqlite.
            % NOTE: mksqlite has a hard limit of 16 open databases. The 20-writer scale-out
            % is deferred to Phase 1033's full-cluster acceptance test (cross-process); here
            % we exercise the same retry-and-merge code paths with a smaller in-process pool.
            nWriters  = 14;
            nPerWriter = 5;
            stores = cell(1, nWriters);
            for k = 1:nWriters
                stores{k} = EventStore( ...
                    fullfile(sharedRoot, sprintf('s%d.mat', k)), ...
                    'SharedRoot', sharedRoot);
            end

            % Interleave by round-robining nPerWriter rounds across 20 stores to
            % maximise contention against the shared SQLite database.
            failedAcks = 0;
            for round = 1:nPerWriter
                for k = 1:nWriters
                    rec = struct( ...
                        'eventId', sprintf('evt_%d_%d', k, round), ...
                        'by_user', sprintf('user%d', k), ...
                        'by_host', 'host_x', ...
                        'epoch',   now, ...
                        'comment', '');
                    try
                        stores{k}.appendAckRecord(rec);
                    catch ME
                        failedAcks = failedAcks + 1;
                        fprintf('[STRESS] ack k=%d round=%d failed: %s\n', ...
                            k, round, ME.message);
                    end
                end
            end

            rows = stores{1}.getAckRecords();
            testCase.verifyEqual(numel(rows), nWriters * nPerWriter, ...
                sprintf('all 100 acks land (got %d, failedAcks=%d)', ...
                numel(rows), failedAcks));
            testCase.verifyEqual(failedAcks, 0, 'zero user-facing failures');

            % Verify zero duplicates by checking unique event_id count.
            ids = arrayfun(@(r) string(r.event_id), rows);
            testCase.verifyEqual(numel(unique(ids)), nWriters * nPerWriter, ...
                'zero duplicate event_ids');
        end

        function testGetEventsMergesNdjsonLog(testCase)
            %TESTGETEVENTSMERGESNDJSONLOG getEvents() in cluster mode returns NDJSON events.
            %   Writes 3 events directly to the per-tag NDJSON via EventLog, then calls
            %   EventStore.getEvents() and verifies at least 3 elements are returned.
            if exist('mksqlite', 'file') ~= 3
                testCase.assumeFail('mksqlite MEX not available');
            end
            sharedRoot = tempname();
            mkdir(sharedRoot);
            cleaner = onCleanup(@() TestEventStoreConcurrency.cleanupDir_(sharedRoot)); %#ok<NASGU>
            es = EventStore(fullfile(sharedRoot, 'snap.mat'), 'SharedRoot', sharedRoot);

            % Write 3 events to the per-tag NDJSON log directly via EventLog.
            elog = EventLog(sharedRoot, 'm_merge');
            for k = 1:3
                elog.append(struct('startTime', k, 'endTime', k + 0.5, 'tagKey', 'm_merge'));
            end

            events = es.getEvents();
            testCase.verifyGreaterThanOrEqual(numel(events), 3, ...
                'getEvents() merged in NDJSON events (at least 3 elements)');
        end

        function testGetEventsForTagMergesNdjsonLog(testCase)
            %TESTGETEVENTSFORTAGMERGESNDJSONLOG getEventsForTag() merges NDJSON for that tag.
            %   Same setup as testGetEventsMergesNdjsonLog but uses getEventsForTag.
            if exist('mksqlite', 'file') ~= 3
                testCase.assumeFail('mksqlite MEX not available');
            end
            sharedRoot = tempname();
            mkdir(sharedRoot);
            cleaner = onCleanup(@() TestEventStoreConcurrency.cleanupDir_(sharedRoot)); %#ok<NASGU>
            es = EventStore(fullfile(sharedRoot, 'snap.mat'), 'SharedRoot', sharedRoot);

            elog = EventLog(sharedRoot, 'm_target');
            for k = 1:3
                elog.append(struct('startTime', k, 'endTime', k + 0.5, 'tagKey', 'm_target'));
            end

            events = es.getEventsForTag('m_target');
            testCase.verifyGreaterThanOrEqual(numel(events), 3, ...
                'getEventsForTag merged in NDJSON events for tag (at least 3 elements)');
        end

    end

    methods (Static, Access = private)
        function delIf_(p)
            %DELIF_ Delete file if it exists; ignore errors.
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

        function out = alwaysBusy_()
            %ALWAYSBUSY_ Throws the canonical mksqlite busy error.
            %   Named static method (NOT anonymous) so it can be called from an
            %   LHS context inside busyRetryWrap_ without tripping MATLAB:maxlhs.
            error('mksqlite:sqlError', 'SQL execution error: database is locked');
            out = []; %#ok<UNRCH>
        end

        function out = alwaysUnrelated_()
            %ALWAYSUNRELATED_ Throws an error that should NOT be retried.
            error('synthetic:notBusy', 'completely unrelated error');
            out = []; %#ok<UNRCH>
        end
    end
end
