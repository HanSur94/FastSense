classdef TestMonitorTagPersistence < matlab.unittest.TestCase
    %TESTMONITORTAGPERSISTENCE MONITOR-09 opt-in disk persistence tests for MonitorTag (Phase 1007-02).
    %   Covers the 6 persistence scenarios from the Plan 02 behavior spec:
    %     1. testPersistDefaultIsFalse               — Persist=false default + empty DataStore (Pitfall 2)
    %     2. testPersistFalseNoDataStoreWrites       — Persist=false with DataStore bound -> ZERO SQLite writes
    %     3. testPersistTrueWritesOnGetXY            — Persist=true + DataStore -> cached (X,Y) + staleness quad
    %     4. testPersistRoundTripAcrossSessions      — in-process m2 same Key -> loads cached; recomputeCount_ == 0
    %     5. testPersistStaleAfterParentMutation     — parent length changes -> quad mismatch -> recompute runs
    %     6. testStoreMonitorLoadMonitorClearMonitor — low-level FastSenseDataStore trio + schema
    %
    %   Plus grep-gate + Pitfall-2 structural assertions (embedded as Test methods):
    %     - Persist / DataStore properties present on MonitorTag.m
    %     - storeMonitor / loadMonitor / clearMonitor / CREATE TABLE monitors on FastSenseDataStore.m
    %     - every storeMonitor call in MonitorTag.m sits inside an `if obj.Persist` branch
    %
    %   Pitfall 2 opt-in gate: Persist=false default means a MonitorTag bound
    %   to a DataStore must NEVER write to SQLite. Any storeMonitor call site
    %   in MonitorTag.m MUST be guarded by `if obj.Persist` within 5 lines.
    %
    %   See also MonitorTag, FastSenseDataStore, TestMonitorTagStreaming.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            addpath(repo);
            install();
            addpath(fullfile(repo, 'tests', 'suite'));
        end
    end

    methods (TestMethodSetup)
        function resetRegistry(testCase) %#ok<MANU>
            TagRegistry.clear();
        end
    end

    methods (TestMethodTeardown)
        function teardownRegistry(testCase) %#ok<MANU>
            TagRegistry.clear();
        end
    end

    methods (Test)

        % ---- Scenario 1: default Persist=false, empty DataStore ----

        function testPersistDefaultIsFalse(testCase)
            parent = SensorTag('p', 'X', 1:10, 'Y', ones(1, 10));
            m = MonitorTag('m', parent, @(x, y) y > 5);

            testCase.verifyEqual(m.Persist, false, ...
                'Scenario 1: default Persist must be false (Pitfall 2)');
            testCase.verifyEmpty(m.DataStore, ...
                'Scenario 1: default DataStore must be empty');
        end

        % ---- Scenario 2: Persist=false + bound DataStore writes nothing ----

        function testPersistFalseNoDataStoreWrites(testCase)
            parent = SensorTag('p', 'X', 1:10, 'Y', ones(1, 10));
            ds = FastSenseDataStore(1:10, ones(1, 10));
            cleanup = onCleanup(@() ds.cleanup());

            m = MonitorTag('m', parent, @(x, y) y > 0.5, ...
                'DataStore', ds, 'Persist', false);
            [~, ~] = m.getXY();

            [X, ~, ~] = ds.loadMonitor('m');
            testCase.verifyEmpty(X, ...
                'Scenario 2: Persist=false with DataStore bound must NOT write (Pitfall 2)');
        end

        % ---- Scenario 3: Persist=true writes on getXY ----

        function testPersistTrueWritesOnGetXY(testCase)
            parent = SensorTag('p', 'X', 1:10, 'Y', ones(1, 10));
            ds = FastSenseDataStore(1:10, ones(1, 10));
            cleanup = onCleanup(@() ds.cleanup());

            m = MonitorTag('m', parent, @(x, y) y > 0.5, ...
                'DataStore', ds, 'Persist', true);
            [~, ~] = m.getXY();

            [X, Y, meta] = ds.loadMonitor('m');
            testCase.verifyNumElements(X, 10, ...
                'Scenario 3: persisted X must have 10 points');
            testCase.verifyNumElements(Y, 10, ...
                'Scenario 3: persisted Y must have 10 points');
            testCase.verifyEqual(double(meta.num_points), 10, ...
                'Scenario 3: quad num_points stamped at write');
            testCase.verifyEqual(meta.parent_xmin, 1, ...
                'Scenario 3: quad parent_xmin stamped at write');
            testCase.verifyEqual(meta.parent_xmax, 10, ...
                'Scenario 3: quad parent_xmax stamped at write');
            testCase.verifyTrue(strcmp(char(meta.parent_key), 'p'), ...
                'Scenario 3: quad parent_key stamped at write');
        end

        % ---- Scenario 4: round-trip across in-process sessions ----

        function testPersistRoundTripAcrossSessions(testCase)
            parent = SensorTag('p', 'X', 1:10, 'Y', ones(1, 10) * 10);
            ds = FastSenseDataStore(1:10, ones(1, 10));
            cleanup = onCleanup(@() ds.cleanup());

            m1 = MonitorTag('m_rt', parent, @(x, y) y > 5, ...
                'DataStore', ds, 'Persist', true);
            [~, y1] = m1.getXY();

            % "Second session" simulation: new MonitorTag, same key/parent/ds.
            TagRegistry.unregister(m1.Key);

            m2 = MonitorTag('m_rt', parent, @(x, y) y > 5, ...
                'DataStore', ds, 'Persist', true);
            [~, y2] = m2.getXY();

            testCase.verifyEqual(m2.recomputeCount_, 0, ...
                'Scenario 4: m2 must skip recompute — loaded from disk');
            testCase.verifyEqual(y2, y1, ...
                'Scenario 4: m2 cached Y must equal m1 cached Y');
        end

        % ---- Scenario 5: stale detection via quad mismatch ----

        function testPersistStaleAfterParentMutation(testCase)
            parent1 = SensorTag('p', 'X', 1:10, 'Y', ones(1, 10) * 10);
            ds = FastSenseDataStore(1:10, ones(1, 10));
            cleanup = onCleanup(@() ds.cleanup());

            m1 = MonitorTag('m_stale', parent1, @(x, y) y > 5, ...
                'DataStore', ds, 'Persist', true);
            [~, ~] = m1.getXY();

            % "Second session" — same Key but parent now has DIFFERENT length.
            TagRegistry.unregister(m1.Key);
            TagRegistry.unregister(parent1.Key);
            parent2 = SensorTag('p', 'X', 1:15, 'Y', ones(1, 15) * 10);

            m2 = MonitorTag('m_stale', parent2, @(x, y) y > 5, ...
                'DataStore', ds, 'Persist', true);
            [~, y2] = m2.getXY();

            testCase.verifyEqual(m2.recomputeCount_, 1, ...
                'Scenario 5: quad mismatch -> recompute must run');
            testCase.verifyEqual(numel(y2), 15, ...
                'Scenario 5: recomputed Y must match new parent length (15)');
        end

        % ---- Scenario 6: low-level FastSenseDataStore trio ----

        function testStoreMonitorLoadMonitorClearMonitor(testCase)
            ds = FastSenseDataStore(1:10, ones(1, 10));
            cleanup = onCleanup(@() ds.cleanup());

            ds.storeMonitor('key1', [1 2 3], [0 1 0], 'parentKey', 3, 1, 3);

            [X, Y, meta] = ds.loadMonitor('key1');
            testCase.verifyEqual(X, [1 2 3], ...
                'Scenario 6: X round-trip');
            testCase.verifyEqual(Y, [0 1 0], ...
                'Scenario 6: Y round-trip');
            testCase.verifyEqual(double(meta.num_points), 3, ...
                'Scenario 6: num_points round-trip');
            testCase.verifyEqual(meta.parent_xmin, 1, ...
                'Scenario 6: parent_xmin round-trip');
            testCase.verifyEqual(meta.parent_xmax, 3, ...
                'Scenario 6: parent_xmax round-trip');

            ds.clearMonitor('key1');
            [X2, ~, ~] = ds.loadMonitor('key1');
            testCase.verifyEmpty(X2, ...
                'Scenario 6: clearMonitor must delete the row');
        end

        % ---- Grep gate: MonitorTag.m has Persist + DataStore properties ----

        function testMonitorTagHasPersistProperties(testCase)
            src = fileread(monitor_tag_path_());
            testCase.verifyTrue( ...
                ~isempty(regexp(src, 'Persist\s*=\s*false', 'once')), ...
                'Grep gate: MonitorTag.m must declare `Persist = false` (opt-in default)');
            testCase.verifyTrue( ...
                ~isempty(regexp(src, 'DataStore\s*=\s*\[\]', 'once')), ...
                'Grep gate: MonitorTag.m must declare `DataStore = []` (default empty)');
        end

        % ---- Grep gate: FastSenseDataStore.m has monitors API + schema ----

        function testFastSenseDataStoreHasMonitorAPI(testCase)
            src = fileread(data_store_path_());
            testCase.verifyEqual( ...
                numel(regexp(src, 'function\s+storeMonitor', 'match')), 1, ...
                'Grep gate: FastSenseDataStore.m must declare `function storeMonitor` exactly once');
            testCase.verifyEqual( ...
                numel(regexp(src, 'function\s+\[.*\]\s*=\s*loadMonitor', 'match')), 1, ...
                'Grep gate: FastSenseDataStore.m must declare loadMonitor with multi-output signature');
            testCase.verifyEqual( ...
                numel(regexp(src, 'function\s+clearMonitor', 'match')), 1, ...
                'Grep gate: FastSenseDataStore.m must declare `function clearMonitor` exactly once');
            testCase.verifyEqual( ...
                numel(regexp(src, 'CREATE TABLE monitors', 'match')), 1, ...
                'Grep gate: FastSenseDataStore.m must CREATE the monitors table in initSqlite');
        end

        % ---- Pitfall 2 structural: every storeMonitor is guarded ----

        function testPitfall2StructuralGate(testCase)
            src = fileread(monitor_tag_path_());
            lines = strsplit(src, char(10));
            nStore = 0;
            nGuarded = 0;
            for i = 1:numel(lines)
                if ~isempty(regexp(lines{i}, 'storeMonitor\s*\(', 'once'))
                    nStore = nStore + 1;
                    lo = max(1, i - 5);
                    window = strjoin(lines(lo:i-1), char(10));
                    if ~isempty(regexp(window, 'if\s+.*obj\.Persist', 'once'))
                        nGuarded = nGuarded + 1;
                    end
                end
            end
            testCase.verifyGreaterThanOrEqual(nStore, 1, ...
                'Pitfall 2: at least one storeMonitor call expected in MonitorTag.m');
            testCase.verifyEqual(nStore, nGuarded, ...
                sprintf('Pitfall 2 FAIL: %d storeMonitor calls, %d guarded by if obj.Persist', ...
                nStore, nGuarded));
        end

    end
end

function p = monitor_tag_path_()
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(fileparts(here));
    p    = fullfile(repo, 'libs', 'SensorThreshold', 'MonitorTag.m');
end

function p = data_store_path_()
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(fileparts(here));
    p    = fullfile(repo, 'libs', 'FastSense', 'FastSenseDataStore.m');
end
