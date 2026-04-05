classdef TestExternalSensorRegistry < matlab.unittest.TestCase
    properties
        TempDir
    end

    methods (TestMethodSetup)
        function createTempDir(testCase)
            testCase.TempDir = tempname();
            mkdir(testCase.TempDir);
            testCase.addTeardown(@() rmdir(testCase.TempDir, 's'));
        end
    end

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

        function testWireMatFile(testCase)
            % Create a .mat file with two signals
            time = [1 2 3 4 5];
            temp_bearing = [20 21 22 23 24];
            press_oil = [5 5.1 5.2 5.3 5.4];
            matPath = fullfile(testCase.TempDir, 'data.mat');
            save(matPath, 'time', 'temp_bearing', 'press_oil');

            reg = ExternalSensorRegistry('TestLab');
            reg.register('bearing_temp', Sensor('bearing_temp'));
            reg.register('oil_pressure', Sensor('oil_pressure'));

            reg.wireMatFile(matPath, {
                'bearing_temp',  'XVar', 'time', 'YVar', 'temp_bearing'
                'oil_pressure',  'XVar', 'time', 'YVar', 'press_oil'
            });

            % Verify Sensor properties were set
            s1 = reg.get('bearing_temp');
            testCase.verifyEqual(s1.MatFile, matPath, 'matfile_set');

            % Verify DataSourceMap was populated
            dsMap = reg.getDataSourceMap();
            testCase.verifyTrue(dsMap.has('bearing_temp'), 'ds_bearing');
            testCase.verifyTrue(dsMap.has('oil_pressure'), 'ds_oil');
        end

        function testWireMatFileUnknownKeyThrows(testCase)
            matPath = fullfile(testCase.TempDir, 'empty.mat');
            x = 1; save(matPath, 'x');

            reg = ExternalSensorRegistry('TestLab');
            threw = false;
            try
                reg.wireMatFile(matPath, {'nonexistent', 'XVar', 'x', 'YVar', 'x'});
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'should_throw_unknown_key');
        end

        function testWireMatFileDuplicateWarns(testCase)
            time = [1 2 3]; val = [10 20 30];
            matPath = fullfile(testCase.TempDir, 'data.mat');
            save(matPath, 'time', 'val');

            reg = ExternalSensorRegistry('TestLab');
            reg.register('s1', Sensor('s1'));
            reg.wireMatFile(matPath, {'s1', 'XVar', 'time', 'YVar', 'val'});

            % Wire again — should warn but not error
            lastwarn('');
            reg.wireMatFile(matPath, {'s1', 'XVar', 'time', 'YVar', 'val'});
            [~, warnId] = lastwarn();
            testCase.verifyEqual(warnId, 'ExternalSensorRegistry:overwrite', 'overwrite_warned');

            % Should still work
            dsMap = reg.getDataSourceMap();
            testCase.verifyTrue(dsMap.has('s1'), 'still_wired');
        end

        function testGetDataSourceMap(testCase)
            reg = ExternalSensorRegistry('TestLab');
            dsMap = reg.getDataSourceMap();
            testCase.verifyTrue(isa(dsMap, 'DataSourceMap'), 'returns_dsmap');
        end

        function testWireStateChannelSameFile(testCase)
            % State data in same file as sensor data
            time = [1 2 3 4 5];
            val = [10 20 30 40 50];
            state_time = [1 3];
            state_val = {{'idle', 'running'}};
            matPath = fullfile(testCase.TempDir, 'combined.mat');
            save(matPath, 'time', 'val', 'state_time', 'state_val');

            reg = ExternalSensorRegistry('TestLab');
            reg.register('s1', Sensor('s1'));
            reg.wireMatFile(matPath, {'s1', 'XVar', 'time', 'YVar', 'val'});
            reg.wireStateChannel('s1', 'machine_state', matPath, ...
                'XVar', 'state_time', 'YVar', 'state_val');

            s = reg.get('s1');
            testCase.verifyEqual(numel(s.StateChannels), 1, 'one_state_channel');
            testCase.verifyEqual(s.StateChannels{1}.Key, 'machine_state', 'sc_key');

            % For same-file case, DataSource should have StateXVar/StateYVar set
            ds = reg.getDataSourceMap().get('s1');
            testCase.verifyEqual(ds.StateXVar, 'state_time', 'ds_stateXVar');
            testCase.verifyEqual(ds.StateYVar, 'state_val', 'ds_stateYVar');
        end

        function testWireStateChannelDifferentFile(testCase)
            % Sensor data in one file, state data in another
            time = [1 2 3 4 5]; val = [10 20 30 40 50];
            sensorPath = fullfile(testCase.TempDir, 'sensor.mat');
            save(sensorPath, 'time', 'val');

            state_time = [1 3]; state_val = {{'idle', 'running'}};
            statePath = fullfile(testCase.TempDir, 'states.mat');
            save(statePath, 'state_time', 'state_val');

            reg = ExternalSensorRegistry('TestLab');
            reg.register('s1', Sensor('s1'));
            reg.wireMatFile(sensorPath, {'s1', 'XVar', 'time', 'YVar', 'val'});
            reg.wireStateChannel('s1', 'machine_state', statePath, ...
                'XVar', 'state_time', 'YVar', 'state_val');

            s = reg.get('s1');
            testCase.verifyEqual(numel(s.StateChannels), 1, 'one_state_channel');
            sc = s.StateChannels{1};
            testCase.verifyEqual(sc.MatFile, statePath, 'sc_matfile');
            testCase.verifyEqual(sc.KeyName, 'state_val', 'sc_keyname');

            % DataSource should NOT have StateXVar set (different file)
            ds = reg.getDataSourceMap().get('s1');
            testCase.verifyEqual(ds.StateXVar, '', 'ds_no_stateXVar');
        end

        function testWireStateChannelUnknownSensorThrows(testCase)
            reg = ExternalSensorRegistry('TestLab');
            threw = false;
            try
                reg.wireStateChannel('nonexistent', 'state', 'file.mat', ...
                    'XVar', 'x', 'YVar', 'y');
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'should_throw');
        end

        function testViewer(testCase)
            reg = ExternalSensorRegistry('TestLab');
            reg.register('temp', Sensor('temp', 'Name', 'Temperature', 'ID', 1));
            hFig = reg.viewer();
            testCase.addTeardown(@close, hFig);
            testCase.verifyTrue(ishandle(hFig), 'returns_figure');
        end

        function testViewerEmpty(testCase)
            reg = ExternalSensorRegistry('TestLab');
            hFig = reg.viewer();
            testCase.addTeardown(@close, hFig);
            testCase.verifyTrue(ishandle(hFig), 'handles_empty');
        end

        function testLivePipelineCompatibility(testCase)
            % Create .mat file with sensor data
            time = linspace(now - 1, now, 100);
            temp = randn(1, 100) * 5 + 50;
            matPath = fullfile(testCase.TempDir, 'live.mat');
            save(matPath, 'time', 'temp');

            % Build registry
            reg = ExternalSensorRegistry('IntegrationTest');
            s = Sensor('temp', 'Name', 'Temperature', 'Units', 'degC');
            t_warning = Threshold('warning', 'Name', 'Warning', 'Direction', 'upper');
            t_warning.addCondition(struct(), 60);
            s.addThreshold(t_warning);
            reg.register('temp', s);
            reg.wireMatFile(matPath, {'temp', 'XVar', 'time', 'YVar', 'temp'});

            % Verify outputs are the right types for LiveEventPipeline
            dsMap = reg.getDataSourceMap();
            sensors = reg.getAll();

            testCase.verifyTrue(isa(dsMap, 'DataSourceMap'), 'dsMap_type');
            testCase.verifyTrue(isa(sensors, 'containers.Map'), 'sensors_type');

            % Verify DataSource can fetch data
            ds = dsMap.get('temp');
            result = ds.fetchNew();
            testCase.verifyTrue(result.changed, 'fetched_data');
            testCase.verifyEqual(numel(result.X), 100, 'all_points');
        end
    end
end
