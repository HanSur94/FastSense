classdef TestDelimitedParseParity < matlab.unittest.TestCase
    %TESTDELIMITEDPARSEPARITY K1 delimited_parse MEX-vs-fallback parity (Wave 0 scaffold).
    %   Asserts struct-field equality between delimited_parse_mex and the
    %   existing readRawDelimited_ over a small corpus of synthetic CSVs.
    %
    %   K1 signature (per phase 1028 RESEARCH §K1):
    %     out = delimited_parse_mex(path)
    %     where out has fields: headers, data, delimiter, hasHeader.
    %
    %   Wave 0: scaffold (assumeTrue gate skips until Wave 1 plan 02 lands).
    %
    %   See also: delimited_parse_mex (Wave 1), readRawDelimited_.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            addpath(repo);
            install();
        end
    end

    methods (Test)
        function testFixture1_5x3_comma_header(testCase)
            mexAvailable      = exist('delimited_parse_mex', 'file') == 3;
            fallbackAvailable = exist('readRawDelimited_',   'file') == 2;
            testCase.assumeTrue(mexAvailable && fallbackAvailable, ...
                'delimited_parse_mex / readRawDelimited_ not yet built (Wave 1 plan 02 lands the MEX).');
            path = makeFixtureCsv_('comma', true, 5, 3, 'int');
            cleanup = onCleanup(@() safeDelete_(path)); %#ok<NASGU>
            assertParseParity_(testCase, path);
        end

        function testFixture2_100x4_semi_noheader_floats(testCase)
            mexAvailable      = exist('delimited_parse_mex', 'file') == 3;
            fallbackAvailable = exist('readRawDelimited_',   'file') == 2;
            testCase.assumeTrue(mexAvailable && fallbackAvailable, ...
                'delimited_parse_mex / readRawDelimited_ not yet built (Wave 1 plan 02 lands the MEX).');
            path = makeFixtureCsv_(';', false, 100, 4, 'float');
            cleanup = onCleanup(@() safeDelete_(path)); %#ok<NASGU>
            assertParseParity_(testCase, path);
        end

        function testFixture3_1000x8_tab_header_mixed(testCase)
            mexAvailable      = exist('delimited_parse_mex', 'file') == 3;
            fallbackAvailable = exist('readRawDelimited_',   'file') == 2;
            testCase.assumeTrue(mexAvailable && fallbackAvailable, ...
                'delimited_parse_mex / readRawDelimited_ not yet built (Wave 1 plan 02 lands the MEX).');
            path = makeFixtureCsv_(sprintf('\t'), true, 1000, 8, 'mixed');
            cleanup = onCleanup(@() safeDelete_(path)); %#ok<NASGU>
            assertParseParity_(testCase, path);
        end
    end
end

function assertParseParity_(testCase, path)
    %ASSERTPARSEPARITY_ Parse path with both implementations; compare structs.
    outMex = delimited_parse_mex(path);
    outFb  = readRawDelimited_(path);

    testCase.verifyEqual(outMex.delimiter, outFb.delimiter, 'delimiter must match');
    testCase.verifyEqual(logical(outMex.hasHeader), logical(outFb.hasHeader), ...
        'hasHeader must match');
    testCase.verifyEqual(outMex.headers, outFb.headers, 'headers (cellstr) must match');
    if isnumeric(outFb.data) && isnumeric(outMex.data)
        testCase.verifyTrue(isequaln(outMex.data, outFb.data), 'numeric data must match');
    else
        testCase.verifyEqual(outMex.data, outFb.data, 'cell data must match');
    end
end

function path = makeFixtureCsv_(delim, hasHeader, nRows, nCols, kind)
    %MAKEFIXTURECSV_ Materialize a synthetic CSV under tempdir.
    base = tempname();
    path = [base '.csv'];
    fid = fopen(path, 'w');
    if fid == -1
        error('TestDelimitedParseParity:fixture', 'Cannot create %s', path);
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

    if hasHeader
        headers = cell(1, nCols);
        for c = 1:nCols
            headers{c} = sprintf('col_%d', c);
        end
        fprintf(fid, '%s\n', strjoin(headers, delim));
    end

    for r = 1:nRows
        row = cell(1, nCols);
        for c = 1:nCols
            switch kind
                case 'int'
                    row{c} = sprintf('%d', r * 10 + c);
                case 'float'
                    row{c} = sprintf('%.6f', -50 + sin(r * 0.1) * c);
                case 'mixed'
                    if c == 1
                        row{c} = sprintf('%.3f', r * 0.5);
                    else
                        row{c} = sprintf('%.3f', cos(r * 0.05 * c));
                    end
                otherwise
                    row{c} = '0';
            end
        end
        fprintf(fid, '%s\n', strjoin(row, delim));
    end
end

function safeDelete_(path)
    try
        if exist(path, 'file')
            delete(path);
        end
    catch
    end
end
