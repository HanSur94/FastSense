classdef TestPlantLogEntry < matlab.unittest.TestCase
%TESTPLANTLOGENTRY Class-based MATLAB-only suite for PlantLogEntry.
%   Mirrors tests/test_plant_log_entry.m one-to-one.

    methods (TestClassSetup)
        function addPaths(testCase)  %#ok<MANU>
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
            repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
            addpath(fullfile(repo_root, 'libs', 'PlantLog'));
        end
    end

    methods (Test)
        function testConstructorFromStruct(testCase)
            s = struct('Timestamp', 736000, 'Message', 'Pump A started', ...
                'Metadata', struct('MachineId', 'M1'), 'SourceFile', 'log.csv');
            e = PlantLogEntry(s);
            testCase.verifyEqual(e.Timestamp, 736000);
            testCase.verifyEqual(e.Message, 'Pump A started');
            testCase.verifyEqual(e.Metadata.MachineId, 'M1');
            testCase.verifyEqual(e.SourceFile, 'log.csv');
            testCase.verifyEqual(e.Id, '');
            testCase.verifyEqual(numel(e.RowHash), 16);
        end

        function testConstructorNameValue(testCase)
            e1 = PlantLogEntry(struct('Timestamp', 1, 'Message', 'x', 'Metadata', struct()));
            e2 = PlantLogEntry('Timestamp', 1, 'Message', 'x', 'Metadata', struct());
            testCase.verifyEqual(e1.RowHash, e2.RowHash);
        end

        function testRowHashAutoShape(testCase)
            e = PlantLogEntry('Timestamp', 1, 'Message', 'x', 'Metadata', struct());
            testCase.verifyMatches(e.RowHash, '^[0-9a-f]{16}$');
        end

        function testRowHashExplicit(testCase)
            e = PlantLogEntry('Timestamp', 1, 'Message', 'x', 'Metadata', struct(), ...
                'RowHash', 'aaaaaaaaaaaaaaaa');
            testCase.verifyEqual(e.RowHash, 'aaaaaaaaaaaaaaaa');
        end

        function testImmutability(testCase)
            e = PlantLogEntry('Timestamp', 1, 'Message', 'x', 'Metadata', struct());
            testCase.verifyError(@() setTimestamp(e), 'MATLAB:class:SetProhibited');
        end

        function testInvalidTimestampNaN(testCase)
            testCase.verifyError( ...
                @() PlantLogEntry('Timestamp', NaN, 'Message', 'x', 'Metadata', struct()), ...
                'PlantLogEntry:invalidInput');
        end

        function testInvalidMessage(testCase)
            testCase.verifyError( ...
                @() PlantLogEntry('Timestamp', 1, 'Message', 42, 'Metadata', struct()), ...
                'PlantLogEntry:typeMismatch');
        end

        function testInvalidMetadata(testCase)
            testCase.verifyError( ...
                @() PlantLogEntry('Timestamp', 1, 'Message', 'x', 'Metadata', 'bad'), ...
                'PlantLogEntry:typeMismatch');
        end

        function testUnknownOption(testCase)
            testCase.verifyError( ...
                @() PlantLogEntry('Timestamp', 1, 'Message', 'x', 'Metadata', struct(), 'Bogus', 1), ...
                'PlantLogEntry:unknownOption');
        end

        function testWithId(testCase)
            e = PlantLogEntry('Timestamp', 1, 'Message', 'x', 'Metadata', struct());
            e2 = e.withId('plog_42');
            testCase.verifyEqual(e2.Id, 'plog_42');
            testCase.verifyEqual(e.Id, '');
        end
    end
end

function setTimestamp(entry)
    %SETTIMESTAMP Helper that attempts a forbidden write to drive testImmutability.
    entry.Timestamp = 99;
end
