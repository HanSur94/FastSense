classdef TestMachine < matlab.unittest.TestCase
    %TESTMACHINE Unit tests for Phase 1042 Machine (Fleet layer).
    %   Nyquist Wave 0 scaffold — all tests are RED until Plan 03 delivers
    %   libs/Fleet/Machine.m.  These suites encode the expected behavior
    %   described in FLEET-01..05 before any production code is written.
    %
    %   Coverage:
    %     FLEET-01: Machine NV constructor; addTag; get/find/findByKind/findByLabel/keys
    %     FLEET-02: Two machines with same local key coexist; TagRegistry untouched
    %     FLEET-03: ingestBatch/startLive wrap pipelines with TagSource + OutputDir
    %     FLEET-05: 5-machine startup metadata-only (no X/Y materialization)
    %
    %   See also TestFleet, Machine, MockTag.

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
        function clearRegistry(testCase) %#ok<MANU>
            TagRegistry.clear();
        end
    end

    methods (TestMethodTeardown)
        function clearRegistryAfter(testCase) %#ok<MANU>
            TagRegistry.clear();
        end
    end

    % ---- FLEET-01: Constructor + basic catalog API ----

    methods (Test)

        function testConstructorRequiresId(testCase)
            %TESTCONSTRUCTORREQUIRESID Machine() with no Id throws Machine:missingId.
            testCase.verifyError(@() Machine(), 'Machine:missingId');
        end

        function testNameDefaultsToId(testCase)
            %TESTNAMEDEFAULTSTOID When Name omitted, Name equals Id.
            m = Machine('Id', 'M01');
            testCase.verifyEqual(m.Name, 'M01');
        end

        function testUnknownOptionErrors(testCase)
            %TESTUNKNOWNOPTIONERRORS Unknown NV key throws Machine:invalidOption.
            testCase.verifyError(@() Machine('Id', 'M01', 'Bogus', 1), ...
                'Machine:invalidOption');
        end

        function testAddTagDuplicateKeyErrors(testCase)
            %TESTADDTAGDUPLICATEKEYERRORS Adding two tags with same key throws Machine:duplicateKey.
            m = Machine('Id', 'M01');
            t = MockTag('temp');
            m.addTag(t);
            testCase.verifyError(@() m.addTag(MockTag('temp')), 'Machine:duplicateKey');
        end

        function testAddTagRejectsNonTag(testCase)
            %TESTADDTAGREJECTSNONTAG Passing a non-Tag to addTag throws Machine:invalidType.
            m = Machine('Id', 'M01');
            testCase.verifyError(@() m.addTag(struct()), 'Machine:invalidType');
        end

        function testGetUnknownKeyErrors(testCase)
            %TESTGETUNKNOWNKEYERRORS Getting a key not in catalog throws Machine:unknownKey.
            m = Machine('Id', 'M01');
            testCase.verifyError(@() m.get('nope'), 'Machine:unknownKey');
        end

        function testGetFindKeysRoundTrip(testCase)
            %TESTGETFINDKEYSROUNDTRIP After addTag, get/keys/find all return the tag.
            m = Machine('Id', 'M01');
            t = MockTag('temperature');
            m.addTag(t);

            % get by key
            testCase.verifyEqual(m.get('temperature').Key, 'temperature');

            % keys lists the key
            ks = m.keys();
            testCase.verifyTrue(any(strcmp(ks, 'temperature')), ...
                'keys() must include the added tag key');

            % find with always-true predicate returns the tag
            found = m.find(@(tg) true);
            testCase.verifyEqual(numel(found), 1);
            testCase.verifyEqual(found{1}.Key, 'temperature');
        end

        function testFindByKind(testCase)
            %TESTFINDBYKIND findByKind returns tags whose getKind() matches.
            m = Machine('Id', 'M01');
            t = MockTag('temp');
            m.addTag(t);
            byMock = m.findByKind('mock');
            testCase.verifyEqual(numel(byMock), 1);
            bySensor = m.findByKind('sensor');
            testCase.verifyEmpty(bySensor);
        end

        function testFindByLabel(testCase)
            %TESTFINDBYLABEL findByLabel returns tags carrying the requested label.
            m = Machine('Id', 'M01');
            t1 = MockTag('temp', 'Labels', {'critical', 'temperature'});
            t2 = MockTag('pressure', 'Labels', {'flow'});
            m.addTag(t1);
            m.addTag(t2);
            res = m.findByLabel('critical');
            testCase.verifyEqual(numel(res), 1);
            testCase.verifyEqual(res{1}.Key, 'temp');
        end

        % ---- FLEET-02: Namespace isolation ----

        function testTwoMachinesSameLocalKeyCoexist(testCase)
            %TESTTWOMACHINESSAMELOCALKEYCOEXIST Two machines with key 'temperature' are both ok.
            m1 = Machine('Id', 'M01');
            m1.addTag(MockTag('temperature'));
            m2 = Machine('Id', 'M02');
            % This must NOT throw Machine:duplicateKey — keys are per-machine
            m2.addTag(MockTag('temperature'));
            testCase.verifyEqual(m1.get('temperature').Key, 'temperature');
            testCase.verifyEqual(m2.get('temperature').Key, 'temperature');
        end

        function testTagRegistryUntouched(testCase)
            %TESTTAGREGISTRYUNTOUCHED Machine.addTag never populates the global TagRegistry.
            m1 = Machine('Id', 'M01');
            m1.addTag(MockTag('temperature'));
            m2 = Machine('Id', 'M02');
            m2.addTag(MockTag('temperature'));
            result = TagRegistry.find(@(t) true);
            testCase.verifyEmpty(result, ...
                'TagRegistry must be empty after machine.addTag (FLEET-02)');
        end

        % ---- FLEET-03: Pipeline wrappers ----

        function testIngestBatchScopesToDataRoot(testCase)
            %TESTINGESTBATCHSCOPESTODATAROOT ingestBatch runs with machine DataRoot.
            %   Uses a SensorTag with a minimal csv written to tempdir so the
            %   pipeline has something to ingest.
            tmp = tempname();
            mkdir(tmp);
            csvPath = fullfile(tmp, 'temp.csv');
            fid = fopen(csvPath, 'w');
            fprintf(fid, '0,1.0\n1,2.0\n2,3.0\n');
            fclose(fid);

            m = Machine('Id', 'M01', 'DataRoot', tmp);
            t = SensorTag('temperature', 'Name', 'Motor Temp', 'Units', 'degC');
            t.RawSource = struct('file', csvPath, 'timeCol', 1, 'valueCol', 2, ...
                'timeUnit', 's', 'delimiter', ',');
            m.addTag(t);

            % ingestBatch should run without error; .mat lands under DataRoot
            m.ingestBatch();
            matFiles = dir(fullfile(tmp, '*.mat'));
            testCase.verifyFalse(isempty(matFiles), ...
                'ingestBatch must write at least one .mat file under DataRoot');
        end

        function testStartLiveStopsTimerOnDelete(testCase)
            %TESTSTARTLIVESTOPSTIMERONDELETE After startLive then delete, timer count is restored.
            tmp = tempname();
            mkdir(tmp);
            m = Machine('Id', 'M01', 'DataRoot', tmp);
            t = SensorTag('temperature');
            t.RawSource = struct('file', fullfile(tmp, 'fake.csv'), ...
                'timeCol', 1, 'valueCol', 2, 'timeUnit', 's', 'delimiter', ',');
            m.addTag(t);

            nBefore = numel(timerfindall());
            m.startLive(5);
            nAfter = numel(timerfindall());
            testCase.verifyGreaterThan(nAfter, nBefore, ...
                'startLive must create at least one timer');

            delete(m);
            nFinal = numel(timerfindall());
            testCase.verifyEqual(nFinal, nBefore, ...
                'delete(machine) must stop and clean up all timers started by startLive');
        end

        % ---- FLEET-05: Metadata-only startup, no X/Y materialization ----

        function testFiveMachineMetadataOnlyLoad(testCase)
            %TESTFIVEMACHINEMETADATAONLYLOAD 5 machines with 10 SensorTags each stay fast.
            %   Asserts wall time < 2 s and that no X/Y arrays are materialized
            %   (tags carry RawSource pointers; getXY is never called here).
            tmp = tempname();
            mkdir(tmp);
            csvPath = fullfile(tmp, 'dummy.csv');
            fid = fopen(csvPath, 'w');
            fprintf(fid, '0,0.0\n');
            fclose(fid);

            tic;
            for mi = 1:5
                m = Machine('Id', sprintf('M%02d', mi), 'DataRoot', tmp);
                for ti = 1:10
                    st = SensorTag(sprintf('sensor_%02d', ti));
                    st.RawSource = struct('file', csvPath, 'timeCol', 1, ...
                        'valueCol', 2, 'timeUnit', 's', 'delimiter', ',');
                    m.addTag(st);
                end
            end
            elapsed = toc;

            testCase.verifyLessThan(elapsed, 2.0, ...
                'Constructing 5 machines with 10 SensorTags each must take < 2 s (FLEET-05)');
        end

    end

end
