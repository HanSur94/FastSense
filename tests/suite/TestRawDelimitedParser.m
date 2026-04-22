classdef TestRawDelimitedParser < matlab.unittest.TestCase
    %TESTRAWDELIMITEDPARSER Phase 1012 Wave 0 RED placeholders for
    % the shared delimited-text parser helpers (readRawDelimited_,
    % sniffDelimiter_, detectHeader_, selectTimeAndValue_) shipped in
    % Plan 03. Every method body is a verifyFail that Wave 1 / Plan 03
    % replaces with real assertions.
    %
    % Coverage matrix per VALIDATION.md §Per-Task Verification Map:
    %   - Delimiter sniffing (comma, tab, semicolon, whitespace)
    %   - Header detection (text-first-row vs all-numeric)
    %   - Wide vs tall parse paths (D-04)
    %   - Named-column selection (D-06)
    %   - 6 TagPipeline:* error IDs emitted by the parser layer (D-19):
    %       fileNotReadable, emptyFile, delimiterAmbiguous,
    %       missingColumn, noHeadersForNamedColumn, insufficientColumns
    %
    % See also: makeSyntheticRaw, TestBatchTagPipeline, TestLiveTagPipeline.

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'libs', 'EventDetection'));
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'libs', 'SensorThreshold'));
            install();
        end
    end

    methods (Test)
        function testSniffCommaDelimiter(testCase)
            % Wave 1 / Plan 03: sniffDelimiter_ returns ',' for comma-separated lines
            testCase.verifyFail('Wave 2 not yet implemented');
        end

        function testSniffTabDelimiter(testCase)
            testCase.verifyFail('Wave 2 not yet implemented');
        end

        function testSniffSemicolonDelimiter(testCase)
            testCase.verifyFail('Wave 2 not yet implemented');
        end

        function testSniffWhitespaceDelimiter(testCase)
            testCase.verifyFail('Wave 2 not yet implemented');
        end

        function testDetectHeaderWithTextFirstRow(testCase)
            testCase.verifyFail('Wave 2 not yet implemented');
        end

        function testDetectNoHeaderAllNumeric(testCase)
            testCase.verifyFail('Wave 2 not yet implemented');
        end

        function testParseWideCsvReturnsAllColumns(testCase)
            testCase.verifyFail('Wave 2 not yet implemented');
        end

        function testParseTallTxtNoHeader(testCase)
            testCase.verifyFail('Wave 2 not yet implemented');
        end

        function testParseTabDat(testCase)
            testCase.verifyFail('Wave 2 not yet implemented');
        end

        function testErrorFileNotReadable(testCase)
            % TagPipeline:fileNotReadable
            testCase.verifyFail('Wave 2 not yet implemented');
        end

        function testErrorEmptyFile(testCase)
            % TagPipeline:emptyFile
            testCase.verifyFail('Wave 2 not yet implemented');
        end

        function testErrorDelimiterAmbiguous(testCase)
            % TagPipeline:delimiterAmbiguous
            testCase.verifyFail('Wave 2 not yet implemented');
        end

        function testSelectTimeAndValueWideByName(testCase)
            testCase.verifyFail('Wave 2 not yet implemented');
        end

        function testSelectTimeAndValueTallNoColumn(testCase)
            testCase.verifyFail('Wave 2 not yet implemented');
        end

        function testErrorMissingColumn(testCase)
            % TagPipeline:missingColumn
            testCase.verifyFail('Wave 2 not yet implemented');
        end

        function testErrorNoHeadersForNamedColumn(testCase)
            % TagPipeline:noHeadersForNamedColumn
            testCase.verifyFail('Wave 2 not yet implemented');
        end

        function testErrorInsufficientColumns(testCase)
            % TagPipeline:insufficientColumns
            testCase.verifyFail('Wave 2 not yet implemented');
        end

        function testTimeColumnResolutionByName(testCase)
            testCase.verifyFail('Wave 2 not yet implemented');
        end
    end
end
