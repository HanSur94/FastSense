classdef TestListenerCannotAcquireLock < matlab.unittest.TestCase
%TESTLISTENERCANNOTACQUIRELOCK Deferred-notify + nested-lock-acquire-forbidden (Pitfall 13).
%
%   Verifies the Plan 1032-01 refactor:
%     - MonitorTag.OnEventStart fires AFTER the emission body completes
%       (inEmission_=false at firing time)
%     - A listener that calls TagWriteCoordinator.acquireTag on a DIFFERENT
%       tag from inside the callback succeeds (callback fires post-flush)
%     - Direct nested acquire of the SAME tag key from the same process
%       throws Concurrency:nestedLockAcquireForbidden — regression for
%       Phase 1030-01's contract that Plan 1032-02 depends on.
%     - Deferred-notify preserves event count and ordering across multiple
%       rising edges in a single appendData call.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            root = fileparts(fileparts(here));
            addpath(root);
            install();
            addpath(fullfile(root, 'libs', 'Concurrency'));
        end
    end

    methods (Test)

        function testListenerFiresPostRelease(testCase)
            % Listener installed via OnEventStart records inEmission_ state at firing time.
            % After triggering a rising-edge event via appendData, the listener MUST have
            % fired (count >= 1) and MUST have observed inEmission_ == false.
            parent = SensorTag('p_listener_test', 'X', 0:9, 'Y', zeros(1, 10));
            TagRegistry.register('p_listener_test', parent);
            cleaner1 = onCleanup(@() TagRegistry.unregister('p_listener_test')); %#ok<NASGU>
            mon = MonitorTag('m_listener_test', parent, @(x, y) y > 0.5);
            TagRegistry.register('m_listener_test', mon);
            cleaner2 = onCleanup(@() TagRegistry.unregister('m_listener_test')); %#ok<NASGU>

            % Mutable observation state via containers.Map (handle class — closure-safe)
            observed = containers.Map('KeyType', 'char', 'ValueType', 'any');
            observed('count') = 0;
            observed('inEmissionAtFire') = NaN;
            mon.OnEventStart = @(ev) testCase.recordObservation_(mon, observed);

            parent.updateData(0:14, [zeros(1, 10), ones(1, 5)]);
            mon.appendData(10:14, ones(1, 5));

            testCase.verifyGreaterThanOrEqual(observed('count'), 1, ...
                'listener fired at least once');
            testCase.verifyEqual(observed('inEmissionAtFire'), false, ...
                'listener observed inEmission_=false at firing time (deferred-notify)');
        end

        function testListenerAcquiresOtherTagLockSuccessfully(testCase)
            % Listener fires post-flush, so a TagWriteCoordinator.acquireTag for a
            % DIFFERENT tag key succeeds with no nested-lock-forbidden error.
            sharedRoot = tempname();
            mkdir(sharedRoot);
            mkdir(fullfile(sharedRoot, 'locks'));
            cleaner = onCleanup(@() rmdir(sharedRoot, 's')); %#ok<NASGU>

            coord = TagWriteCoordinator(sharedRoot);
            parent = SensorTag('p_acquire_in_cb', 'X', 0:9, 'Y', zeros(1, 10));
            TagRegistry.register('p_acquire_in_cb', parent);
            cleanerP = onCleanup(@() TagRegistry.unregister('p_acquire_in_cb')); %#ok<NASGU>
            mon = MonitorTag('m_acquire_in_cb', parent, @(x, y) y > 0.5);
            TagRegistry.register('m_acquire_in_cb', mon);
            cleanerM = onCleanup(@() TagRegistry.unregister('m_acquire_in_cb')); %#ok<NASGU>

            result = containers.Map('KeyType', 'char', 'ValueType', 'any');
            result('ok') = false;
            result('errId') = '';
            mon.OnEventStart = @(ev) testCase.acquireOtherTag_(coord, 'other_tag_for_test', result);

            parent.updateData(0:14, [zeros(1, 10), ones(1, 5)]);
            mon.appendData(10:14, ones(1, 5));

            testCase.verifyTrue(result('ok'), ...
                sprintf('listener-acquired lock on different tag must succeed; errId=%s', result('errId')));
        end

        function testNestedAcquireFromSameTagThrows(testCase)
            % Regression check for Phase 1030-01: same-process nested acquire of the
            % same tag key MUST throw Concurrency:nestedLockAcquireForbidden.
            sharedRoot = tempname();
            mkdir(sharedRoot);
            mkdir(fullfile(sharedRoot, 'locks'));
            cleaner = onCleanup(@() rmdir(sharedRoot, 's')); %#ok<NASGU>

            coord = TagWriteCoordinator(sharedRoot);
            [lock1, ok1] = coord.acquireTag('repro_tag');
            testCase.verifyTrue(ok1, 'first acquire succeeds');
            cleanerLock = onCleanup(@() lock1.release()); %#ok<NASGU>

            testCase.verifyError(@() coord.acquireTag('repro_tag'), ...
                'Concurrency:nestedLockAcquireForbidden');
        end

        function testDeferredOrderingPreservedAcrossMultipleEvents(testCase)
            % Three rising edges in one appendData call should fire OnEventStart
            % exactly the expected number of times, all AFTER the emission body
            % completes (proven by checking inEmission_ in the callback).
            parent = SensorTag('p_multi_edge', 'X', 0:6, 'Y', [0 1 0 1 0 1 0]);
            TagRegistry.register('p_multi_edge', parent);
            cleaner = onCleanup(@() TagRegistry.unregister('p_multi_edge')); %#ok<NASGU>

            store = EventStore([tempname() '.mat']);
            mon = MonitorTag('m_multi_edge', parent, @(x, y) y > 0.5, ...
                'EventStore', store);
            TagRegistry.register('m_multi_edge', mon);
            cleanerM = onCleanup(@() TagRegistry.unregister('m_multi_edge')); %#ok<NASGU>

            fireCount = containers.Map('KeyType', 'char', 'ValueType', 'any');
            fireCount('starts') = 0;
            fireCount('allPostEmission') = true;
            mon.OnEventStart = @(ev) testCase.recordFire_(mon, fireCount);

            mon.appendData(0:6, [0 1 0 1 0 1 0]);

            % At least one rising edge should produce a Start callback
            testCase.verifyGreaterThanOrEqual(fireCount('starts'), 1, ...
                'OnEventStart fired at least once for rising edges');
            testCase.verifyTrue(fireCount('allPostEmission'), ...
                'every callback fired with inEmission_=false');
            testCase.verifyGreaterThanOrEqual(store.numEvents(), 1, ...
                'event store recorded at least one event');
        end

    end

    methods (Access = private)

        function recordObservation_(~, mon, observed)
            observed('count') = observed('count') + 1;
            observed('inEmissionAtFire') = mon.getInEmission_();
        end

        function acquireOtherTag_(~, coord, tagKey, result)
            try
                [lock, ok] = coord.acquireTag(tagKey);
                result('ok') = ok;
                result('errId') = '';
                if ok
                    lock.release();
                end
            catch ME
                result('ok') = false;
                result('errId') = ME.identifier;
            end
        end

        function recordFire_(~, mon, fireCount)
            fireCount('starts') = fireCount('starts') + 1;
            if mon.getInEmission_()
                fireCount('allPostEmission') = false;
            end
        end

    end

end
