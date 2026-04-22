classdef TestBatchTagPipeline < matlab.unittest.TestCase
    %TESTBATCHTAGPIPELINE Phase 1012 Wave 0 RED placeholders for
    % BatchTagPipeline (Plan 04). Every method body is a verifyFail that
    % Wave 2 / Plan 04 replaces with real assertions.
    %
    % Coverage matrix per VALIDATION.md §Per-Task Verification Map:
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
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'libs', 'EventDetection'));
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'libs', 'SensorThreshold'));
            install();
        end
    end

    methods (Test)
        function testConstructorRequiresOutputDir(testCase)
            % TagPipeline:invalidOutputDir
            testCase.verifyFail('Wave 3 not yet implemented');
        end

        function testConstructorCreatesOutputDirIfMissing(testCase)
            % D-15 auto-mkdir
            testCase.verifyFail('Wave 3 not yet implemented');
        end

        function testErrorCannotCreateOutputDir(testCase)
            % TagPipeline:cannotCreateOutputDir
            testCase.verifyFail('Wave 3 not yet implemented');
        end

        function testWideFileFanOut(testCase)
            % D-04 wide dispatch
            testCase.verifyFail('Wave 3 not yet implemented');
        end

        function testTallFileTwoColumn(testCase)
            % D-04 tall dispatch
            testCase.verifyFail('Wave 3 not yet implemented');
        end

        function testRoundTripThroughSensorTagLoad(testCase)
            % D-09 end-to-end round-trip through SensorTag.load
            testCase.verifyFail('Wave 3 not yet implemented');
        end

        function testOneMatFilePerTag(testCase)
            % D-10 strict one-tag-per-mat
            testCase.verifyFail('Wave 3 not yet implemented');
        end

        function testStateTagCellstrRoundTrip(testCase)
            % D-11 cellstr Y on StateTag
            testCase.verifyFail('Wave 3 not yet implemented');
        end

        function testFileCacheDedup(testCase)
            % D-07 + Major-2 LastFileParseCount == 1 for 2 tags sharing a file
            testCase.verifyFail('Wave 3 not yet implemented');
        end

        function testSilentSkipMonitorTag(testCase)
            % D-08 + D-16 (MonitorTag silently skipped even if has RawSource)
            testCase.verifyFail('Wave 3 not yet implemented');
        end

        function testSilentSkipTagWithoutRawSource(testCase)
            % D-08 (SensorTag with no RawSource skipped silently)
            testCase.verifyFail('Wave 3 not yet implemented');
        end

        function testCompositeTagNotMaterialized(testCase)
            % D-16 CompositeTag never written to disk
            testCase.verifyFail('Wave 3 not yet implemented');
        end

        function testMonitorPersistPathUntouched(testCase)
            % D-17 MonitorTag.Persist = true path remains MONITOR-09's domain
            testCase.verifyFail('Wave 3 not yet implemented');
        end

        function testPerTagErrorIsolationContinuesToNext(testCase)
            % D-18 per-tag try/catch — one failing tag doesn't abort the run
            testCase.verifyFail('Wave 3 not yet implemented');
        end

        function testIngestFailedThrownAtEnd(testCase)
            % TagPipeline:ingestFailed raised at end of run when any tag failed
            testCase.verifyFail('Wave 3 not yet implemented');
        end

        function testErrorInvalidRawSource(testCase)
            % TagPipeline:invalidRawSource
            testCase.verifyFail('Wave 3 not yet implemented');
        end

        function testErrorInvalidWriteMode(testCase)
            % TagPipeline:invalidWriteMode
            testCase.verifyFail('Wave 3 not yet implemented');
        end

        function testDispatchUnknownExtension(testCase)
            % TagPipeline:unknownExtension (D-02 hidden dispatch table)
            testCase.verifyFail('Wave 3 not yet implemented');
        end
    end
end
