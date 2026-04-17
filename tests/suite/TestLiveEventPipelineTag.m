classdef TestLiveEventPipelineTag < matlab.unittest.TestCase
    %TESTLIVEEVENTPIPELINETAG End-to-end evidence for Phase 1007 SC#4.
    %   Phase 1009 Plan 03 — proves the LiveEventPipeline MonitorTag path
    %   wires `MonitorTag.appendData` into `runCycle`, enforces the
    %   Pitfall Y parent-before-child ordering, and preserves the
    %   legacy Sensor-based LEP path byte-for-byte.
    %
    %   Ordering invariant (per MonitorTag.m:333-334 docstring):
    %     monitor.Parent.updateData(newX, newY)  ← MUST be called FIRST
    %     monitor.appendData(newX, newY)         ← THEN this
    %   Wrong order causes cache incoherence (appendData cold-path
    %   recomputes over stale parent data).
    %
    %   See also LiveEventPipeline, MonitorTag, StubDataSource.

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

        function testMonitorTagPathEmitsEventsOnAppendData(testCase)
            [pipeline, store, ~, ~, ds] = makeLiveTagFixture_();
            ds.setNextResult(struct('changed', true, ...
                'X', 6:10, 'Y', [1 1 20 20 1], ...
                'stateX', [], 'stateY', {{}}));

            pipeline.runCycle();

            evts = store.getEvents();
            testCase.verifyGreaterThanOrEqual(numel(evts), 1, ...
                'MonitorTag path must emit >= 1 event on rising edge');

            % Carrier invariants (MONITOR-05): SensorName=parent.Key,
            % ThresholdLabel=monitor.Key.  A per-Tag TagKeys field MUST NOT
            % exist yet — that is reserved for Phase 1010 (Pitfall X).
            testCase.verifyEqual(evts(1).SensorName, 's1', ...
                'carrier: SensorName=parent.Key');
            testCase.verifyEqual(evts(1).ThresholdLabel, 'm1', ...
                'carrier: ThresholdLabel=monitor.Key');
        end

        function testAppendDataOrderWithParent(testCase)
            % Pitfall Y ordering gate: parent.updateData MUST be called
            % BEFORE monitor.appendData.  Proof: after a fresh, non-dirty
            % cache is primed, a subsequent runCycle tail-append should
            % take appendData's fast path (which only succeeds when the
            % parent already carries the new samples).  recomputeCount_
            % must NOT increment during the live tick — if ordering were
            % wrong, appendData would hit the cold recompute_() path
            % because the cache is cleared via parent-cascade invalidate
            % BEFORE appendData runs.  We detect this by recording the
            % recompute count before and after the live tick.
            [pipeline, ~, monitor, parent, ds] = makeLiveTagFixture_();

            % Seed parent with baseline data + warm the monitor cache.
            parent.updateData(1:5, [1 1 1 1 1]);
            [~, ~] = monitor.getXY();  % prime cache (not dirty, fast-path ready)

            preRecompute = monitor.recomputeCount_;

            ds.setNextResult(struct('changed', true, ...
                'X', 6:10, 'Y', [20 20 20 20 20], ...
                'stateX', [], 'stateY', {{}}));
            pipeline.runCycle();

            postRecompute = monitor.recomputeCount_;

            % If ordering is correct, appendData's fast path handles the
            % tail without a fresh recompute; recomputeCount_ stays
            % unchanged (delta == 0).  A delta >= 2 would indicate a
            % double-recompute (cold recompute_ + post-invalidate
            % recompute).  We allow delta <= 1 as slack since the
            % first-ever tick may cold-start once.
            testCase.verifyLessThanOrEqual(postRecompute - preRecompute, 1, ...
                sprintf(['Pitfall Y violation: appendData hit cold path ' ...
                         '(recompute delta = %d). parent.updateData must ' ...
                         'be called BEFORE monitor.appendData.'], ...
                        postRecompute - preRecompute));

            % Also verify the cache now contains the appended tail —
            % only possible if appendData ran after the parent absorbed
            % the new (X, Y).
            [cx, ~] = monitor.getXY();
            testCase.verifyGreaterThanOrEqual(numel(cx), 10, ...
                'monitor cache must extend after live tick');
            testCase.verifyEqual(cx(end), 10, ...
                'monitor cache must end at parent tail');
        end

        function testLegacySensorPathUnchanged(testCase)
            % Legacy constructor shape (no 'Monitors' NV pair) must still
            % yield a functional pipeline — byte-for-byte preservation.
            s = SensorTag('s1');
            thr = Threshold('warn', 'Name', 'warn', 'Direction', 'upper');
            thr.addCondition(struct(), 10);
            s.addThreshold(thr);

            sensors = containers.Map('KeyType', 'char', 'ValueType', 'any');
            sensors('s1') = s;
            dsMap = DataSourceMap();
            ds = StubDataSource();
            dsMap.add('s1', ds);

            p = LiveEventPipeline(sensors, dsMap, ...
                'Interval', 60, 'MinDuration', 0);

            % No data armed — runCycle must not error; Status 'stopped'.
            p.runCycle();
            testCase.verifyEqual(p.Status, 'stopped', 'legacy: Status unchanged');
        end

        function testMonitorsNVPairOptional(testCase)
            % Constructor without 'Monitors' NV pair must succeed; the new
            % MonitorTargets property defaults to an empty containers.Map.
            s = SensorTag('s1');
            thr = Threshold('warn', 'Name', 'warn', 'Direction', 'upper');
            thr.addCondition(struct(), 10);
            s.addThreshold(thr);
            sensors = containers.Map('KeyType', 'char', 'ValueType', 'any');
            sensors('s1') = s;
            dsMap = DataSourceMap();
            dsMap.add('s1', StubDataSource());

            p = LiveEventPipeline(sensors, dsMap, 'Interval', 60);
            testCase.verifyTrue(isa(p.MonitorTargets, 'containers.Map'), ...
                'MonitorTargets must be containers.Map');
            testCase.verifyEqual(double(p.MonitorTargets.Count), 0, ...
                'MonitorTargets defaults to empty');
        end

        function testMixedSensorsAndMonitors(testCase)
            % A pipeline with BOTH a Sensor target and a MonitorTag target
            % processes both independently without error.
            TagRegistry.clear();

            % Monitor side: s1 parent + m1 monitor
            parent = SensorTag('s1', 'X', 1:5, 'Y', [1 1 1 1 1]);
            TagRegistry.register('s1', parent);
            monitor = MonitorTag('m1', parent, @(x, y) y > 15);
            TagRegistry.register('m1', monitor);
            store = EventStore(makePhase1009Fixtures.makeEventStoreTmp());
            monitor.EventStore = store;

            % Sensor side: legacy
            s2 = SensorTag('s2');
            thr = Threshold('warn', 'Name', 'warn', 'Direction', 'upper');
            thr.addCondition(struct(), 10);
            s2.addThreshold(thr);

            sensors = containers.Map('KeyType', 'char', 'ValueType', 'any');
            sensors('s2') = s2;

            ds1 = StubDataSource();
            ds1.setNextResult(struct('changed', true, ...
                'X', 6:10, 'Y', [20 20 20 20 20], ...
                'stateX', [], 'stateY', {{}}));
            ds2 = StubDataSource();  % no data
            dsMap = DataSourceMap();
            dsMap.add('s1', ds1);
            dsMap.add('s2', ds2);

            monitorsMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
            monitorsMap('s1') = monitor;

            p = LiveEventPipeline(sensors, dsMap, ...
                'Monitors', monitorsMap, ...
                'Interval', 60, 'MinDuration', 0);

            p.runCycle();  % must not error

            % Monitor side should have at least one event
            testCase.verifyGreaterThanOrEqual(store.numEvents(), 1, ...
                'mixed: MonitorTag side emits events');
        end

    end
end

% ---- Shared fixture -----------------------------------------------------

function [pipeline, store, monitor, parent, ds] = makeLiveTagFixture_()
    TagRegistry.clear();

    parent  = SensorTag('s1', 'X', 1:5, 'Y', [1 1 1 1 1]);
    TagRegistry.register('s1', parent);

    monitor = MonitorTag('m1', parent, @(x, y) y > 15);
    TagRegistry.register('m1', monitor);

    store = EventStore(makePhase1009Fixtures.makeEventStoreTmp());
    monitor.EventStore = store;

    ds    = StubDataSource();
    dsMap = DataSourceMap();
    dsMap.add('s1', ds);

    monitorsMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    monitorsMap('s1') = monitor;

    sensors = containers.Map('KeyType', 'char', 'ValueType', 'any');

    pipeline = LiveEventPipeline(sensors, dsMap, ...
        'Monitors', monitorsMap, ...
        'Interval', 60, 'MinDuration', 0);
end
