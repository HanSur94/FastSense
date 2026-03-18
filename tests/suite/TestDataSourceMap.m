classdef TestDataSourceMap < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'libs', 'EventDetection'));
            install();
        end
    end

    methods (Test)
        function testAddAndGet(testCase)
            m = DataSourceMap();
            ds = MockDataSource('BaseValue', 50);
            m.add('pressure', ds);
            out = m.get('pressure');
            testCase.verifyEqual(out.BaseValue, 50, 'get_returns_source');
        end

        function testKeys(testCase)
            m = DataSourceMap();
            m.add('a', MockDataSource());
            m.add('b', MockDataSource());
            k = m.keys();
            testCase.verifyEqual(numel(k), 2, 'two_keys');
            testCase.verifyTrue(ismember('a', k) && ismember('b', k), 'correct_keys');
        end

        function testHas(testCase)
            m = DataSourceMap();
            m.add('x', MockDataSource());
            testCase.verifyTrue(m.has('x'), 'has_true');
            testCase.verifyTrue(~m.has('y'), 'has_false');
        end

        function testUnknownKeyErrors(testCase)
            m = DataSourceMap();
            threw = false;
            try
                m.get('nope');
                error('Should not reach here');
            catch ex
                threw = true;
                testCase.verifyTrue(contains(ex.identifier, 'unknownKey'), 'error_id');
            end
            testCase.verifyTrue(threw, 'should throw on unknown key');
        end

        function testRemove(testCase)
            m = DataSourceMap();
            m.add('x', MockDataSource());
            m.remove('x');
            testCase.verifyTrue(~m.has('x'), 'removed');
        end
    end
end
