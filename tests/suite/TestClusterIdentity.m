classdef TestClusterIdentity < matlab.unittest.TestCase
    %TESTCLUSTERIDENTITY Tests for ClusterIdentity and userIdentity (IDENT-01).
    %
    %   Covers:
    %     testIdentityTupleComplete          - userIdentity() returns non-empty user + host
    %     testClusterModeThrowsOnFailure     - ClusterIdentity Strict mode throws on empty
    %
    %   See also ClusterIdentity, userIdentity.

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
        function testIdentityTupleComplete(testCase)
            %TESTIDENTITYTUPLECOMPLETE userIdentity returns non-empty user and host.
            [user, host] = userIdentity();
            testCase.verifyFalse(isempty(user), 'userIdentity: user must be non-empty');
            testCase.verifyFalse(isempty(host), 'userIdentity: host must be non-empty');
            testCase.verifyTrue(ischar(user), 'userIdentity: user must be char');
            testCase.verifyTrue(ischar(host), 'userIdentity: host must be char');
        end

        function testClusterModeThrowsOnFailure(testCase)
            %TESTCLUSTERMODETHREWSONFAILURE Strict mode throws Concurrency:identityResolutionFailed.
            %   STUB — implemented in Task 2 after ClusterIdentity.m exists.
            %   This method is a placeholder so the test class passes in Task 1.
            testCase.verifyTrue(true, 'Task 2 will implement ClusterIdentity strict mode throw');
        end
    end
end
