classdef TestBatchTagPipeline < matlab.unittest.TestCase
    %TESTBATCHTAGPIPELINE Suite for Phase 1012 BatchTagPipeline (Plan 04).
    %
    % Coverage matrix per VALIDATION.md:
    %   - D-02 (hidden parser dispatch; unknownExtension error)
    %   - D-04 (wide vs tall file fan-out)
    %   - D-07 (de-dup internal file cache; LastFileParseCount observability)
    %   - D-08 (silent skip for tags without RawSource and for MonitorTag)
    %   - D-09 / D-10 (data.<KeyName> shape; strict one-mat-per-tag)
    %   - D-11 (StateTag cellstr Y round-trip)
    %   - D-12 (BatchTagPipeline as a standalone class)
    %   - D-15 (OutputDir constructor param + auto-mkdir)
    %   - D-16 (MonitorTag / CompositeTag never materialized)
    %   - D-17 (MonitorTag.Persist path untouched)
    %   - D-18 (per-tag try/catch + end-of-run TagPipeline:ingestFailed)
    %   - D-19 error IDs (invalidRawSource, invalidOutputDir,
    %       cannotCreateOutputDir, invalidWriteMode, ingestFailed,
    %       unknownExtension)
    %
    % See also: makeSyntheticRaw, TestRawDelimitedParser, TestLiveTagPipeline.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'libs', 'EventDetection'));
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'libs', 'SensorThreshold'));
            install();
        end
    end

    methods (TestMethodSetup)
        function resetRegistry(testCase) %#ok<MANU>
            TagRegistry.clear();
        end
    end

    methods (TestMethodTeardown)
        function clearRegistry(testCase) %#ok<MANU>
            TagRegistry.clear();
        end
    end

    methods (Test)
        % ---- Constructor / OutputDir lifecycle (D-15, D-19) ----

        function testConstructorRequiresOutputDir(testCase)
            % TagPipeline:invalidOutputDir — missing OutputDir
            testCase.verifyError(@() BatchTagPipeline(), ...
                'TagPipeline:invalidOutputDir');
            % Empty OutputDir also fails
            testCase.verifyError(@() BatchTagPipeline('OutputDir', ''), ...
                'TagPipeline:invalidOutputDir');
        end

        function testConstructorCreatesOutputDirIfMissing(testCase)
            % D-15: auto-mkdir on missing OutputDir
            outDir = fullfile(tempname(), 'sub_a', 'sub_b');
            testCase.addTeardown(@() removeIfExists_(outDir));
            testCase.verifyFalse(exist(outDir, 'dir') == 7);
            p = BatchTagPipeline('OutputDir', outDir);
            testCase.verifyEqual(exist(p.OutputDir, 'dir'), 7);
        end

        function testErrorCannotCreateOutputDir(testCase)
            % TagPipeline:cannotCreateOutputDir - mkdir fails under a non-dir
            % parent. Use a regular file as a parent path so mkdir must fail
            % with ENOTDIR (POSIX) or equivalent on Windows.
            parentFile = [tempname(), '.txt'];
            fid = fopen(parentFile, 'w');
            fprintf(fid, 'not a dir\n');
            fclose(fid);
            testCase.addTeardown(@() deleteIfExists_(parentFile));
            childDir = fullfile(parentFile, 'child');
            % mkdir on a path beneath a regular file fails on every
            % supported platform (macOS ENOTDIR, Linux ENOTDIR, Windows
            % ERROR_DIRECTORY). The pipeline maps that failure to
            % TagPipeline:cannotCreateOutputDir.
            testCase.verifyError(@() BatchTagPipeline('OutputDir', childDir), ...
                'TagPipeline:cannotCreateOutputDir');
        end

        % ---- Happy-path dispatch tests (D-04, D-09) ----

        function testWideFileFanOut(testCase)
            % D-04 wide dispatch: 4-col CSV with header; column='pressure_a'.
            files = makeSyntheticRaw(testCase);
            outDir = tempname();  mkdir(outDir);
            testCase.addTeardown(@() removeIfExists_(outDir));

            t = SensorTag('p_a', ...
                'RawSource', struct('file', files.wideCsv, 'column', 'pressure_a'));
            TagRegistry.register('p_a', t);

            p = BatchTagPipeline('OutputDir', outDir);
            report = p.run();

            testCase.verifyEqual(report.succeeded, {'p_a'});
            testCase.verifyEqual(exist(fullfile(outDir, 'p_a.mat'), 'file'), 2);
            loaded = load(fullfile(outDir, 'p_a.mat'));
            testCase.verifyTrue(isfield(loaded, 'p_a'));
            testCase.verifyEqual(loaded.p_a.x(:)', [1 2 3]);
            testCase.verifyEqual(loaded.p_a.y(:)', [10 11 12]);
        end

        function testTallFileTwoColumn(testCase)
            % D-04 tall dispatch: 2-col whitespace TXT, no column specified.
            files = makeSyntheticRaw(testCase);
            outDir = tempname();  mkdir(outDir);
            testCase.addTeardown(@() removeIfExists_(outDir));

            t = SensorTag('lvl', ...
                'RawSource', struct('file', files.tallTxt));
            TagRegistry.register('lvl', t);

            p = BatchTagPipeline('OutputDir', outDir);
            p.run();

            loaded = load(fullfile(outDir, 'lvl.mat'));
            testCase.verifyEqual(loaded.lvl.x(:)', [1 2 3]);
            testCase.verifyEqual(loaded.lvl.y(:)', [100 101 102]);
        end

        function testRoundTripThroughSensorTagLoad(testCase)
            % D-09: tag -> run -> SensorTag.load recovers identical X/Y.
            files = makeSyntheticRaw(testCase);
            outDir = tempname();  mkdir(outDir);
            testCase.addTeardown(@() removeIfExists_(outDir));

            t = SensorTag('p_b', ...
                'RawSource', struct('file', files.wideCsv, 'column', 'pressure_b'));
            TagRegistry.register('p_b', t);

            p = BatchTagPipeline('OutputDir', outDir);
            p.run();

            % Round-trip via SensorTag.load (D-09 contract).
            t2 = SensorTag('p_b');
            t2.load(fullfile(outDir, 'p_b.mat'));
            [x, y] = t2.getXY();
            testCase.verifyEqual(x(:)', [1 2 3]);
            testCase.verifyEqual(y(:)', [20 21 22]);
        end

        function testOneMatFilePerTag(testCase)
            % D-10: one .mat per tag, distinct filenames.
            files = makeSyntheticRaw(testCase);
            outDir = tempname();  mkdir(outDir);
            testCase.addTeardown(@() removeIfExists_(outDir));

            t1 = SensorTag('p_a', ...
                'RawSource', struct('file', files.wideCsv, 'column', 'pressure_a'));
            t2 = SensorTag('p_b', ...
                'RawSource', struct('file', files.wideCsv, 'column', 'pressure_b'));
            t3 = SensorTag('temp', ...
                'RawSource', struct('file', files.wideCsv, 'column', 'temperature'));
            TagRegistry.register('p_a', t1);
            TagRegistry.register('p_b', t2);
            TagRegistry.register('temp', t3);

            p = BatchTagPipeline('OutputDir', outDir);
            p.run();

            testCase.verifyEqual(exist(fullfile(outDir, 'p_a.mat'),  'file'), 2);
            testCase.verifyEqual(exist(fullfile(outDir, 'p_b.mat'),  'file'), 2);
            testCase.verifyEqual(exist(fullfile(outDir, 'temp.mat'), 'file'), 2);
            % Each .mat has its own top-level key (no cross-collision).
            la = load(fullfile(outDir, 'p_a.mat'));
            lb = load(fullfile(outDir, 'p_b.mat'));
            lt = load(fullfile(outDir, 'temp.mat'));
            testCase.verifyTrue(isfield(la, 'p_a'));
            testCase.verifyTrue(isfield(lb, 'p_b'));
            testCase.verifyTrue(isfield(lt, 'temp'));
            testCase.verifyEqual(la.p_a.y(:)',  [10 11 12]);
            testCase.verifyEqual(lb.p_b.y(:)',  [20 21 22]);
            testCase.verifyEqual(lt.temp.y(:)', [30 31 32]);
        end

        function testStateTagCellstrRoundTrip(testCase)
            % D-11: StateTag with cellstr Y round-trip through StateTag.fromStruct.
            files = makeSyntheticRaw(testCase);
            outDir = tempname();  mkdir(outDir);
            testCase.addTeardown(@() removeIfExists_(outDir));

            t = StateTag('mode', ...
                'RawSource', struct('file', files.stateCellstrCsv, 'column', 'state'));
            TagRegistry.register('mode', t);

            p = BatchTagPipeline('OutputDir', outDir);
            p.run();

            loaded = load(fullfile(outDir, 'mode.mat'));
            testCase.verifyTrue(isfield(loaded, 'mode'));
            yOut = loaded.mode.y;
            testCase.verifyTrue(iscell(yOut));
            testCase.verifyEqual(yOut(:)', {'idle', 'running', 'idle'});
            testCase.verifyEqual(loaded.mode.x(:)', [1 2 3]);
        end

        % ---- D-07 de-dup + Major-2 observability ----

        function testFileCacheDedup(testCase)
            % Major-2 / D-07: 2 tags share a file -> parsed ONCE.
            % Asserted via pipeline.LastFileParseCount == 1 (pure property read).
            files = makeSyntheticRaw(testCase);
            outDir = tempname();  mkdir(outDir);
            testCase.addTeardown(@() removeIfExists_(outDir));

            t1 = SensorTag('share_a', ...
                'RawSource', struct('file', files.sharedFile, 'column', 'p_a'));
            t2 = SensorTag('share_b', ...
                'RawSource', struct('file', files.sharedFile, 'column', 'p_b'));
            TagRegistry.register('share_a', t1);
            TagRegistry.register('share_b', t2);

            p = BatchTagPipeline('OutputDir', outDir);
            p.run();

            % 2 tags; 1 shared file -> exactly 1 parse (D-07 dedup).
            testCase.verifyEqual(p.LastFileParseCount, 1);
            % Both fan-out files exist.
            testCase.verifyEqual(exist(fullfile(outDir, 'share_a.mat'), 'file'), 2);
            testCase.verifyEqual(exist(fullfile(outDir, 'share_b.mat'), 'file'), 2);
            la = load(fullfile(outDir, 'share_a.mat'));
            lb = load(fullfile(outDir, 'share_b.mat'));
            testCase.verifyEqual(la.share_a.y(:)', [1 2 3]);
            testCase.verifyEqual(lb.share_b.y(:)', [10 20 30]);
        end

        % ---- Silent-skip tests (D-08, D-16, D-17) ----

        function testSilentSkipMonitorTag(testCase)
            % D-16: MonitorTag NEVER materialized by the pipeline, even
            % alongside ingestable SensorTags.
            files = makeSyntheticRaw(testCase);
            outDir = tempname();  mkdir(outDir);
            testCase.addTeardown(@() removeIfExists_(outDir));

            st = SensorTag('press_raw', 'X', 1:5, 'Y', 1:5);
            mon = MonitorTag('press_hi', st, @(x, y) y > 3);
            ingestable = SensorTag('temp', ...
                'RawSource', struct('file', files.wideCsv, 'column', 'temperature'));
            TagRegistry.register('press_raw', st);
            TagRegistry.register('press_hi',  mon);
            TagRegistry.register('temp',      ingestable);

            p = BatchTagPipeline('OutputDir', outDir);
            p.run();

            % Only the ingestable SensorTag's output exists; no monitor .mat.
            testCase.verifyEqual(exist(fullfile(outDir, 'temp.mat'),      'file'), 2);
            testCase.verifyEqual(exist(fullfile(outDir, 'press_hi.mat'),  'file'), 0);
            testCase.verifyEqual(exist(fullfile(outDir, 'press_raw.mat'), 'file'), 0);
        end

        function testSilentSkipTagWithoutRawSource(testCase)
            % D-08: SensorTag with NO RawSource is silently skipped.
            files = makeSyntheticRaw(testCase);
            outDir = tempname();  mkdir(outDir);
            testCase.addTeardown(@() removeIfExists_(outDir));

            % Tag without RawSource (no RawSource NV pair given).
            t1 = SensorTag('no_src', 'X', 1:3, 'Y', 1:3);
            t2 = SensorTag('with_src', ...
                'RawSource', struct('file', files.wideCsv, 'column', 'pressure_a'));
            TagRegistry.register('no_src',   t1);
            TagRegistry.register('with_src', t2);

            p = BatchTagPipeline('OutputDir', outDir);
            report = p.run();

            testCase.verifyEqual(report.succeeded, {'with_src'});
            testCase.verifyEqual(exist(fullfile(outDir, 'no_src.mat'),   'file'), 0);
            testCase.verifyEqual(exist(fullfile(outDir, 'with_src.mat'), 'file'), 2);
        end

        function testCompositeTagNotMaterialized(testCase)
            % D-16: CompositeTag NEVER materialized (positive-isa guard).
            files = makeSyntheticRaw(testCase);
            outDir = tempname();  mkdir(outDir);
            testCase.addTeardown(@() removeIfExists_(outDir));

            st = SensorTag('sensor_a', 'X', 1:5, 'Y', 1:5);
            m1 = MonitorTag('mon_1', st, @(x, y) y > 2);
            m2 = MonitorTag('mon_2', st, @(x, y) y > 4);
            comp = CompositeTag('comp_1', 'and');
            TagRegistry.register('sensor_a', st);
            TagRegistry.register('mon_1',    m1);
            TagRegistry.register('mon_2',    m2);
            TagRegistry.register('comp_1',   comp);
            comp.addChild(m1);
            comp.addChild(m2);

            ingestable = SensorTag('temp', ...
                'RawSource', struct('file', files.wideCsv, 'column', 'temperature'));
            TagRegistry.register('temp', ingestable);

            p = BatchTagPipeline('OutputDir', outDir);
            p.run();

            testCase.verifyEqual(exist(fullfile(outDir, 'temp.mat'),   'file'), 2);
            testCase.verifyEqual(exist(fullfile(outDir, 'comp_1.mat'), 'file'), 0);
            testCase.verifyEqual(exist(fullfile(outDir, 'mon_1.mat'),  'file'), 0);
            testCase.verifyEqual(exist(fullfile(outDir, 'mon_2.mat'),  'file'), 0);
        end

        function testMonitorPersistPathUntouched(testCase)
            % D-17: MonitorTag.Persist path is the MonitorTag's own
            % concern (Phase 1007 storeMonitor/loadMonitor domain). The
            % batch pipeline never routes a MonitorTag through the
            % parser+writer helpers and never emits <monitor>.mat in
            % OutputDir — whether the monitor has Persist=true or not.
            % This test verifies the NEGATIVE: pipeline does not touch
            % a MonitorTag whose recomputeCount_ starts at 0.
            files = makeSyntheticRaw(testCase);
            outDir = tempname();  mkdir(outDir);
            testCase.addTeardown(@() removeIfExists_(outDir));

            st = SensorTag('press_raw', 'X', 1:5, 'Y', 1:5);
            mon = MonitorTag('press_hi', st, @(x, y) y > 3);
            ingestable = SensorTag('temp', ...
                'RawSource', struct('file', files.wideCsv, 'column', 'temperature'));
            TagRegistry.register('press_raw', st);
            TagRegistry.register('press_hi',  mon);
            TagRegistry.register('temp',      ingestable);

            preCount = mon.recomputeCount_;
            p = BatchTagPipeline('OutputDir', outDir);
            p.run();
            postCount = mon.recomputeCount_;

            % MonitorTag .mat is NEVER written to the pipeline OutputDir.
            testCase.verifyEqual(exist(fullfile(outDir, 'press_hi.mat'), 'file'), 0);
            testCase.verifyEqual(exist(fullfile(outDir, 'temp.mat'),     'file'), 2);
            % MonitorTag was NEVER recomputed by the pipeline -- its
            % Persist path (recompute_ -> persistIfEnabled_) was untouched.
            testCase.verifyEqual(postCount, preCount);
        end

        % ---- Error isolation (D-18) ----

        function testPerTagErrorIsolationContinuesToNext(testCase)
            % D-18: one failing tag does NOT abort the batch.
            files = makeSyntheticRaw(testCase);
            outDir = tempname();  mkdir(outDir);
            testCase.addTeardown(@() removeIfExists_(outDir));

            goodA = SensorTag('good_a', ...
                'RawSource', struct('file', files.wideCsv, 'column', 'pressure_a'));
            bad = SensorTag('bad', ...
                'RawSource', struct('file', '/this/path/does/not/exist.csv'));
            goodB = SensorTag('good_b', ...
                'RawSource', struct('file', files.wideCsv, 'column', 'pressure_b'));
            TagRegistry.register('good_a', goodA);
            TagRegistry.register('bad',    bad);
            TagRegistry.register('good_b', goodB);

            p = BatchTagPipeline('OutputDir', outDir);
            testCase.verifyError(@() p.run(), 'TagPipeline:ingestFailed');

            % Both good tags STILL wrote their .mat files.
            testCase.verifyEqual(exist(fullfile(outDir, 'good_a.mat'), 'file'), 2);
            testCase.verifyEqual(exist(fullfile(outDir, 'good_b.mat'), 'file'), 2);
            % Bad tag DID NOT write.
            testCase.verifyEqual(exist(fullfile(outDir, 'bad.mat'),    'file'), 0);
            % Report captured the failure.
            testCase.verifyEqual(numel(p.LastReport.failed), 1);
            testCase.verifyEqual(p.LastReport.failed.key, 'bad');
        end

        function testIngestFailedThrownAtEnd(testCase)
            % TagPipeline:ingestFailed thrown when ANY tag failed.
            outDir = tempname();  mkdir(outDir);
            testCase.addTeardown(@() removeIfExists_(outDir));

            bad1 = SensorTag('bad1', ...
                'RawSource', struct('file', '/nope/a.csv'));
            bad2 = SensorTag('bad2', ...
                'RawSource', struct('file', '/nope/b.csv'));
            TagRegistry.register('bad1', bad1);
            TagRegistry.register('bad2', bad2);

            p = BatchTagPipeline('OutputDir', outDir);
            testCase.verifyError(@() p.run(), 'TagPipeline:ingestFailed');
            testCase.verifyEqual(numel(p.LastReport.failed), 2);
            testCase.verifyEqual(numel(p.LastReport.succeeded), 0);
        end

        % ---- Error-ID coverage (D-19) ----

        function testErrorInvalidRawSource(testCase)
            % TagPipeline:invalidRawSource raised at SensorTag construction
            % (validator surface from Plan 02; re-asserted here under
            % BatchTagPipeline's ownership of the error-ID catalog).
            testCase.verifyError(@() SensorTag('bad', 'RawSource', 'not a struct'), ...
                'TagPipeline:invalidRawSource');
            testCase.verifyError(@() SensorTag('bad', 'RawSource', struct('column', 'x')), ...
                'TagPipeline:invalidRawSource');
        end

        function testErrorInvalidWriteMode(testCase)
            % TagPipeline:invalidWriteMode raised from writeTagMat_ (Plan 03).
            % Re-asserted here under BatchTagPipeline error-ID ownership.
            outDir = tempname();  mkdir(outDir);
            testCase.addTeardown(@() removeIfExists_(outDir));
            t = SensorTag('k', 'X', 1:3, 'Y', 1:3);
            testCase.verifyError( ...
                @() writeTagMat_(outDir, t, t.X, t.Y, 'bogus'), ...
                'TagPipeline:invalidWriteMode');
        end

        function testDispatchUnknownExtension(testCase)
            % D-02: TagPipeline:unknownExtension raised when file extension
            % is not in {.csv, .txt, .dat}.
            % Create a zero-byte file with .xml extension so only the
            % extension-dispatch check fires (not fileNotReadable).
            xmlPath = [tempname(), '.xml'];
            fid = fopen(xmlPath, 'w');
            fprintf(fid, 'not supported\n');
            fclose(fid);
            testCase.addTeardown(@() deleteIfExists_(xmlPath));

            outDir = tempname();  mkdir(outDir);
            testCase.addTeardown(@() removeIfExists_(outDir));

            t = SensorTag('xml_tag', 'RawSource', struct('file', xmlPath));
            TagRegistry.register('xml_tag', t);

            p = BatchTagPipeline('OutputDir', outDir);
            testCase.verifyError(@() p.run(), 'TagPipeline:ingestFailed');
            % Unknown-extension is captured in the failed report entry.
            testCase.verifyEqual(numel(p.LastReport.failed), 1);
            testCase.verifyEqual(p.LastReport.failed(1).errorId, ...
                'TagPipeline:unknownExtension');
        end
    end
end

% ---- Local helpers (function-suite scope, not shared) ----

function removeIfExists_(d)
    %REMOVEIFEXISTS_ Best-effort recursive remove; ignores missing dir.
    if exist(d, 'dir') == 7
        try
            rmdir(d, 's');
        catch
            % swallow — teardown best-effort
        end
    end
end

function deleteIfExists_(f)
    %DELETEIFEXISTS_ Best-effort file delete.
    if exist(f, 'file') == 2
        try
            delete(f);
        catch
            % swallow — teardown best-effort
        end
    end
end

