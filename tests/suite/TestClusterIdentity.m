classdef TestClusterIdentity < matlab.unittest.TestCase
    %TESTCLUSTERIDENTITY Tests for ClusterIdentity and userIdentity (IDENT-01).
    %
    %   Covers:
    %     testIdentityTupleComplete          - ClusterIdentity.resolve() returns
    %                                          non-empty struct with all 4 fields
    %     testClusterModeThrowsOnFailure     - Strict mode throws on empty user/host
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
            %TESTIDENTITYTUPLECOMPLETE ClusterIdentity.resolve() returns all 4 fields.
            ClusterIdentity.clearCache();
            id = ClusterIdentity.resolve();

            % user: non-empty char
            testCase.verifyTrue(ischar(id.user), 'id.user must be char');
            testCase.verifyFalse(isempty(id.user), 'id.user must be non-empty');

            % host: non-empty char
            testCase.verifyTrue(ischar(id.host), 'id.host must be char');
            testCase.verifyFalse(isempty(id.host), 'id.host must be non-empty');

            % pid: int64 scalar > 0
            testCase.verifyEqual(class(id.pid), 'int64', 'id.pid must be int64');
            testCase.verifyGreaterThan(double(id.pid), 0, 'id.pid must be positive');

            % epoch: datetime
            testCase.verifyTrue(isa(id.epoch, 'datetime'), 'id.epoch must be datetime');

            ClusterIdentity.clearCache();
        end

        function testClusterModeThrowsOnFailure(testCase)
            %TESTCLUSTERMODETHREWSONFAILURE Strict mode throws Concurrency:identityResolutionFailed.
            %   Tests that an empty user triggers the error.
            ClusterIdentity.clearCache();
            testCase.verifyError( ...
                @() ClusterIdentity.resolve('Strict', true, 'OverrideUser', ''), ...
                'Concurrency:identityResolutionFailed');

            ClusterIdentity.clearCache();
            testCase.verifyError( ...
                @() ClusterIdentity.resolve('Strict', true, 'OverrideHost', ''), ...
                'Concurrency:identityResolutionFailed');

            ClusterIdentity.clearCache();
        end
    end
end
