classdef TestGroupViolations < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
            TestGroupViolations.addEventPrivatePath();
        end
    end

    methods (Test)
        function testSingleGroup(testCase)
            t      = [1 2 3 4 5 6 7 8 9 10];
            values = [5 5 12 14 11 13 5 5 5 5];
            groups = groupViolations(t, values, 10, 'upper');
            testCase.verifyEqual(numel(groups), 1, 'singleGroup: count');
            testCase.verifyEqual(groups(1).startIdx, 3, 'singleGroup: startIdx');
            testCase.verifyEqual(groups(1).endIdx, 6, 'singleGroup: endIdx');
        end

        function testTwoGroups(testCase)
            t      = [1 2 3 4 5 6 7 8 9 10];
            values = [12 13 5 5 5 14 15 5 5 5];
            groups = groupViolations(t, values, 10, 'upper');
            testCase.verifyEqual(numel(groups), 2, 'twoGroups: count');
            testCase.verifyEqual(groups(1).startIdx, 1, 'twoGroups: g1 start');
            testCase.verifyEqual(groups(1).endIdx, 2, 'twoGroups: g1 end');
            testCase.verifyEqual(groups(2).startIdx, 6, 'twoGroups: g2 start');
            testCase.verifyEqual(groups(2).endIdx, 7, 'twoGroups: g2 end');
        end

        function testLowDirection(testCase)
            t      = [1 2 3 4 5];
            values = [50 3 2 4 50];
            groups = groupViolations(t, values, 10, 'lower');
            testCase.verifyEqual(numel(groups), 1, 'lowDir: count');
            testCase.verifyEqual(groups(1).startIdx, 2, 'lowDir: start');
            testCase.verifyEqual(groups(1).endIdx, 4, 'lowDir: end');
        end

        function testNoViolations(testCase)
            t      = [1 2 3 4 5];
            values = [5 6 7 8 9];
            groups = groupViolations(t, values, 10, 'upper');
            testCase.verifyEmpty(groups, 'noViolations: empty');
        end

        function testAllViolations(testCase)
            t      = [1 2 3];
            values = [20 30 40];
            groups = groupViolations(t, values, 10, 'upper');
            testCase.verifyEqual(numel(groups), 1, 'allViolations: count');
            testCase.verifyEqual(groups(1).startIdx, 1, 'allViolations: start');
            testCase.verifyEqual(groups(1).endIdx, 3, 'allViolations: end');
        end
    end

    methods (Static, Access = private)
        function addEventPrivatePath()
            suiteDir = fileparts(mfilename('fullpath'));
            repoRoot = fullfile(suiteDir, '..', '..');
            privDir = fullfile(repoRoot, 'libs', 'EventDetection', 'private');

            w = warning('off', 'all');
            addpath(privDir);
            warning(w);

            % Check if it actually landed on the path (R2025b rejects private/)
            dirs = strsplit(path, pathsep);
            if ~any(strcmp(dirs, privDir))
                tmpDir = fullfile(tempdir, 'event_detection_private_proxy');
                if ~exist(tmpDir, 'dir')
                    mkdir(tmpDir);
                end
                files = dir(fullfile(privDir, '*.m'));
                for i = 1:numel(files)
                    src = fullfile(privDir, files(i).name);
                    dst = fullfile(tmpDir, files(i).name);
                    copyfile(src, dst);
                end
                addpath(tmpDir);
            end
        end
    end
end
