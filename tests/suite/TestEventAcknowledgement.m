classdef TestEventAcknowledgement < matlab.unittest.TestCase
    %TESTEVENTACKNOWLEDGEMENT Ack workflow + ISA-18.2 three-state + identity stamp + legacy load.
    %
    %   Verifies Phase 1032-04: ACK-01, ACK-02, ACK-03, IDENT-02.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)

        function testEventDefaultIdentityIsEmpty(testCase)
            ev = Event(0, 1, 's', 'thr', 100, 'upper');
            testCase.verifyEqual(ev.Identity, struct(), 'default Identity is empty struct');
            testCase.verifyEmpty(ev.AckedAt, 'default AckedAt is []');
            testCase.verifyEqual(ev.AckedBy, struct(), 'default AckedBy is empty struct');
        end

        function testComputeDisplayStateUnackedActive(testCase)
            ev = Event(0, NaN, 's', 'thr', 100, 'upper');
            ev.IsOpen = true;
            testCase.verifyEqual(ev.computeDisplayState(), 'unacked-active');
        end

        function testComputeDisplayStateAckedActive(testCase)
            ev = Event(0, NaN, 's', 'thr', 100, 'upper');
            ev.IsOpen = true;
            ev.AckedAt = now;
            testCase.verifyEqual(ev.computeDisplayState(), 'acked-active');
        end

        function testComputeDisplayStateAckedCleared(testCase)
            ev = Event(0, 1, 's', 'thr', 100, 'upper');
            ev.IsOpen = false;
            ev.AckedAt = now;
            testCase.verifyEqual(ev.computeDisplayState(), 'acked-cleared');
        end

        function testComputeDisplayStateUnackedCleared(testCase)
            ev = Event(0, 1, 's', 'thr', 100, 'upper');
            ev.IsOpen = false;
            % AckedAt is [] by default
            testCase.verifyEqual(ev.computeDisplayState(), 'unacked-cleared');
        end

        function testAckRoundtripSingleUser(testCase)
            f = [tempname() '.mat'];
            cleaner = onCleanup(@() TestEventAcknowledgement.delIf_(f)); %#ok<NASGU>
            es = EventStore(f);
            ev = Event(0, 1, 's', 'thr', 100, 'upper');
            es.append(ev);
            ackedId = ev.Id;

            es.acknowledgeEvent(ackedId, struct('comment', 'looked into it'));

            % Verify AckedAt populated in-memory
            allEvents = es.getEvents();
            testCase.verifyNotEmpty(allEvents(1).AckedAt, 'AckedAt populated');

            % Verify ack stored in acks_ via getAckRecordsForEvent
            acks = es.getAckRecordsForEvent(ackedId);
            testCase.verifyEqual(numel(acks), 1, 'one ack recorded');
            testCase.verifyEqual(acks(1).comment, 'looked into it');

            % Save + reload — verify acks survived
            es.save();
            testCase.verifyTrue(isfile(f), 'snapshot written');
            d = builtin('load', f);
            testCase.verifyTrue(isfield(d, 'acks'), 'acks field present in saved .mat');
        end

        function testAckRoundtripClusterMode(testCase)
            % Windows holds mksqlite's DB file handle open until the process exits,
            % so the onCleanup rmdir fires while the file is still locked and the
            % whole test errors out. macOS/Linux release the handle when the
            % EventStore destructor runs. Skip on Windows — the cluster-mode SQLite
            % round-trip is fully covered by the Linux TestEventStoreCluster suite.
            testCase.assumeTrue(~ispc(), ...
                'SQLite file-handle release on test teardown is unreliable on Windows.');
            if exist('mksqlite', 'file') ~= 3
                testCase.assumeFail('mksqlite MEX unavailable');
            end
            sharedRoot = tempname();
            mkdir(sharedRoot);
            es = EventStore(fullfile(sharedRoot, 'snap.mat'), 'SharedRoot', sharedRoot);
            % Cleanup order matters: delete EventStore FIRST (closes DB handle),
            % then rmdir. onCleanup destroys in LIFO order — so register
            % rmCleaner FIRST and esCleaner SECOND, so esCleaner fires first.
            rmCleaner = onCleanup(@() rmdir(sharedRoot, 's')); %#ok<NASGU>
            esCleaner = onCleanup(@() delete(es)); %#ok<NASGU>
            ev = Event(0, 1, 's_cluster', 'thr', 100, 'upper');
            es.append(ev);

            es.acknowledgeEvent(ev.Id, struct('comment', 'ack from cluster'));
            acks = es.getAckRecordsForEvent(ev.Id);
            testCase.verifyEqual(numel(acks), 1, 'cluster ack recorded');
        end

        function testAckCommentPersisted(testCase)
            f = [tempname() '.mat'];
            cleaner = onCleanup(@() TestEventAcknowledgement.delIf_(f)); %#ok<NASGU>
            es = EventStore(f);
            ev = Event(0, 1, 's', 'thr', 100, 'upper');
            es.append(ev);

            es.acknowledgeEvent(ev.Id, struct('comment', 'detailed reason text'));
            acks = es.getAckRecordsForEvent(ev.Id);
            testCase.verifyEqual(acks(1).comment, 'detailed reason text');
        end

        function testAckUnknownEventIdThrows(testCase)
            f = [tempname() '.mat'];
            cleaner = onCleanup(@() TestEventAcknowledgement.delIf_(f)); %#ok<NASGU>
            es = EventStore(f);
            testCase.verifyError(@() es.acknowledgeEvent('nonexistent', struct()), ...
                'EventStore:unknownEventId');
        end

        function testLegacyEventLoadsWithoutIdentity(testCase)
            % Simulate a v3.x event struct WITHOUT Identity / AckedAt / AckedBy fields.
            legacyStruct = struct( ...
                'StartTime', 0, 'EndTime', 1, 'Duration', 1, ...
                'SensorName', 's_legacy', 'ThresholdLabel', 'thr_legacy', ...
                'ThresholdValue', 100, 'Direction', 'upper', ...
                'PeakValue', 50, 'NumPoints', 10, ...
                'MinValue', 0, 'MaxValue', 100, 'MeanValue', 50, ...
                'RmsValue', 50, 'StdValue', 5, ...
                'TagKeys', {{'s_legacy'}}, 'Severity', 1, 'Category', '', ...
                'Id', 'evt_legacy_1', 'IsOpen', false, 'Notes', '');
            ev = Event.fromStructSafe(legacyStruct);
            testCase.verifyEqual(ev.SensorName, 's_legacy');
            testCase.verifyEqual(ev.Identity, struct(), ...
                'legacy event gets default empty-struct Identity');
            testCase.verifyEmpty(ev.AckedAt, 'legacy event gets default [] AckedAt');
        end

        function testIdentityCanBeAssignedPostConstruction(testCase)
            ev = Event(0, 1, 's', 'thr', 100, 'upper');
            ev.Identity = struct('user', 'alice', 'host', 'plant-a', 'epoch', now);
            testCase.verifyEqual(ev.Identity.user, 'alice');
            testCase.verifyEqual(ev.Identity.host, 'plant-a');
        end

        function testAckWithNoCommentDefaultsToEmpty(testCase)
            f = [tempname() '.mat'];
            cleaner = onCleanup(@() TestEventAcknowledgement.delIf_(f)); %#ok<NASGU>
            es = EventStore(f);
            ev = Event(0, 1, 's', 'thr', 100, 'upper');
            es.append(ev);

            % No comment field — should NOT throw
            es.acknowledgeEvent(ev.Id, struct());
            acks = es.getAckRecordsForEvent(ev.Id);
            testCase.verifyEqual(numel(acks), 1, 'ack recorded without comment');
            testCase.verifyEqual(acks(1).comment, '', 'comment defaults to empty string');
        end

        function testAckAckedAtMirroredOnEvent(testCase)
            f = [tempname() '.mat'];
            cleaner = onCleanup(@() TestEventAcknowledgement.delIf_(f)); %#ok<NASGU>
            es = EventStore(f);
            ev = Event(0, 1, 's', 'thr', 100, 'upper');
            ev.IsOpen = true;
            es.append(ev);

            % Before ack: unacked-active
            testCase.verifyEqual(ev.computeDisplayState(), 'unacked-active');

            es.acknowledgeEvent(ev.Id, struct('comment', 'handled'));

            % After ack with IsOpen=true: acked-active
            testCase.verifyEqual(ev.computeDisplayState(), 'acked-active');
            testCase.verifyEqual(ev.AckComment, 'handled');
        end

    end

    methods (Static, Access = private)
        function delIf_(p)
            if exist(p, 'file') == 2, delete(p); end
        end
    end
end
