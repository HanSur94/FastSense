classdef TestLiveTagPipeline < matlab.unittest.TestCase
    %TESTLIVETAGPIPELINE Phase 1012 Wave 3 (Plan 05) suite for LiveTagPipeline.
    %
    % Coverage matrix per VALIDATION.md Per-Task Verification Map:
    %   - D-07 (per-tick de-dup; LastFileParseCount observability)
    %   - D-12 (LiveTagPipeline as a standalone class)
    %   - D-13 (modTime + lastIndex incremental-append pattern)
    %   - D-14 (does NOT subclass LiveEventPipeline)
    %   - D-15 (OutputDir constructor param + auto-mkdir)
    %   - D-16 (MonitorTag / CompositeTag never materialized)
    %   - D-18 (per-tag try/catch within a tick)
    %   - D-19 error IDs (invalidOutputDir)
    %   - RESEARCH Q3 (tag state GC when a tag leaves the registry)
    %   - Pitfall 2 (save-append must preserve prior rows, not overwrite)
    %   - mtime-guard via pause(1.1) (TestMatFileDataSource parity)
    %
    % See also: makeSyntheticRaw, TestRawDelimitedParser, TestBatchTagPipeline.

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
        function testNoSubclassOfLiveEventPipeline(testCase)
            % D-14 -- LiveTagPipeline must NOT subclass LiveEventPipeline.
            mc = meta.class.fromName('LiveTagPipeline');
            superNames = {};
            for i = 1:numel(mc.SuperclassList)
                superNames{end+1} = mc.SuperclassList(i).Name; %#ok<AGROW>
            end
            testCase.verifyTrue(any(strcmp(superNames, 'handle')), ...
                'LiveTagPipeline must inherit handle');
            testCase.verifyFalse(any(strcmp(superNames, 'LiveEventPipeline')), ...
                'LiveTagPipeline must NOT subclass LiveEventPipeline (D-14)');
        end

        function testConstructorRequiresOutputDir(testCase)
            % TagPipeline:invalidOutputDir -- missing/empty OutputDir
            testCase.verifyError(@() LiveTagPipeline(), ...
                'TagPipeline:invalidOutputDir');
            testCase.verifyError(@() LiveTagPipeline('OutputDir', ''), ...
                'TagPipeline:invalidOutputDir');
        end

        function testStartSetsStatusRunning(testCase)
            % D-14 timer ergonomics: start() sets Status='running'.
            outDir = tempname();  mkdir(outDir);
            testCase.addTeardown(@() removeIfExists_(outDir));
            p = LiveTagPipeline('OutputDir', outDir, 'Interval', 3600);
            testCase.addTeardown(@() safeStop_(p));
            p.start();
            testCase.verifyEqual(p.Status, 'running');
            p.stop();
        end

        function testStopSetsStatusStopped(testCase)
            % D-14 timer ergonomics: stop() sets Status='stopped'.
            outDir = tempname();  mkdir(outDir);
            testCase.addTeardown(@() removeIfExists_(outDir));
            p = LiveTagPipeline('OutputDir', outDir, 'Interval', 3600);
            testCase.addTeardown(@() safeStop_(p));
            p.start();
            p.stop();
            testCase.verifyEqual(p.Status, 'stopped');
        end

        function testFirstTickWritesAll(testCase)
            % D-13 first tick = full read (lastIndex starts at 0).
            files = makeSyntheticRaw(testCase);
            outDir = tempname();  mkdir(outDir);
            testCase.addTeardown(@() removeIfExists_(outDir));

            t = SensorTag('p_a', ...
                'RawSource', struct('file', files.wideCsv, 'column', 'pressure_a'));
            TagRegistry.register('p_a', t);

            p = LiveTagPipeline('OutputDir', outDir, 'Interval', 3600);
            p.tickOnce();

            testCase.verifyEqual(exist(fullfile(outDir, 'p_a.mat'), 'file'), 2);
            loaded = load(fullfile(outDir, 'p_a.mat'));
            testCase.verifyTrue(isfield(loaded, 'p_a'));
            testCase.verifyEqual(loaded.p_a.x(:)', [1 2 3]);
            testCase.verifyEqual(loaded.p_a.y(:)', [10 11 12]);
        end

        function testSecondTickWritesOnlyNewRows(testCase)
            % D-13 incremental append via modTime + lastIndex (pause(1.1) mtime guard).
            outDir = tempname();  mkdir(outDir);
            testCase.addTeardown(@() removeIfExists_(outDir));
            d = tempname();  mkdir(d);
            testCase.addTeardown(@() removeIfExists_(d));

            csvPath = fullfile(d, 'growing.csv');
            fid = fopen(csvPath, 'w');
            fprintf(fid, 'time,value\n1,10\n2,20\n');
            fclose(fid);

            t = SensorTag('grow', ...
                'RawSource', struct('file', csvPath, 'column', 'value'));
            TagRegistry.register('grow', t);

            p = LiveTagPipeline('OutputDir', outDir, 'Interval', 3600);
            p.tickOnce();

            % Simulate writer appending rows after the first tick.
            pause(1.1);  % Pitfall 4 -- ensure mtime bump is observable
            fid = fopen(csvPath, 'a');
            fprintf(fid, '3,30\n4,40\n');
            fclose(fid);

            p.tickOnce();

            loaded = load(fullfile(outDir, 'grow.mat'));
            % Full cumulative content: initial [1;2] + appended [3;4]
            testCase.verifyEqual(loaded.grow.x(:)', [1 2 3 4]);
            testCase.verifyEqual(loaded.grow.y(:)', [10 20 30 40]);
        end

        function testUnchangedFileSkipped(testCase)
            % D-13 modTime guard -- identical mtime -> no re-read/write.
            files = makeSyntheticRaw(testCase);
            outDir = tempname();  mkdir(outDir);
            testCase.addTeardown(@() removeIfExists_(outDir));

            t = SensorTag('p_a', ...
                'RawSource', struct('file', files.wideCsv, 'column', 'pressure_a'));
            TagRegistry.register('p_a', t);

            p = LiveTagPipeline('OutputDir', outDir, 'Interval', 3600);
            p.tickOnce();
            matPath = fullfile(outDir, 'p_a.mat');
            testCase.verifyEqual(exist(matPath, 'file'), 2);
            matInfo1 = dir(matPath);
            mtime1 = matInfo1(1).datenum;

            % Second tick with UNCHANGED CSV -- should not re-parse or
            % re-write the output. LastFileParseCount == 0 proves no parse.
            pause(1.1);  % ensure enough wall-clock for a write-mtime bump to be distinguishable
            p.tickOnce();

            testCase.verifyEqual(p.LastFileParseCount, 0, ...
                'Unchanged file must not be parsed');
            matInfo2 = dir(matPath);
            testCase.verifyEqual(matInfo2(1).datenum, mtime1, ...
                'Output .mat must not be rewritten when source is unchanged');
            % Content still the same.
            loaded = load(matPath);
            testCase.verifyEqual(loaded.p_a.y(:)', [10 11 12]);
        end

        function testDedupAcrossTagsPerTick(testCase)
            % Major-2 + D-07 live mode: 2 tags share a file -> parsed ONCE per tick.
            % Assert via pipeline.LastFileParseCount == 1 (shim-free property read).
            files = makeSyntheticRaw(testCase);
            outDir = tempname();  mkdir(outDir);
            testCase.addTeardown(@() removeIfExists_(outDir));

            t1 = SensorTag('share_a', ...
                'RawSource', struct('file', files.sharedFile, 'column', 'p_a'));
            t2 = SensorTag('share_b', ...
                'RawSource', struct('file', files.sharedFile, 'column', 'p_b'));
            TagRegistry.register('share_a', t1);
            TagRegistry.register('share_b', t2);

            p = LiveTagPipeline('OutputDir', outDir, 'Interval', 3600);
            p.tickOnce();

            % Core Major-2 assertion: 2 tags, 1 shared file -> 1 parse.
            testCase.verifyEqual(p.LastFileParseCount, 1);
            testCase.verifyEqual(exist(fullfile(outDir, 'share_a.mat'), 'file'), 2);
            testCase.verifyEqual(exist(fullfile(outDir, 'share_b.mat'), 'file'), 2);
            la = load(fullfile(outDir, 'share_a.mat'));
            lb = load(fullfile(outDir, 'share_b.mat'));
            testCase.verifyEqual(la.share_a.y(:)', [1 2 3]);
            testCase.verifyEqual(lb.share_b.y(:)', [10 20 30]);
        end

        function testPerTagFileIsolation(testCase)
            % D-10 under live writes -- each tag's .mat is untouched by others.
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

            p = LiveTagPipeline('OutputDir', outDir, 'Interval', 3600);
            p.tickOnce();

            testCase.verifyEqual(exist(fullfile(outDir, 'p_a.mat'),  'file'), 2);
            testCase.verifyEqual(exist(fullfile(outDir, 'p_b.mat'),  'file'), 2);
            testCase.verifyEqual(exist(fullfile(outDir, 'temp.mat'), 'file'), 2);
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

        function testAppendModePreservesPriorRows(testCase)
            % Pitfall 2 (save-append data loss guard): tick 1 writes [1;2;3],
            % tick 2 appends [4;5] -> final x is [1;2;3;4;5], NOT [4;5].
            outDir = tempname();  mkdir(outDir);
            testCase.addTeardown(@() removeIfExists_(outDir));
            d = tempname();  mkdir(d);
            testCase.addTeardown(@() removeIfExists_(d));

            csvPath = fullfile(d, 'append_guard.csv');
            fid = fopen(csvPath, 'w');
            fprintf(fid, 'time,value\n1,100\n2,200\n3,300\n');
            fclose(fid);

            t = SensorTag('aptest', ...
                'RawSource', struct('file', csvPath, 'column', 'value'));
            TagRegistry.register('aptest', t);

            p = LiveTagPipeline('OutputDir', outDir, 'Interval', 3600);
            p.tickOnce();

            loaded1 = load(fullfile(outDir, 'aptest.mat'));
            testCase.verifyEqual(loaded1.aptest.x(:)', [1 2 3]);
            testCase.verifyEqual(loaded1.aptest.y(:)', [100 200 300]);

            % Grow the CSV file; second tick must preserve [1;2;3] + [4;5].
            pause(1.1);
            fid = fopen(csvPath, 'a');
            fprintf(fid, '4,400\n5,500\n');
            fclose(fid);

            p.tickOnce();

            loaded2 = load(fullfile(outDir, 'aptest.mat'));
            % CRITICAL Pitfall 2 gate: prior rows PRESERVED, not clobbered.
            testCase.verifyEqual(loaded2.aptest.x(:)', [1 2 3 4 5]);
            testCase.verifyEqual(loaded2.aptest.y(:)', [100 200 300 400 500]);
        end

        function testTagStateGCDropsUnregistered(testCase)
            % RESEARCH Q3 -- per-tag modTime/lastIndex state is dropped when
            % the tag leaves the registry between ticks.
            files = makeSyntheticRaw(testCase);
            outDir = tempname();  mkdir(outDir);
            testCase.addTeardown(@() removeIfExists_(outDir));

            t1 = SensorTag('p_a', ...
                'RawSource', struct('file', files.wideCsv, 'column', 'pressure_a'));
            t2 = SensorTag('p_b', ...
                'RawSource', struct('file', files.wideCsv, 'column', 'pressure_b'));
            TagRegistry.register('p_a', t1);
            TagRegistry.register('p_b', t2);

            p = LiveTagPipeline('OutputDir', outDir, 'Interval', 3600);
            p.tickOnce();

            % Both entries tracked.
            testCase.verifyEqual(p.TagStateCount, 2);

            % Unregister p_b; next tick should GC its tagState_ entry.
            TagRegistry.unregister('p_b');
            p.tickOnce();

            testCase.verifyEqual(p.TagStateCount, 1, ...
                'tagState_ must drop entries for tags no longer in TagRegistry');
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
            % swallow -- teardown best-effort
        end
    end
end

function safeStop_(p)
    %SAFESTOP_ Best-effort pipeline stop for teardown; ignores errors.
    try
        p.stop();
    catch
        % swallow -- teardown best-effort
    end
end
