classdef TestPlantLogHash < matlab.unittest.TestCase
%TESTPLANTLOGHASH Class-based MATLAB-only suite for hash determinism / sort-stability.
%   Hash helpers live under libs/PlantLog/private/ and are exercised
%   indirectly via PlantLogEntry.RowHash. Mirrors tests/test_plant_log_hash.m.

    methods (TestClassSetup)
        function addPaths(testCase)  %#ok<MANU>
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
            repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
            addpath(fullfile(repo_root, 'libs', 'PlantLog'));
        end
    end

    methods (Test)
        function testDeterminism(testCase)
            md = struct('A', 1, 'B', 'x');
            e1 = PlantLogEntry('Timestamp', 1, 'Message', 'hello', 'Metadata', md);
            e2 = PlantLogEntry('Timestamp', 1, 'Message', 'hello', 'Metadata', md);
            testCase.verifyEqual(e1.RowHash, e2.RowHash);
        end

        function testSortStability(testCase)
            md1 = struct('A', 1, 'B', 'x');
            md2 = struct('B', 'x', 'A', 1);
            e1 = PlantLogEntry('Timestamp', 1, 'Message', 'hello', 'Metadata', md1);
            e2 = PlantLogEntry('Timestamp', 1, 'Message', 'hello', 'Metadata', md2);
            testCase.verifyEqual(e1.RowHash, e2.RowHash);
        end

        function testSensitivityMessage(testCase)
            md = struct('A', 1);
            e1 = PlantLogEntry('Timestamp', 1, 'Message', 'hello', 'Metadata', md);
            e2 = PlantLogEntry('Timestamp', 1, 'Message', 'world', 'Metadata', md);
            testCase.verifyNotEqual(e1.RowHash, e2.RowHash);
        end

        function testSensitivityMetadata(testCase)
            e1 = PlantLogEntry('Timestamp', 1, 'Message', 'x', 'Metadata', struct('A', 1));
            e2 = PlantLogEntry('Timestamp', 1, 'Message', 'x', 'Metadata', struct('A', 2));
            testCase.verifyNotEqual(e1.RowHash, e2.RowHash);
        end

        function testShape(testCase)
            e = PlantLogEntry('Timestamp', 1, 'Message', 'x', 'Metadata', struct());
            testCase.verifyMatches(e.RowHash, '^[0-9a-f]{16}$');
        end

        function testEmptySeed(testCase)
            e = PlantLogEntry('Timestamp', 1, 'Message', '', 'Metadata', struct());
            testCase.verifyEqual(e.RowHash, '0000000000001505');
        end
    end
end
