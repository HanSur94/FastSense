classdef TestPlantLogReader < matlab.unittest.TestCase
%TESTPLANTLOGREADER MATLAB class-based suite for PlantLogReader.
%
%   Mirrors tests/test_plant_log_reader.m. Covers autoDetect on ISO/EU/US
%   tables, readFile happy path + error paths, and integration with
%   PlantLogStore.addEntries. Class-based suite is MATLAB-only; Octave
%   runs the function-style version.

    properties (Access = private)
        TmpFiles = {}
    end

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            this_dir = fileparts(mfilename('fullpath'));
            tests_dir = fileparts(this_dir);
            repo_root = fileparts(tests_dir);
            addpath(repo_root);
            install();
        end
    end

    methods (TestMethodTeardown)
        function cleanupTmp(testCase)
            for k = 1:numel(testCase.TmpFiles)
                p = testCase.TmpFiles{k};
                try
                    if exist(p, 'file') == 2
                        delete(p);
                    end
                catch
                end
            end
            testCase.TmpFiles = {};
        end
    end

    methods (Test)

        function testAutoDetectIso(testCase)
            p = testCase.writeCsv_({ ...
                {'2025-01-15 12:00:00', 'Pump A on', 'M1'}, ...
                {'2025-01-15 12:05:00', 'Pump A off', 'M1'}, ...
                {'2025-01-15 12:10:00', 'Pump B on', 'M2'}}, ...
                {'Time', 'Description', 'Machine'});
            T = readtable(p);
            m = PlantLogReader.autoDetect(T);
            testCase.verifyEqual(m.TimestampColumn, 'Time');
            testCase.verifyEqual(m.TimestampFormat, '');
        end

        function testAutoDetectEu(testCase)
            p = testCase.writeCsv_({ ...
                {'15.01.2025 12:00:00', 'msg1'}, ...
                {'15.01.2025 12:05:00', 'msg2'}, ...
                {'15.01.2025 12:10:00', 'msg3'}}, ...
                {'Zeit', 'Text'});
            T = readtable(p);
            m = PlantLogReader.autoDetect(T);
            testCase.verifyEqual(m.TimestampColumn, 'Zeit');
        end

        function testAutoDetectUs(testCase)
            p = testCase.writeCsv_({ ...
                {'01/15/2025', 'note 1'}, ...
                {'01/16/2025', 'note 2'}, ...
                {'01/17/2025', 'note 3'}}, ...
                {'Date', 'Note'});
            T = readtable(p);
            m = PlantLogReader.autoDetect(T);
            testCase.verifyEqual(m.TimestampColumn, 'Date');
        end

        function testAutoDetectNoTimestampColumn(testCase)
            p = testCase.writeCsv_({ ...
                {'apple',  'red'},  ...
                {'banana', 'yellow'}, ...
                {'cherry', 'red'}}, ...
                {'Fruit', 'Color'});
            T = readtable(p);
            m = PlantLogReader.autoDetect(T);
            testCase.verifyEqual(m.TimestampColumn, '');
        end

        function testReadFileBasic(testCase)
            p = testCase.writeCsv_({ ...
                {'2025-01-15 12:00:00', 'Pump A on', 'M1'}, ...
                {'2025-01-15 12:05:00', 'Pump A off', 'M1'}}, ...
                {'Time', 'Description', 'Machine'});
            m = struct('TimestampColumn', 'Time', 'MessageColumn', 'Description', 'TimestampFormat', '');
            entries = PlantLogReader.readFile(p, m);
            testCase.verifyEqual(numel(entries), 2);
            testCase.verifyClass(entries, 'PlantLogEntry');
            testCase.verifyEqual(entries(1).Message, 'Pump A on');
        end

        function testReadFileEmpty(testCase)
            p = [tempname() '.csv'];
            testCase.TmpFiles{end+1} = p;
            fid = fopen(p, 'w'); fprintf(fid, 'Time,Msg\n'); fclose(fid);
            m = struct('TimestampColumn', 'Time', 'MessageColumn', 'Msg', 'TimestampFormat', '');
            entries = PlantLogReader.readFile(p, m);
            testCase.verifyTrue(isempty(entries));
        end

        function testReadFileUnknownColumn(testCase)
            p = testCase.writeCsv_({{'2025-01-15 12:00:00', 'hi'}}, {'Time', 'Msg'});
            m = struct('TimestampColumn', 'NoSuchColumn', 'MessageColumn', 'Msg', 'TimestampFormat', '');
            testCase.verifyError(@() PlantLogReader.readFile(p, m), 'PlantLogReader:unknownColumn');
        end

        function testReadFileNotFound(testCase)
            m = struct('TimestampColumn', 'Time', 'MessageColumn', 'Msg', 'TimestampFormat', '');
            testCase.verifyError(@() PlantLogReader.readFile('/nonexistent/path.csv', m), ...
                'PlantLogReader:fileNotFound');
        end

        function testReadFileUnsupportedFormat(testCase)
            p = [tempname() '.json'];
            testCase.TmpFiles{end+1} = p;
            fid = fopen(p, 'w'); fprintf(fid, '{}\n'); fclose(fid);
            m = struct('TimestampColumn', 'Time', 'MessageColumn', 'Msg', 'TimestampFormat', '');
            testCase.verifyError(@() PlantLogReader.readFile(p, m), ...
                'PlantLogReader:unsupportedFormat');
        end

        function testReadFileFlowsIntoStore(testCase)
            p = testCase.writeCsv_({ ...
                {'2025-01-15 12:00:00', 'first',  'M1'}, ...
                {'2025-01-15 12:05:00', 'second', 'M2'}}, ...
                {'Time', 'Msg', 'Machine'});
            m = struct('TimestampColumn', 'Time', 'MessageColumn', 'Msg', 'TimestampFormat', '');
            entries = PlantLogReader.readFile(p, m);
            store = PlantLogStore(p);
            store.addEntries(entries);
            testCase.verifyEqual(store.getCount(), numel(entries));
        end

    end

    methods (Access = private)
        function p = writeCsv_(testCase, rows, headers)
            p = [tempname() '.csv'];
            testCase.TmpFiles{end+1} = p;
            fid = fopen(p, 'w');
            cleanup = onCleanup(@() fclose(fid));
            fprintf(fid, '%s\n', strjoin(headers, ','));
            for r = 1:numel(rows)
                fprintf(fid, '%s\n', strjoin(rows{r}, ','));
            end
        end
    end
end
