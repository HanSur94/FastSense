classdef TestLiveTagPipeline < matlab.unittest.TestCase
    %TESTLIVETAGPIPELINE Phase 1012 Wave 0 RED placeholders for
    % LiveTagPipeline (Plan 05). Every method body is a verifyFail that
    % Wave 3 / Plan 05 replaces with real assertions.
    %
    % Coverage matrix per VALIDATION.md §Per-Task Verification Map:
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
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'libs', 'EventDetection'));
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'libs', 'SensorThreshold'));
            install();
        end
    end

    methods (Test)
        function testNoSubclassOfLiveEventPipeline(testCase)
            % D-14 — LiveTagPipeline must NOT subclass LiveEventPipeline
            testCase.verifyFail('Wave 4 not yet implemented');
        end

        function testConstructorRequiresOutputDir(testCase)
            % TagPipeline:invalidOutputDir
            testCase.verifyFail('Wave 4 not yet implemented');
        end

        function testStartSetsStatusRunning(testCase)
            % D-14 timer ergonomics (start/stop/Status)
            testCase.verifyFail('Wave 4 not yet implemented');
        end

        function testStopSetsStatusStopped(testCase)
            testCase.verifyFail('Wave 4 not yet implemented');
        end

        function testFirstTickWritesAll(testCase)
            % D-13 first tick = full read (lastIndex starts at 0)
            testCase.verifyFail('Wave 4 not yet implemented');
        end

        function testSecondTickWritesOnlyNewRows(testCase)
            % D-13 incremental append via modTime + lastIndex (uses pause(1.1))
            testCase.verifyFail('Wave 4 not yet implemented');
        end

        function testUnchangedFileSkipped(testCase)
            % D-13 modTime guard — identical mtime = no re-read
            testCase.verifyFail('Wave 4 not yet implemented');
        end

        function testDedupAcrossTagsPerTick(testCase)
            % D-07 live mode + Major-2 LastFileParseCount == 1 per shared file per tick
            testCase.verifyFail('Wave 4 not yet implemented');
        end

        function testPerTagFileIsolation(testCase)
            % D-10 under live writes — each tag's .mat is untouched by others
            testCase.verifyFail('Wave 4 not yet implemented');
        end

        function testAppendModePreservesPriorRows(testCase)
            % Pitfall 2 (save-append data loss guard): [1;2;3] then [4;5]
            % must result in [1;2;3;4;5] NOT [4;5]
            testCase.verifyFail('Wave 4 not yet implemented');
        end

        function testTagStateGCDropsUnregistered(testCase)
            % RESEARCH Q3 — per-tag modTime/lastIndex state is dropped when
            % the tag leaves the registry between ticks
            testCase.verifyFail('Wave 4 not yet implemented');
        end
    end
end
