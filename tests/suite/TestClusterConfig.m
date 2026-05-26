classdef TestClusterConfig < matlab.unittest.TestCase
    %TESTCLUSTERCONFIG Tests for ClusterConfig.resolve() and SharedPaths (—).
    %
    %   Covers:
    %     testResolutionPrecedence    - explicit opt > env var > single-user default
    %     testSharedPathsRoot         - SharedPaths path builders return correct paths
    %
    %   See also ClusterConfig, SharedPaths.

    methods (TestClassSetup)
        function addPaths(~)
            here = fileparts(mfilename('fullpath'));
            root = fileparts(fileparts(here));   % up from tests/suite/ to repo root
            addpath(root);
            addpath(fullfile(root, 'libs', 'Concurrency'));
            install();
        end
    end

    methods (Test)
        function testResolutionPrecedence(testCase)
            %TESTRESOLUTIONPRECEDENCE ClusterConfig.resolve() honours precedence chain.
            priorEnv = getenv('FASTSENSE_SHARED_ROOT');
            cleanup = onCleanup(@() setenv('FASTSENSE_SHARED_ROOT', priorEnv));

            % Case 1: nothing set -> IsClusterMode=false, SharedRoot=''
            setenv('FASTSENSE_SHARED_ROOT', '');
            cfg = ClusterConfig.resolve();
            testCase.verifyFalse(cfg.IsClusterMode, 'Case 1: no opts/env -> not cluster mode');
            testCase.verifyEqual(cfg.SharedRoot, '', 'Case 1: SharedRoot must be empty');

            % Case 2: env var only -> IsClusterMode=true
            tmpRoot = tempname();
            mkdir(tmpRoot);
            rmDir = onCleanup(@() rmdir(tmpRoot, 's'));
            setenv('FASTSENSE_SHARED_ROOT', tmpRoot);
            cfg = ClusterConfig.resolve();
            testCase.verifyTrue(cfg.IsClusterMode, 'Case 2: env var set -> cluster mode');
            testCase.verifyEqual(cfg.SharedRoot, tmpRoot, 'Case 2: SharedRoot must equal env var');

            % Case 3: explicit opt + env var -> opt wins
            tmpRoot2 = tempname();
            mkdir(tmpRoot2);
            rmDir2 = onCleanup(@() rmdir(tmpRoot2, 's'));
            cfg = ClusterConfig.resolve(struct('SharedRoot', tmpRoot2));
            testCase.verifyEqual(cfg.SharedRoot, tmpRoot2, 'Case 3: opts.SharedRoot must win over env var');

            % Case 4: invalid SharedRoot throws Concurrency:sharedRootUnreachable
            testCase.verifyError( ...
                @() ClusterConfig.resolve(struct('SharedRoot', '/definitely/not/a/folder/xyzzy123')), ...
                'Concurrency:sharedRootUnreachable');
        end

        function testSharedPathsRoot(testCase)
            %TESTSHAREDPATHSROOT SharedPaths builders return correct subpaths.
            root = '/x';
            testCase.verifyEqual(SharedPaths.tagsDir(root),   fullfile(root, 'tags'));
            testCase.verifyEqual(SharedPaths.locksDir(root),  fullfile(root, 'locks'));
            testCase.verifyEqual(SharedPaths.eventsDir(root), fullfile(root, 'events'));

            % isClusterMode with no args -> false (single-user default)
            setenv('FASTSENSE_SHARED_ROOT', '');
            testCase.verifyFalse(SharedPaths.isClusterMode(), 'isClusterMode() default must be false');
        end
    end
end
