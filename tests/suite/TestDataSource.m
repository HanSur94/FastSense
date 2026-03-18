classdef TestDataSource < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'libs', 'EventDetection'));
            install();
        end
    end

    methods (Test)
        function testCannotInstantiate(testCase)
            threw = false;
            try
                ds = DataSource();
                error('Should not reach here');
            catch ex
                threw = true;
                testCase.verifyTrue(contains(ex.message, 'Abstract'), 'cannot_instantiate');
            end
            testCase.verifyTrue(threw, 'DataSource should not be instantiable');
        end

        function testSubclassMustImplementFetchNew(testCase)
            mc = meta.class.fromName('DataSource');
            testCase.verifyNotEmpty(mc, 'class_exists');
            methods = {mc.MethodList.Name};
            testCase.verifyTrue(ismember('fetchNew', methods), 'has_fetchNew');
        end
    end
end
