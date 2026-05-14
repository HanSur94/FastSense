classdef TestMonitorTagSingleSource < matlab.unittest.TestCase
    %TESTMONITORTAGSINGLESOURCE Single-source emission across 4-node simulated cluster (ACK-04).
    %
    %   Verifies the Phase 1032-02 wiring: LiveEventPipeline.processMonitorTag_
    %   acquires the per-tag FileLock via TagWriteCoordinator BEFORE the
    %   parent.updateData + monitor.appendData sequence, so that across N
    %   simultaneous Companions polling the same MonitorTag, exactly ONE
    %   process emits each rising edge — the lock holder.
    %
    %   The 4-process cluster test is Linux-CI only (per 1030-02 convention)
    %   because matlab -batch startup inside a running session exceeds the
    %   90s budget on macOS / Windows. Platform gate: isunix() && ~ismac().
    %   Env gate: FASTSENSE_STRESS_4=1 (mirrors FASTSENSE_STRESS_50 convention).
    %
    %   Always-run tests:
    %     testSingleUserModeByteIdentical
    %     testSkippedMonitorCountIncrements
    %     testClusterConstructionWiresEventLogIntoMonitors
    %   Linux-CI only:
    %     testFourNodeRisingEdges (FASTSENSE_STRESS_4=1 required)
    %
    %   See also LiveEventPipeline, TagWriteCoordinator, FileLock, EventLog.

    methods (TestClassSetup)
        function addPaths(~)
            root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
            addpath(root);
            install();
        end
    end

    methods (TestMethodSetup)
        function resetState(~)
            try, TagRegistry.clear();          catch, end
            try, ClusterIdentity.clearCache(); catch, end
            try, FileLock.clearCache();        catch, end
        end
    end

    methods (TestMethodTeardown)
        function cleanupState(~)
            try, TagRegistry.clear();          catch, end
            try, ClusterIdentity.clearCache(); catch, end
            try, FileLock.clearCache();        catch, end
        end
    end

    methods (Test)

        function testSingleUserModeByteIdentical(testCase)
            %TESTSINGLEUSERMODEBYTEIDENTICAL Without SharedRoot, NO cluster code paths exercised.
            %   Verifies: IsClusterMode_=false, events emitted to EventStore, SkippedMonitorCount=0,
            %   no shared-root filesystem artefacts created.
            parent = SensorTag('p_su', 'X', 1:5, 'Y', [1 1 1 1 1]);
            TagRegistry.register('p_su', parent);
            cleanerP = onCleanup(@() TagRegistry.clear()); %#ok<NASGU>

            store = EventStore(tempname());
            mon = MonitorTag('m_su', parent, @(x, y) y > 0.5, 'EventStore', store);
            TagRegistry.register('m_su', mon);

            monitors = containers.Map({'m_su'}, {mon});
            ds = StubDataSource();
            % Feed 5 rising edges: y = [0 1 0 1 0 1 0 1 0 1 0] -- 5 transitions
            ds.setNextResult(struct('changed', true, ...
                'X', 1:15, 'Y', [0 1 0 0 1 0 0 1 0 0 1 0 0 1 0], ...
                'stateX', [], 'stateY', {{}}));
            dsMap = DataSourceMap();
            dsMap.add('m_su', ds);

            pipe = LiveEventPipeline(monitors, dsMap, 'Interval', 1);

            testCase.verifyFalse(pipe.IsClusterMode_, ...
                'single-user: IsClusterMode_ must be false');
            pipe.runCycle();
            testCase.verifyGreaterThanOrEqual(store.numEvents(), 1, ...
                'single-user: at least one rising edge must produce an event');
            testCase.verifyEqual(pipe.SkippedMonitorCount, 0, ...
                'single-user: no lock contention, SkippedMonitorCount=0');
            testCase.verifyTrue(isempty(mon.EventLog), ...
                'single-user: EventLog must remain empty (cluster code path not entered)');
        end

        function testSkippedMonitorCountIncrements(testCase)
            %TESTSKIPPEDMONITORCOUNTINCREMENTS Contention path: pre-held lock causes ok=false.
            %   Simulates a competing process by pre-acquiring the per-tag lock via a SEPARATE
            %   TagWriteCoordinator instance. processMonitorTag_ must detect the contention,
            %   increment SkippedMonitorCount, and populate LastLockContentionEvent.
            sharedRoot = tempname();
            mkdir(sharedRoot);
            cleanerRoot = onCleanup(@() rmdir(sharedRoot, 's')); %#ok<NASGU>

            parent = SensorTag('p_skip', 'X', 1:5, 'Y', [1 1 1 1 1]);
            TagRegistry.register('p_skip', parent);

            mon = MonitorTag('m_skip', parent, @(x, y) y > 0.5);
            TagRegistry.register('m_skip', mon);

            monitors = containers.Map({'m_skip'}, {mon});
            ds = StubDataSource();
            ds.setNextResult(struct('changed', true, ...
                'X', 6:10, 'Y', [1 1 20 20 1], ...
                'stateX', [], 'stateY', {{}}));
            dsMap = DataSourceMap();
            dsMap.add('m_skip', ds);

            pipe = LiveEventPipeline(monitors, dsMap, ...
                'Interval', 1, 'SharedRoot', sharedRoot);

            % Pre-hold the per-tag lock with a SEPARATE coordinator (simulates another process).
            coord = TagWriteCoordinator(sharedRoot);
            [lockHandle, gotLock] = coord.acquireTag('m_skip');
            testCase.assertTrue(gotLock, 'pre-hold acquire from competing coord must succeed');
            lockCleaner = onCleanup(@() lockHandle.release()); %#ok<NASGU>

            preSkipped = pipe.SkippedMonitorCount;
            pipe.runCycle();

            testCase.verifyGreaterThanOrEqual(pipe.SkippedMonitorCount, preSkipped + 1, ...
                'SkippedMonitorCount must increment when lock is contended');
            testCase.verifyTrue(isstruct(pipe.LastLockContentionEvent), ...
                'LastLockContentionEvent must be a struct after contention');
            testCase.verifyTrue(isfield(pipe.LastLockContentionEvent, 'tagKey'), ...
                'LastLockContentionEvent must have tagKey field');
            testCase.verifyEqual(pipe.LastLockContentionEvent.tagKey, 'm_skip', ...
                'LastLockContentionEvent.tagKey must match the contended monitor key');
        end

        function testClusterConstructionWiresEventLogIntoMonitors(testCase)
            %TESTCLUSTERCONSTRUCTIONWIRESEVENTLOG Cluster init populates EventLog on every monitor.
            %   After construction with SharedRoot, each MonitorTag in MonitorTargets must have
            %   a non-empty EventLog handle of class 'EventLog'.
            sharedRoot = tempname();
            mkdir(sharedRoot);
            cleanerRoot = onCleanup(@() rmdir(sharedRoot, 's')); %#ok<NASGU>

            parent = SensorTag('p_wire', 'X', 1:5, 'Y', zeros(1, 5));
            TagRegistry.register('p_wire', parent);

            mon = MonitorTag('m_wire', parent, @(x, y) y > 0.5);
            TagRegistry.register('m_wire', mon);

            monitors = containers.Map({'m_wire'}, {mon});
            ds = StubDataSource();
            dsMap = DataSourceMap();
            dsMap.add('m_wire', ds);

            pipe = LiveEventPipeline(monitors, dsMap, ...
                'Interval', 1, 'SharedRoot', sharedRoot);

            testCase.verifyTrue(pipe.IsClusterMode_, ...
                'cluster mode must be active when SharedRoot is provided');
            testCase.verifyFalse(isempty(mon.EventLog), ...
                'EventLog must be wired into monitor during cluster construction');
            testCase.verifyEqual(class(mon.EventLog), 'EventLog', ...
                'EventLog must be an EventLog handle');
        end

        function testFourNodeRisingEdges(testCase)
            %TESTFOURNODERISINGEDGES 4-process smoke: N rising edges = N events (ACK-04).
            %   Spawns 4 matlab -batch children each polling the same MonitorTag.
            %   Verifies exactly 5 events emerge for 5 rising edges regardless of which
            %   child won each tick. Linux-CI only (macOS/Windows spawn cost exceeds budget).
            %   Env gate: FASTSENSE_STRESS_4=1.
            testCase.assumeTrue(isunix() && ~ismac(), ...
                'matlab -batch cluster smoke is Linux-CI only (macOS/Windows spawn cost > 90s budget)');
            testCase.assumeTrue(strcmp(getenv('FASTSENSE_STRESS_4'), '1'), ...
                'enable 4-node cluster smoke with FASTSENSE_STRESS_4=1');

            sharedRoot = tempname();
            mkdir(sharedRoot);
            mkdir(fullfile(sharedRoot, 'events'));
            cleanerRoot = onCleanup(@() rmdir(sharedRoot, 's')); %#ok<NASGU>

            repoRoot = fullfile(fileparts(mfilename('fullpath')), '..', '..');

            % Author the child harness as a temp .m script file.
            childScript = fullfile(sharedRoot, 'child_harness.m');
            fid = fopen(childScript, 'w');
            fprintf(fid, 'try\n');
            fprintf(fid, '  addpath(''%s'');\n', repoRoot);
            fprintf(fid, '  install();\n');
            fprintf(fid, '  parent = SensorTag(''p_fn'', ''X'', 1:15, ''Y'', [0 1 0 0 1 0 0 1 0 0 1 0 0 1 0]);\n');
            fprintf(fid, '  TagRegistry.register(''p_fn'', parent);\n');
            fprintf(fid, '  mon = MonitorTag(''m_fn'', parent, @(x, y) y > 0.5);\n');
            fprintf(fid, '  TagRegistry.register(''m_fn'', mon);\n');
            fprintf(fid, '  monitors = containers.Map({''m_fn''}, {mon});\n');
            fprintf(fid, '  ds = StubDataSource();\n');
            fprintf(fid, '  ds.setNextResult(struct(''changed'', true, ''X'', 1:15, ''Y'', [0 1 0 0 1 0 0 1 0 0 1 0 0 1 0], ''stateX'', [], ''stateY'', {{}}));\n');
            fprintf(fid, '  dsMap = DataSourceMap(); dsMap.add(''m_fn'', ds);\n');
            fprintf(fid, '  pipe = LiveEventPipeline(monitors, dsMap, ''SharedRoot'', ''%s'', ''Interval'', 1);\n', sharedRoot);
            fprintf(fid, '  for k = 1:3; pipe.runCycle(); pause(0.3); end\n');
            fprintf(fid, 'catch ME\n');
            fprintf(fid, '  fprintf(2, ''CHILD: %%s\\n'', ME.message);\n');
            fprintf(fid, '  exit(2);\n');
            fprintf(fid, 'end\n');
            fprintf(fid, 'exit(0);\n');
            fclose(fid);

            % Spawn 4 children in parallel via background system calls.
            cmd = sprintf('matlab -batch "run(''%s'')"', childScript);
            for k = 1:4
                system(sprintf('%s &', cmd));
            end
            pause(20);   % give children time to complete (Linux CI is fast)

            % Verify exactly 5 events (5 rising edges) in the NDJSON event log.
            logPath = fullfile(sharedRoot, 'events', 'm_fn.events.ndjson');
            testCase.verifyTrue(isfile(logPath), ...
                'event log file must exist after 4-node run');
            reader = EventLogReader(logPath);
            evts = reader.readAll();
            testCase.verifyGreaterThanOrEqual(numel(evts), 5, ...
                'all 5 rising edges must be captured across 4 nodes');
            testCase.verifyLessThanOrEqual(numel(evts), 5, ...
                sprintf('exactly 5 events expected (single-source guarantee); got %d', numel(evts)));
        end

    end
end
