classdef TestLoadModuleData < matlab.unittest.TestCase

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Static)
        function ms = makeModuleStruct(sensorKeys, nPoints)
            %MAKEMODULESTRUCT Build a fake module struct for testing.
            ms.time_utc = linspace(datenum(2024,1,1), datenum(2024,1,2), nPoints);
            for i = 1:numel(sensorKeys)
                ms.(sensorKeys{i}) = randn(1, nPoints);
                ms.doc.(sensorKeys{i}).name = sensorKeys{i};
                ms.doc.(sensorKeys{i}).datum = 'time_utc';
            end
        end
    end

    methods (Test)
        function testBasicMatch(testCase)
            % 3 sensors registered, 3 fields in struct — all match
            reg = ExternalSensorRegistry('Test');
            reg.register('temp', Sensor('temp'));
            reg.register('press', Sensor('press'));
            reg.register('flow', Sensor('flow'));

            ms = TestLoadModuleData.makeModuleStruct({'temp', 'press', 'flow'}, 100);
            sensors = loadModuleData(reg, ms);

            testCase.verifyEqual(numel(sensors), 3, 'all_matched');
            for i = 1:numel(sensors)
                testCase.verifyEqual(numel(sensors{i}.X), 100, 'X_length');
                testCase.verifyEqual(numel(sensors{i}.Y), 100, 'Y_length');
            end
        end

        function testPartialMatch(testCase)
            % 2 sensors registered, struct has 3 fields + doc + datenum
            reg = ExternalSensorRegistry('Test');
            reg.register('temp', Sensor('temp'));
            reg.register('press', Sensor('press'));

            ms = TestLoadModuleData.makeModuleStruct({'temp', 'press', 'flow'}, 50);
            sensors = loadModuleData(reg, ms);

            testCase.verifyEqual(numel(sensors), 2, 'partial_match');
        end

        function testNoMatch(testCase)
            % Registry has sensors not in struct
            reg = ExternalSensorRegistry('Test');
            reg.register('voltage', Sensor('voltage'));

            ms = TestLoadModuleData.makeModuleStruct({'temp', 'press'}, 50);
            sensors = loadModuleData(reg, ms);

            testCase.verifyTrue(isempty(sensors), 'no_match_empty');
            testCase.verifyEqual(size(sensors), [1 0], 'empty_1x0');
        end

        function testEmptyRegistry(testCase)
            reg = ExternalSensorRegistry('Test');
            ms = TestLoadModuleData.makeModuleStruct({'temp'}, 50);
            sensors = loadModuleData(reg, ms);

            testCase.verifyTrue(isempty(sensors), 'empty_registry');
            testCase.verifyEqual(size(sensors), [1 0], 'empty_registry_1x0');
        end

        function testSharedXValues(testCase)
            % All matched sensors receive the same X values
            reg = ExternalSensorRegistry('Test');
            reg.register('a', Sensor('a'));
            reg.register('b', Sensor('b'));

            ms = TestLoadModuleData.makeModuleStruct({'a', 'b'}, 100);
            sensors = loadModuleData(reg, ms);

            testCase.verifyEqual(sensors{1}.X, sensors{2}.X, 'shared_X');
            testCase.verifyEqual(sensors{1}.X, ms.time_utc, 'X_matches_datenum');
        end

        function testOutputOrderFollowsFieldnames(testCase)
            % Output order matches fieldnames(moduleStruct), not registry order
            reg = ExternalSensorRegistry('Test');
            reg.register('beta', Sensor('beta'));
            reg.register('alpha', Sensor('alpha'));

            % Struct fields: doc, time_utc, alpha, beta
            ms = TestLoadModuleData.makeModuleStruct({'alpha', 'beta'}, 10);
            sensors = loadModuleData(reg, ms);

            testCase.verifyEqual(sensors{1}.Key, 'alpha', 'first_is_alpha');
            testCase.verifyEqual(sensors{2}.Key, 'beta', 'second_is_beta');
        end

        function testDocFieldExcluded(testCase)
            % Even if registry has a sensor named 'doc', it should be excluded
            reg = ExternalSensorRegistry('Test');
            reg.register('doc', Sensor('doc'));
            reg.register('temp', Sensor('temp'));

            ms.doc.temp.name = 'Temperature';
            ms.doc.temp.datum = 'time_utc';
            ms.time_utc = linspace(datenum(2024,1,1), datenum(2024,1,2), 50);
            ms.temp = randn(1, 50);
            sensors = loadModuleData(reg, ms);

            testCase.verifyEqual(numel(sensors), 1, 'doc_excluded');
            testCase.verifyEqual(sensors{1}.Key, 'temp', 'only_temp');
        end

        function testDatenumFieldExcluded(testCase)
            % If registry has a sensor with same name as datenum field, exclude it
            reg = ExternalSensorRegistry('Test');
            reg.register('time_utc', Sensor('time_utc'));
            reg.register('temp', Sensor('temp'));

            ms = TestLoadModuleData.makeModuleStruct({'temp'}, 50);
            sensors = loadModuleData(reg, ms);

            testCase.verifyEqual(numel(sensors), 1, 'datenum_excluded');
            testCase.verifyEqual(sensors{1}.Key, 'temp', 'only_temp');
        end

        function testMissingDocFieldErrors(testCase)
            reg = ExternalSensorRegistry('Test');
            ms = struct('temp', [1 2 3]);  % no doc field
            threw = false;
            try
                loadModuleData(reg, ms);
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'missing_doc_throws');
        end

        function testDocMissingDatumErrors(testCase)
            % doc entry without .datum field
            reg = ExternalSensorRegistry('Test');
            ms.doc.temp.name = 'Temperature';  % no .datum
            ms.temp = [1 2 3];
            threw = false;
            try
                loadModuleData(reg, ms);
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'missing_datum_throws');
        end

        function testDatenumFieldNotInStructErrors(testCase)
            reg = ExternalSensorRegistry('Test');
            ms.doc.temp.name = 'Temperature';
            ms.doc.temp.datum = 'nonexistent';
            ms.temp = [1 2 3];
            threw = false;
            try
                loadModuleData(reg, ms);
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'bad_datenum_ref_throws');
        end

        function testDatumNotCharErrors(testCase)
            % Defensive test: validates datum type
            reg = ExternalSensorRegistry('Test');
            ms.doc.temp.name = 'Temperature';
            ms.doc.temp.datum = 42;
            ms.temp = [1 2 3];
            threw = false;
            try
                loadModuleData(reg, ms);
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'non_char_datum_throws');
        end

        function testOutputIsRowCell(testCase)
            reg = ExternalSensorRegistry('Test');
            reg.register('temp', Sensor('temp'));

            ms = TestLoadModuleData.makeModuleStruct({'temp'}, 10);
            sensors = loadModuleData(reg, ms);

            testCase.verifyEqual(size(sensors, 1), 1, 'row_cell');
        end

        function testOverwriteOnRepeatedCall(testCase)
            % Calling twice overwrites sensor data (handle semantics)
            reg = ExternalSensorRegistry('Test');
            reg.register('temp', Sensor('temp'));

            ms1 = TestLoadModuleData.makeModuleStruct({'temp'}, 50);
            sensors1 = loadModuleData(reg, ms1);

            ms2 = TestLoadModuleData.makeModuleStruct({'temp'}, 100);
            sensors2 = loadModuleData(reg, ms2);

            % Same handle, new data — verify via both references
            testCase.verifyEqual(numel(sensors2{1}.Y), 100, 'overwritten_Y');
            testCase.verifyEqual(numel(sensors1{1}.Y), 100, 'sensors1_also_overwritten');
            testCase.verifyTrue(sensors1{1} == sensors2{1}, 'same_handle');
        end
    end
end
