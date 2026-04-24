classdef TestDataSource < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'libs', 'EventDetection'));
            install();
        end
    end

    methods (Test)
        function testFetchNewMustBeImplementedBySubclass(testCase)
            % DataSource is the abstract interface for fetchNew. The class
            % itself can be instantiated, but calling fetchNew() on the base
            % class throws 'DataSource:abstract' — subclasses MUST override.
            ds = DataSource();
            testCase.verifyError(@() ds.fetchNew(), 'DataSource:abstract');
        end

        function testSubclassMustImplementFetchNew(testCase)
            mc = meta.class.fromName('DataSource');
            testCase.verifyNotEmpty(mc, 'class_exists');
            methods = {mc.MethodList.Name};
            testCase.verifyTrue(ismember('fetchNew', methods), 'has_fetchNew');
        end
    end
end
