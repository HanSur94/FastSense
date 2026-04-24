classdef TestRawDelimitedParser < matlab.unittest.TestCase
    %TESTRAWDELIMITEDPARSER Phase 1012 Wave 1 GREEN suite for the shared
    % delimited-text parser helpers (readRawDelimited_, sniffDelimiter_,
    % detectHeader_, selectTimeAndValue_) shipped in Plan 03. All tests
    % invoke the private helpers via the public shim
    % readRawDelimitedForTest_ (revision-1 / Major-1 Option A).
    %
    % Coverage matrix per VALIDATION.md Per-Task Verification Map:
    %   - Delimiter sniffing (comma, tab, semicolon, whitespace)
    %   - Header detection (text-first-row vs all-numeric)
    %   - Wide vs tall parse paths (D-04)
    %   - Named-column selection (D-06)
    %   - 6 TagPipeline:* error IDs emitted by the parser layer (D-19):
    %       fileNotReadable, emptyFile, delimiterAmbiguous,
    %       missingColumn, noHeadersForNamedColumn, insufficientColumns
    %
    % See also: makeSyntheticRaw, TestBatchTagPipeline, TestLiveTagPipeline,
    % readRawDelimitedForTest_ (shim), readRawDelimited_ (private),
    % selectTimeAndValue_ (private).

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'libs', 'EventDetection'));
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'libs', 'SensorThreshold'));
            install();
        end
    end

    methods (Test)

        % ---- sniffDelimiter_ (exercised through 'sniff' dispatch) ----

        function testSniffCommaDelimiter(testCase)
            files = makeSyntheticRaw(testCase);
            d = readRawDelimitedForTest_('sniff', files.wideCsv);
            testCase.verifyEqual(d, ',');
        end

        function testSniffTabDelimiter(testCase)
            files = makeSyntheticRaw(testCase);
            d = readRawDelimitedForTest_('sniff', files.tallDat);
            testCase.verifyEqual(double(d), 9);  % tab
        end

        function testSniffSemicolonDelimiter(testCase)
            files = makeSyntheticRaw(testCase);
            d = readRawDelimitedForTest_('sniff', files.semiCsv);
            testCase.verifyEqual(d, ';');
        end

        function testSniffWhitespaceDelimiter(testCase)
            files = makeSyntheticRaw(testCase);
            d = readRawDelimitedForTest_('sniff', files.tallTxt);
            testCase.verifyEqual(d, ' ');
        end

        % ---- Header detection (exercised through 'parse' dispatch) ----

        function testDetectHeaderWithTextFirstRow(testCase)
            files = makeSyntheticRaw(testCase);
            p = readRawDelimitedForTest_('parse', files.wideCsv);
            testCase.verifyTrue(p.hasHeader);
            testCase.verifyEqual(p.headers, {'time','pressure_a','pressure_b','temperature'});
        end

        function testDetectNoHeaderAllNumeric(testCase)
            files = makeSyntheticRaw(testCase);
            p = readRawDelimitedForTest_('parse', files.tallTxt);
            testCase.verifyFalse(p.hasHeader);
            testCase.verifyEmpty(p.headers);
        end

        % ---- Parse: shape fidelity ----

        function testParseWideCsvReturnsAllColumns(testCase)
            files = makeSyntheticRaw(testCase);
            p = readRawDelimitedForTest_('parse', files.wideCsv);
            testCase.verifyEqual(p.delimiter, ',');
            testCase.verifyTrue(p.hasHeader);
            testCase.verifyEqual(size(p.data), [3 4]);
            testCase.verifyEqual(p.data, [1 10 20 30; 2 11 21 31; 3 12 22 32]);
        end

        function testParseTallTxtNoHeader(testCase)
            files = makeSyntheticRaw(testCase);
            p = readRawDelimitedForTest_('parse', files.tallTxt);
            testCase.verifyEqual(p.delimiter, ' ');
            testCase.verifyFalse(p.hasHeader);
            testCase.verifyEqual(p.data, [1 100; 2 101; 3 102]);
        end

        function testParseTabDat(testCase)
            files = makeSyntheticRaw(testCase);
            p = readRawDelimitedForTest_('parse', files.tallDat);
            testCase.verifyEqual(double(p.delimiter), 9);
            testCase.verifyTrue(p.hasHeader);
            testCase.verifyEqual(p.headers, {'time','flow_rate'});
            testCase.verifyEqual(size(p.data), [3 2]);
        end

        % ---- Error IDs (D-19) ----

        function testErrorFileNotReadable(testCase)
            testCase.verifyError( ...
                @() readRawDelimitedForTest_('parse', '/nonexistent/path/bogus.csv'), ...
                'TagPipeline:fileNotReadable');
        end

        function testErrorEmptyFile(testCase)
            files = makeSyntheticRaw(testCase);
            testCase.verifyError( ...
                @() readRawDelimitedForTest_('parse', files.empty), ...
                'TagPipeline:emptyFile');
            % Header-only file is also empty (no data rows).
            testCase.verifyError( ...
                @() readRawDelimitedForTest_('parse', files.headerOnly), ...
                'TagPipeline:emptyFile');
        end

        function testErrorDelimiterAmbiguous(testCase)
            files = makeSyntheticRaw(testCase);
            testCase.verifyError( ...
                @() readRawDelimitedForTest_('parse', files.corrupt), ...
                'TagPipeline:delimiterAmbiguous');
        end

        % ---- selectTimeAndValue_ (exercised through 'select' dispatch) ----

        function testSelectTimeAndValueWideByName(testCase)
            files = makeSyntheticRaw(testCase);
            parsed = readRawDelimitedForTest_('parse', files.wideCsv);
            rs = struct('file', files.wideCsv, 'column', 'pressure_b', 'format', '');
            out = readRawDelimitedForTest_('select', parsed, rs);
            testCase.verifyEqual(out{1}, [1; 2; 3]);
            testCase.verifyEqual(out{2}, [20; 21; 22]);
        end

        function testSelectTimeAndValueTallNoColumn(testCase)
            files = makeSyntheticRaw(testCase);
            parsed = readRawDelimitedForTest_('parse', files.tallTxt);
            rs = struct('file', files.tallTxt, 'column', '', 'format', '');
            out = readRawDelimitedForTest_('select', parsed, rs);
            testCase.verifyEqual(out{1}, [1; 2; 3]);
            testCase.verifyEqual(out{2}, [100; 101; 102]);
        end

        function testErrorMissingColumn(testCase)
            files = makeSyntheticRaw(testCase);
            parsed = readRawDelimitedForTest_('parse', files.missingColumn);
            % 2 cols, but RawSource names a column that does not exist
            rs = struct('file', files.missingColumn, 'column', 'pressure_b', 'format', '');
            testCase.verifyError( ...
                @() readRawDelimitedForTest_('select', parsed, rs), ...
                'TagPipeline:missingColumn');
            % Also: wide file (3 cols) with no column field -> missingColumn
            parsedWide = readRawDelimitedForTest_('parse', files.sharedFile);
            rsNoCol = struct('file', files.sharedFile, 'format', '');
            testCase.verifyError( ...
                @() readRawDelimitedForTest_('select', parsedWide, rsNoCol), ...
                'TagPipeline:missingColumn');
        end

        function testErrorNoHeadersForNamedColumn(testCase)
            files = makeSyntheticRaw(testCase);
            % Build a no-header wide file on the fly (3 cols of numerics)
            fn = fullfile(files.dir, 'nohdr_wide.csv');
            fid = fopen(fn, 'w');
            fprintf(fid, '1,10,20\n2,11,21\n3,12,22\n');
            fclose(fid);
            parsed = readRawDelimitedForTest_('parse', fn);
            rs = struct('file', fn, 'column', 'pressure_a', 'format', '');
            testCase.verifyError( ...
                @() readRawDelimitedForTest_('select', parsed, rs), ...
                'TagPipeline:noHeadersForNamedColumn');
        end

        function testErrorInsufficientColumns(testCase)
            files = makeSyntheticRaw(testCase); %#ok<NASGU>
            % Construct a 1-column parsed struct manually (parser rejects
            % this earlier via delimiter sniffing, but the dispatcher must
            % still have its own guard).
            parsed = struct('headers', {{'only'}}, 'data', [1; 2; 3], ...
                'delimiter', ',', 'hasHeader', true);
            rs = struct('file', '', 'column', '', 'format', '');
            testCase.verifyError( ...
                @() readRawDelimitedForTest_('select', parsed, rs), ...
                'TagPipeline:insufficientColumns');
        end

        function testTimeColumnResolutionByName(testCase)
            files = makeSyntheticRaw(testCase);
            % wideCsv has 'time' header -> time column = col 1. Verify by
            % selecting 'temperature' and confirming x comes from 'time'.
            parsed = readRawDelimitedForTest_('parse', files.wideCsv);
            rs = struct('file', files.wideCsv, 'column', 'temperature', 'format', '');
            out = readRawDelimitedForTest_('select', parsed, rs);
            testCase.verifyEqual(out{1}, [1; 2; 3]);
            testCase.verifyEqual(out{2}, [30; 31; 32]);
        end

    end
end
