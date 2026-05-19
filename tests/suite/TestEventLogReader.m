classdef TestEventLogReader < matlab.unittest.TestCase
%TESTEVENTLOGREADER Class-based test suite for EventLogReader.
%
%   Tests cover:
%     1. readAll on missing file -> []
%     2. readAll on valid 3-event log -> 3 events, SkippedLineCount == 0
%     3. tail(2) returns last 2 events with correct payload
%     4. Corrupt line in middle is skipped; SkippedLineCount == 1
%     5. mtime cache: second read with no changes -> LastReadCacheHit == true
%     6. mtime cache invalidates after file is updated
%     7. torn-rename recovery: <0.1% reader errors with Retries=3
%
%   DESIGN NOTE: Tests in makeReaderWith_ use EventLog.append() to generate
%   fixtures. If EventLog.m is absent (Plan 02 running concurrently in a
%   different worktree), the fixture helper will fail and those tests will
%   error. The torn-rename test (testTornRenameRecovery) is fully standalone
%   and writes raw NDJSON payload without depending on EventLog.
%   Adapted from TestAtomicWriter.testTornRenameRecovery (lines 138-165).

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)

        function testReadAllOnEmptyFile(testCase)
            % File does not exist -> readAll returns [] with SkippedLineCount 0.
            missing = [tempname(), '.events.ndjson'];
            r = EventLogReader(missing);
            ev = r.readAll();
            testCase.verifyEmpty(ev, 'missing file -> []');
            testCase.verifyEqual(r.SkippedLineCount, 0, 'no skipped lines');
            testCase.verifyFalse(r.LastReadCacheHit, 'not a cache hit');
        end

        function testReadAllReturnsAllEvents(testCase)
            [r, sharedRoot] = TestEventLogReader.makeReaderWith_(3);
            testCase.addTeardown(@() TestEventLogReader.cleanup_(sharedRoot));
            ev = r.readAll();
            testCase.verifyEqual(numel(ev), 3, '3 events read back');
            testCase.verifyEqual(r.SkippedLineCount, 0, '0 skipped lines');
            testCase.verifyFalse(r.LastReadCacheHit, 'first read is a cache miss');
        end

        function testTailReturnsLastN(testCase)
            [r, sharedRoot] = TestEventLogReader.makeReaderWith_(5);
            testCase.addTeardown(@() TestEventLogReader.cleanup_(sharedRoot));
            ev = r.tail(2);
            testCase.verifyEqual(numel(ev), 2, 'tail(2) returns 2 events');
            % makeReaderWith_ writes structs with field 'i' = 1..N
            testCase.verifyEqual(ev(1).i, 4, 'second-to-last event has i==4');
            testCase.verifyEqual(ev(2).i, 5, 'last event has i==5');
        end

        function testTailFewerThanNReturnsAll(testCase)
            % tail(n) when file has fewer events returns all events.
            [r, sharedRoot] = TestEventLogReader.makeReaderWith_(2);
            testCase.addTeardown(@() TestEventLogReader.cleanup_(sharedRoot));
            ev = r.tail(10);
            testCase.verifyEqual(numel(ev), 2, 'fewer than n -> return all');
        end

        function testCorruptLineSkippedAndCounted(testCase)
            % Manually append a malformed JSON line; verify it is skipped and
            % counted but does not abort the read.  This simulates what SMB/NFS
            % line tearing would produce per Pitfall 5.
            [r, sharedRoot, logPath] = TestEventLogReader.makeReaderWith_(3);
            testCase.addTeardown(@() TestEventLogReader.cleanup_(sharedRoot));

            % Append a corrupt line that is not valid JSON.
            fid = fopen(logPath, 'a');
            testCase.verifyGreaterThan(fid, 0, 'fopen for corrupt inject');
            fwrite(fid, sprintf('{not_a_valid_json}\n'), 'char');
            fclose(fid);

            % Force mtime change (datenum granularity is ~1 second on most filesystems).
            pause(1.1);

            ev = r.readAll();
            testCase.verifyEqual(numel(ev), 3, '3 good events preserved');
            testCase.verifyEqual(r.SkippedLineCount, 1, '1 corrupt line counted');
        end

        function testMtimeCacheHit(testCase)
            % Two consecutive reads with no write between: second is a cache hit.
            [r, sharedRoot] = TestEventLogReader.makeReaderWith_(2);
            testCase.addTeardown(@() TestEventLogReader.cleanup_(sharedRoot));

            first = r.readAll();
            testCase.verifyFalse(r.LastReadCacheHit, 'first read = cache miss');

            second = r.readAll();
            testCase.verifyTrue(r.LastReadCacheHit, 'second read = cache HIT');
            testCase.verifyEqual(numel(second), numel(first), 'same event count from cache');
        end

        function testMtimeCacheInvalidates(testCase)
            % Read; wait >1 s; append a new event; read again -> cache miss + new event present.
            [r, sharedRoot] = TestEventLogReader.makeReaderWith_(2);
            testCase.addTeardown(@() TestEventLogReader.cleanup_(sharedRoot));

            first = r.readAll();
            testCase.verifyFalse(r.LastReadCacheHit, 'first read = miss');

            % Cross datenum granularity (~1 second on macOS HFS+/APFS).
            pause(1.1);

            % Append one more event via EventLog (lock-serialised path).
            el = EventLog(sharedRoot, 'k');
            ok = el.append(struct('i', 99));
            testCase.verifyTrue(ok, 'EventLog.append succeeded');

            second = r.readAll();
            testCase.verifyFalse(r.LastReadCacheHit, 'after write = cache MISS');
            testCase.verifyEqual(numel(second), numel(first) + 1, 'new event picked up');
            testCase.verifyEqual(second(end).i, 99, 'new event payload correct');
        end

        function testTornRenameRecovery(testCase)
            % Adapted from TestAtomicWriter.testTornRenameRecovery.
            % Writer in a tight temp+rename loop; reader in interleaved cycle.
            % With Retries=3 (default), reader-side errors must be <0.1% (smoke gate).
            %
            % STANDALONE: does not depend on EventLog — writes raw NDJSON directly
            % so this test passes whether or not Plan 02's EventLog is present.
            sharedRoot = tempname();
            mkdir(sharedRoot);
            testCase.addTeardown(@() TestEventLogReader.cleanup_(sharedRoot));

            eventsDir = fullfile(sharedRoot, 'events');
            mkdir(eventsDir);
            logPath = fullfile(eventsDir, 'torn.events.ndjson');

            r = EventLogReader(logPath, struct('Retries', 3, 'BackoffMs', 10));

            nCycles    = 30;
            readerErrs = 0;
            % Valid NDJSON payload: header + one event line.
            payload = sprintf('%s\n%s\n', ...
                '#FASTSENSE_EVENTLOG_V1', ...
                ndjsonEncode(struct('i', 1)));

            for k = 1:nCycles
                tempPath = sprintf('%s.tmp.%d', logPath, k);
                fid = fopen(tempPath, 'w');
                fwrite(fid, payload, 'char');
                fclose(fid);
                movefile(tempPath, logPath, 'f');

                % Interleaved read in same process — exercises the readWithRetry
                % path on any transient FS-level error.
                try
                    r.readAll();
                catch
                    readerErrs = readerErrs + 1;
                end
            end

            testCase.verifyLessThan(readerErrs, nCycles * 0.01, ...
                sprintf('reader errors %d/%d must be <1%% smoke target', readerErrs, nCycles));
        end

        function testReadAllWithStats(testCase)
            % readAllWithStats exposes parseStats.SkippedLineCount directly.
            [~, sharedRoot, logPath] = TestEventLogReader.makeReaderWith_(2);
            testCase.addTeardown(@() TestEventLogReader.cleanup_(sharedRoot));

            % Inject a corrupt line.
            fid = fopen(logPath, 'a');
            fwrite(fid, sprintf('{bad}\n'), 'char');
            fclose(fid);

            r = EventLogReader(logPath);
            [ev, ps] = r.readAllWithStats();
            testCase.verifyEqual(numel(ev), 2, '2 good events');
            testCase.verifyEqual(ps.SkippedLineCount, 1, 'parseStats.SkippedLineCount == 1');
        end

    end

    methods (Static, Access = private)

        function [r, sharedRoot, logPath] = makeReaderWith_(nEvents)
            %MAKEREADER_ Create sharedRoot, write nEvents via EventLog, return reader.
            %   Each event is a struct with field 'i' = 1..nEvents so tail tests
            %   can verify the ordering by inspecting event.i values.
            sharedRoot = tempname();
            mkdir(sharedRoot);
            el = EventLog(sharedRoot, 'k');
            for i = 1:nEvents
                ok = el.append(struct('i', i));
                if ~ok
                    pause(0.05);
                    el.append(struct('i', i));   % one retry on lock contention
                end
            end
            logPath = fullfile(sharedRoot, 'events', 'k.events.ndjson');
            r = EventLogReader(logPath);
        end

        function cleanup_(sharedRoot)
            %CLEANUP_ Remove temp directory created by a test.
            if isfolder(sharedRoot)
                try, rmdir(sharedRoot, 's'); catch, end
            end
        end

    end

end
