classdef TestEventLogConsolidator < matlab.unittest.TestCase
%TESTEVENTLOGCONSOLIDATOR Tests for libs/Concurrency/EventLogConsolidator.m
%
%   Phase 1033 Plan 02 — leader-elected NDJSON-to-snapshot consolidator.
%
%   Tests:
%     testSingleTagRoundtrip      — 3 events -> consolidate -> events.mat has 3
%     testLeaderElectionContention— pre-hold lock -> consolidate skips silently
%     testIdempotency             — consolidate twice -> same event count
%     testMultiTagMerge           — 3 tags × 2 events -> events.mat has 6
%     testEmptyEventsDirNoCrash   — no NDJSON files -> acquiredLeader=true, eventCount=0

    methods (TestClassSetup)
        function addPaths(~)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (TestMethodSetup)
        function clearLocks(~)
            %CLEARLOCKS Reset per-process lock registry between tests.
            %   Prevents lock state leakage across test methods — same pattern
            %   as TestFileLock.resetCaches (Phase 1029-03).
            FileLock.clearCache();
        end
    end

    methods (Test)

        function testSingleTagRoundtrip(testCase)
            %TESTSINGLETAGROUNDTRIP Write 3 events; consolidate; verify events.mat has 3.
            root = TestEventLogConsolidator.makeSharedRoot_(testCase);
            tagKey = 'pressure';
            % Write 3 events via EventLog (Phase 1031-02 contract).
            el = EventLog(root, tagKey);
            for i = 1:3
                ok = el.append(struct('Id', sprintf('evt_%d', i), ...
                    'tagKey', tagKey, 'value', i, 'epoch', posixtime(datetime('now', 'TimeZone', 'UTC'))));
                testCase.verifyTrue(ok, ...
                    sprintf('testSingleTagRoundtrip: EventLog.append %d failed', i));
            end
            cons = EventLogConsolidator(root);
            result = cons.consolidate();
            testCase.verifyTrue(result.acquiredLeader, ...
                'testSingleTagRoundtrip: must acquire leader on uncontended root');
            testCase.verifyEqual(result.eventCount, 3, ...
                'testSingleTagRoundtrip: snapshot must contain 3 events');
            testCase.verifyTrue(exist(result.snapshotPath, 'file') == 2, ...
                'testSingleTagRoundtrip: snapshot file must exist on disk');
            % Load and verify independently.
            loaded = load(result.snapshotPath, 'events');
            testCase.verifyEqual(numel(loaded.events), 3, ...
                'testSingleTagRoundtrip: loaded snapshot must contain 3 events');
        end

        function testLeaderElectionContention(testCase)
            %TESTLEADERELECTIONCONTENTION Pre-hold lock; consolidate skips silently.
            %   On a single-process system, holding the 'events-consolidator' key
            %   and calling consolidate() from the SAME process triggers
            %   nestedLockAcquireForbidden internally.  EventLogConsolidator
            %   catches this and converts it to a silent skip (acquiredLeader=false).
            root = TestEventLogConsolidator.makeSharedRoot_(testCase);
            % Pre-hold the consolidator lock from a separate FileLock instance.
            preheld = FileLock('events-consolidator', ...
                'LockDir', SharedPaths.locksDir(root));
            [acquired, ~] = preheld.tryAcquire('Timeout', 0);
            testCase.assumeTrue(acquired, ...
                'testLeaderElectionContention: precondition — pre-hold the lock');
            % Teardowns run LIFO: register delete first so release runs before delete.
            testCase.addTeardown(@() delete(preheld));
            testCase.addTeardown(@() preheld.release());
            % Consolidate from a separate instance — must skip silently.
            cons = EventLogConsolidator(root);
            result = cons.consolidate();
            testCase.verifyFalse(result.acquiredLeader, ...
                'testLeaderElectionContention: must NOT acquire leader when held');
            testCase.verifyEqual(result.eventCount, 0, ...
                'testLeaderElectionContention: eventCount must be 0 on contention');
        end

        function testIdempotency(testCase)
            %TESTIDEMPOTENCY Two consolidations on the same data produce the same count.
            root = TestEventLogConsolidator.makeSharedRoot_(testCase);
            el = EventLog(root, 'temp');
            for i = 1:5
                el.append(struct('Id', sprintf('idem_%d', i), ...
                    'tagKey', 'temp', 'value', i, 'epoch', posixtime(datetime('now', 'TimeZone', 'UTC'))));
            end
            cons = EventLogConsolidator(root);
            r1 = cons.consolidate();
            r2 = cons.consolidate();
            testCase.verifyTrue(r1.acquiredLeader, ...
                'testIdempotency: first call must acquire leader');
            testCase.verifyTrue(r2.acquiredLeader, ...
                'testIdempotency: second call must acquire leader');
            testCase.verifyEqual(r2.eventCount, r1.eventCount, ...
                'testIdempotency: snapshot event count must be stable across runs');
            testCase.verifyEqual(r1.eventCount, 5, ...
                'testIdempotency: first consolidation should see 5 events');
        end

        function testMultiTagMerge(testCase)
            %TESTMULTITAGMERGE 3 tags × 2 events each -> 6 events in snapshot.
            root = TestEventLogConsolidator.makeSharedRoot_(testCase);
            for tagIdx = 1:3
                tagKey = sprintf('tag_%d', tagIdx);
                el = EventLog(root, tagKey);
                for evIdx = 1:2
                    el.append(struct('Id', sprintf('%s_%d', tagKey, evIdx), ...
                        'tagKey', tagKey, 'value', evIdx, 'epoch', posixtime(datetime('now', 'TimeZone', 'UTC'))));
                end
            end
            cons = EventLogConsolidator(root);
            result = cons.consolidate();
            testCase.verifyTrue(result.acquiredLeader, ...
                'testMultiTagMerge: must acquire leader');
            testCase.verifyEqual(result.eventCount, 6, ...
                'testMultiTagMerge: 3 tags × 2 events each = 6 events');
            % Verify the snapshot file contains all 6.
            loaded = load(result.snapshotPath, 'events');
            testCase.verifyEqual(numel(loaded.events), 6, ...
                'testMultiTagMerge: loaded snapshot must contain 6 events');
        end

        function testEmptyEventsDirNoCrash(testCase)
            %TESTEMPTYEVENTSDIRNOCRASH No NDJSON files -> acquiredLeader=true, eventCount=0.
            root = TestEventLogConsolidator.makeSharedRoot_(testCase);
            cons = EventLogConsolidator(root);
            result = cons.consolidate();
            testCase.verifyTrue(result.acquiredLeader, ...
                'testEmptyEventsDirNoCrash: must acquire leader on empty root');
            testCase.verifyEqual(result.eventCount, 0, ...
                'testEmptyEventsDirNoCrash: event count must be 0');
            testCase.verifyTrue(exist(result.snapshotPath, 'file') == 2, ...
                'testEmptyEventsDirNoCrash: empty snapshot file must be written');
            % Load and verify events is empty (not an error state).
            loaded = load(result.snapshotPath, 'events');
            testCase.verifyEmpty(loaded.events, ...
                'testEmptyEventsDirNoCrash: loaded events must be empty');
        end

    end

    methods (Static, Access = private)

        function root = makeSharedRoot_(testCase)
            %MAKESHAREDROOT_ Create a temp shared root with events/ and locks/ subdirs.
            %   Registers addTeardown(rmdir) so the directory is cleaned up after each test.
            root = fullfile(tempdir(), sprintf('elc_%d', round(rand() * 1e9)));
            mkdir(root);
            mkdir(fullfile(root, 'events'));
            mkdir(fullfile(root, 'locks'));
            testCase.addTeardown(@() TestEventLogConsolidator.cleanup_(root));
        end

        function cleanup_(root)
            %CLEANUP_ Remove temp shared root directory created for a test.
            if isfolder(root)
                try
                    rmdir(root, 's');
                catch %#ok<CTCH>
                end
            end
        end

    end

end
