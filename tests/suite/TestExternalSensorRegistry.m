classdef TestExternalSensorRegistry < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testConstructor(testCase)
            reg = ExternalSensorRegistry('TestLab');
            testCase.verifyEqual(reg.Name, 'TestLab', 'name_set');
        end

        function testEmptyOnCreation(testCase)
            reg = ExternalSensorRegistry('TestLab');
            testCase.verifyEqual(reg.count(), 0, 'empty_count');
            testCase.verifyTrue(isempty(reg.keys()), 'empty_keys');
        end

        function testRegisterAndGet(testCase)
            reg = ExternalSensorRegistry('TestLab');
            s = Sensor('temp', 'Name', 'Temperature');
            reg.register('temp', s);
            out = reg.get('temp');
            testCase.verifyEqual(out.Key, 'temp', 'get_key');
            testCase.verifyEqual(out.Name, 'Temperature', 'get_name');
            testCase.verifyEqual(reg.count(), 1, 'count_after_register');
        end

        function testGetUnknownKeyThrows(testCase)
            reg = ExternalSensorRegistry('TestLab');
            threw = false;
            try
                reg.get('nonexistent');
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'should_throw');
        end

        function testUnregister(testCase)
            reg = ExternalSensorRegistry('TestLab');
            reg.register('temp', Sensor('temp'));
            reg.unregister('temp');
            testCase.verifyEqual(reg.count(), 0, 'empty_after_unregister');
        end

        function testGetMultiple(testCase)
            reg = ExternalSensorRegistry('TestLab');
            reg.register('a', Sensor('a'));
            reg.register('b', Sensor('b'));
            out = reg.getMultiple({'a', 'b'});
            testCase.verifyEqual(numel(out), 2, 'getMultiple_count');
            testCase.verifyEqual(out{1}.Key, 'a', 'getMultiple_key1');
            testCase.verifyEqual(out{2}.Key, 'b', 'getMultiple_key2');
        end

        function testGetAll(testCase)
            reg = ExternalSensorRegistry('TestLab');
            reg.register('a', Sensor('a'));
            reg.register('b', Sensor('b'));
            m = reg.getAll();
            testCase.verifyTrue(isa(m, 'containers.Map'), 'getAll_type');
            testCase.verifyEqual(m.Count, uint64(2), 'getAll_count');
        end

        function testGetAllReturnsCopy(testCase)
            reg = ExternalSensorRegistry('TestLab');
            reg.register('a', Sensor('a'));
            m = reg.getAll();
            m('injected') = Sensor('injected');
            % Original registry should be unaffected
            testCase.verifyEqual(reg.count(), 1, 'copy_not_mutated');
        end

        function testRegisterNonSensorThrows(testCase)
            reg = ExternalSensorRegistry('TestLab');
            threw = false;
            try
                reg.register('bad', struct('Key', 'bad'));
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'should_throw_non_sensor');
        end

        function testUnregisterNonexistentNoError(testCase)
            reg = ExternalSensorRegistry('TestLab');
            reg.unregister('nonexistent');  % should not error
        end

        function testListNoError(testCase)
            reg = ExternalSensorRegistry('TestLab');
            reg.register('temp', Sensor('temp', 'Name', 'Temperature'));
            reg.list();  % should not error
        end

        function testListEmpty(testCase)
            reg = ExternalSensorRegistry('TestLab');
            reg.list();  % should not error on empty registry
        end

        function testPrintTableNoError(testCase)
            reg = ExternalSensorRegistry('TestLab');
            reg.register('temp', Sensor('temp', 'Name', 'Temperature', 'ID', 1));
            reg.printTable();  % should not error
        end

        function testPrintTableEmpty(testCase)
            reg = ExternalSensorRegistry('TestLab');
            reg.printTable();  % should not error on empty registry
        end
    end
end
